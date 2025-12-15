import 'package:get/get.dart';

import '../coordinators/reorder_coordinator.dart';

class BrowserReorderActions {
  final ReorderCoordinator reorderCoordinator;
  final RxBool isReordering;

  BrowserReorderActions({
    required this.reorderCoordinator,
    required this.isReordering,
  });

  // Starts reorder mode for a single image.
  void startReorder(String imagePath) {
    reorderCoordinator.startReorder(imagePath);
  }

  // Updates reorder preview when hovering over target image.
  void previewReorderTo(String targetImagePath) {
    reorderCoordinator.previewReorderTo(targetImagePath);
  }

  // Cancels reorder preview.
  void cancelReorderPreview() {
    reorderCoordinator.cancelReorderPreview();
  }

  // Commits reorder and triggers renumber.
  void commitReorderAndRenumber() {
    reorderCoordinator.commitReorderAndRenumber();
  }

  // Handles drag end for reorder gesture.
  void handleReorderDragEnd({required bool wasAccepted}) {
    reorderCoordinator.handleReorderDragEnd(wasAccepted: wasAccepted);
  }

  // Ends reorder after accepted drop.
  void endReorderAfterAcceptedDrop() {
    reorderCoordinator.endReorderAfterAcceptedDrop();
  }
}
