import 'dart:io';

import 'package:path/path.dart' as p;

import 'image_scan_utils.dart';
import 'naming_utils.dart';

(bool, String) importExternalImagesToFolder(
  List<String> sourcePaths,
  String folderPath,
) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return (false, 'error_target_not_exist');
  }
  if (sourcePaths.isEmpty) {
    return (true, 'success');
  }

  final folderName = p.basename(folderPath);
  final imageSources = <String>[];
  for (final path in sourcePaths) {
    if (File(path).existsSync() && isImageFile(path)) {
      imageSources.add(path);
    }
  }
  if (imageSources.isEmpty) {
    return (true, 'success');
  }

  try {
    var nextNum = getNextFileNumber(folderPath, folderName);
    for (final src in imageSources) {
      final ext = p.extension(src);
      final newName = '$folderName (${nextNum.toString().padLeft(3, '0')})$ext';
      final newPath = p.join(folderPath, newName);
      File(src).copySync(newPath);
      nextNum++;
    }
    return (true, 'success');
  } catch (e) {
    return (false, 'error_import_failed');
  }
}
