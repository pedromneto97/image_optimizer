import 'package:flutter/material.dart';

import '../cubit/image_optimizer_state.dart';
import 'file_detail_row.dart';
import 'format_bytes.dart';

class InputSummaryCard extends StatelessWidget {
  const InputSummaryCard({required this.state, super.key});

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
            FileDetailRow(
              label: 'Path',
              value: state.inputPath ?? 'No image selected',
            ),
            FileDetailRow(
              label: 'Original size',
              value: formatBytes(state.originalSizeBytes),
            ),
          ],
        ),
      ),
    );
  }
}
