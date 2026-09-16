part of 'image_optimizer_cubit.dart';

final class FailedImage extends ImageOptimizationItem {
  const FailedImage({
    required this.exception,
    required super.pickedFile,
    required super.outputPath,
    required super.minimumQuality,
  });

  factory FailedImage.fromImageOptimizationItem(
    ImageOptimizationItem item, {
    required ImageOptimizationException exception,
  }) => FailedImage(
    exception: exception,
    pickedFile: item.pickedFile,
    outputPath: item.outputPath,
    minimumQuality: item.minimumQuality,
  );

  final ImageOptimizationException exception;

  @override
  List<Object?> get props => [...super.props, exception];
}

/// One picked file in a batch, and how far its conversion has got.
sealed class ImageOptimizationItem extends Equatable {
  const ImageOptimizationItem({
    required this.pickedFile,
    required this.outputPath,
    required this.minimumQuality,
  });

  final XFile pickedFile;
  final String outputPath;

  /// The value the batch was started with, which is not always
  /// `state.minimumQuality`: the slider stays live while the isolates work, so
  /// it can move between the request and the result.
  final int minimumQuality;

  @override
  List<Object?> get props => [pickedFile, outputPath, minimumQuality];
}

final class OptimizedImage extends ImageOptimizationItem {
  const OptimizedImage({
    required this.frameCount,
    required this.inputSizeBytes,
    required this.outputQuality,
    required this.outputSizeBytes,
    required super.pickedFile,
    required super.outputPath,
    required super.minimumQuality,
  });

  factory OptimizedImage.fromImageOptimizationItem(
    ImageOptimizationItem item, {
    required int frameCount,
    required int inputSizeBytes,
    required int outputQuality,
    required int outputSizeBytes,
  }) => OptimizedImage(
    frameCount: frameCount,
    inputSizeBytes: inputSizeBytes,
    outputQuality: outputQuality,
    outputSizeBytes: outputSizeBytes,
    pickedFile: item.pickedFile,
    outputPath: item.outputPath,
    minimumQuality: item.minimumQuality,
  );

  /// Frames in the output. 1 for a still image, more for an animation.
  final int frameCount;

  /// Sizes are read once, when the conversion lands, rather than from the
  /// widget: every item update in a batch rebuilds every visible card, and a
  /// future started in `build` would re-read both files each time.
  final int inputSizeBytes;
  final int outputQuality;
  final int outputSizeBytes;

  bool get isAnimated => frameCount > 1;

  @override
  List<Object?> get props => [
    ...super.props,
    frameCount,
    inputSizeBytes,
    outputQuality,
    outputSizeBytes,
  ];

  int get sizeDifferenceBytes => outputSizeBytes - inputSizeBytes;
}

final class OptimizingImage extends ImageOptimizationItem {
  const OptimizingImage({
    required super.pickedFile,
    required super.outputPath,
    required super.minimumQuality,
  });

  factory OptimizingImage.fromImageOptimizationItem(
    ImageOptimizationItem item,
  ) => OptimizingImage(
    pickedFile: item.pickedFile,
    outputPath: item.outputPath,
    minimumQuality: item.minimumQuality,
  );
}

final class PendingImage extends ImageOptimizationItem {
  const PendingImage({
    required super.pickedFile,
    required super.outputPath,
    required super.minimumQuality,
  });
}
