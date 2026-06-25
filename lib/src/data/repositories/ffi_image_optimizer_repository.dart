import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../domain/entities/optimization_result.dart';
import '../../domain/repositories/image_optimizer_repository.dart';
import '../../ffi.g.dart';

class FfiImageOptimizerRepository implements ImageOptimizerRepository {
  @override
  Future<OptimizationResult> optimize({
    required String inputPath,
    required int minimumQuality,
    required String outputPath,
  }) async {
    final inputPointer = inputPath.toNativeUtf8().cast<Char>();
    final outputPointer = outputPath.toNativeUtf8().cast<Char>();
    final resultPointer = calloc<OptimizeImageOutput>();

    try {
      final errorCode = optimize_image_ffi(
        inputPointer,
        minimumQuality.clamp(0, 100).toInt(),
        outputPointer,
        resultPointer,
      );
      final ffiResult = resultPointer.ref;
      final effectiveErrorCode = errorCode == 0 ? ffiResult.error_code : errorCode;

      if (effectiveErrorCode != 0) {
        throw ImageOptimizationException.fromCode(effectiveErrorCode);
      }

      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw const ImageOptimizationException(
          'The optimizer finished, but the output file was not created.',
        );
      }

      return OptimizationResult(
        outputPath: outputPath,
        selectedQuality: ffiResult.quality,
        convertedSizeBytes: await outputFile.length(),
      );
    } finally {
      calloc.free(inputPointer);
      calloc.free(outputPointer);
      calloc.free(resultPointer);
    }
  }
}

class ImageOptimizationException implements Exception {
  const ImageOptimizationException(this.message);

  factory ImageOptimizationException.fromCode(int code) {
    return ImageOptimizationException(
      switch (code) {
        1 => 'Input image file was not found.',
        2 => 'Failed to open the input image.',
        3 => 'This image type is not supported.',
        4 => 'WebP encoding failed.',
        5 => 'The optimized image could not be written.',
        -1 => 'Invalid optimizer parameters were provided.',
        _ => 'Image optimization failed with error code $code.',
      },
    );
  }

  final String message;

  @override
  String toString() => message;
}
