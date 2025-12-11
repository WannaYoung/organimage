import 'dart:io';

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
      style: (style) => style.copyWith(maxWidth: 160),
      menu: [
        FItemGroup(
          children: [
            FItem(
              prefix: const Icon(FIcons.pencil),
              title: Text('rename'.tr),
              onPress: () {
                _popoverController.hide();
                _showRenameDialog(context, fileName);
              },
            ),
            FItem(
              prefix: const Icon(FIcons.folderOpen),
              title: Text('show_in_finder'.tr),
              onPress: () {
                _popoverController.hide();
                widget.controller.openInFinder(widget.imagePath);
              },
            ),
            FItem(
              prefix: Icon(FIcons.trash2, color: theme.colors.destructive),
              title: Text(
                'delete'.tr,
                style: TextStyle(color: theme.colors.destructive),
              ),
              onPress: () {
                _popoverController.hide();
                _showDeleteConfirmDialog(context, fileName);
              },
            ),
          ],
        ),
      ],
      builder: (context, controller, child) {
        final content = FTooltip(
          tipBuilder: (context, _) => _buildTooltipContent(),
          child: GestureDetector(
            onTap: () =>
                widget.controller.toggleImageSelection(widget.imagePath),
            onDoubleTap: () => _openImagePreview(context),
            onSecondaryTap: controller.toggle,
            child: _buildThumbnailContent(theme, isSelected),
          ),
        );

        // Wrap with Draggable for drag to folder support
        return Draggable<List<String>>(
          data: dragData,
          feedback: _buildDragFeedback(theme, dragData.length),
          onDragStarted: () {
            // Auto-select when dragging if not already selected
            if (!widget.controller.selectedImages.contains(widget.imagePath)) {
              widget.controller.selectedImages.add(widget.imagePath);
            }
          },
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _buildThumbnailContent(theme, true),
          ),
          child: content,
        );
      },
    );
  }

  Widget _buildTooltipContent() {
    try {
      final file = File(widget.imagePath);
      final stat = file.statSync();
      final size = formatFileSize(stat.size);
      final modified = stat.modified;
      final dateStr =
          '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}';

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.basename(widget.imagePath)),
          Text('$size  •  $dateStr'),
        ],
      );
    } catch (e) {
      return Text(p.basename(widget.imagePath));
    }
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

  void _showRenameDialog(BuildContext context, String currentName) {
    final nameWithoutExt = p.basenameWithoutExtension(widget.imagePath);
    final ext = p.extension(widget.imagePath);
    final textController = TextEditingController(text: nameWithoutExt);
    final theme = FTheme.of(context);

    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text('rename_image'.tr),
        body: Row(
          children: [
            Expanded(
              child: FTextField(
                controller: textController,
                autofocus: true,
                hint: 'enter_new_name'.tr,
              ),
            ),
            const SizedBox(width: 8),
            Text(ext, style: theme.typography.base),
          ],
        ),
        direction: Axis.horizontal,
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr),
          ),
          FButton(
            onPress: () {
              final newName = '${textController.text.trim()}$ext';
              if (textController.text.trim().isNotEmpty &&
                  newName != currentName) {
                widget.controller.renameImage(widget.imagePath, newName);
              }
              Navigator.of(context).pop();
            },
            child: Text('confirm'.tr),
          ),
        ],
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
}
