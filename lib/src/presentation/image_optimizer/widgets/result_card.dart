import 'dart:io';

import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, DiagnosticsProperty;
import 'package:flutter/material.dart';

import '../cubit/image_optimizer_state.dart';
import 'file_detail_row.dart';
import 'format_bytes.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({required this.state, super.key});

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
            Text(
              'Optimized WebP',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
            FileDetailRow(
              label: 'Requested minimum quality',
              value: '${state.minimumQuality}',
            ),
            FileDetailRow(
              label: 'Actual quality',
              value: '${state.outputQuality ?? '-'}',
            ),
            FileDetailRow(
              label: 'New size',
              value: formatBytes(state.convertedSizeBytes),
            ),
            FileDetailRow(
              label: 'Difference',
              value: formatSignedBytes(state.sizeDifferenceBytes),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ImageOptimizerState>('state', state));
  }
}
