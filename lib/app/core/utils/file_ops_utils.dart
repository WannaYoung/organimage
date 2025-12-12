import 'dart:io';

import 'package:path/path.dart' as p;

import 'naming_utils.dart';
import 'trash_utils.dart';

(bool, String) moveFileToFolderKeepName(String filePath, String folderPath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return (false, 'error_source_not_exist');
  }

  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return (false, 'error_target_not_exist');
  }

  final fileName = p.basename(filePath);
  var newPath = p.join(folderPath, fileName);

  if (File(newPath).existsSync()) {
    final baseName = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    var counter = 1;
    while (counter <= 9999) {
      final candidateName = '$baseName ($counter)$ext';
      final candidatePath = p.join(folderPath, candidateName);
      if (!File(candidatePath).existsSync()) {
        newPath = candidatePath;
        break;
      }
      counter++;
    }
    if (File(newPath).existsSync()) {
      return (false, 'error_file_exists');
    }
  }

  try {
    file.renameSync(newPath);
    return (true, newPath);
  } catch (e) {
    return (false, e.toString());
  }
}

(bool, String) moveFileToFolder(String filePath, String folderPath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return (false, 'error_source_not_exist');
  }

  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return (false, 'error_target_not_exist');
  }

  final folderName = p.basename(folderPath);
  final ext = p.extension(filePath);
  final nextNum = getNextFileNumber(folderPath, folderName);
  final newName = '$folderName (${nextNum.toString().padLeft(3, '0')})$ext';
  final newPath = p.join(folderPath, newName);

  try {
    file.renameSync(newPath);
    return (true, newPath);
  } catch (e) {
    return (false, e.toString());
  }
}

(bool, String) createFolder(String parentPath, String folderName) {
  final newPath = p.join(parentPath, folderName);
  final dir = Directory(newPath);

  if (dir.existsSync()) {
    return (false, 'error_folder_exists');
  }

  try {
    dir.createSync(recursive: true);
    return (true, newPath);
  } catch (e) {
    return (false, e.toString());
  }
}

(bool, String) deleteFile(String filePath) {
  if (!File(filePath).existsSync()) {
    return (false, 'error_file_not_exist');
  }
  return movePathToTrash(filePath);
}

(bool, String) deleteFolder(String folderPath) {
  if (!Directory(folderPath).existsSync()) {
    return (false, 'error_folder_not_exist');
  }
  return movePathToTrash(folderPath);
}

(bool, String) renameFile(String filePath, String newName) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return (false, 'error_file_not_exist');
  }

  final parentDir = p.dirname(filePath);
  final newPath = p.join(parentDir, newName);

  if (File(newPath).existsSync()) {
    return (false, 'error_file_exists');
  }

  try {
    file.renameSync(newPath);
    return (true, newPath);
  } catch (e) {
    return (false, e.toString());
  }
}

(bool, String) renameFolder(String folderPath, String newName) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return (false, 'error_folder_not_exist');
  }

  final parentDir = p.dirname(folderPath);
  final newPath = p.join(parentDir, newName);

  if (Directory(newPath).existsSync()) {
    return (false, 'error_folder_exists');
  }

  try {
    dir.renameSync(newPath);
    return (true, newPath);
  } catch (e) {
    return (false, e.toString());
  }
}

(bool, String) openInFinderUtil(String path) {
  if (!File(path).existsSync() && !Directory(path).existsSync()) {
    return (false, 'error_path_not_exist');
  }

  try {
    if (Platform.isMacOS) {
      if (File(path).existsSync()) {
        Process.runSync('open', ['-R', path]);
      } else {
        Process.runSync('open', [path]);
      }
    } else if (Platform.isWindows) {
      if (File(path).existsSync()) {
        Process.runSync('explorer', ['/select,', path]);
      } else {
        Process.runSync('explorer', [path]);
      }
    } else {
      final parent = File(path).existsSync() ? p.dirname(path) : path;
      Process.runSync('xdg-open', [parent]);
    }
    return (true, 'success');
  } catch (e) {
    return (false, e.toString());
  }
}
