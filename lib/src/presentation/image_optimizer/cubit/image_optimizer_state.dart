import 'package:equatable/equatable.dart';

import '../../../domain/entities/optimization_result.dart';

sealed class ImageOptimizerState extends Equatable {
  const ImageOptimizerState({this.minimumQuality = 80});

  final int minimumQuality;

  String? get inputPath => null;
  int? get originalSizeBytes => null;
  OptimizationResult? get result => null;
  bool get isBusy => false;
  bool get canOptimize => inputPath != null && !isBusy;

  int? get outputQuality => result?.selectedQuality;
  String? get outputPath => result?.outputPath;
  int? get convertedSizeBytes => result?.convertedSizeBytes;

  int? get sizeDifferenceBytes {
    final original = originalSizeBytes;
    final converted = convertedSizeBytes;
    if (original == null || converted == null) {
      return null;
    }
    return converted - original;
  }
}

class ImageOptimizerInitial extends ImageOptimizerState {
  const ImageOptimizerInitial() : super(minimumQuality: 80);

  @override
  List<Object?> get props => [minimumQuality];
}

class ImageOptimizerPicking extends ImageOptimizerState {
  const ImageOptimizerPicking({required super.minimumQuality});

  @override
  bool get isBusy => true;

  @override
  List<Object?> get props => [minimumQuality];
}

class ImageOptimizerReady extends ImageOptimizerState {
  const ImageOptimizerReady({
    required this.selectedInputPath,
    required this.selectedOriginalSizeBytes,
    required super.minimumQuality,
    this.optimizationResult,
  });

  final String selectedInputPath;
  final int selectedOriginalSizeBytes;
  final OptimizationResult? optimizationResult;

  @override
  String get inputPath => selectedInputPath;

  @override
  int get originalSizeBytes => selectedOriginalSizeBytes;

  @override
  OptimizationResult? get result => optimizationResult;

  ImageOptimizerReady copyWith({
    int? minimumQuality,
    OptimizationResult? optimizationResult,
    bool clearResult = false,
  }) {
    return ImageOptimizerReady(
      selectedInputPath: selectedInputPath,
      selectedOriginalSizeBytes: selectedOriginalSizeBytes,
      minimumQuality: minimumQuality ?? this.minimumQuality,
      optimizationResult: clearResult
          ? null
          : optimizationResult ?? this.optimizationResult,
    );
  }

  @override
  List<Object?> get props => [
        selectedInputPath,
        selectedOriginalSizeBytes,
        minimumQuality,
        optimizationResult,
      ];
}

class ImageOptimizerOptimizing extends ImageOptimizerState {
  const ImageOptimizerOptimizing({required this.readyState})
      : super(minimumQuality: readyState.minimumQuality);

  final ImageOptimizerReady readyState;

  @override
  String get inputPath => readyState.inputPath;

  @override
  int get originalSizeBytes => readyState.originalSizeBytes;

  @override
  bool get isBusy => true;

  @override
  List<Object?> get props => [readyState];
}

class ImageOptimizerFailure extends ImageOptimizerState {
  const ImageOptimizerFailure({
    required this.previousState,
    required this.exception,
  }) : super(minimumQuality: previousState.minimumQuality);

  final ImageOptimizerState previousState;
  final Exception exception;

  @override
  String? get inputPath => previousState.inputPath;

  @override
  int? get originalSizeBytes => previousState.originalSizeBytes;

  @override
  OptimizationResult? get result => previousState.result;

  @override
  List<Object?> get props => [previousState, exception];
}
