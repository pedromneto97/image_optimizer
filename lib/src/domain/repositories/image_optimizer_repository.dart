import '../entities/optimization_result.dart';

abstract interface class ImageOptimizerRepository {
  Future<OptimizationResult> optimize({
    required String inputPath,
    required int minimumQuality,
    required String outputPath,
  });
}
