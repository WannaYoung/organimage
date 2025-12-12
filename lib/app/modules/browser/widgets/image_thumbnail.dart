import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/file_utils.dart';
import '../controllers/browser_controller.dart';
import 'image_preview.dart';

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

  bool _isCtrlOrMetaPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
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

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    return Obx(() {
      final isSelected = widget.controller.selectedImages.contains(
        widget.imagePath,
      );

      // If dragging a selected image, drag all selected; otherwise drag only this image
      final dragData = isSelected && widget.controller.selectedImages.isNotEmpty
          ? widget.controller.selectedImages.toList()
          : [widget.imagePath];

      return _buildThumbnailWithMenu(theme, isSelected, dragData);
    });
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
      menu: [
        FItemGroup(
          children: [
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
            if (widget.controller.selectedImages.length <= 1)
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
          ],
        ),
      ],
      builder: (context, controller, child) {
        final content = FTooltip(
          hoverEnterDuration: const Duration(milliseconds: 200),
          tipBuilder: (context, _) => _buildTooltipContent(),
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
                _mouseCtrlPressed = _isCtrlOrMetaPressed();
                _mouseShiftPressed = _isShiftPressed();
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
              child: _buildThumbnailContent(theme, isSelected),
            ),
          ),
        );

        // Wrap with Draggable for drag to folder support
        final draggable = Draggable<List<String>>(
          data: dragData,
          feedback: IgnorePointer(
            child: _buildDragFeedback(theme, dragData.length),
          ),
          onDragStarted: () {
            _mouseDragStarted = true;
            _skipNextTap = true;
            // Auto-select when dragging if not already selected
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
            child: _buildThumbnailContent(theme, true),
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

  void _ensureSelectionForAction() {
    if (widget.controller.selectedImages.contains(widget.imagePath)) {
      return;
    }
    widget.controller.selectSingleImage(widget.imagePath);
  }

  void _showMoveToFolderDialog(BuildContext context) {
    final rootPath = widget.controller.rootPath.value;
    if (rootPath == null) return;

    final currentPath = widget.controller.currentPath.value;
    final targets = <String>[
      rootPath,
      ...widget.controller.subdirectories.map((d) => d.path),
    ].where((p) => p != currentPath).toList();

    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text('choose_target_folder'.tr),
        body: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: targets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final target = targets[index];
              final isRoot = target == rootPath;
              final name = p.basename(target);
              return _buildTargetFolderItem(
                context,
                FTheme.of(context),
                name,
                target,
                isRoot: isRoot,
                onTap: () {
                  Navigator.of(context).pop();
                  if (isRoot) {
                    widget.controller.moveSelectedToRootFolder();
                  } else {
                    widget.controller.moveSelectedToFolder(target);
                  }
                },
              );
            },
          ),
        ),
        direction: Axis.horizontal,
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetFolderItem(
    BuildContext context,
    FThemeData theme,
    String name,
    String path, {
    required bool isRoot,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colors.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isRoot ? FIcons.house : FIcons.folder,
              color: theme.colors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: theme.typography.sm.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRoot) FBadge(child: Text('root'.tr)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path,
                    style: theme.typography.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              FIcons.chevronRight,
              color: theme.colors.mutedForeground,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipContent() {
    final theme = FTheme.of(context);
    final labelStyle = theme.typography.sm.copyWith(
      color: theme.colors.mutedForeground,
    );
    final valueStyle = theme.typography.sm.copyWith(
      color: theme.colors.foreground,
    );

    try {
      final file = File(widget.imagePath);
      final stat = file.statSync();
      final size = formatFileSize(stat.size);
      final modified = stat.modified;
      final dateStr =
          '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}';
      final fileName = p.basename(widget.imagePath);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTooltipRow(labelStyle, valueStyle, 'file_name'.tr, fileName),
          const SizedBox(height: 4),
          _buildTooltipRow(labelStyle, valueStyle, 'file_size'.tr, size),
          const SizedBox(height: 4),
          _buildTooltipRow(labelStyle, valueStyle, 'modified_date'.tr, dateStr),
        ],
      );
    } catch (e) {
      return Text(p.basename(widget.imagePath), style: valueStyle);
    }
  }

  Widget _buildTooltipRow(
    TextStyle labelStyle,
    TextStyle valueStyle,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
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

  Widget _buildDragFeedback(FThemeData theme, int count) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        image: DecorationImage(
          image: FileImage(File(widget.imagePath)),
          fit: BoxFit.cover,
        ),
      ),
      child: count > 1
          ? Container(
              decoration: BoxDecoration(
                color: const Color(0x88000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: theme.typography.lg.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildThumbnailContent(FThemeData theme, bool isSelected) {
    final isDark = theme.colors.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? theme.colors.primary
              : isDark
              ? theme.colors.border.withValues(alpha: 0.3)
              : const Color(0x00000000),
          width: isSelected ? 3 : 1,
        ),
        color: null,
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x1A000000),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
              cacheWidth: (widget.size * 2).toInt(),
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: theme.colors.secondary,
                  child: Icon(
                    FIcons.imageOff,
                    color: theme.colors.mutedForeground,
                  ),
                );
              },
            ),
            // File name overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
                child: Text(
                  p.basenameWithoutExtension(widget.imagePath),
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    FIcons.check,
                    size: 14,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, String fileName) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text('delete_image'.tr),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FAlert(
              style: FAlertStyle.destructive(),
              icon: const Icon(FIcons.triangleAlert),
              title: Text('action_irreversible'.tr),
              subtitle: Text(
                'image_delete_warning'.trParams({'name': fileName}),
              ),
            ),
          ],
        ),
        direction: Axis.horizontal,
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr),
          ),
          FButton(
            style: FButtonStyle.destructive(),
            onPress: () {
              widget.controller.deleteImage(widget.imagePath);
              Navigator.of(context).pop();
            },
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }

  void _showDeleteSelectedConfirmDialog(BuildContext context, int count) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text('delete_selected'.tr),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FAlert(
              style: FAlertStyle.destructive(),
              icon: const Icon(FIcons.triangleAlert),
              title: Text('action_irreversible'.tr),
              subtitle: Text('selected_count'.trParams({'count': '$count'})),
            ),
          ],
        ),
        direction: Axis.horizontal,
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr),
          ),
          FButton(
            style: FButtonStyle.destructive(),
            onPress: () {
              widget.controller.deleteSelectedImages();
              Navigator.of(context).pop();
            },
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }
}
