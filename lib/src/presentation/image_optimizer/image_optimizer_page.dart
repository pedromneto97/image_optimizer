import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/image_optimizer_cubit.dart';
import 'widgets/image_optimizer_error_message.dart';
import 'widgets/optimizing_card.dart';
import 'widgets/quality_slider.dart';
import 'widgets/result_card.dart';

class ImageOptimizerPage extends StatelessWidget {
  const ImageOptimizerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Image Optimizer')),
    body: BlocListener<ImageOptimizerCubit, ImageOptimizerState>(
      // Only a change of state type counts. Moving the slider re-emits the
      // current state with a new quality, which would otherwise repeat the
      // snackbar on every drag.
      listenWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      listener: (context, state) {
        // FailedToPickImage renders as nothing at all, so the snackbar is the
        // only way it reaches the user. Per-file errors are already on their
        // cards; the snackbar only tells a long batch that some exist.
        final message = switch (state) {
          ImageOptimizerCompleted(:final failedCount, :final items)
              when failedCount > 0 =>
            items.length == 1
                ? imageOptimizerErrorMessage(
                    (items.single as FailedImage).exception,
                  )
                : '$failedCount of ${items.length} images failed.',
          FailedToPickImage() => 'The images could not be picked.',
          _ => null,
        };

        if (message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Convert desktop images to WebP with the best '
                    'size/quality ratio.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    spacing: 16,
                    children: [
                      const Expanded(child: QualitySlider()),
                      Expanded(
                        child:
                            BlocSelector<
                              ImageOptimizerCubit,
                              ImageOptimizerState,
                              (int, int)?
                            >(
                              selector: _batchProgress,
                              builder: (context, progress) => FilledButton.icon(
                                onPressed: progress != null
                                    ? null
                                    : context
                                          .read<ImageOptimizerCubit>()
                                          .pickImages,
                                icon: progress != null
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.image_search),
                                label: Text(switch (progress) {
                                  (final completed, final total) =>
                                    'Optimizing $completed/$total...',
                                  null => 'Pick images',
                                }),
                              ),
                            ),
                      ),
                    ],
                  ),
                  BlocSelector<
                    ImageOptimizerCubit,
                    ImageOptimizerState,
                    (int, int)?
                  >(
                    selector: _batchProgress,
                    builder: (context, progress) => switch (progress) {
                      (final completed, final total) => Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: OptimizingCard(
                          completed: completed,
                          total: total,
                        ),
                      ),
                      null => const SizedBox.shrink(),
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver:
                BlocSelector<
                  ImageOptimizerCubit,
                  ImageOptimizerState,
                  List<ImageOptimizationItem>
                >(
                  selector: (state) => state is ImageOptimizerFilesPicked
                      ? state.items
                      : const [],
                  builder: (context, items) => SliverList.separated(
                    itemCount: items.length,
                    itemBuilder: (context, index) => ResultCard(
                      key: ValueKey(items[index].outputPath),
                      item: items[index],
                    ),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                  ),
                ),
          ),
        ],
      ),
    ),
  );
}

/// `(completed, total)` while a batch runs, null otherwise.
(int, int)? _batchProgress(ImageOptimizerState state) => switch (state) {
  ImageOptimizerOptimizing(:final completedCount, :final items) => (
    completedCount,
    items.length,
  ),
  _ => null,
};
