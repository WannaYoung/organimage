String formatFileSize(int size) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double s = size.toDouble();
  int unitIndex = 0;

  while (s >= 1024 && unitIndex < units.length - 1) {
    s /= 1024;
    unitIndex++;
  }

  if (unitIndex == 0) {
    return '${s.toInt()} ${units[unitIndex]}';
  }
  return '${s.toStringAsFixed(1)} ${units[unitIndex]}';
}
