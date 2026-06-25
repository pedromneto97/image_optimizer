import 'package:equatable/equatable.dart';

class OptimizationResult extends Equatable {
  const OptimizationResult({
    required this.outputPath,
    required this.selectedQuality,
  });

  final String outputPath;
  final int selectedQuality;

  @override
  List<Object> get props => [outputPath, selectedQuality];
}
