String formatBytes(int? bytes) {
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

String formatSignedBytes(int? bytes) {
  if (bytes == null) {
    return '-';
  }

  final sign = bytes > 0
      ? '+'
      : bytes < 0
          ? '-'
          : '';
  return '$sign${formatBytes(bytes.abs())}';
}
