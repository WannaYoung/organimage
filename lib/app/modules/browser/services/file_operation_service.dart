import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'batch_operation_result.dart';

class FileOperationService {
  Future<(bool, String)> createFolder(String parentPath, String folderName) {
    return Isolate.run(() => _createFolderSync(parentPath, folderName));
  }

  Future<(bool, String)> renameFile(String filePath, String newName) {
    return Isolate.run(() => _renameFileSync(filePath, newName));
  }

  Future<(bool, String)> deleteFile(String filePath) {
    return Isolate.run(() => _deletePathSync(filePath, isFolder: false));
  }

  Future<(bool, String)> deleteFolder(String folderPath) {
    return Isolate.run(() => _deletePathSync(folderPath, isFolder: true));
  }

  Future<(bool, String)> openInFinder(String path) {
    return Isolate.run(() => _openInFinderSync(path));
  }

  Future<BatchOperationResult> importExternalImagesToFolderFiltered(
    List<String> candidatePaths,
    String folderPath, {
    required bool Function(String path) isImageFile,
  }) async {
    if (candidatePaths.isEmpty) return BatchOperationResult.empty;

    final imagePaths = <String>[];
    for (final path in candidatePaths) {
      if (File(path).existsSync() && isImageFile(path)) {
        imagePaths.add(path);
      }
    }
    if (imagePaths.isEmpty) return BatchOperationResult.empty;

    final (success, result) = await Isolate.run(
      () => _importExternalImagesToFolderSync(imagePaths, folderPath),
    );
    if (success) {
      return BatchOperationResult(
        succeededPaths: imagePaths,
        failedPaths: const <String>[],
        errorMessages: const <String>[],
      );
    }
    return BatchOperationResult(
      succeededPaths: const <String>[],
      failedPaths: imagePaths,
      errorMessages: <String>[result],
    );
  }

  Future<BatchOperationResult> moveFilesToFolder(
    List<String> filePaths,
    String folderPath,
  ) async {
    if (filePaths.isEmpty) return BatchOperationResult.empty;

    final (succeeded, failed, errors) = await Isolate.run(
      () => _moveFilesToFolderSync(filePaths, folderPath),
    );

    return BatchOperationResult(
      succeededPaths: succeeded,
      failedPaths: failed,
      errorMessages: errors,
    );
  }

  Future<BatchOperationResult> moveFilesToFolderKeepName(
    List<String> filePaths,
    String folderPath,
  ) async {
    if (filePaths.isEmpty) return BatchOperationResult.empty;

    final (succeeded, failed, errors) = await Isolate.run(
      () => _moveFilesToFolderKeepNameSync(filePaths, folderPath),
    );

    return BatchOperationResult(
      succeededPaths: succeeded,
      failedPaths: failed,
      errorMessages: errors,
    );
  }

  Future<BatchOperationResult> deleteFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return BatchOperationResult.empty;

    final (succeeded, failed, errors) = await Isolate.run(
      () => _deleteFilesSync(filePaths),
    );
    return BatchOperationResult(
      succeededPaths: succeeded,
      failedPaths: failed,
      errorMessages: errors,
    );
  }
}

(bool, String) _createFolderSync(String parentPath, String folderName) {
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

(bool, String) _renameFileSync(String filePath, String newName) {
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

(bool, String) _deletePathSync(String path, {required bool isFolder}) {
  if (!File(path).existsSync() && !Directory(path).existsSync()) {
    return (
      false,
      isFolder ? 'error_folder_not_exist' : 'error_file_not_exist',
    );
  }
  return _movePathToTrashSync(path);
}

(bool, String) _movePathToTrashSync(String path) {
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

(bool, String) _openInFinderSync(String path) {
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

int _getNextFileNumberSync(String folderPath, String folderName) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) return 1;

  final pattern = RegExp(
    r'^' + RegExp.escape(folderName) + r' \((\d{3})\)\.[^.]+$',
  );
  var maxNum = 0;
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
    // ignore
  }

  return maxNum + 1;
}

(List<String>, List<String>, List<String>) _moveFilesToFolderSync(
  List<String> filePaths,
  String folderPath,
) {
  final succeeded = <String>[];
  final failed = <String>[];
  final errors = <String>[];

  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    for (final fp in filePaths) {
      failed.add(fp);
      errors.add('error_target_not_exist');
    }
    return (succeeded, failed, errors);
  }

  final folderName = p.basename(folderPath);
  var nextNum = _getNextFileNumberSync(folderPath, folderName);

  for (final filePath in filePaths) {
    final file = File(filePath);
    if (!file.existsSync()) {
      failed.add(filePath);
      errors.add('error_source_not_exist');
      continue;
    }

    final ext = p.extension(filePath);
    final newName = '$folderName (${nextNum.toString().padLeft(3, '0')})$ext';
    final newPath = p.join(folderPath, newName);
    try {
      file.renameSync(newPath);
      succeeded.add(filePath);
      nextNum++;
    } catch (e) {
      failed.add(filePath);
      errors.add(e.toString());
    }
  }

  return (succeeded, failed, errors);
}

(List<String>, List<String>, List<String>) _moveFilesToFolderKeepNameSync(
  List<String> filePaths,
  String folderPath,
) {
  final succeeded = <String>[];
  final failed = <String>[];
  final errors = <String>[];

  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    for (final fp in filePaths) {
      failed.add(fp);
      errors.add('error_target_not_exist');
    }
    return (succeeded, failed, errors);
  }

  for (final filePath in filePaths) {
    final file = File(filePath);
    if (!file.existsSync()) {
      failed.add(filePath);
      errors.add('error_source_not_exist');
      continue;
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
        failed.add(filePath);
        errors.add('error_file_exists');
        continue;
      }
    }

    try {
      file.renameSync(newPath);
      succeeded.add(filePath);
    } catch (e) {
      failed.add(filePath);
      errors.add(e.toString());
    }
  }

  return (succeeded, failed, errors);
}

(List<String>, List<String>, List<String>) _deleteFilesSync(
  List<String> filePaths,
) {
  final succeeded = <String>[];
  final failed = <String>[];
  final errors = <String>[];

  for (final filePath in filePaths) {
    final (success, result) = _deletePathSync(filePath, isFolder: false);
    if (success) {
      succeeded.add(filePath);
    } else {
      failed.add(filePath);
      errors.add(result);
    }
  }
  return (succeeded, failed, errors);
}

(bool, String) _importExternalImagesToFolderSync(
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

  try {
    var nextNum = _getNextFileNumberSync(folderPath, folderName);
    for (final src in sourcePaths) {
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
