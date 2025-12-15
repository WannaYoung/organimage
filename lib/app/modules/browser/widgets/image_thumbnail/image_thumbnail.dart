import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../controllers/browser_controller.dart';
import '../image_preview.dart';

import 'image_thumbnail_content.dart';
import 'image_thumbnail_dialogs.dart';
import 'image_thumbnail_tooltip.dart';

class ImageThumbnail extends StatefulWidget {
  final String imagePath;
  final double size;
  final BrowserController controller;
  final bool enableDrag;

  const ImageThumbnail({
    super.key,
    required this.imagePath,
    required this.size,
    required this.controller,
    this.enableDrag = true,
  });

  @override
  State<ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<ImageThumbnail>
    with SingleTickerProviderStateMixin {
  late final FPopoverController _popoverController;

  bool _skipNextTap = false;

  bool _mouseDown = false;
  bool _mouseDragStarted = false;
  bool _mouseCtrlPressed = false;
  bool _mouseShiftPressed = false;

  // Read modifier keys from current keyboard state.
  // We read on pointer-up to reduce focus-related inconsistencies.
  (bool ctrlOrMeta, bool shift) _readModifierKeys() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final ctrlOrMeta =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    final shift =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    return (ctrlOrMeta, shift);
  }

  @override
  void initState() {
    super.initState();
    _popoverController = FPopoverController(vsync: this);
  }

  @override
  void dispose() {
    _popoverController.dispose();
    super.dispose();
  }

  // Ensures the current thumbnail is part of selection before executing an action.
  void _ensureSelectionForAction() {
    if (widget.controller.selectedImages.contains(widget.imagePath)) {
      return;
    }
    widget.controller.selectSingleImage(widget.imagePath);
  }

