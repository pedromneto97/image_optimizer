import 'package:equatable/equatable.dart';

class OptimizationResult extends Equatable {
  const OptimizationResult({
    required this.outputPath,
    required this.selectedQuality,
    required this.convertedSizeBytes,
  });

  final String outputPath;
  final int selectedQuality;
  final int convertedSizeBytes;

  @override
  List<Object> get props => [outputPath, selectedQuality, convertedSizeBytes];
}
