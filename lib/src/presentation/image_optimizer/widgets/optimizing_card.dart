import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, IntProperty;
import 'package:flutter/material.dart';

class OptimizingCard extends StatelessWidget {
  const OptimizingCard({
    required this.completed,
    required this.total,
    super.key,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              total == 1
                  ? 'Optimizing image...'
                  : 'Optimizing images... $completed of $total done',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // A lone image has no progress to report until it is done, so it
            // gets the indeterminate bar rather than one pinned at zero.
            LinearProgressIndicator(
              value: total == 1 ? null : completed / total,
            ),
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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('completed', completed))
      ..add(IntProperty('total', total));
  }
}
