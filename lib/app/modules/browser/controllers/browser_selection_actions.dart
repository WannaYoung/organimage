import 'dart:io';

import 'package:get/get.dart';

import '../coordinators/selection_coordinator.dart';

/// 选择操作处理器，处理图片选择相关操作
class BrowserSelectionActions {
  final RxList<String> selectedImages;
  final RxList<FileSystemEntity> imageFiles;

  final SelectionCoordinator selectionCoordinator;
  final void Function(List<String> ids) update;

  BrowserSelectionActions({
    required this.selectedImages,
    required this.imageFiles,
    required this.selectionCoordinator,
    required this.update,
  });

  /// 切换单张图片的选中状态并触发最小UI更新
  void toggleImageSelection(String imagePath) {
    final before = selectedImages.toSet();
    selectionCoordinator.toggleImageSelection(imagePath);
    _updateChanged(before);
  }

  /// 选择单张图片（清除之前的选择）并触发最小UI更新
  void selectSingleImage(String imagePath) {
    final before = selectedImages.toSet();
    selectionCoordinator.selectSingleImage(imagePath);
    _updateChanged(before);
  }

  /// 选择到给定图片路径的范围
  void selectRangeTo(String imagePath, {required bool additive}) {
    final before = selectedImages.toSet();
    selectionCoordinator.selectRangeTo(imagePath, additive: additive);
    _updateChanged(before);
  }

  /// 处理带修饰键的点击选择
  void handleImageTapSelection(
    String imagePath, {
    required bool isCtrlPressed,
    required bool isShiftPressed,
  }) {
    final before = selectedImages.toSet();
    selectionCoordinator.handleImageTapSelection(
      imagePath,
      isCtrlPressed: isCtrlPressed,
      isShiftPressed: isShiftPressed,
    );
    _updateChanged(before);
  }

  /// 清除选择并为之前选中的项目触发UI更新
  void clearSelection() {
    final before = selectedImages.toSet();
    selectionCoordinator.clearSelection();
    if (before.isNotEmpty) {
      update(before.toList());
    }
  }

  /// 选择当前文件夹中的所有图片
  void selectAllImages() {
    final before = selectedImages.toSet();
    selectionCoordinator.selectAllImages();
    _updateChanged(before);
  }

  /// 应用拖拽选择（框选）
  void applyDragSelection(
    List<String> paths, {
    required bool additive,
    List<String>? baseSelection,
  }) {
    final before = selectedImages.toSet();
    selectionCoordinator.applyDragSelection(
      paths,
      additive: additive,
      baseSelection: baseSelection,
    );
    _updateChanged(before);
  }

  void _updateChanged(Set<String> before) {
    final after = selectedImages.toSet();
    final changed = <String>{...before, ...after}
      ..removeWhere((p) => before.contains(p) && after.contains(p));
    if (changed.isNotEmpty) {
      update(changed.toList());
    }
  }
}
