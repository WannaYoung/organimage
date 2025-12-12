import 'dart:io';
import 'package:path/path.dart' as p;

import '../constants.dart';

(bool, String) movePathToTrash(String path) {
  if (!File(path).existsSync() && !Directory(path).existsSync()) {
    return (false, 'error_path_not_exist');
  }

  try {
    if (Platform.isMacOS) {
      final escaped = path.replaceAll('"', '\\"');
      final script =
          'tell application "Finder" to delete POSIX file "$escaped"';
      final result = Process.runSync('osascript', ['-e', script]);
      if (result.exitCode == 0) {
        return (true, 'success');
      }
      return (false, 'error_trash_failed');
    }

    if (Platform.isWindows) {
      final escaped = path.replaceAll("'", "''");
      final command =
          "\$shell = New-Object -ComObject Shell.Application; "
          "\$recycleBin = \$shell.Namespace(0xA); "
          "\$recycleBin.MoveHere('$escaped')";
      final result = Process.runSync('powershell', [
        '-NoProfile',
        '-Command',
        command,
      ]);
      if (result.exitCode == 0) {
        return (true, 'success');
      }
      return (false, 'error_trash_failed');
    }

    final result = Process.runSync('gio', ['trash', path]);
    if (result.exitCode == 0) {
      return (true, 'success');
    }
    return (false, 'error_trash_failed');
  } catch (e) {
    return (false, 'error_trash_failed');
  }
}

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

/// Check if a file is a supported image format
bool isImageFile(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  return imageExtensions.contains(ext);
}

/// Get all image files in a directory
List<FileSystemEntity> getImageFiles(String directoryPath) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) return [];

  try {
    final files = dir
        .listSync()
        .where((entity) => entity is File && isImageFile(entity.path))
        .toList();
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  } catch (e) {
    return [];
  }
}

/// Get all subdirectories in a directory
List<Directory> getSubdirectories(String directoryPath) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) return [];

  try {
    final dirs = dir
        .listSync()
        .whereType<Directory>()
        .where((d) => !p.basename(d.path).startsWith('.'))
        .toList();
    dirs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return dirs;
  } catch (e) {
    return [];
  }
}

/// Count files in a directory
int countFilesInDirectory(String directoryPath) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) return 0;

  try {
    return dir.listSync().whereType<File>().length;
  } catch (e) {
    return 0;
  }
}

/// Get the first image file in a directory for preview
String? getFirstImageInDirectory(String directoryPath) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) return null;

  try {
    final files = dir
        .listSync()
        .where((entity) => entity is File && isImageFile(entity.path))
        .toList();
    if (files.isEmpty) return null;
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files.first.path;
  } catch (e) {
    return null;
  }
}

/// Get the next available file number for naming convention
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

/// Move a file to a folder without renaming (keep original name)
/// Returns (success, newPath or errorKey)
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

(bool, String) renumberFilesInFolderByOrderUtil(
  String folderPath,
  List<String> orderedFilePaths,
) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return (false, 'error_folder_not_exist');
  }

  final folderName = p.basename(folderPath);

  try {
    final existing = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is File && isImageFile(entity.path)) {
        existing.add(entity.path);
      }
    }
    if (existing.isEmpty) {
      return (true, 'success');
    }

    final existingSet = existing.toSet();
    final finalOrder = <String>[];
    for (final path in orderedFilePaths) {
      if (existingSet.contains(path)) {
        finalOrder.add(path);
      }
    }
    if (finalOrder.length != existing.length) {
      final remaining = existing.where((p) => !finalOrder.contains(p)).toList();
      remaining.sort((a, b) => p.basename(a).compareTo(p.basename(b)));
      finalOrder.addAll(remaining);
    }

    final tempMappings = <(String, String)>[];
    for (var i = 0; i < finalOrder.length; i++) {
      final filePath = finalOrder[i];
      final ext = p.extension(filePath);
      final tempName = '__temp_reorder_${i.toString().padLeft(5, '0')}$ext';
      final tempPath = p.join(folderPath, tempName);
      File(filePath).renameSync(tempPath);
      tempMappings.add((tempPath, ext));
    }

    for (var i = 0; i < tempMappings.length; i++) {
      final (tempPath, ext) = tempMappings[i];
      final newFileName =
          '$folderName (${(i + 1).toString().padLeft(3, '0')})$ext';
      final newFilePath = p.join(folderPath, newFileName);
      File(tempPath).renameSync(newFilePath);
    }

    return (true, 'success');
  } catch (e) {
    return (false, e.toString());
  }
}

