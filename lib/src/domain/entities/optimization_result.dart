class OptimizationResult {
  const OptimizationResult({
    required this.outputPath,
    required this.selectedQuality,
    required this.convertedSizeBytes,
  });

  final String outputPath;
  final int selectedQuality;
  final int convertedSizeBytes;
}
