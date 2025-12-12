import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants.dart';

bool isImageFile(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  return imageExtensions.contains(ext);
}

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

int countFilesInDirectory(String directoryPath) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) return 0;

  try {
    return dir.listSync().whereType<File>().length;
  } catch (e) {
    return 0;
  }
}

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
