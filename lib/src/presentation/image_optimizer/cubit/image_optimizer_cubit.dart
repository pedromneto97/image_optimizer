import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' show basenameWithoutExtension, join;
import 'package:path_provider/path_provider.dart';

import '../../../domain/exceptions.dart';
import '../../../domain/usecases/optimize_image.dart';

part 'image_optimizer_state.dart';

class ImageOptimizerCubit extends Cubit<ImageOptimizerState> {
  ImageOptimizerCubit({required this._optimizeImage, ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker(),
      super(const ImageOptimizerInitial());

  final OptimizeImage _optimizeImage;
  final ImagePicker _imagePicker;

  Future<void> pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return;
      }

      // Pin the slider value for this run. The conversion isolate leaves the
      // UI live, so the slider can move while it works, and the result has to
      // report the quality the conversion was asked for — not the one the
      // slider happens to sit at when it lands.
      final minimumQuality = state.minimumQuality;
      final outputPath = await _buildOutputPath(
        basenameWithoutExtension(pickedFile.name),
      );
      emit(
        ImageOptimizerOptimizing.fromImageOptimizerState(
          state,
          outputPath: outputPath,
          pickedFile: pickedFile,
        ),
      );

      final result = await _optimizeImage.call(
        inputPath: pickedFile.path,
        outputPath: outputPath,
        minimumQuality: minimumQuality,
      );

      emit(
        OptimizeImageSuccess.fromImageOptimizerState(
          state as ImageOptimizerFilePicked,
          frameCount: result.frameCount,
          minimumQuality: minimumQuality,
          outputQuality: result.selectedQuality,
        ),
      );
    } on ImageOptimizationException catch (e) {
      emit(
        ImageOptimizerFailure.fromImageOptimizerState(
          state as ImageOptimizerFilePicked,
          exception: e,
        ),
      );
    } catch (e) {
      // Not every failure past this point is one of the optimizer's own error
      // codes — a dead conversion isolate throws a RemoteError. Once a file is
      // picked those still belong in the failure state, which the page renders;
      // FailedToPickImage drops the picked file and would show as nothing.
      final currentState = state;

      emit(
        currentState is ImageOptimizerFilePicked
            ? ImageOptimizerFailure.fromImageOptimizerState(
                currentState,
                exception: UnexpectedOptimizationFailureException(e),
              )
            : FailedToPickImage.fromImageOptimizerState(currentState),
      );
    }
  }

  void updateMinimumQuality(int value) {
    final minimumQuality = value.round().clamp(0, 100).toInt();

    emit(state.copyWith(minimumQuality: minimumQuality));
  }

  Future<String> _buildOutputPath(String fileName) async {
    final outputDir = await getApplicationDocumentsDirectory();

    return join(
      outputDir.path,
      '${fileName}_${DateTime.now().millisecondsSinceEpoch}.webp',
    );
  }
}
