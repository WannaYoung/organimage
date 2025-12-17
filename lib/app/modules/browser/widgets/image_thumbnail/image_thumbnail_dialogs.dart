import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../controllers/browser_controller.dart';

/// 移动到文件夹对话框组件
class MoveToFolderDialog extends StatelessWidget {
  final BrowserController controller;
  final String? currentPath;

  const MoveToFolderDialog({
    super.key,
    required this.controller,
    required this.currentPath,
  });

  // 构建用于移动当前选中项的文件夹选择对话框
  @override
  Widget build(BuildContext context) {
    final rootPath = controller.rootPath.value;
    if (rootPath == null) {
      return const SizedBox.shrink();
    }

    final targets = <String>[
      rootPath,
      ...controller.subdirectories.map((d) => d.path),
    ].where((p) => p != currentPath).toList();

    return FDialog(
      title: Text('choose_target_folder'.tr),
      body: ListView.separated(
        shrinkWrap: true,
        itemCount: targets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final target = targets[index];
          final isRoot = target == rootPath;
          final name = p.basename(target);
          return _TargetFolderItem(
            name: name,
            path: target,
            isRoot: isRoot,
            onTap: () {
              Navigator.of(context).pop();
              if (isRoot) {
                controller.moveSelectedToRootFolder();
              } else {
                controller.moveSelectedToFolder(target);
              }
            },
          );
        },
      ),

      direction: Axis.horizontal,
      actions: [
        FButton(
          onPress: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr),
        ),
      ],
    );
  }
}

class _TargetFolderItem extends StatelessWidget {
  final String name;
  final String path;
  final bool isRoot;
  final VoidCallback onTap;

  const _TargetFolderItem({
    required this.name,
    required this.path,
    required this.isRoot,
    required this.onTap,
  });

  // 渲染一个可选择的文件夹条目
  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
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
}

/// 删除图片确认对话框组件
class DeleteImageConfirmDialog extends StatelessWidget {
  final BrowserController controller;
  final String imagePath;
  final String fileName;

  const DeleteImageConfirmDialog({
    super.key,
    required this.controller,
    required this.imagePath,
    required this.fileName,
  });

  // 确认删除单张图片
  @override
  Widget build(BuildContext context) {
    return FDialog(
      title: Text('delete_image'.tr),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FAlert(
            style: FAlertStyle.destructive(),
            icon: const Icon(FIcons.triangleAlert),
            title: Text('action_irreversible'.tr),
            subtitle: Text('image_delete_warning'.trParams({'name': fileName})),
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
            controller.deleteImage(imagePath);
            Navigator.of(context).pop();
          },
          child: Text('delete'.tr),
        ),
      ],
    );
  }
}

/// 删除选中项确认对话框组件
class DeleteSelectedConfirmDialog extends StatelessWidget {
  final BrowserController controller;
  final int count;

  const DeleteSelectedConfirmDialog({
    super.key,
    required this.controller,
    required this.count,
  });

  // 确认删除当前选中项
  @override
  Widget build(BuildContext context) {
    return FDialog(
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
            controller.deleteSelectedImages();
            Navigator.of(context).pop();
          },
          child: Text('delete'.tr),
        ),
      ],
    );
  }
}
