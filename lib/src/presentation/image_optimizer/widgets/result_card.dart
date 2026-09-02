import 'dart:io';

import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, DiagnosticsProperty;
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../cubit/image_optimizer_cubit.dart';
import 'file_detail_row.dart';
import 'format_bytes.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({required this.state, super.key});

  final OptimizeImageSuccess state;

  @override
  Widget build(BuildContext context) {
    final outputPath = state.outputPath;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.isAnimated ? 'Optimized animated WebP' : 'Optimized WebP',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: Image.file(
                File(outputPath),
                height: 280,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            FileDetailRow(
              label: 'Output path',
              value: outputPath,
              trailing: IconButton(
                onPressed: _onTapOpenDirectory,
                icon: const Icon(Icons.open_in_new),
              ),
            ),
            FileDetailRow(
              label: 'Requested minimum quality',
              value: '${state.minimumQuality}',
            ),
            FileDetailRow(
              label: 'Actual quality',
              value: '${state.outputQuality}',
            ),
            if (state.isAnimated)
              FileDetailRow(label: 'Frames', value: '${state.frameCount}'),
            FutureBuilder(
              future: state.outputFileSizeBytes,
              builder: (context, asyncSnapshot) => FileDetailRow(
                label: 'New size',
                value: asyncSnapshot.data == null
                    ? 'Loading...'
                    : formatBytes(asyncSnapshot.data ?? 0),
              ),
            ),
            FutureBuilder(
              future: state.sizeDifferenceBytes,
              builder: (context, asyncSnapshot) => FileDetailRow(
                label: 'Difference',
                value: asyncSnapshot.data == null
                    ? 'Loading...'
                    : formatBytes(asyncSnapshot.data ?? 0),
              ),
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

  void _onTapOpenDirectory() =>
      launchUrlString('file:${dirname(state.outputPath)}');
}
