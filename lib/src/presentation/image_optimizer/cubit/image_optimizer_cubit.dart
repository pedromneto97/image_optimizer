import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
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

      final outputPath = await _buildOutputPath(
        pickedFile.name.split('.').first,
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
        minimumQuality: state.minimumQuality,
      );

      emit(
        OptimizeImageSuccess.fromImageOptimizerState(
          state as ImageOptimizerFilePicked,
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
      emit(FailedToPickImage.fromImageOptimizerState(state));
    }
  }

  void updateMinimumQuality(int value) {
    final minimumQuality = value.round().clamp(0, 100).toInt();

    emit(state.copyWith(minimumQuality: minimumQuality));
  }

  Future<String> _buildOutputPath(String fileName) async {
    final outputDir = await getApplicationDocumentsDirectory();

    return '${outputDir.path}${Platform.pathSeparator}${fileName}_${DateTime.now().millisecondsSinceEpoch}.webp';
  }
}
