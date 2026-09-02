part of 'image_optimizer_cubit.dart';

final class FailedToPickImage extends ImageOptimizerState {
  const FailedToPickImage({required super.minimumQuality});

  factory FailedToPickImage.fromImageOptimizerState(
    ImageOptimizerState state,
  ) => FailedToPickImage(minimumQuality: state.minimumQuality);

  @override
  ImageOptimizerState copyWith({int? minimumQuality}) =>
      FailedToPickImage(minimumQuality: minimumQuality ?? this.minimumQuality);
}

final class ImageOptimizerFailure extends ImageOptimizerFilePicked {
  const ImageOptimizerFailure({
    required this.exception,
    required super.pickedFile,
    required super.outputPath,
    required super.minimumQuality,
  });

  factory ImageOptimizerFailure.fromImageOptimizerState(
    ImageOptimizerFilePicked state, {
    required ImageOptimizationException exception,
  }) => ImageOptimizerFailure(
    exception: exception,
    pickedFile: state.pickedFile,
    outputPath: state.outputPath,
    minimumQuality: state.minimumQuality,
  );

  final ImageOptimizationException exception;

  @override
  List<Object?> get props => [...super.props, exception];

  @override
  ImageOptimizerState copyWith({
    int? minimumQuality,
    XFile? pickedFile,
    String? outputPath,
    ImageOptimizationException? exception,
  }) => ImageOptimizerFailure(
    exception: exception ?? this.exception,
    pickedFile: pickedFile ?? this.pickedFile,
    outputPath: outputPath ?? this.outputPath,
    minimumQuality: minimumQuality ?? this.minimumQuality,
  );
}

sealed class ImageOptimizerFilePicked extends ImageOptimizerState {
  const ImageOptimizerFilePicked({
    required this.pickedFile,
    required this.outputPath,
    required super.minimumQuality,
  });

  final XFile pickedFile;
  final String outputPath;

  @override
  List<Object?> get props => [...super.props, pickedFile, outputPath];

  @override
  ImageOptimizerState copyWith({
    int? minimumQuality,
    XFile? pickedFile,
    String? outputPath,
  });
}

final class ImageOptimizerInitial extends ImageOptimizerState {
  const ImageOptimizerInitial({super.minimumQuality = 80});

  @override
  ImageOptimizerState copyWith({int? minimumQuality}) => ImageOptimizerInitial(
    minimumQuality: minimumQuality ?? this.minimumQuality,
  );
}

final class ImageOptimizerOptimizing extends ImageOptimizerFilePicked {
  const ImageOptimizerOptimizing({
    required super.pickedFile,
    required super.outputPath,
    required super.minimumQuality,
  });

  factory ImageOptimizerOptimizing.fromImageOptimizerState(
    ImageOptimizerState state, {
    required XFile pickedFile,
    required String outputPath,
  }) => ImageOptimizerOptimizing(
    pickedFile: pickedFile,
    outputPath: outputPath,
    minimumQuality: state.minimumQuality,
  );

  @override
  ImageOptimizerState copyWith({
    int? minimumQuality,
    XFile? pickedFile,
    String? outputPath,
  }) => ImageOptimizerOptimizing(
    pickedFile: pickedFile ?? this.pickedFile,
    outputPath: outputPath ?? this.outputPath,
    minimumQuality: minimumQuality ?? this.minimumQuality,
  );
}

sealed class ImageOptimizerState extends Equatable {
  const ImageOptimizerState({required this.minimumQuality});

  final int minimumQuality;

  @override
  List<Object?> get props => [minimumQuality];

  ImageOptimizerState copyWith({int? minimumQuality});
}

final class OptimizeImageSuccess extends ImageOptimizerFilePicked {
  const OptimizeImageSuccess({
    required super.pickedFile,
    required super.outputPath,
    required this.outputQuality,
    required this.frameCount,
    required super.minimumQuality,
  });

  /// [minimumQuality] is the value the conversion actually ran with, which is
  /// not always `state.minimumQuality`: the slider stays live while the
  /// isolate works, so it can move between the request and the result.
  factory OptimizeImageSuccess.fromImageOptimizerState(
    ImageOptimizerFilePicked state, {
    required int frameCount,
    required int minimumQuality,
    required int outputQuality,
  }) => OptimizeImageSuccess(
    pickedFile: state.pickedFile,
    outputPath: state.outputPath,
    outputQuality: outputQuality,
    frameCount: frameCount,
    minimumQuality: minimumQuality,
  );

  /// Frames in the output. 1 for a still image, more for an animation.
  final int frameCount;
  final int outputQuality;

  bool get isAnimated => frameCount > 1;

  Future<int> get outputFileSizeBytes async => File(outputPath).length();

  @override
  List<Object?> get props => [...super.props, outputQuality, frameCount];

  Future<int> get sizeDifferenceBytes async {
    final inputFile = File(pickedFile.path);
    final outputFile = File(outputPath);

    final [inputSize, outputSize] = await Future.wait([
      inputFile.length(),
      outputFile.length(),
    ]);

    return outputSize - inputSize;
  }

  @override
  ImageOptimizerState copyWith({
    int? minimumQuality,
    XFile? pickedFile,
    String? outputPath,
    int? outputQuality,
    int? frameCount,
  }) => OptimizeImageSuccess(
    pickedFile: pickedFile ?? this.pickedFile,
    outputPath: outputPath ?? this.outputPath,
    outputQuality: outputQuality ?? this.outputQuality,
    frameCount: frameCount ?? this.frameCount,
    minimumQuality: minimumQuality ?? this.minimumQuality,
  );
}
