import 'package:get/get.dart';

import '../coordinators/reorder_coordinator.dart';

/// 重排序操作处理器，处理图片拖拽重排序相关操作
class BrowserReorderActions {
  final ReorderCoordinator reorderCoordinator;
  final RxBool isReordering;

  BrowserReorderActions({
    required this.reorderCoordinator,
    required this.isReordering,
  });

  /// 为单张图片启动重排序模式
  void startReorder(String imagePath) {
    reorderCoordinator.startReorder(imagePath);
  }

  /// 悬停在目标图片上时更新重排序预览
  void previewReorderTo(String targetImagePath) {
    reorderCoordinator.previewReorderTo(targetImagePath);
  }

  /// 取消重排序预览
  void cancelReorderPreview() {
    reorderCoordinator.cancelReorderPreview();
  }

  /// 提交重排序并触发重新编号
  void commitReorderAndRenumber() {
    reorderCoordinator.commitReorderAndRenumber();
  }

  /// 处理重排序手势的拖拽结束
  void handleReorderDragEnd({required bool wasAccepted}) {
    reorderCoordinator.handleReorderDragEnd(wasAccepted: wasAccepted);
  }

  /// 接受拖放后结束重排序
  void endReorderAfterAcceptedDrop() {
    reorderCoordinator.endReorderAfterAcceptedDrop();
  }
}
