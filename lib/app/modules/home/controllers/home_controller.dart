import 'dart:io';

import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../routes/app_pages.dart';

/// 主页控制器，管理文件夹选择和最近文件夹
class HomeController extends GetxController {
  final Rx<String?> selectedPath = Rx<String?>(null);
  final RxBool isLoading = false.obs;
  final RxList<String> recentFolders = <String>[].obs;
  final RxBool useThumbnails = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadRecentFolders();
    _loadUseThumbnails();
  }

  Future<void> _loadUseThumbnails() async {
    useThumbnails.value = await StorageService.getUseThumbnails();
  }

  Future<void> setUseThumbnails(bool enabled) async {
    useThumbnails.value = enabled;
    await StorageService.setUseThumbnails(enabled);
    if (!enabled) {
      await StorageService.clearThumbnailCache();
    }
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
    // 检查文件夹是否仍然存在
    if (!await Directory(path).exists()) {
      showErrorToast('error_folder_not_exist'.tr);
      // 从最近文件夹中移除
      await _removeInvalidFolder(path);
      return;
    }
    await _openFolder(path);
  }

  Future<void> _removeInvalidFolder(String path) async {
    recentFolders.remove(path);
    final config = await StorageService.getRecentFolders();
    // 配置已更新，只需刷新列表
    recentFolders.value = config.where((f) => f != path).toList();
  }

  Future<void> _openFolder(String path) async {
    selectedPath.value = path;
    // 保存到最近文件夹
    await StorageService.addRecentFolder(path);
    await _loadRecentFolders();
    // 使用选中的路径导航到浏览器页面
    Get.toNamed(
      Routes.browser,
      arguments: {'rootPath': path, 'useThumbnails': useThumbnails.value},
    );
  }

  Future<void> clearRecentFolders() async {
    await StorageService.clearRecentFolders();
    recentFolders.clear();
  }
}
