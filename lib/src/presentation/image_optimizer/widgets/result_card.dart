import 'dart:io';

import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, DiagnosticsProperty;
import 'package:flutter/material.dart';
import 'package:path/path.dart' show basename, dirname;
import 'package:url_launcher/url_launcher_string.dart';

import '../cubit/image_optimizer_cubit.dart';
import 'format_bytes.dart';
import 'image_optimizer_error_message.dart';

/// One file of a batch: a thumbnail, its name, and where its conversion is.
class ResultCard extends StatelessWidget {
  const ResultCard({required this.item, super.key});

  static const double _thumbnailSize = 72;

  final ImageOptimizationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final detailStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 16,
          children: [
            SizedBox.square(
              dimension: _thumbnailSize,
              child: switch (item) {
                OptimizedImage(:final outputPath) => ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: Image(
                    // Decode at thumbnail size: a batch of full-resolution
                    // images decoded just to draw 72px squares would hold
                    // hundreds of megabytes.
                    image: ResizeImage(
                      FileImage(File(outputPath)),
                      width: (_thumbnailSize * 2).toInt(),
                      height: (_thumbnailSize * 2).toInt(),
                      policy: ResizeImagePolicy.fit,
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
                OptimizingImage() => const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                PendingImage() => Icon(
                  Icons.schedule,
                  color: colorScheme.onSurfaceVariant,
                ),
                FailedImage() => Icon(
                  Icons.error_outline,
                  color: colorScheme.error,
                ),
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    basename(item.pickedFile.path),
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ...switch (item) {
                    OptimizedImage(
                      :final inputSizeBytes,
                      :final outputSizeBytes,
                      :final sizeDifferenceBytes,
                      :final outputQuality,
                      :final minimumQuality,
                      :final isAnimated,
                      :final frameCount,
                    ) =>
                      [
                        Text(
                          '${formatBytes(inputSizeBytes)} → '
                          '${formatBytes(outputSizeBytes)} '
                          '(${formatSignedBytes(sizeDifferenceBytes)})',
                        ),
                        Text(
                          'Quality $outputQuality (min $minimumQuality)'
                          '${isAnimated ? ' · $frameCount frames' : ''}',
                          style: detailStyle,
                        ),
                      ],
                    FailedImage(:final exception) => [
                      Text(
                        imageOptimizerErrorMessage(exception),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                    OptimizingImage() => [
                      Text('Optimizing...', style: detailStyle),
                    ],
                    PendingImage() => [Text('Waiting', style: detailStyle)],
                  },
                ],
              ),
            ),
            if (item is OptimizedImage)
              IconButton(
                tooltip: 'Open output folder',
                onPressed: _onTapOpenDirectory,
                icon: const Icon(Icons.open_in_new),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ImageOptimizationItem>('item', item));
  }

  void _onTapOpenDirectory() =>
      launchUrlString('file:${dirname(item.outputPath)}');
}
