import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/constants.dart';

/// 目录服务，提供目录和文件操作的基础功能
class DirectoryService {
  /// 检查文件是否为图片文件
  bool isImageFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return imageExtensions.contains(ext);
  }

  /// 获取目录中的所有图片文件
  Future<List<FileSystemEntity>> getImageFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return <FileSystemEntity>[];

    try {
      final files = <FileSystemEntity>[];
      await for (final entity in dir.list()) {
        if (entity is File && isImageFile(entity.path)) {
          files.add(entity);
        }
      }
      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      return files;
    } catch (e) {
      return <FileSystemEntity>[];
    }
  }

  /// 获取目录中的所有子目录
  Future<List<Directory>> getSubdirectories(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return <Directory>[];

    try {
      final dirs = <Directory>[];
      await for (final entity in dir.list()) {
        if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
          dirs.add(entity);
        }
      }
      dirs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      return dirs;
    } catch (e) {
      return <Directory>[];
    }
  }

  /// 统计目录中的文件数量
  Future<int> countFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return 0;

    try {
      var count = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 获取目录中的第一张图片
  Future<String?> getFirstImage(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return null;

    try {
      final files = <FileSystemEntity>[];
      await for (final entity in dir.list()) {
        if (entity is File && isImageFile(entity.path)) {
          files.add(entity);
        }
      }
      if (files.isEmpty) return null;
      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      return files.first.path;
    } catch (e) {
      return null;
    }
  }

  /// 获取文件夹元数据（文件数量和首张图片）
  Future<(int, String?)> getFolderMeta(String directoryPath) async {
    final count = await countFiles(directoryPath);
    final firstImage = await getFirstImage(directoryPath);
    return (count, firstImage);
  }

  /// 批量获取多个文件夹的元数据
  Future<Map<String, (int, String?)>> getFolderMetas(
    List<String> folderPaths,
  ) async {
    if (folderPaths.isEmpty) {
      return <String, (int, String?)>{};
    }

    const concurrency = 4;
    final results = <String, (int, String?)>{};

    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        final i = nextIndex;
        nextIndex++;
        if (i >= folderPaths.length) return;
        final path = folderPaths[i];
        results[path] = await getFolderMeta(path);
      }
    }

    final workerCount = folderPaths.length < concurrency
        ? folderPaths.length
        : concurrency;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }
}
