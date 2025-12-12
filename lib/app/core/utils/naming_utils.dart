import 'dart:io';

import 'package:path/path.dart' as p;

int getNextFileNumber(String folderPath, String folderName) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) return 1;

  final pattern = RegExp(
    r'^' + RegExp.escape(folderName) + r' \((\d{3})\)\.[^.]+$',
  );
  int maxNum = 0;

  try {
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final filename = p.basename(entity.path);
        final match = pattern.firstMatch(filename);
        if (match != null) {
          final num = int.parse(match.group(1)!);
          if (num > maxNum) maxNum = num;
        }
      }
    }
  } catch (e) {
    // Ignore errors
  }

  return maxNum + 1;
}
