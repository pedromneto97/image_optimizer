import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/usecases/optimize_image.dart';
import 'image_optimizer_state.dart';

class ImageOptimizerCubit extends Cubit<ImageOptimizerState> {
  ImageOptimizerCubit({
    required OptimizeImage optimizeImage,
    ImagePicker? imagePicker,
  })  : _optimizeImage = optimizeImage,
        _imagePicker = imagePicker ?? ImagePicker(),
        super(const ImageOptimizerInitial());

  final OptimizeImage _optimizeImage;
  final ImagePicker _imagePicker;

  Future<void> pickImage() async {
    final previousState = state;
    emit(ImageOptimizerPicking(minimumQuality: state.minimumQuality));

    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        emit(previousState);
        return;
      }

      final file = File(image.path);
      emit(
        ImageOptimizerReady(
          selectedInputPath: image.path,
          selectedOriginalSizeBytes: await file.length(),
          minimumQuality: state.minimumQuality,
        ),
      );
    } on Exception catch (error) {
      emit(
        ImageOptimizerFailure(previousState: previousState, exception: error),
      );
    }
  }

  void updateMinimumQuality(double value) {
    final minimumQuality = value.round().clamp(0, 100).toInt();
    final currentState = state;

    switch (currentState) {
      case ImageOptimizerReady():
        emit(currentState.copyWith(minimumQuality: minimumQuality));
      case ImageOptimizerFailure(previousState: final previousState):
        emit(_withMinimumQuality(previousState, minimumQuality));
      default:
        emit(_MinimumQualityOnlyState(minimumQuality: minimumQuality));
    }
  }

  Future<void> optimizeSelectedImage() async {
    final readyState = _readyStateFrom(state);
    if (readyState == null) {
      emit(
        ImageOptimizerFailure(
          previousState: state,
          exception: const ImageNotSelectedException(),
        ),
      );
      return;
    }

    emit(
      ImageOptimizerOptimizing(
        readyState: readyState.copyWith(clearResult: true),
      ),
    );

    try {
      final outputPath = _buildOutputPath(readyState.inputPath);
      final result = await _optimizeImage(
        inputPath: readyState.inputPath,
        minimumQuality: readyState.minimumQuality,
        outputPath: outputPath,
      );

      emit(readyState.copyWith(optimizationResult: result));
    } on Exception catch (error) {
      emit(ImageOptimizerFailure(previousState: readyState, exception: error));
    }
  }

  ImageOptimizerReady? _readyStateFrom(ImageOptimizerState state) {
    return switch (state) {
      ImageOptimizerReady() => state,
      ImageOptimizerFailure(previousState: final previousState) =>
        _readyStateFrom(previousState),
      _ => null,
    };
  }

  ImageOptimizerState _withMinimumQuality(
    ImageOptimizerState state,
    int minimumQuality,
  ) {
    return switch (state) {
      ImageOptimizerReady() => state.copyWith(minimumQuality: minimumQuality),
      _ => _MinimumQualityOnlyState(minimumQuality: minimumQuality),
    };
  }

  String _buildOutputPath(String inputPath) {
    final file = File(inputPath);
    final directory = file.parent.path;
    final name = file.uri.pathSegments.last;
    final dotIndex = name.lastIndexOf('.');
    final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;

    return '$directory${Platform.pathSeparator}$baseName.optimized.webp';
  }
}

class ImageNotSelectedException implements Exception {
  const ImageNotSelectedException();
}

class _MinimumQualityOnlyState extends ImageOptimizerState {
  const _MinimumQualityOnlyState({required super.minimumQuality});

  @override
  List<Object?> get props => [minimumQuality];
}