/// Move a file to a folder with automatic renaming
/// Returns (success, newPath or errorKey)
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

/// Create a new folder
/// Returns (success, newFolderPath or errorKey)
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

/// Delete a file
/// Returns (success, messageKey)
(bool, String) deleteFile(String filePath) {
  if (!File(filePath).existsSync()) {
    return (false, 'error_file_not_exist');
  }
  return movePathToTrash(filePath);
}

/// Delete a folder and all its contents
/// Returns (success, messageKey)
(bool, String) deleteFolder(String folderPath) {
  if (!Directory(folderPath).existsSync()) {
    return (false, 'error_folder_not_exist');
  }
  return movePathToTrash(folderPath);
}

/// Rename a file
/// Returns (success, newPath or errorKey)
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

/// Rename a folder
/// Returns (success, newFolderPath or errorKey)
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

/// Format file size to human readable string
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

/// Open file or folder in system file manager
/// Returns (success, messageKey)
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

/// Re-number all image files in a folder with sequential numbering
/// Returns (success, messageKey)
(bool, String) renumberFilesInFolder(String folderPath) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return (false, 'error_folder_not_exist');
  }

  final folderName = p.basename(folderPath);

  try {
    // Get all image files and sort them
    final imageFiles = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is File && isImageFile(entity.path)) {
        imageFiles.add(entity.path);
      }
    }
    if (imageFiles.isEmpty) {
      return (true, 'success');
    }
    imageFiles.sort((a, b) => p.basename(a).compareTo(p.basename(b)));

    // First pass: rename to temp names to avoid conflicts
    final tempMappings = <(String, String)>[]; // (tempPath, ext)
    for (var i = 0; i < imageFiles.length; i++) {
      final filePath = imageFiles[i];
      final ext = p.extension(filePath);
      final tempName = '__temp_renumber_${i.toString().padLeft(5, '0')}$ext';
      final tempPath = p.join(folderPath, tempName);
      File(filePath).renameSync(tempPath);
      tempMappings.add((tempPath, ext));
    }

    // Second pass: rename to final names
    for (var i = 0; i < tempMappings.length; i++) {
      final (tempPath, ext) = tempMappings[i];
      final newFileName =
          '$folderName (${(i + 1).toString().padLeft(3, '0')})$ext';
      final newFilePath = p.join(folderPath, newFileName);
      File(tempPath).renameSync(newFilePath);
    }

    return (true, 'success');
  } catch (e) {
    return (false, e.toString());
  }
}

/// Rename folder and all image files inside with sequential numbering
/// Returns (success, newFolderPath or errorKey)
(bool, String) renameFolderWithContentsUtil(String folderPath, String newName) {
  final oldName = p.basename(folderPath);
  final parentDir = p.dirname(folderPath);
  final newFolderPath = p.join(parentDir, newName);

  if (oldName == newName) {
    return (true, folderPath);
  }

  if (Directory(newFolderPath).existsSync()) {
    return (false, 'error_folder_exists');
  }

  try {
    // Get all image files and sort them
    final imageFiles = <String>[];
    for (final entity in Directory(folderPath).listSync()) {
      if (entity is File && isImageFile(entity.path)) {
        imageFiles.add(entity.path);
      }
    }
    imageFiles.sort((a, b) => p.basename(a).compareTo(p.basename(b)));

    // First pass: rename to temp names to avoid conflicts
    final tempMappings =
        <(String, String, String)>[]; // (tempPath, ext, origPath)
    for (var i = 0; i < imageFiles.length; i++) {
      final filePath = imageFiles[i];
      final ext = p.extension(filePath);
      final tempName = '__temp_rename_${i.toString().padLeft(5, '0')}$ext';
      final tempPath = p.join(folderPath, tempName);
      File(filePath).renameSync(tempPath);
      tempMappings.add((tempPath, ext, filePath));
    }

    // Second pass: rename to final names
    for (var i = 0; i < tempMappings.length; i++) {
      final (tempPath, ext, _) = tempMappings[i];
      final newFileName =
          '$newName (${(i + 1).toString().padLeft(3, '0')})$ext';
      final newFilePath = p.join(folderPath, newFileName);
      File(tempPath).renameSync(newFilePath);
    }

    // Rename the folder itself
    Directory(folderPath).renameSync(newFolderPath);
    return (true, newFolderPath);
  } catch (e) {
    return (false, e.toString());
  }
}
