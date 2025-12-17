import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import '../../../core/utils/toast_utils.dart';
import '../services/batch_operation_result.dart';
import '../services/directory_service.dart';
import '../services/file_operation_service.dart';
import '../services/renumber_service.dart';
import '../services/thumbnail_service.dart';

/// 文件操作处理器，处理文件的导入、移动、删除等操作
class BrowserFileOps {
  final DirectoryService directoryService;
  final FileOperationService fileOperationService;
  final RenumberService renumberService;
  final ThumbnailService thumbnailService;

  final RxList<String> selectedImages;
  final RxList<FileSystemEntity> imageFiles;

  final Rx<String?> rootPath;
  final Rx<String?> currentPath;

  final RxBool useThumbnails;
  final RxDouble thumbnailSize;

  final RxBool isLoading;
  final Rx<String?> loadingMessageKey;

  final bool Function() isAtRoot;

  final void Function() loadCurrentDirectory;
  final void Function() clearImageCache;
  final void Function(String folderPath) invalidateFolderCache;
  final void Function() clearSelection;
  final void Function() update;

  final String Function(String keyOrMessage) formatErrorMessage;

  BrowserFileOps({
    required this.directoryService,
    required this.fileOperationService,
    required this.renumberService,
    required this.thumbnailService,
    required this.selectedImages,
    required this.imageFiles,
    required this.rootPath,
    required this.currentPath,
    required this.useThumbnails,
    required this.thumbnailSize,
    required this.isLoading,
    required this.loadingMessageKey,
    required this.isAtRoot,
    required this.loadCurrentDirectory,
    required this.clearImageCache,
    required this.invalidateFolderCache,
    required this.clearSelection,
    required this.update,
    required this.formatErrorMessage,
  });

  /// 文件系统更改后刷新UI
  Future<void> refreshAfterFileOperation({
    required bool renumberCurrentFolder,
  }) async {
    if (renumberCurrentFolder && !isAtRoot() && currentPath.value != null) {
      await renumberService.renumberFilesInFolder(currentPath.value!);
    }

    final folder = currentPath.value;
    if (folder != null) {
      invalidateFolderCache(folder);
    }
    if (useThumbnails.value) {
      thumbnailService.clearResolvedCache();
    }

    loadCurrentDirectory();
    clearImageCache();
  }

  /// 将外部图片（拖放）导入到当前文件夹
  Future<void> importExternalImagesToCurrentFolder(List<String> paths) async {
    final folderPath = currentPath.value;
    if (folderPath == null) return;
    if (paths.isEmpty) return;

    isLoading.value = true;
    loadingMessageKey.value = 'loading_importing';
    try {
      final BatchOperationResult result = await fileOperationService
          .importExternalImagesToFolderFiltered(
            paths,
            folderPath,
            isImageFile: directoryService.isImageFile,
          );

      if (result.successCount == 0) return;
      if (result.failCount > 0) {
        for (final error in result.errorMessages) {
          showErrorToast(formatErrorMessage(error));
        }
        return;
      }

      await refreshAfterFileOperation(renumberCurrentFolder: false);
      showSuccessToast(
        'imported_count'.trParams({'count': '${result.successCount}'}),
      );
    } finally {
      isLoading.value = false;
      loadingMessageKey.value = null;
    }
  }

  /// 将选中的图片移动到文件夹
  Future<void> moveSelectedToFolder(String folderPath) async {
    if (selectedImages.isEmpty) return;

    if (currentPath.value == folderPath) {
      showInfoToast('error_same_folder'.tr);
      return;
    }

    isLoading.value = true;
    loadingMessageKey.value = 'loading_moving';
    try {
      final BatchOperationResult result = await fileOperationService
          .moveFilesToFolder(selectedImages.toList(), folderPath);
      for (final error in result.errorMessages) {
        showErrorToast(formatErrorMessage(error));
      }
      if (result.succeededPaths.isNotEmpty) {
        selectedImages.removeWhere((p) => result.succeededPaths.contains(p));
      }

      await refreshAfterFileOperation(renumberCurrentFolder: true);
      if (result.successCount > 0 && result.failCount == 0) {
        showSuccessToast(
          'moved_count'.trParams({'count': '${result.successCount}'}),
        );
      }
    } finally {
      isLoading.value = false;
      loadingMessageKey.value = null;
    }
  }

