import 'package:get/get.dart';

import '../controllers/browser_controller.dart';
import '../services/directory_service.dart';
import '../services/file_operation_service.dart';
import '../services/renumber_service.dart';
import '../services/thumbnail_service.dart';

/// 浏览器模块绑定，注册依赖注入
class BrowserBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DirectoryService>(() => DirectoryService());
    Get.lazyPut<FileOperationService>(() => FileOperationService());
    Get.lazyPut<RenumberService>(() => RenumberService());
    Get.lazyPut<ThumbnailService>(() => ThumbnailService());

    Get.lazyPut<BrowserController>(
      () => BrowserController(
        directoryService: Get.find<DirectoryService>(),
        fileOperationService: Get.find<FileOperationService>(),
        renumberService: Get.find<RenumberService>(),
        thumbnailService: Get.find<ThumbnailService>(),
      ),
    );
  }
}
