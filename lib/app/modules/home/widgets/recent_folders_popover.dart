import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';

/// 最近文件夹弹出框组件
class RecentFoldersPopover extends GetView<HomeController> {
  const RecentFoldersPopover({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);

    ImageFilter blurFilter(double animation) => ImageFilter.compose(
      outer: ImageFilter.blur(sigmaX: animation * 5, sigmaY: animation * 5),
      inner: ColorFilter.mode(
        Color.lerp(
          Colors.transparent,
          Colors.black.withValues(alpha: 0.2),
          animation,
        )!,
        BlendMode.srcOver,
      ),
    );

    return FPopover(
      style: (style) => style.copyWith(barrierFilter: blurFilter),
      popoverAnchor: Alignment.bottomCenter,
      childAnchor: Alignment.topCenter,
      popoverBuilder: (context, popoverController) => Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FIcons.history,
                    size: 20,
                    color: theme.colors.foreground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'recent_folders'.tr,
                    style: theme.typography.base.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  FButton(
                    style: FButtonStyle.ghost(),
                    onPress: () {
                      controller.clearRecentFolders();
                      popoverController.hide();
                    },
                    child: Text('clear'.tr),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const FDivider(),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Obx(
                  () => ListView.separated(
                    shrinkWrap: true,
                    itemCount: controller.recentFolders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final path = controller.recentFolders[index];
                      final folderName = path.split('/').last;
                      return _buildFolderItem(
                        context,
                        theme,
                        path,
                        folderName,
                        popoverController,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      builder: (context, popoverController, child) => FButton(
        style: FButtonStyle.outline(),
        onPress: popoverController.toggle,
        prefix: const Icon(FIcons.history, size: 18),
        child: Text('recent_folders'.tr),
      ),
    );
  }

  Widget _buildFolderItem(
    BuildContext context,
    FThemeData theme,
    String path,
    String folderName,
    FPopoverController popoverController,
  ) {
    return GestureDetector(
      onTap: () {
        popoverController.hide();
        controller.openRecentFolder(path);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colors.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(FIcons.folder, color: theme.colors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folderName,
                    style: theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
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
