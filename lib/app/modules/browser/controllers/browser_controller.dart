import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/toast_utils.dart';
import '../coordinators/reorder_coordinator.dart';
import '../coordinators/selection_coordinator.dart';
import '../services/directory_service.dart';
import '../services/batch_operation_result.dart';
import '../services/file_operation_service.dart';
import '../services/renumber_service.dart';

class BrowserController extends GetxController {
  BrowserController({
    required this.directoryService,
    required this.fileOperationService,
    required this.renumberService,
  }) {
    _selectionCoordinator = SelectionCoordinator(
      selectedImages: selectedImages,
      imageFiles: imageFiles,
    );
    _reorderCoordinator = ReorderCoordinator(
      imageFiles: imageFiles,
      isReordering: isReordering,
      renumberService: renumberService,
      getCurrentFolderPath: () => currentPath.value,
      canReorderInCurrentFolder: () => canReorderInCurrentFolder,
      setLoading: ({required bool value, String? messageKey}) {
        isLoading.value = value;
        loadingMessageKey.value = value ? messageKey : null;
      },
      refreshAfterCommit: () {
        loadCurrentDirectory();
        _clearImageCache();
      },
      showError: (message) {
        showErrorToast(_formatErrorMessage(message));
      },
    );
  }

  final DirectoryService directoryService;
  final FileOperationService fileOperationService;
  final RenumberService renumberService;

  late final SelectionCoordinator _selectionCoordinator;
  late final ReorderCoordinator _reorderCoordinator;

  // Root path selected by user
  final Rx<String?> rootPath = Rx<String?>(null);

  // Current directory path (for displaying images)
  final Rx<String?> currentPath = Rx<String?>(null);

  // Subdirectories in ROOT path (always show root's subfolders)
  final RxList<Directory> subdirectories = <Directory>[].obs;

  final RxMap<String, int> folderFileCounts = <String, int>{}.obs;
  final RxMap<String, String?> folderPreviewImages = <String, String?>{}.obs;

  // Image files in current selected folder
  final RxList<FileSystemEntity> imageFiles = <FileSystemEntity>[].obs;

  // Selected image files
  final RxList<String> selectedImages = <String>[].obs;

  // Thumbnail size
  final RxDouble thumbnailSize = 120.0.obs;

  // Loading state
  final RxBool isLoading = false.obs;

  final Rx<String?> loadingMessageKey = Rx<String?>(null);

  final RxBool isReordering = false.obs;

