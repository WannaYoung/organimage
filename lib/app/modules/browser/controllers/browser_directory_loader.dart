import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../services/directory_service.dart';
import '../services/thumbnail_service.dart';

/// 目录加载器，负责加载和缓存目录内容
class BrowserDirectoryLoader {
  final DirectoryService directoryService;
  final ThumbnailService thumbnailService;

  final Rx<String?> rootPath;
  final Rx<String?> currentPath;
  final RxList<Directory> subdirectories;

  final RxMap<String, int> folderFileCounts;
  final RxMap<String, String?> folderPreviewImages;

  final RxList<FileSystemEntity> imageFiles;
  final RxBool useThumbnails;

  final RxBool isLoading;
  final Rx<String?> loadingMessageKey;

  final void Function() clearSelection;
  final void Function() update;

  final Future<void> Function() preGenerateThumbnailsForCurrentFolder;

  BrowserDirectoryLoader({
    required this.directoryService,
    required this.thumbnailService,
    required this.rootPath,
    required this.currentPath,
    required this.subdirectories,
    required this.folderFileCounts,
    required this.folderPreviewImages,
    required this.imageFiles,
    required this.useThumbnails,
    required this.isLoading,
    required this.loadingMessageKey,
    required this.clearSelection,
    required this.update,
    required this.preGenerateThumbnailsForCurrentFolder,
  });

  int loadRequestId = 0;

  final Map<String, List<FileSystemEntity>> folderImageCache =
      <String, List<FileSystemEntity>>{};
  final List<String> folderImageCacheOrder = <String>[];
  static const int folderImageCacheCapacity = 8;

  /// 从导航参数初始化控制器状态
  void onInitFromArgs(
    Map<String, dynamic>? args, {
    required void Function(String path) setRootPath,
  }) {
    if (args != null && args['rootPath'] != null) {
      if (args['useThumbnails'] is bool) {
        useThumbnails.value = args['useThumbnails'] as bool;
      }
      setRootPath(args['rootPath'] as String);
    }
  }

  /// 设置根文件夹并加载其内容
  void setRootPath(
    String path, {
    required void Function() loadCurrentDirectory,
  }) {
    rootPath.value = path;
    currentPath.value = path;
    loadCurrentDirectory();
  }

  /// 导航到文件夹并触发目录加载
  void navigateToFolder(
    String folderPath, {
    required void Function() loadCurrentDirectory,
  }) {
    currentPath.value = folderPath;
    loadCurrentDirectory();
  }

  /// 触发当前选中文件夹的刷新
  void loadCurrentDirectory({
    required Future<void> Function(int requestId) refreshFolderMetaCacheAsync,
  }) {
    _loadCurrentDirectoryAsync(
      refreshFolderMetaCacheAsync: refreshFolderMetaCacheAsync,
    );
  }

  /// 加载当前文件夹的子文件夹和图片文件，支持请求取消
  Future<void> _loadCurrentDirectoryAsync({
    required Future<void> Function(int requestId) refreshFolderMetaCacheAsync,
  }) async {
    final selected = currentPath.value;
    if (selected == null) return;

    final requestId = ++loadRequestId;

    final cached = folderImageCache[selected];
    if (cached != null) {
      imageFiles.assignAll(cached);
      clearSelection();
      isLoading.value = false;
      loadingMessageKey.value = null;
    } else {
      isLoading.value = true;
      loadingMessageKey.value = 'loading_scanning';
    }

    try {
      final root = rootPath.value;
      if (root != null) {
        final dirs = await directoryService.getSubdirectories(root);
        if (requestId != loadRequestId) return;
        subdirectories.assignAll(dirs);
      }

      final newFiles = await directoryService.getImageFiles(selected);
      if (requestId != loadRequestId) return;
      final next = List<FileSystemEntity>.unmodifiable(newFiles);
      putFolderCache(selected, next);

      if (!areSamePaths(imageFiles, next)) {
        imageFiles.assignAll(next);
        clearSelection();
      }

      if (useThumbnails.value) {
        unawaited(
          thumbnailService.preGenerateForFolder(
            selected,
            next.map((e) => e.path).toList(growable: false),
            onProgress: () {
              if (useThumbnails.value) {
                update();
              }
            },
          ),
        );
      }

      await refreshFolderMetaCacheAsync(requestId);
    } finally {
      if (requestId == loadRequestId) {
        isLoading.value = false;
        loadingMessageKey.value = null;
      }
    }
  }

  /// 重排序提交后重新加载UI并刷新缩略图/元数据缓存
  Future<void> reloadAfterReorderCommit({
    required Future<(int, String?)> Function(String folderPath) getFolderMeta,
  }) async {
    final folder = currentPath.value;
    if (folder == null) return;

    clearSelection();
    clearImageCache();

    if (useThumbnails.value) {
      await preGenerateThumbnailsForCurrentFolder();
      update();
    }

    final meta = await getFolderMeta(folder);
    folderFileCounts[folder] = meta.$1;
    folderPreviewImages[folder] = meta.$2;
  }

  /// 刷新根目录及其子文件夹的缓存元数据（数量/预览图）
  Future<void> refreshFolderMetaCacheAsync(
    int requestId, {
    required Future<Map<String, (int, String?)>> Function(
      List<String> folderPaths,
    )
    getFolderMetas,
  }) async {
    final root = rootPath.value;
    if (root == null) return;

    final folderPaths = <String>[root, ...subdirectories.map((d) => d.path)];
    if (requestId != loadRequestId) return;

    final metas = await getFolderMetas(folderPaths);
    if (requestId != loadRequestId) return;

    final nextCounts = <String, int>{};
    final nextPreviews = <String, String?>{};
    metas.forEach((path, meta) {
      nextCounts[path] = meta.$1;
      nextPreviews[path] = meta.$2;
    });

    folderFileCounts.assignAll(nextCounts);
    folderPreviewImages.assignAll(nextPreviews);
  }

  /// 返回文件夹的缓存图片数量
  int getFolderFileCount(String folderPath) {
    return folderFileCounts[folderPath] ?? 0;
  }

  /// 返回文件夹的缓存预览图路径
  String? getFolderPreviewImage(String folderPath) {
    return folderPreviewImages[folderPath];
  }

  /// 检查两个文件列表是否表示相同的有序路径集
  bool areSamePaths(List<FileSystemEntity> a, List<FileSystemEntity> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].path != b[i].path) return false;
    }
    return true;
  }

  /// 插入/更新文件夹缓存并执行LRU容量限制
  void putFolderCache(String folderPath, List<FileSystemEntity> files) {
    folderImageCache[folderPath] = files;
    folderImageCacheOrder.remove(folderPath);
    folderImageCacheOrder.add(folderPath);

    while (folderImageCacheOrder.length > folderImageCacheCapacity) {
      final oldest = folderImageCacheOrder.removeAt(0);
      folderImageCache.remove(oldest);
    }
  }

  /// 使文件夹的缓存图片列表失效
  void invalidateFolderCache(String folderPath) {
    folderImageCache.remove(folderPath);
    folderImageCacheOrder.remove(folderPath);
  }

  /// 清除Flutter图片缓存以在文件系统更改后强制重新加载
  void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// 当前文件夹显示名称
  String getCurrentFolderName() {
    final path = currentPath.value;
    if (path == null) return '';
    return p.basename(path);
  }
}
