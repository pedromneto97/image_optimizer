import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, StringProperty;
import 'package:flutter/material.dart';

class FileDetailRow extends StatelessWidget {
  const FileDetailRow({
    required this.label,
    required this.value,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Expanded(child: SelectableText(value));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null)
            Expanded(child: Row(spacing: 4, children: [text, trailing!]))
          else
            text,
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(StringProperty('value', value));
  }
}
