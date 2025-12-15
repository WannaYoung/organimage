import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../services/renumber_service.dart';

class ReorderCoordinator {
  ReorderCoordinator({
    required this.imageFiles,
    required this.isReordering,
    required this.renumberService,
    required this.getCurrentFolderPath,
    required this.canReorderInCurrentFolder,
    required this.setLoading,
    required this.refreshAfterCommit,
    required this.showError,
  });

  final RxList<FileSystemEntity> imageFiles;
  final RxBool isReordering;
  final RenumberService renumberService;

  final String? Function() getCurrentFolderPath;
  final bool Function() canReorderInCurrentFolder;
  final void Function({required bool value, String? messageKey}) setLoading;
  final Future<void> Function() refreshAfterCommit;
  final void Function(String message) showError;

  String? _reorderDraggingPath;
  List<String> _reorderOriginalOrder = <String>[];
  String? _reorderLastTargetPath;
  bool _reorderCommitted = false;

  void startReorder(String imagePath) {
    if (!canReorderInCurrentFolder()) return;
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
    _commitReorderAndRenumberAsync();
  }

  Future<void> _commitReorderAndRenumberAsync() async {
    if (!isReordering.value) return;
    if (!canReorderInCurrentFolder()) {
      cancelReorderPreview();
      return;
    }

    final folderPath = getCurrentFolderPath();
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
      setLoading(value: true, messageKey: 'loading_reordering');
      final (success, result) = await renumberService
          .renumberFilesInFolderByOrder(folderPath, orderedPaths);
      if (!success) {
        showError(result);
      } else {
        final folderName = p.basename(folderPath);
        final next = <FileSystemEntity>[];
        for (var i = 0; i < orderedPaths.length; i++) {
          final ext = p.extension(orderedPaths[i]);
          final newFileName =
              '$folderName (${(i + 1).toString().padLeft(3, '0')})$ext';
          final newPath = p.join(folderPath, newFileName);
          next.add(File(newPath));
        }
        imageFiles.assignAll(List<FileSystemEntity>.unmodifiable(next));
      }
      await refreshAfterCommit();
    } finally {
      _reorderDraggingPath = null;
      _reorderOriginalOrder = <String>[];
      _reorderLastTargetPath = null;
      setLoading(value: false);
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
}
