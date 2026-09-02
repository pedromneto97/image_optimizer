import 'package:equatable/equatable.dart';

class OptimizationResult extends Equatable {
  const OptimizationResult({
    required this.frameCount,
    required this.outputPath,
    required this.selectedQuality,
  });

  /// Frames written to the output. 1 for a still image, more for an animation.
  final int frameCount;
  final String outputPath;
  final int selectedQuality;

  bool get isAnimated => frameCount > 1;

  @override
  List<Object> get props => [outputPath, selectedQuality, frameCount];
}
