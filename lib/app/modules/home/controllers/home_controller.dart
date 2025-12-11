import 'dart:io';

import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../routes/app_pages.dart';

class HomeController extends GetxController {
  final Rx<String?> selectedPath = Rx<String?>(null);
  final RxBool isLoading = false.obs;
  final RxList<String> recentFolders = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadRecentFolders();
  }

  Future<void> _loadRecentFolders() async {
    final folders = await StorageService.getRecentFolders();
    recentFolders.value = folders;
  }

  Future<void> selectFolder() async {
    isLoading.value = true;
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'select_folder'.tr,
      );

      if (result != null) {
        await _openFolder(result);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openRecentFolder(String path) async {
    // Check if folder still exists
    if (!await Directory(path).exists()) {
      showErrorToast('error_folder_not_exist'.tr);
      // Remove from recent folders
      await _removeInvalidFolder(path);
      return;
    }
    await _openFolder(path);
  }

  Future<void> _removeInvalidFolder(String path) async {
    recentFolders.remove(path);
    final config = await StorageService.getRecentFolders();
    // Config is already updated, just refresh the list
    recentFolders.value = config.where((f) => f != path).toList();
  }

  Future<void> _openFolder(String path) async {
    selectedPath.value = path;
    // Save to recent folders
    await StorageService.addRecentFolder(path);
    await _loadRecentFolders();
    // Navigate to browser page with the selected path
    Get.toNamed(Routes.browser, arguments: {'rootPath': path});
  }

  Future<void> clearRecentFolders() async {
    await StorageService.clearRecentFolders();
    recentFolders.clear();
  }
}