  int _loadRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    // Get arguments from navigation
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['rootPath'] != null) {
      setRootPath(args['rootPath'] as String);
    }
  }

  void setRootPath(String path) {
    rootPath.value = path;
    currentPath.value = path;
    loadCurrentDirectory();
  }

  void loadCurrentDirectory() {
    _loadCurrentDirectoryAsync();
  }

  Future<void> _loadCurrentDirectoryAsync() async {
    final selected = currentPath.value;
    if (selected == null) return;

    final requestId = ++_loadRequestId;
    isLoading.value = true;
    loadingMessageKey.value = 'loading_scanning';
    try {
      final root = rootPath.value;
      if (root != null) {
        final dirs = await directoryService.getSubdirectories(root);
        if (requestId != _loadRequestId) return;
        subdirectories.assignAll(dirs);
      }

      final newFiles = await directoryService.getImageFiles(selected);
      if (requestId != _loadRequestId) return;
      imageFiles.assignAll(newFiles);

      _selectionCoordinator.clearSelection();

      _refreshFolderMetaCacheAsync(requestId);
    } finally {
      if (requestId == _loadRequestId) {
        isLoading.value = false;
        loadingMessageKey.value = null;
      }
    }
  }

  Future<void> _refreshFolderMetaCacheAsync(int requestId) async {
    final root = rootPath.value;
    if (root == null) return;

    final folderPaths = <String>[root, ...subdirectories.map((d) => d.path)];
    if (requestId != _loadRequestId) return;

    final metas = await directoryService.getFolderMetas(folderPaths);
    if (requestId != _loadRequestId) return;

    final nextCounts = <String, int>{};
    final nextPreviews = <String, String?>{};
    metas.forEach((path, meta) {
      nextCounts[path] = meta.$1;
      nextPreviews[path] = meta.$2;
    });

    folderFileCounts.assignAll(nextCounts);
    folderPreviewImages.assignAll(nextPreviews);
  }

  int getFolderFileCount(String folderPath) {
    return folderFileCounts[folderPath] ?? 0;
  }

  String? getFolderPreviewImage(String folderPath) {
    return folderPreviewImages[folderPath];
  }

  void navigateToFolder(String folderPath) {
    currentPath.value = folderPath;
    loadCurrentDirectory();
  }

  void goToHome() {
    Get.back();
  }

  void toggleImageSelection(String imagePath) {
    _selectionCoordinator.toggleImageSelection(imagePath);
  }

  void selectSingleImage(String imagePath) {
    _selectionCoordinator.selectSingleImage(imagePath);
  }

  void selectRangeTo(String imagePath, {required bool additive}) {
    _selectionCoordinator.selectRangeTo(imagePath, additive: additive);
  }

  void handleImageTapSelection(
    String imagePath, {
    required bool isCtrlPressed,
    required bool isShiftPressed,
  }) {
    _selectionCoordinator.handleImageTapSelection(
      imagePath,
      isCtrlPressed: isCtrlPressed,
      isShiftPressed: isShiftPressed,
    );
  }

  void clearSelection() {
    _selectionCoordinator.clearSelection();
  }

  String _formatErrorMessage(String keyOrMessage) {
    if (keyOrMessage.startsWith('error_')) {
      return keyOrMessage.tr;
    }
    return keyOrMessage;
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  // Refresh UI after a file system change.
  // This keeps the original workflow: optional renumber -> reload -> clear cache.
  Future<void> _refreshAfterFileOperation({
    required bool renumberCurrentFolder,
  }) async {
    if (renumberCurrentFolder && !isAtRoot && currentPath.value != null) {
      await renumberService.renumberFilesInFolder(currentPath.value!);
    }
    loadCurrentDirectory();
    _clearImageCache();
  }

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
          showErrorToast(_formatErrorMessage(error));
        }
        return;
      }

      await _refreshAfterFileOperation(renumberCurrentFolder: false);
      showSuccessToast(
        'imported_count'.trParams({'count': '${result.successCount}'}),
      );
    } finally {
      isLoading.value = false;
      loadingMessageKey.value = null;
    }
  }

  void selectAllImages() {
    _selectionCoordinator.selectAllImages();
  }

  void applyDragSelection(
    List<String> paths, {
    required bool additive,
    List<String>? baseSelection,
  }) {
    _selectionCoordinator.applyDragSelection(
      paths,
      additive: additive,
      baseSelection: baseSelection,
    );
  }

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
        showErrorToast(_formatErrorMessage(error));
      }
      if (result.succeededPaths.isNotEmpty) {
        selectedImages.removeWhere((p) => result.succeededPaths.contains(p));
      }

      await _refreshAfterFileOperation(renumberCurrentFolder: true);
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

  /// Move selected images to root folder without renaming
  Future<void> moveSelectedToRootFolder() async {
    if (selectedImages.isEmpty || rootPath.value == null) return;

    isLoading.value = true;
    loadingMessageKey.value = 'loading_moving';
    try {
      final BatchOperationResult result = await fileOperationService
          .moveFilesToFolderKeepName(selectedImages.toList(), rootPath.value!);
      for (final error in result.errorMessages) {
        showErrorToast(_formatErrorMessage(error));
      }
      if (result.succeededPaths.isNotEmpty) {
        selectedImages.removeWhere((p) => result.succeededPaths.contains(p));
      }

      await _refreshAfterFileOperation(renumberCurrentFolder: true);
    } finally {
      isLoading.value = false;
      loadingMessageKey.value = null;
    }
  }

  Future<void> deleteSelectedImages() async {
    if (selectedImages.isEmpty) return;

    isLoading.value = true;
    loadingMessageKey.value = 'loading_deleting';
    try {
      final BatchOperationResult result = await fileOperationService
          .deleteFiles(selectedImages.toList());
      for (final error in result.errorMessages) {
        showErrorToast(_formatErrorMessage(error));
      }
      if (result.succeededPaths.isNotEmpty) {
        selectedImages.removeWhere((p) => result.succeededPaths.contains(p));
      }

      await _refreshAfterFileOperation(renumberCurrentFolder: true);

      if (result.successCount > 0 && result.failCount == 0) {
        showSuccessToast(
          'deleted_count'.trParams({'count': '${result.successCount}'}),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

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
      showErrorToast(_formatErrorMessage(result));
    }
  }

  void setThumbnailSize(double size) {
    thumbnailSize.value = size;
  }

  String get currentFolderName {
    if (currentPath.value == null) return '';
    return p.basename(currentPath.value!);
  }

  bool get isAtRoot {
    return currentPath.value == rootPath.value;
  }

  bool get canReorderInCurrentFolder {
    return !isAtRoot && currentPath.value != null;
  }

  void startReorder(String imagePath) {
    _reorderCoordinator.startReorder(imagePath);
  }

  void previewReorderTo(String targetImagePath) {
    _reorderCoordinator.previewReorderTo(targetImagePath);
  }

  void cancelReorderPreview() {
    _reorderCoordinator.cancelReorderPreview();
  }

  void commitReorderAndRenumber() {
    _reorderCoordinator.commitReorderAndRenumber();
  }

  void handleReorderDragEnd({required bool wasAccepted}) {
    _reorderCoordinator.handleReorderDragEnd(wasAccepted: wasAccepted);
  }

  void endReorderAfterAcceptedDrop() {
    _reorderCoordinator.endReorderAfterAcceptedDrop();
  }

  // Open file or folder in system file manager
  Future<void> openInFinder(String path) async {
    final result = await fileOperationService.openInFinder(path);
    if (!result.$1) {
      showErrorToast(_formatErrorMessage(result.$2));
    }
  }

  // Rename a single image
  Future<void> renameImage(String imagePath, String newName) async {
    final (success, result) = await fileOperationService.renameFile(
      imagePath,
      newName,
    );
    if (success) {
      loadCurrentDirectory();
      showSuccessToast('image_renamed'.tr);
    } else {
      showErrorToast(_formatErrorMessage(result));
    }
  }

  // Delete a single image
  // If in a subfolder, renumber remaining files after deletion
  Future<void> deleteImage(String imagePath) async {
    final (success, result) = await fileOperationService.deleteFile(imagePath);
    if (success) {
      selectedImages.remove(imagePath);
      await _refreshAfterFileOperation(renumberCurrentFolder: true);
      showSuccessToast('image_deleted'.tr);
    } else {
      showErrorToast(_formatErrorMessage(result));
    }
  }

  // Delete a folder by path
  Future<void> deleteFolderByPath(String folderPath) async {
    final (success, result) = await fileOperationService.deleteFolder(
      folderPath,
    );
    if (success) {
      await _refreshAfterFileOperation(renumberCurrentFolder: false);
      showSuccessToast('folder_deleted'.tr);
    } else {
      showErrorToast(_formatErrorMessage(result));
    }
  }

  // Rename folder and all its contents
  Future<void> renameFolderWithContents(
    String folderPath,
    String newName,
  ) async {
    final (success, newPath) = await renumberService.renameFolderWithContents(
      folderPath,
      newName,
    );
    if (success) {
      // Update currentPath if we renamed the currently viewed folder
      if (currentPath.value == folderPath) {
        currentPath.value = newPath;
      }
      await _refreshAfterFileOperation(renumberCurrentFolder: false);
      showSuccessToast('folder_renamed'.tr);
    } else {
      showErrorToast(_formatErrorMessage(newPath));
    }
  }
}
