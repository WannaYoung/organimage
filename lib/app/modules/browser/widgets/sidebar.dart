import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../controllers/browser_controller.dart';
import 'folder_item.dart';

/// 侧边栏组件，显示文件夹列表
class Sidebar extends StatelessWidget {
  final BrowserController controller;

  const Sidebar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 总项目数 = 1（根目录）+ 子目录数量
      final totalItems = 1 + controller.subdirectories.length;

      return FSidebar.builder(
        style: (style) => style.copyWith(constraints: const BoxConstraints()),
        header: _buildHeader(context),
        footer: _buildNewFolderButton(context),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (index == 0) {
            // 根文件夹项
            return _buildRootFolderItem(context);
          }
          // 子文件夹项
          final folder = controller.subdirectories[index - 1];
          return FolderItem(folder: folder, controller: controller);
        },
      );
    });
  }

  Widget _buildRootFolderItem(BuildContext context) {
    final theme = FTheme.of(context);
    final rootPath = controller.rootPath.value;
    if (rootPath == null) return const SizedBox.shrink();

    final folderName = p.basename(rootPath);

    return Obx(() {
      final isSelected = controller.currentPath.value == rootPath;
      // 只有不在根目录时才接受拖放
      final canAcceptDrop = !controller.isAtRoot;
      final previewImage = controller.getFolderPreviewImage(rootPath);

      return DragTarget<List<String>>(
        onWillAcceptWithDetails: (details) {
          // 只有不在根目录且有文件时才接受
          return canAcceptDrop && details.data.isNotEmpty;
        },
        onAcceptWithDetails: (details) {
          controller.endReorderAfterAcceptedDrop();
          controller.moveSelectedToRootFolder();
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return GestureDetector(
            onTap: () => controller.navigateToFolder(rootPath),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isHovering || isSelected
                    ? theme.colors.primary.withValues(alpha: 0.1)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // 缩略图预览或主页图标
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
                                  _buildHomeIcon(
                                    theme,
                                    isHovering || isSelected,
                                  ),
                            )
                          : _buildHomeIcon(theme, isHovering || isSelected),
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
                  FBadge(child: Text('root'.tr)),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildHomeIcon(FThemeData theme, bool isSelected) {
    return Container(
      color: theme.colors.secondary,
      child: Center(
        child: Icon(
          FIcons.house,
          color: isSelected
              ? theme.colors.primary
              : theme.colors.mutedForeground,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = FTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 15, left: 12),
      child: FHeader.nested(
        prefixes: [
          FTooltip(
            tipBuilder: (context, _) => Text('back_home'.tr),
            child: FHeaderAction(
              icon: Icon(FIcons.house, size: 30, color: theme.colors.primary),
              onPress: controller.goToHome,
            ),
          ),
          const SizedBox(width: 2),
        ],
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.currentFolderName,
                style: theme.typography.base.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'folders_count'.trParams({
                  'count': '${controller.subdirectories.length}',
                }),
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        titleAlignment: Alignment.centerLeft,
      ),
    );
  }

  Widget _buildNewFolderButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: FButton(
          onPress: () => _showCreateFolderDialog(context),
          prefix: const Icon(FIcons.folderPlus, size: 18),
          child: Text('new_folder'.tr),
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final textController = TextEditingController();

    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text('create_folder'.tr),
        body: FTextField(
          controller: textController,
          autofocus: true,
          hint: 'enter_folder_name'.tr,
          textInputAction: TextInputAction.done,
          onSubmit: (value) {
            final name = value.trim();
            if (name.isNotEmpty) {
              controller.createNewFolder(name);
              Navigator.of(context).pop();
            }
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
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                controller.createNewFolder(name);
                Navigator.of(context).pop();
              }
            },
            child: Text('create'.tr),
          ),
        ],
      ),
    );
  }
}