  /// 将选中的图片移动到根目录（不重命名）
  Future<void> moveSelectedToRootFolder() async {
    if (selectedImages.isEmpty || rootPath.value == null) return;

    isLoading.value = true;
    loadingMessageKey.value = 'loading_moving';
    try {
      final BatchOperationResult result = await fileOperationService
          .moveFilesToFolderKeepName(selectedImages.toList(), rootPath.value!);
      for (final error in result.errorMessages) {
        showErrorToast(formatErrorMessage(error));
      }
      if (result.succeededPaths.isNotEmpty) {
        selectedImages.removeWhere((p) => result.succeededPaths.contains(p));
      }

      await refreshAfterFileOperation(renumberCurrentFolder: true);
    } finally {
      isLoading.value = false;
      loadingMessageKey.value = null;
    }
  }

  /// 删除选中的图片
  Future<void> deleteSelectedImages() async {
    if (selectedImages.isEmpty) return;

    isLoading.value = true;
    loadingMessageKey.value = 'loading_deleting';
    try {
      final BatchOperationResult result = await fileOperationService
          .deleteFiles(selectedImages.toList());
      for (final error in result.errorMessages) {
        showErrorToast(formatErrorMessage(error));
      }
      if (result.succeededPaths.isNotEmpty) {
        selectedImages.removeWhere((p) => result.succeededPaths.contains(p));
      }

      await refreshAfterFileOperation(renumberCurrentFolder: true);

      if (result.successCount > 0 && result.failCount == 0) {
        showSuccessToast(
          'deleted_count'.trParams({'count': '${result.successCount}'}),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// 在当前路径下创建新文件夹
  Future<void> createNewFolder(String folderName) async {
    if (currentPath.value == null) return;

    final (success, result) = await fileOperationService.createFolder(
      currentPath.value!,
      folderName,
    );
    if (success) {
      loadCurrentDirectory();
      showSuccessToast('folder_created'.tr);
    } else {
      showErrorToast(formatErrorMessage(result));
    }
  }

  /// 更新缩略图大小偏好
  void setThumbnailSize(double size) {
    thumbnailSize.value = size;
  }

  /// 切换缩略图使用并触发预生成
  void setUseThumbnails(bool enabled) {
    if (useThumbnails.value == enabled) return;
    useThumbnails.value = enabled;

    if (enabled) {
      final folder = currentPath.value;
      if (folder != null) {
        final paths = imageFiles.map((e) => e.path).toList(growable: false);
        unawaited(
          thumbnailService.preGenerateForFolder(
            folder,
            paths,
            onProgress: () {
              if (useThumbnails.value) {
                update();
              }
            },
          ),
        );
      }
    }

    update();
  }

  /// 在系统文件管理器中打开文件或文件夹
  Future<void> openInFinder(String path) async {
    final result = await fileOperationService.openInFinder(path);
    if (!result.$1) {
      showErrorToast(formatErrorMessage(result.$2));
    }
  }

  /// 重命名单张图片
  Future<void> renameImage(String imagePath, String newName) async {
    final (success, result) = await fileOperationService.renameFile(
      imagePath,
      newName,
    );
    if (success) {
      loadCurrentDirectory();
      showSuccessToast('image_renamed'.tr);
    } else {
      showErrorToast(formatErrorMessage(result));
    }
  }

  /// 删除单张图片
  Future<void> deleteImage(String imagePath) async {
    final (success, result) = await fileOperationService.deleteFile(imagePath);
    if (success) {
      selectedImages.remove(imagePath);
      await refreshAfterFileOperation(renumberCurrentFolder: true);
      showSuccessToast('image_deleted'.tr);
    } else {
      showErrorToast(formatErrorMessage(result));
    }
  }

  /// 根据路径删除文件夹
  Future<void> deleteFolderByPath(String folderPath) async {
    final (success, result) = await fileOperationService.deleteFolder(
      folderPath,
    );
    if (success) {
      await refreshAfterFileOperation(renumberCurrentFolder: false);
      showSuccessToast('folder_deleted'.tr);
    } else {
      showErrorToast(formatErrorMessage(result));
    }
  }

  /// 重命名文件夹及其所有内容
  Future<void> renameFolderWithContents(
    String folderPath,
    String newName,
  ) async {
    final (success, newPath) = await renumberService.renameFolderWithContents(
      folderPath,
      newName,
    );
    if (success) {
      if (currentPath.value == folderPath) {
        currentPath.value = newPath;
      }
      await refreshAfterFileOperation(renumberCurrentFolder: false);
      showSuccessToast('folder_renamed'.tr);
    } else {
      showErrorToast(formatErrorMessage(newPath));
    }
  }
}
