import 'package:flutter/material.dart';

class OptimizingCard extends StatelessWidget {
  const OptimizingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Optimizing image...', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Animated images can take a while.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
