import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../../../core/utils/file_utils.dart';
import '../controllers/browser_controller.dart';
import 'folder_item.dart';

class Sidebar extends StatelessWidget {
  final BrowserController controller;

  const Sidebar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Total items = 1 (root) + subdirectories count
      final totalItems = 1 + controller.subdirectories.length;

      return FSidebar.builder(
        style: (style) => style.copyWith(constraints: const BoxConstraints()),
        header: _buildHeader(context),
        footer: _buildNewFolderButton(context),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Root folder item
            return _buildRootFolderItem(context);
          }
          // Subfolder items
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

    final folderName = rootPath.split('/').last;
    final previewImage = getFirstImageInDirectory(rootPath);

    return Obx(() {
      final isSelected = controller.currentPath.value == rootPath;
      // Only accept drops when not in root directory
      final canAcceptDrop = !controller.isAtRoot;

      return DragTarget<List<String>>(
        onWillAcceptWithDetails: (details) {
          // Only accept if not in root directory and has files
          return canAcceptDrop && details.data.isNotEmpty;
        },
        onAcceptWithDetails: (details) {
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
                  // Thumbnail preview or home icon
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
      padding: const EdgeInsets.only(top: 15),
      child: FHeader.nested(
        prefixes: [
          FTooltip(
            tipBuilder: (context, _) => Text('back_home'.tr),
            child: FHeaderAction(
              icon: const Icon(FIcons.house),
              onPress: controller.goToHome,
            ),
          ),
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
