import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/image_optimizer_cubit.dart';
import 'cubit/image_optimizer_state.dart';
import 'widgets/file_detail_row.dart';

class ImageOptimizerPage extends StatelessWidget {
  const ImageOptimizerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Optimizer')),
      body: BlocBuilder<ImageOptimizerCubit, ImageOptimizerState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Convert desktop images to WebP with the best size/quality ratio.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: state.isLoading
                    ? null
                    : context.read<ImageOptimizerCubit>().pickImage,
                icon: const Icon(Icons.image_search),
                label: const Text('Pick image'),
              ),
              const SizedBox(height: 16),
              _InputSummary(state: state),
              const SizedBox(height: 24),
              Text('Minimum quality: ${state.minimumQuality}'),
              Slider(
                value: state.minimumQuality.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: state.minimumQuality.toString(),
                onChanged: state.isLoading
                    ? null
                    : context.read<ImageOptimizerCubit>().updateMinimumQuality,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.canOptimize
                    ? context.read<ImageOptimizerCubit>().optimizeSelectedImage
                    : null,
                icon: state.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.compress),
                label: Text(state.isLoading ? 'Optimizing...' : 'Run optimization'),
              ),
              if (state.errorMessage case final error?) ...[
                const SizedBox(height: 16),
                Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (state.outputPath != null) ...[
                const SizedBox(height: 24),
                _ResultCard(state: state),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InputSummary extends StatelessWidget {
  const _InputSummary({required this.state});

  final ImageOptimizerState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Input', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FileDetailRow(label: 'Path', value: state.inputPath ?? 'No image selected'),
            FileDetailRow(
              label: 'Original size',
              value: _formatBytes(state.originalSizeBytes),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.state});

  final ImageOptimizerState state;

  @override
  Widget build(BuildContext context) {
    final outputPath = state.outputPath!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Optimized WebP', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(outputPath),
                height: 280,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            FileDetailRow(label: 'Output path', value: outputPath),
            FileDetailRow(label: 'Requested minimum quality', value: '${state.minimumQuality}'),
            FileDetailRow(label: 'Actual quality', value: '${state.outputQuality ?? '-'}'),
            FileDetailRow(label: 'New size', value: _formatBytes(state.convertedSizeBytes)),
            FileDetailRow(label: 'Difference', value: _formatSignedBytes(state.sizeDifferenceBytes)),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int? bytes) {
  if (bytes == null) {
    return '-';
  }

  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
}

String _formatSignedBytes(int? bytes) {
  if (bytes == null) {
    return '-';
  }

  final sign = bytes > 0 ? '+' : bytes < 0 ? '-' : '';
  return '$sign${_formatBytes(bytes.abs())}';
}
