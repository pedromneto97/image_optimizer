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

/// Every item in the batch has finished, as [OptimizedImage] or [FailedImage].
final class ImageOptimizerCompleted extends ImageOptimizerFilesPicked {
  const ImageOptimizerCompleted({
    required super.items,
    required super.minimumQuality,
  });

  factory ImageOptimizerCompleted.fromImageOptimizerState(
    ImageOptimizerFilesPicked state,
  ) => ImageOptimizerCompleted(
    items: state.items,
    minimumQuality: state.minimumQuality,
  );

  @override
  ImageOptimizerState copyWith({
    int? minimumQuality,
    List<ImageOptimizationItem>? items,
  }) => ImageOptimizerCompleted(
    items: items ?? this.items,
    minimumQuality: minimumQuality ?? this.minimumQuality,
  );
}

sealed class ImageOptimizerFilesPicked extends ImageOptimizerState {
  const ImageOptimizerFilesPicked({
    required this.items,
    required super.minimumQuality,
  });

  /// One entry per picked file, in the order they were picked.
  final List<ImageOptimizationItem> items;

  /// Items that have finished, successfully or not.
  int get completedCount => items
      .where((item) => item is OptimizedImage || item is FailedImage)
      .length;

  int get failedCount => items.whereType<FailedImage>().length;

  @override
  List<Object?> get props => [...super.props, items];

  @override
  ImageOptimizerState copyWith({
    int? minimumQuality,
    List<ImageOptimizationItem>? items,
  });
}

final class ImageOptimizerInitial extends ImageOptimizerState {
  const ImageOptimizerInitial({super.minimumQuality = 80});

  @override
  ImageOptimizerState copyWith({int? minimumQuality}) => ImageOptimizerInitial(
    minimumQuality: minimumQuality ?? this.minimumQuality,
  );
}

final class ImageOptimizerOptimizing extends ImageOptimizerFilesPicked {
  const ImageOptimizerOptimizing({
    required super.items,
    required super.minimumQuality,
  });

  factory ImageOptimizerOptimizing.fromImageOptimizerState(
    ImageOptimizerState state, {
    required List<ImageOptimizationItem> items,
  }) => ImageOptimizerOptimizing(
    items: items,
    minimumQuality: state.minimumQuality,
  );

  @override
  ImageOptimizerState copyWith({
    int? minimumQuality,
    List<ImageOptimizationItem>? items,
  }) => ImageOptimizerOptimizing(
    items: items ?? this.items,
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
