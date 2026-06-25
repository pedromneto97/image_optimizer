import '../entities/optimization_result.dart';
import '../repositories/image_optimizer_repository.dart';

class OptimizeImage {
  const OptimizeImage(this._repository);

  final ImageOptimizerRepository _repository;

  Future<OptimizationResult> call({
    required String inputPath,
    required int minimumQuality,
    required String outputPath,
  }) {
    return _repository.optimize(
      inputPath: inputPath,
      minimumQuality: minimumQuality,
      outputPath: outputPath,
    );
  }
}
