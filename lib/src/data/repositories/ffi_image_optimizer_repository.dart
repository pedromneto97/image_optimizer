import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

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
  }) => Isolate.run(
    () => _optimizeSync(
      inputPath: inputPath,
      minimumQuality: minimumQuality,
      outputPath: outputPath,
    ),
    debugName: 'optimize_image_ffi',
  );
}

/// Runs the conversion and blocks until it finishes.
///
/// Called through [Isolate.run] because the FFI call never yields: an animated
/// GIF re-encodes every frame once per quality candidate, which would freeze
/// the UI outright. Top-level so the closure captures only the arguments —
/// an `Isolate.run` closure cannot capture `this`. `@Native` bindings resolve
/// process-wide, so the symbol is callable from the spawned isolate.
OptimizationResult _optimizeSync({
  required String inputPath,
  required int minimumQuality,
  required String outputPath,
}) {
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
      _throwExceptionFromCode(effectiveErrorCode);
    }

    final outputFile = File(outputPath);
    if (!outputFile.existsSync()) {
      throw const MissingOutputImageException();
    }

    return OptimizationResult(
      frameCount: ffiResult.frame_count,
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

Never _throwExceptionFromCode(int code) => throw switch (code) {
  1 => const InputImageNotFoundException(),
  2 => const InputImageOpenException(),
  3 => const UnsupportedImageTypeException(),
  4 => const WebPEncodingException(),
  5 => const OutputImageWriteException(),
  6 => const AnimationDecodingException(),
  7 => const AnimationEncodingException(),
  -1 => const InvalidOptimizerParametersException(),
  _ => UnknownImageOptimizationException(code),
};
