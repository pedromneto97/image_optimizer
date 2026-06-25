import 'package:flutter/foundation.dart';

@immutable
class ImageOptimizerState {
  const ImageOptimizerState({
    this.inputPath,
    this.originalSizeBytes,
    this.minimumQuality = 80,
    this.outputPath,
    this.outputQuality,
    this.convertedSizeBytes,
    this.isLoading = false,
    this.errorMessage,
  });

  final String? inputPath;
  final int? originalSizeBytes;
  final int minimumQuality;
  final String? outputPath;
  final int? outputQuality;
  final int? convertedSizeBytes;
  final bool isLoading;
  final String? errorMessage;

  int? get sizeDifferenceBytes {
    final original = originalSizeBytes;
    final converted = convertedSizeBytes;
    if (original == null || converted == null) {
      return null;
    }
    return converted - original;
  }

  bool get canOptimize => inputPath != null && !isLoading;

  ImageOptimizerState copyWith({
    String? inputPath,
    int? originalSizeBytes,
    int? minimumQuality,
    String? outputPath,
    int? outputQuality,
    int? convertedSizeBytes,
    bool? isLoading,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return ImageOptimizerState(
      inputPath: inputPath ?? this.inputPath,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
      minimumQuality: minimumQuality ?? this.minimumQuality,
      outputPath: clearResult ? null : outputPath ?? this.outputPath,
      outputQuality: clearResult ? null : outputQuality ?? this.outputQuality,
      convertedSizeBytes: clearResult
          ? null
          : convertedSizeBytes ?? this.convertedSizeBytes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
