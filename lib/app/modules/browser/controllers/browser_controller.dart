import 'dart:io';

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

  // Image files in current selected folder
  final RxList<FileSystemEntity> imageFiles = <FileSystemEntity>[].obs;

  // Selected image files
  final RxList<String> selectedImages = <String>[].obs;

  // Thumbnail size
  final RxDouble thumbnailSize = 120.0.obs;

  // Loading state
  final RxBool isLoading = false.obs;

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
    } finally {
      isLoading.value = false;
    }
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
  }

  void clearSelection() {
    selectedImages.clear();
  }

  Future<void> moveSelectedToFolder(String folderPath) async {
    if (selectedImages.isEmpty) return;

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
          showErrorToast(result);
        }
      }
      loadCurrentDirectory();
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
          showErrorToast(result);
        }
      }
      loadCurrentDirectory();
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
  void deleteImage(String imagePath) {
    final (success, result) = deleteFile(imagePath);
    if (success) {
      selectedImages.remove(imagePath);
      loadCurrentDirectory();
      showSuccessToast('image_deleted'.tr);
    } else {
      showErrorToast(result);
    }
  }

  // Delete a folder by path
  void deleteFolderByPath(String folderPath) {
    final (success, result) = deleteFolder(folderPath);
    if (success) {
      loadCurrentDirectory();
      showSuccessToast('folder_deleted'.tr);
    } else {
      showErrorToast(result);
    }
  }

  // Rename folder and all its contents
  void renameFolderWithContents(String folderPath, String newName) {
    final (success, result) = renameFolderWithContentsUtil(folderPath, newName);
    if (success) {
      loadCurrentDirectory();
      showSuccessToast('folder_renamed'.tr);
    } else {
      showErrorToast(result);
    }
  }
}
