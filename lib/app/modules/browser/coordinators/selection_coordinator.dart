import 'dart:io';

import 'package:get/get.dart';

/// 选择协调器，管理图片选择的状态和逻辑
class SelectionCoordinator {
  SelectionCoordinator({
    required this.selectedImages,
    required this.imageFiles,
  });

  final RxList<String> selectedImages;
  final RxList<FileSystemEntity> imageFiles;

  String? _lastSelectedImagePath;

  /// 切换图片选中状态
  void toggleImageSelection(String imagePath) {
    if (selectedImages.contains(imagePath)) {
      selectedImages.remove(imagePath);
    } else {
      selectedImages.add(imagePath);
    }
    _lastSelectedImagePath = imagePath;
  }

  /// 选择单张图片
  void selectSingleImage(String imagePath) {
    selectedImages
      ..clear()
      ..add(imagePath);
    _lastSelectedImagePath = imagePath;
  }

  /// 选择范围到指定图片
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
      final unionSet = <String>{...selectedImages, ...range};
      final union = paths.where(unionSet.contains).toList();
      selectedImages
        ..clear()
        ..addAll(union);
    }

    _lastSelectedImagePath = imagePath;
  }

  /// 处理图片点击选择
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

  /// 清除选择
  void clearSelection() {
    selectedImages.clear();
    _lastSelectedImagePath = null;
  }

  /// 选择所有图片
  void selectAllImages() {
    final all = imageFiles.map((e) => e.path).toList();
    selectedImages
      ..clear()
      ..addAll(all);
    _lastSelectedImagePath = all.isNotEmpty ? all.last : null;
  }

  /// 应用拖拽选择
  void applyDragSelection(
    List<String> paths, {
    required bool additive,
    List<String>? baseSelection,
  }) {
    final base = baseSelection ?? <String>[];
    if (!additive) {
      selectedImages
        ..clear()
        ..addAll(paths);

      if (paths.isNotEmpty) {
        _lastSelectedImagePath = paths.last;
      }
      return;
    }

    final unionSet = <String>{...base, ...paths};
    final ordered = imageFiles.map((e) => e.path).where(unionSet.contains);
    final next = ordered.toList();
    selectedImages
      ..clear()
      ..addAll(next);

    if (paths.isNotEmpty) {
      _lastSelectedImagePath = paths.last;
    }
  }
}
