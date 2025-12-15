import 'dart:io';

import 'package:get/get.dart';

import '../coordinators/selection_coordinator.dart';

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

  // Toggles the selection state of a single image and triggers minimal UI update.
  void toggleImageSelection(String imagePath) {
    final before = selectedImages.toSet();
    selectionCoordinator.toggleImageSelection(imagePath);
    _updateChanged(before);
  }

  // Selects a single image (clears previous selection) and triggers minimal UI update.
  void selectSingleImage(String imagePath) {
    final before = selectedImages.toSet();
    selectionCoordinator.selectSingleImage(imagePath);
    _updateChanged(before);
  }

  // Selects a range to the given image path.
  void selectRangeTo(String imagePath, {required bool additive}) {
    final before = selectedImages.toSet();
    selectionCoordinator.selectRangeTo(imagePath, additive: additive);
    _updateChanged(before);
  }

  // Handles click selection with modifier keys.
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

  // Clears selection and triggers UI update for previously selected items.
  void clearSelection() {
    final before = selectedImages.toSet();
    selectionCoordinator.clearSelection();
    if (before.isNotEmpty) {
      update(before.toList());
    }
  }

  // Selects all images in current folder.
  void selectAllImages() {
    final before = selectedImages.toSet();
    selectionCoordinator.selectAllImages();
    _updateChanged(before);
  }

  // Applies drag selection (rubber band selection).
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
