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
        super(const ImageOptimizerState());

  final OptimizeImage _optimizeImage;
  final ImagePicker _imagePicker;

  Future<void> pickImage() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        emit(state.copyWith(isLoading: false));
        return;
      }

      final file = File(image.path);
      emit(
        state.copyWith(
          inputPath: image.path,
          originalSizeBytes: await file.length(),
          isLoading: false,
          clearResult: true,
          clearError: true,
        ),
      );
    } on Exception catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not pick an image: $error',
        ),
      );
    }
  }

  void updateMinimumQuality(double value) {
    emit(
      state.copyWith(
        minimumQuality: value.round().clamp(0, 100).toInt(),
        clearError: true,
      ),
    );
  }

  Future<void> optimizeSelectedImage() async {
    final inputPath = state.inputPath;
    if (inputPath == null) {
      emit(state.copyWith(errorMessage: 'Choose an image before optimizing.'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true, clearResult: true));

    try {
      final outputPath = _buildOutputPath(inputPath);
      final result = await _optimizeImage(
        inputPath: inputPath,
        minimumQuality: state.minimumQuality,
        outputPath: outputPath,
      );

      emit(
        state.copyWith(
          isLoading: false,
          outputPath: result.outputPath,
          outputQuality: result.selectedQuality,
          convertedSizeBytes: result.convertedSizeBytes,
          clearError: true,
        ),
      );
    } on Exception catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
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
