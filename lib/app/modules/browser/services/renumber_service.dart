import 'dart:isolate';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/constants.dart';

class RenumberService {
  Future<(bool, String)> renumberFilesInFolderByOrder(
    String folderPath,
    List<String> orderedFilePaths,
  ) {
    return Isolate.run(
      () => _renumberFilesInFolderByOrderSync(folderPath, orderedFilePaths),
    );
  }

  Future<(bool, String)> renumberFilesInFolder(String folderPath) {
    return Isolate.run(() => _renumberFilesInFolderSync(folderPath));
  }

  Future<(bool, String)> renameFolderWithContents(
    String folderPath,
    String newName,
  ) {
    return Isolate.run(
      () => _renameFolderWithContentsSync(folderPath, newName),
    );
  }
}

bool _isImageFile(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  return imageExtensions.contains(ext);
}

(bool, String) _renumberFilesInFolderByOrderSync(
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
      if (entity is File && _isImageFile(entity.path)) {
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

(bool, String) _renumberFilesInFolderSync(String folderPath) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return (false, 'error_folder_not_exist');
  }

  final folderName = p.basename(folderPath);

  try {
    final imageFiles = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is File && _isImageFile(entity.path)) {
        imageFiles.add(entity.path);
      }
    }
    if (imageFiles.isEmpty) {
      return (true, 'success');
    }
    imageFiles.sort((a, b) => p.basename(a).compareTo(p.basename(b)));

    final tempMappings = <(String, String)>[];
    for (var i = 0; i < imageFiles.length; i++) {
      final filePath = imageFiles[i];
      final ext = p.extension(filePath);
      final tempName = '__temp_renumber_${i.toString().padLeft(5, '0')}$ext';
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

(bool, String) _renameFolderWithContentsSync(
  String folderPath,
  String newName,
) {
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
    final imageFiles = <String>[];
    for (final entity in Directory(folderPath).listSync()) {
      if (entity is File && _isImageFile(entity.path)) {
        imageFiles.add(entity.path);
      }
    }
    imageFiles.sort((a, b) => p.basename(a).compareTo(p.basename(b)));

    final tempMappings = <(String, String, String)>[];
    for (var i = 0; i < imageFiles.length; i++) {
      final filePath = imageFiles[i];
      final ext = p.extension(filePath);
      final tempName = '__temp_rename_${i.toString().padLeft(5, '0')}$ext';
      final tempPath = p.join(folderPath, tempName);
      File(filePath).renameSync(tempPath);
      tempMappings.add((tempPath, ext, filePath));
    }

    for (var i = 0; i < tempMappings.length; i++) {
      final (tempPath, ext, _) = tempMappings[i];
      final newFileName =
          '$newName (${(i + 1).toString().padLeft(3, '0')})$ext';
      final newFilePath = p.join(folderPath, newFileName);
      File(tempPath).renameSync(newFilePath);
    }

    Directory(folderPath).renameSync(newFolderPath);
    return (true, newFolderPath);
  } catch (e) {
    return (false, e.toString());
  }
}
