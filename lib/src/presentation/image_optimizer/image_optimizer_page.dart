import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/image_optimizer_cubit.dart';
import 'cubit/image_optimizer_state.dart';
import 'widgets/image_optimizer_error_message.dart';
import 'widgets/input_summary_card.dart';
import 'widgets/result_card.dart';

class ImageOptimizerPage extends StatelessWidget {
  const ImageOptimizerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Image Optimizer')),
    body: BlocConsumer<ImageOptimizerCubit, ImageOptimizerState>(
      listener: (context, state) {
        if (state case ImageOptimizerFailure(:final exception)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(imageOptimizerErrorMessage(exception))),
          );
        }
      },
      builder: (context, state) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Convert desktop images to WebP with the best size/quality ratio.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: state.isBusy
                ? null
                : context.read<ImageOptimizerCubit>().pickImage,
            icon: const Icon(Icons.image_search),
            label: const Text('Pick image'),
          ),
          const SizedBox(height: 16),
          InputSummaryCard(state: state),
          const SizedBox(height: 24),
          Text('Minimum quality: ${state.minimumQuality}'),
          Slider(
            value: state.minimumQuality.toDouble(),
            max: 100,
            divisions: 100,
            label: state.minimumQuality.toString(),
            onChanged: state.isBusy
                ? null
                : context.read<ImageOptimizerCubit>().updateMinimumQuality,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.canOptimize
                ? context.read<ImageOptimizerCubit>().optimizeSelectedImage
                : null,
            icon: state.isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.compress),
            label: Text(state.isBusy ? 'Optimizing...' : 'Run optimization'),
          ),
          if (state.outputPath != null) ...[
            const SizedBox(height: 24),
            ResultCard(state: state),
          ],
        ],
      ),
    ),
  );
}
