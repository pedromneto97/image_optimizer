import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, DiagnosticsProperty;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'file_detail_row.dart';
import 'format_bytes.dart';

class InputSummaryCard extends StatelessWidget {
  const InputSummaryCard({required this.file, super.key});

  final XFile file;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Input', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FileDetailRow(label: 'Path', value: file.path),
          FutureBuilder(
            future: file.length(),
            builder: (context, asyncSnapshot) {
              if (asyncSnapshot.connectionState == ConnectionState.waiting ||
                  asyncSnapshot.hasError) {
                return const FileDetailRow(
                  label: 'Original size',
                  value: 'Loading...',
                );
              }

              return FileDetailRow(
                label: 'Original size',
                value: formatBytes(asyncSnapshot.data!),
              );
            },
          ),
        ],
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<XFile>('file', file));
  }
}
