import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../domain/entities/optimization_result.dart';
import '../../domain/exceptions.dart';
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
      final effectiveErrorCode = errorCode == 0
          ? ffiResult.error_code
          : errorCode;

      if (effectiveErrorCode != 0) {
        throw _exceptionFromCode(effectiveErrorCode);
      }

      final outputFile = File(outputPath);
      if (!outputFile.existsSync()) {
        throw const MissingOutputImageException();
      }

      return OptimizationResult(
        outputPath: outputPath,
        selectedQuality: ffiResult.quality,
      );
    } finally {
      calloc
        ..free(inputPointer)
        ..free(outputPointer)
        ..free(resultPointer);
    }
  }

  ImageOptimizationException _exceptionFromCode(int code) => switch (code) {
    1 => const InputImageNotFoundException(),
    2 => const InputImageOpenException(),
    3 => const UnsupportedImageTypeException(),
    4 => const WebPEncodingException(),
    5 => const OutputImageWriteException(),
    -1 => const InvalidOptimizerParametersException(),
    _ => UnknownImageOptimizationException(code),
  };
}
