import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/file_utils.dart';
import '../../../core/utils/toast_utils.dart';

class BrowserController extends GetxController {
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

  String? _lastSelectedImagePath;

  // Thumbnail size
  final RxDouble thumbnailSize = 120.0.obs;

  // Loading state
  final RxBool isLoading = false.obs;

  final RxBool isReordering = false.obs;

  String? _reorderDraggingPath;
  List<String> _reorderOriginalOrder = <String>[];
  String? _reorderLastTargetPath;
  bool _reorderCommitted = false;

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
    if (currentPath.value == null) return;

    isLoading.value = true;
    try {
      // Always load subdirectories from ROOT path (like Python version)
      if (rootPath.value != null) {
        subdirectories.value = getSubdirectories(rootPath.value!);
      }
      // Load images from current selected folder
      // Use assignAll to properly trigger GetX reactive update
      final newFiles = getImageFiles(currentPath.value!);
      imageFiles.assignAll(newFiles);
      selectedImages.clear();
      _lastSelectedImagePath = null;

      Future.microtask(_refreshFolderMetaCache);
    } finally {
      isLoading.value = false;
    }
  }

  void _refreshFolderMetaCache() {
    final root = rootPath.value;
    if (root == null) return;

    final nextCounts = <String, int>{};
    final nextPreviews = <String, String?>{};

    nextCounts[root] = countFilesInDirectory(root);
    nextPreviews[root] = getFirstImageInDirectory(root);

    for (final dir in subdirectories) {
      nextCounts[dir.path] = countFilesInDirectory(dir.path);
      nextPreviews[dir.path] = getFirstImageInDirectory(dir.path);
    }

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
    if (selectedImages.contains(imagePath)) {
      selectedImages.remove(imagePath);
    } else {
      selectedImages.add(imagePath);
    }

    _lastSelectedImagePath = imagePath;
  }

  void selectSingleImage(String imagePath) {
    selectedImages
      ..clear()
      ..add(imagePath);
    _lastSelectedImagePath = imagePath;
  }

  void selectRangeTo(String imagePath, {required bool additive}) {
    final lastPath = _lastSelectedImagePath;
    final paths = imageFiles.map((e) => e.path).toList();
    if (paths.isEmpty) return;

    final endIndex = paths.indexOf(imagePath);
    if (endIndex < 0) {
      selectSingleImage(imagePath);
      return;
    }

    if (lastPath == null) {
      selectSingleImage(imagePath);
      return;
    }

    final startIndex = paths.indexOf(lastPath);
    if (startIndex < 0) {
      selectSingleImage(imagePath);
      return;
    }

    final from = startIndex < endIndex ? startIndex : endIndex;
    final to = startIndex < endIndex ? endIndex : startIndex;
    final range = paths.sublist(from, to + 1);

    if (!additive) {
      selectedImages
        ..clear()
        ..addAll(range);
    } else {
      final union = <String>{...selectedImages, ...range}.toList();
      selectedImages
        ..clear()
        ..addAll(union);
    }

    _lastSelectedImagePath = imagePath;
  }

  void handleImageTapSelection(
    String imagePath, {
    required bool isCtrlPressed,
    required bool isShiftPressed,
  }) {
    if (isShiftPressed) {
      selectRangeTo(imagePath, additive: isCtrlPressed);
      return;
    }

    if (isCtrlPressed) {
      toggleImageSelection(imagePath);
      return;
    }

    selectSingleImage(imagePath);
  }

  void clearSelection() {
    selectedImages.clear();
    _lastSelectedImagePath = null;
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

  Future<void> importExternalImagesToCurrentFolder(List<String> paths) async {
    final folderPath = currentPath.value;
    if (folderPath == null) return;
    if (paths.isEmpty) return;

    final imagePaths = <String>[];
    for (final path in paths) {
      if (File(path).existsSync() && isImageFile(path)) {
        imagePaths.add(path);
      }
    }
    if (imagePaths.isEmpty) return;

    isLoading.value = true;
    try {
      final (success, result) = importExternalImagesToFolder(
        imagePaths,
        folderPath,
      );
      if (!success) {
        showErrorToast(_formatErrorMessage(result));
        return;
      }

      loadCurrentDirectory();
      _clearImageCache();
      showSuccessToast(
        'imported_count'.trParams({'count': '${imagePaths.length}'}),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void selectAllImages() {
    final all = imageFiles.map((e) => e.path).toList();
    selectedImages
      ..clear()
      ..addAll(all);
    _lastSelectedImagePath = all.isNotEmpty ? all.last : null;
  }

  void applyDragSelection(
    List<String> paths, {
    required bool additive,
    List<String>? baseSelection,
  }) {
    final base = baseSelection ?? <String>[];
    final next = additive ? <String>{...base, ...paths}.toList() : paths;
    selectedImages
      ..clear()
      ..addAll(next);

    if (paths.isNotEmpty) {
      _lastSelectedImagePath = paths.last;
    }
  }

  Future<void> moveSelectedToFolder(String folderPath) async {
    if (selectedImages.isEmpty) return;

    if (currentPath.value == folderPath) {
      showInfoToast('error_same_folder'.tr);
      return;
    }

    isLoading.value = true;
    int successCount = 0;
    int failCount = 0;
    try {
      for (final imagePath in selectedImages.toList()) {
        final (success, result) = moveFileToFolder(imagePath, folderPath);
        if (success) {
          selectedImages.remove(imagePath);
          successCount++;
        } else {
          failCount++;
          showErrorToast(_formatErrorMessage(result));
        }
      }

      if (!isAtRoot && currentPath.value != null) {
        renumberFilesInFolder(currentPath.value!);
      }
      loadCurrentDirectory();
      _clearImageCache();
      if (successCount > 0 && failCount == 0) {
        showSuccessToast('moved_count'.trParams({'count': '$successCount'}));
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Move selected images to root folder without renaming
  Future<void> moveSelectedToRootFolder() async {
    if (selectedImages.isEmpty || rootPath.value == null) return;

    isLoading.value = true;
    try {
      for (final imagePath in selectedImages.toList()) {
        final (success, result) = moveFileToFolderKeepName(
          imagePath,
          rootPath.value!,
        );
        if (success) {
          selectedImages.remove(imagePath);
        } else {
          showErrorToast(_formatErrorMessage(result));
        }
      }

      if (!isAtRoot && currentPath.value != null) {
        renumberFilesInFolder(currentPath.value!);
      }
      loadCurrentDirectory();
      _clearImageCache();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteSelectedImages() async {
    if (selectedImages.isEmpty) return;

    isLoading.value = true;
    int successCount = 0;
    int failCount = 0;
    try {
      for (final imagePath in selectedImages.toList()) {
        final (success, result) = deleteFile(imagePath);
        if (success) {
          selectedImages.remove(imagePath);
          successCount++;
        } else {
          failCount++;
          showErrorToast(_formatErrorMessage(result));
        }
      }

      if (!isAtRoot && currentPath.value != null) {
        renumberFilesInFolder(currentPath.value!);
      }
      loadCurrentDirectory();
      _clearImageCache();

      if (successCount > 0 && failCount == 0) {
        showSuccessToast('deleted_count'.trParams({'count': '$successCount'}));
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createNewFolder(String folderName) async {
    if (currentPath.value == null) return;

    final (success, result) = createFolder(currentPath.value!, folderName);
    if (success) {
      loadCurrentDirectory();
      showSuccessToast('folder_created'.tr);
    } else {
      showErrorToast(result);
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
    if (!canReorderInCurrentFolder) return;
    _reorderDraggingPath = imagePath;
    _reorderOriginalOrder = imageFiles.map((e) => e.path).toList();
    _reorderLastTargetPath = null;
    _reorderCommitted = false;
    isReordering.value = true;
  }

  void previewReorderTo(String targetImagePath) {
    if (!isReordering.value) return;
    final draggingPath = _reorderDraggingPath;
    if (draggingPath == null) return;
    if (draggingPath == targetImagePath) return;
    if (_reorderLastTargetPath == targetImagePath) return;

    final paths = imageFiles.map((e) => e.path).toList();
    if (paths.toSet().length != paths.length) {
      final unique = <String>[];
      for (final path in paths) {
        if (!unique.contains(path)) {
          unique.add(path);
        }
      }
      imageFiles.assignAll(unique.map((p) => File(p)).toList());
      return;
    }
    final fromIndex = paths.indexOf(draggingPath);
    final toIndex = paths.indexOf(targetImagePath);
    if (fromIndex < 0 || toIndex < 0) return;
    if (fromIndex == toIndex) return;

    paths.removeAt(fromIndex);
    paths.insert(toIndex, draggingPath);
    _reorderLastTargetPath = targetImagePath;
    imageFiles.assignAll(paths.map((p) => File(p)).toList());
  }

  void cancelReorderPreview() {
    if (!isReordering.value) return;
    if (_reorderCommitted) return;
    if (_reorderOriginalOrder.isNotEmpty) {
      imageFiles.assignAll(_reorderOriginalOrder.map((p) => File(p)).toList());
    }
    _reorderDraggingPath = null;
    _reorderOriginalOrder = <String>[];
    _reorderLastTargetPath = null;
    isReordering.value = false;
  }

  void commitReorderAndRenumber() {
    if (!isReordering.value) return;
    if (!canReorderInCurrentFolder) {
      cancelReorderPreview();
      return;
    }

    final folderPath = currentPath.value;
    if (folderPath == null) {
      cancelReorderPreview();
      return;
    }

    final orderedPaths = imageFiles.map((e) => e.path).toList();
    if (_reorderOriginalOrder.length == orderedPaths.length) {
      var same = true;
      for (var i = 0; i < orderedPaths.length; i++) {
        if (_reorderOriginalOrder[i] != orderedPaths[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        _reorderDraggingPath = null;
        _reorderOriginalOrder = <String>[];
        isReordering.value = false;
        return;
      }
    }

    _reorderCommitted = true;
    isReordering.value = false;
    try {
      isLoading.value = true;
      final (success, result) = renumberFilesInFolderByOrderUtil(
        folderPath,
        orderedPaths,
      );
      if (!success) {
        showErrorToast(result);
      }
      loadCurrentDirectory();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } finally {
      _reorderDraggingPath = null;
      _reorderOriginalOrder = <String>[];
      _reorderLastTargetPath = null;
      isLoading.value = false;
    }
  }

  void handleReorderDragEnd({required bool wasAccepted}) {
    if (_reorderCommitted) return;
    if (!isReordering.value) return;
    if (wasAccepted) {
      endReorderAfterAcceptedDrop();
    } else {
      cancelReorderPreview();
    }
  }

  void endReorderAfterAcceptedDrop() {
    if (!isReordering.value) return;
    if (_reorderCommitted) return;
    _reorderDraggingPath = null;
    _reorderOriginalOrder = <String>[];
    _reorderLastTargetPath = null;
    isReordering.value = false;
  }

  // Open file or folder in system file manager
  void openInFinder(String path) {
    final result = openInFinderUtil(path);
    if (!result.$1) {
      showErrorToast(result.$2);
    }
  }

  // Rename a single image
  void renameImage(String imagePath, String newName) {
    final (success, result) = renameFile(imagePath, newName);
    if (success) {
      loadCurrentDirectory();
      showSuccessToast('image_renamed'.tr);
    } else {
      showErrorToast(result);
    }
  }

  // Delete a single image
  // If in a subfolder, renumber remaining files after deletion
  void deleteImage(String imagePath) {
    final (success, result) = deleteFile(imagePath);
    if (success) {
      selectedImages.remove(imagePath);
      // Renumber files if we're in a subfolder (not root)
      if (!isAtRoot && currentPath.value != null) {
        renumberFilesInFolder(currentPath.value!);
      }
      loadCurrentDirectory();
      _clearImageCache();
      showSuccessToast('image_deleted'.tr);
    } else {
      showErrorToast(_formatErrorMessage(result));
    }
  }

  // Delete a folder by path
  void deleteFolderByPath(String folderPath) {
    final (success, result) = deleteFolder(folderPath);
    if (success) {
      loadCurrentDirectory();
      _clearImageCache();
      showSuccessToast('folder_deleted'.tr);
    } else {
      showErrorToast(_formatErrorMessage(result));
    }
  }

  // Rename folder and all its contents
  void renameFolderWithContents(String folderPath, String newName) {
    final (success, newPath) = renameFolderWithContentsUtil(
      folderPath,
      newName,
    );
    if (success) {
      // Update currentPath if we renamed the currently viewed folder
      if (currentPath.value == folderPath) {
        currentPath.value = newPath;
      }
      loadCurrentDirectory();
      _clearImageCache();
      showSuccessToast('folder_renamed'.tr);
    } else {
      showErrorToast(newPath);
    }
  }
}
