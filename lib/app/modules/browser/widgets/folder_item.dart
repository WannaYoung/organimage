import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../controllers/browser_controller.dart';
import 'image_preview.dart';

/// 文件夹项组件，显示单个文件夹的信息和操作
class FolderItem extends StatefulWidget {
  final Directory folder;
  final BrowserController controller;

  const FolderItem({super.key, required this.folder, required this.controller});

  @override
  State<FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<FolderItem>
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

  Widget _buildFolderIcon(FThemeData theme, bool isHighlighted) {
    return Container(
      color: theme.colors.secondary,
      child: Center(
        child: Icon(
          FIcons.folder,
          color: isHighlighted
              ? theme.colors.primary
              : theme.colors.brightness == Brightness.dark
              ? const Color(0xFFFFCC80)
              : const Color(0xFFFFB74D),
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    final folderName = p.basename(widget.folder.path);

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
        // 如果有文件被拖拽则接受
        return details.data.isNotEmpty;
      },
      onAcceptWithDetails: (details) {
        // 直接使用拖拽的数据，包含自动选中的图片
        widget.controller.endReorderAfterAcceptedDrop();
        widget.controller.moveSelectedToFolder(widget.folder.path);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return FPopoverMenu(
          popoverController: _popoverController,
          menuAnchor: Alignment.topLeft,
          childAnchor: Alignment.bottomLeft,
          style: (style) => style.copyWith(maxWidth: 180),
          menu: [
            FItemGroup(
              children: [
                FItem(
                  prefix: const Icon(FIcons.pencil),
                  title: Text('rename'.tr),
                  onPress: () {
                    _popoverController.hide();
                    _showRenameDialog(this.context, folderName);
                  },
                ),
                FItem(
                  prefix: const Icon(FIcons.folderOpen),
                  title: Text('show_in_finder'.tr),
                  onPress: () {
                    _popoverController.hide();
                    widget.controller.openInFinder(widget.folder.path);
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
                    _showDeleteConfirmDialog(this.context, folderName);
                  },
                ),
              ],
            ),
          ],
          builder: (context, controller, child) => Obx(() {
            final isSelected =
                widget.controller.currentPath.value == widget.folder.path;
            final fileCount = widget.controller.getFolderFileCount(
              widget.folder.path,
            );
            final previewImage = widget.controller.getFolderPreviewImage(
              widget.folder.path,
            );
            return GestureDetector(
              onTap: () =>
                  widget.controller.navigateToFolder(widget.folder.path),
              onDoubleTap: () => _openFirstImagePreview(this.context),
              onSecondaryTap: controller.toggle,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isHovering || isSelected
                      ? theme.colors.primary.withValues(alpha: 0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // 缩略图预览或文件夹图标
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isHovering || isSelected
                              ? theme.colors.primary
                              : theme.colors.border.withValues(alpha: 0.5),
                          width: isHovering || isSelected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: previewImage != null
                            ? Image.file(
                                File(previewImage),
                                fit: BoxFit.cover,
                                cacheWidth: 72,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildFolderIcon(
                                      theme,
                                      isHovering || isSelected,
                                    ),
                              )
                            : _buildFolderIcon(theme, isHovering || isSelected),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        folderName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.sm.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    FBadge(child: Text('$fileCount')),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Future<void> _openFirstImagePreview(BuildContext context) async {
    final firstImage = await widget.controller.directoryService.getFirstImage(
      widget.folder.path,
    );
    if (firstImage == null) return;

    final images = await widget.controller.directoryService.getImageFiles(
      widget.folder.path,
    );
    final imageList = images.map((f) => f.path).toList();

    if (!context.mounted) return;

    showImagePreview(context, imagePath: firstImage, imageList: imageList);
  }

  void _showRenameDialog(BuildContext context, String currentName) {
    final textController = TextEditingController(text: currentName);

    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text('rename_folder'.tr),
        body: FTextField(
          controller: textController,
          autofocus: true,
          hint: 'enter_new_name'.tr,
          textInputAction: TextInputAction.done,
          onSubmit: (value) {
            final newName = value.trim();
            if (newName.isNotEmpty && newName != currentName) {
              widget.controller.renameFolderWithContents(
                widget.folder.path,
                newName,
              );
            }
            Navigator.of(context).pop();
          },
        ),
        direction: Axis.horizontal,
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr),
          ),
          FButton(
            onPress: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                widget.controller.renameFolderWithContents(
                  widget.folder.path,
                  newName,
                );
              }
              Navigator.of(context).pop();
            },
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, String folderName) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text('delete_folder'.tr),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FAlert(
              style: FAlertStyle.destructive(),
              icon: const Icon(FIcons.triangleAlert),
              title: Text('action_irreversible'.tr),
              subtitle: Text(
                'folder_delete_warning'.trParams({'name': folderName}),
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
              widget.controller.deleteFolderByPath(widget.folder.path);
              Navigator.of(context).pop();
            },
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }
}
