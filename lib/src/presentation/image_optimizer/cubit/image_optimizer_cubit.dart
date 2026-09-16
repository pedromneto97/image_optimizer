import 'dart:io';
import 'dart:math' show min;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' show basenameWithoutExtension, join;
import 'package:path_provider/path_provider.dart';

import '../../../domain/exceptions.dart';
import '../../../domain/usecases/optimize_image.dart';

part 'image_optimization_item.dart';
part 'image_optimizer_state.dart';

class ImageOptimizerCubit extends Cubit<ImageOptimizerState> {
  ImageOptimizerCubit({
    required this._optimizeImage,
    ImagePicker? imagePicker,
    int? maxConcurrency,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _maxConcurrency = maxConcurrency ?? _defaultMaxConcurrency(),
       super(const ImageOptimizerInitial());

  final OptimizeImage _optimizeImage;
  final ImagePicker _imagePicker;
  final int _maxConcurrency;

  Future<void> pickImages() async {
    if (state is ImageOptimizerOptimizing) {
      return;
    }

    final List<ImageOptimizationItem> items;
    try {
      final pickedFiles = await _imagePicker.pickMultiImage();

      if (pickedFiles.isEmpty) {
        return;
      }

      // Pin the slider value for this batch. The conversion isolates leave the
      // UI live, so the slider can move while they work, and each result has
      // to report the quality its conversion was asked for — not the one the
      // slider happens to sit at when it lands.
      final minimumQuality = state.minimumQuality;
      final outputPaths = await _buildOutputPaths(pickedFiles);
      items = [
        for (final (index, pickedFile) in pickedFiles.indexed)
          PendingImage(
            pickedFile: pickedFile,
            outputPath: outputPaths[index],
            minimumQuality: minimumQuality,
          ),
      ];
    } catch (_) {
      if (!isClosed) {
        emit(FailedToPickImage.fromImageOptimizerState(state));
      }
      return;
    }

    // A second call can get past the guard above while the picker is open;
    // two pools writing items by index into each other's batch would corrupt
    // both.
    if (isClosed || state is ImageOptimizerOptimizing) {
      return;
    }

    emit(ImageOptimizerOptimizing.fromImageOptimizerState(state, items: items));

    // Workers share one cursor. It is only read and advanced synchronously,
    // so no two workers ever take the same item.
    var next = 0;
    Future<void> worker() async {
      while (!isClosed && next < items.length) {
        final index = next++;
        await _optimizeItem(index, items[index]);
      }
    }

    await Future.wait([
      for (var i = 0; i < min(_maxConcurrency, items.length); i++) worker(),
    ]);

    final currentState = state;
    if (!isClosed && currentState is ImageOptimizerFilesPicked) {
      emit(ImageOptimizerCompleted.fromImageOptimizerState(currentState));
    }
  }

  void updateMinimumQuality(int value) {
    final minimumQuality = value.round().clamp(0, 100).toInt();

    emit(state.copyWith(minimumQuality: minimumQuality));
  }

  /// One output path per picked file, `<input>_<epochMillis>.webp`.
  ///
  /// The whole batch shares one timestamp, so a basename that repeats — two
  /// `photo.jpg` picked from different folders — gets a `_<n>` suffix rather
  /// than overwriting the first. Names are compared case-insensitively because
  /// the macOS and Windows file systems are.
  Future<List<String>> _buildOutputPaths(List<XFile> files) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final occurrences = <String, int>{};
    final paths = <String>[];

    for (final file in files) {
      final fileName = basenameWithoutExtension(file.name);
      final occurrence = occurrences.update(
        fileName.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final suffix = occurrence > 1 ? '_$occurrence' : '';

      paths.add(join(outputDir.path, '${fileName}_$timestamp$suffix.webp'));
    }

    return paths;
  }

  Future<void> _optimizeItem(int index, ImageOptimizationItem item) async {
    final optimizing = OptimizingImage.fromImageOptimizationItem(item);
    _replaceItem(index, optimizing);

    final finished = await _convert(optimizing);

    if (!isClosed) {
      _replaceItem(index, finished);
    }
  }

  Future<ImageOptimizationItem> _convert(OptimizingImage item) async {
    try {
      final result = await _optimizeImage.call(
        inputPath: item.pickedFile.path,
        outputPath: item.outputPath,
        minimumQuality: item.minimumQuality,
      );
      final [inputSizeBytes, outputSizeBytes] = await Future.wait([
        File(item.pickedFile.path).length(),
        File(result.outputPath).length(),
      ]);

      return OptimizedImage.fromImageOptimizationItem(
        item,
        frameCount: result.frameCount,
        inputSizeBytes: inputSizeBytes,
        outputQuality: result.selectedQuality,
        outputSizeBytes: outputSizeBytes,
      );
    } on ImageOptimizationException catch (e) {
      return FailedImage.fromImageOptimizationItem(item, exception: e);
    } catch (e) {
      // Not every failure is one of the optimizer's own error codes — a dead
      // conversion isolate throws a RemoteError. It still belongs to this
      // item alone; the rest of the batch carries on.
      return FailedImage.fromImageOptimizationItem(
        item,
        exception: UnexpectedOptimizationFailureException(e),
      );
    }
  }

  /// Swaps one item for [item]. [state] is read and emitted with no `await` in
  /// between, so workers finishing at the same time cannot drop each other's
  /// updates.
  void _replaceItem(int index, ImageOptimizationItem item) {
    final currentState = state;
    if (currentState is! ImageOptimizerFilesPicked) {
      return;
    }

    emit(currentState.copyWith(items: [...currentState.items]..[index] = item));
  }
}

/// How many images convert at once. The encoder is single-threaded per image,
/// so each extra isolate is a real speedup, but animated GIFs are memory-heavy
/// to encode; the cap keeps a batch of them from exhausting memory.
int _defaultMaxConcurrency() =>
    (Platform.numberOfProcessors ~/ 2).clamp(1, 4).toInt();