  void _showMoveToFolderDialog(BuildContext context) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => MoveToFolderDialog(
        controller: widget.controller,
        currentPath: widget.controller.currentPath.value,
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, String fileName) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => DeleteImageConfirmDialog(
        controller: widget.controller,
        imagePath: widget.imagePath,
        fileName: fileName,
      ),
    );
  }

  void _showDeleteSelectedConfirmDialog(BuildContext context, int count) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => DeleteSelectedConfirmDialog(
        controller: widget.controller,
        count: count,
      ),
    );
  }

  Widget _buildDragFeedback(FThemeData theme, int count) {
    final content = SizedBox(
      width: widget.size,
      height: widget.size,
      child: ImageThumbnailContent(
        controller: widget.controller,
        imagePath: widget.imagePath,
        size: widget.size,
        isSelected: true,
      ),
    );

    if (count <= 1) return content;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        Positioned(
          right: -6,
          top: -6,
          child: FBadge(
            style: FBadgeStyle.primary(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('$count'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    return GetBuilder<BrowserController>(
      id: widget.imagePath,
      builder: (_) {
        final isSelected = widget.controller.selectedImages.contains(
          widget.imagePath,
        );

        // If dragging a selected image, drag all selected; otherwise drag only this image
        final dragData =
            isSelected && widget.controller.selectedImages.isNotEmpty
            ? widget.controller.selectedImages.toList()
            : [widget.imagePath];

        return _buildThumbnailWithMenu(theme, isSelected, dragData);
      },
    );
  }

  Widget _buildThumbnailWithMenu(
    FThemeData theme,
    bool isSelected,
    List<String> dragData,
  ) {
    final fileName = p.basename(widget.imagePath);

    return FPopoverMenu(
      popoverController: _popoverController,
      menuAnchor: Alignment.topLeft,
      childAnchor: Alignment.bottomLeft,
      style: (style) => style.copyWith(maxWidth: 180),
      menu: [FItemGroup(children: _buildContextMenuItems(theme, fileName))],
      builder: (context, controller, child) {
        final content = FTooltip(
          hoverEnterDuration: const Duration(milliseconds: 200),
          tipBuilder: (context, _) =>
              ImageThumbnailTooltip(imagePath: widget.imagePath),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (event.kind != PointerDeviceKind.mouse) return;
              if (event.buttons != kPrimaryButton) return;

              _mouseDown = true;
              _mouseDragStarted = false;
              _mouseCtrlPressed = false;
              _mouseShiftPressed = false;
            },
            onPointerUp: (event) {
              if (event.kind != PointerDeviceKind.mouse) return;
              if (!_mouseDown) return;

              if (!_mouseDragStarted) {
                final modifiers = _readModifierKeys();
                _mouseCtrlPressed = modifiers.$1;
                _mouseShiftPressed = modifiers.$2;
                widget.controller.handleImageTapSelection(
                  widget.imagePath,
                  isCtrlPressed: _mouseCtrlPressed,
                  isShiftPressed: _mouseShiftPressed,
                );
                _skipNextTap = true;
              }

              _mouseDown = false;
              _mouseDragStarted = false;
              _mouseCtrlPressed = false;
              _mouseShiftPressed = false;
            },
            child: GestureDetector(
              onTap: () {
                if (_skipNextTap) {
                  _skipNextTap = false;
                  return;
                }
                widget.controller.selectSingleImage(widget.imagePath);
              },
              onDoubleTap: () => _openImagePreview(context),
              onSecondaryTap: controller.toggle,
              child: ImageThumbnailContent(
                controller: widget.controller,
                imagePath: widget.imagePath,
                size: widget.size,
                isSelected: isSelected,
              ),
            ),
          ),
        );

        // Internal drag: move to folder OR reorder within current folder.
        final draggable = Draggable<List<String>>(
          data: dragData,
          feedback: IgnorePointer(
            child: _buildDragFeedback(theme, dragData.length),
          ),
          onDragStarted: () {
            _mouseDragStarted = true;
            _skipNextTap = true;
            // Auto-select when dragging if not already selected.
            if (!widget.controller.selectedImages.contains(widget.imagePath)) {
              widget.controller.selectedImages
                ..clear()
                ..add(widget.imagePath);
            }

            if (widget.controller.canReorderInCurrentFolder &&
                widget.controller.selectedImages.length == 1) {
              widget.controller.startReorder(widget.imagePath);
            }
          },
          onDragCompleted: () {
            widget.controller.handleReorderDragEnd(wasAccepted: true);
          },
          onDraggableCanceled: (velocity, offset) {
            widget.controller.handleReorderDragEnd(wasAccepted: false);
          },
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: ImageThumbnailContent(
              controller: widget.controller,
              imagePath: widget.imagePath,
              size: widget.size,
              isSelected: true,
            ),
          ),
          child: content,
        );

        if (!widget.controller.canReorderInCurrentFolder) {
          return draggable;
        }

        return DragTarget<List<String>>(
          onWillAcceptWithDetails: (details) {
            final canReorder =
                widget.controller.isReordering.value &&
                widget.controller.selectedImages.length == 1;
            if (canReorder) {
              widget.controller.previewReorderTo(widget.imagePath);
            }
            return canReorder;
          },
          onMove: (details) {
            if (widget.controller.isReordering.value &&
                widget.controller.selectedImages.length == 1) {
              widget.controller.previewReorderTo(widget.imagePath);
            }
          },
          onAcceptWithDetails: (details) {
            widget.controller.previewReorderTo(widget.imagePath);
            widget.controller.commitReorderAndRenumber();
          },
          builder: (context, candidateData, rejectedData) {
            return draggable;
          },
        );
      },
    );
  }

  List<FItemMixin> _buildContextMenuItems(FThemeData theme, String fileName) {
    final isMultiSelect = widget.controller.selectedImages.length > 1;
    return <FItemMixin>[
      FItem(
        prefix: const Icon(FIcons.folderOpen),
        title: Text('show_in_finder'.tr),
        onPress: () {
          _popoverController.hide();
          widget.controller.openInFinder(widget.imagePath);
        },
      ),
      FItem(
        prefix: const Icon(FIcons.move),
        title: Text('move_to_folder'.tr),
        onPress: () {
          _popoverController.hide();
          _ensureSelectionForAction();
          _showMoveToFolderDialog(context);
        },
      ),
      if (!isMultiSelect)
        FItem(
          prefix: Icon(FIcons.trash2, color: theme.colors.destructive),
          title: Text(
            'delete'.tr,
            style: TextStyle(color: theme.colors.destructive),
          ),
          onPress: () {
            _popoverController.hide();
            _ensureSelectionForAction();
            _showDeleteConfirmDialog(context, fileName);
          },
        )
      else
        FItem(
          prefix: Icon(FIcons.trash2, color: theme.colors.destructive),
          title: Text(
            'delete_selected'.tr,
            style: TextStyle(color: theme.colors.destructive),
          ),
          onPress: () {
            _popoverController.hide();
            _ensureSelectionForAction();
            _showDeleteSelectedConfirmDialog(
              context,
              widget.controller.selectedImages.length,
            );
          },
        ),
    ];
  }

  void _openImagePreview(BuildContext context) {
    // Get all image paths from controller
    final imageList = widget.controller.imageFiles.map((f) => f.path).toList();

    showImagePreview(
      context,
      imagePath: widget.imagePath,
      imageList: imageList,
    );
  }
}
