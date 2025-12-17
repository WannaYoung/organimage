import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../widgets/widgets.dart';

/// 主页视图，显示应用介绍和文件夹选择
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);

    return FScaffold(
      child: Stack(
        children: [
          // 主要内容
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 带渐变背景的应用图标
                    _buildAppIcon(theme),
                    const SizedBox(height: 32),

                    // 标题
                    Text(
                      'app_name'.tr,
                      style: theme.typography.xl3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 副标题
                    Text(
                      'app_subtitle'.tr,
                      style: theme.typography.base.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // 功能提示
                    _buildFeatureHints(theme),
                    const SizedBox(height: 40),

                    // 按钮行
                    _buildActionButtons(theme),
                  ],
                ),
              ),
            ),
          ),

          // 右上角带弹出框的设置按钮
          const Positioned(top: 16, right: 16, child: SettingsPopover()),
        ],
      ),
    );
  }

  Widget _buildAppIcon(FThemeData theme) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colors.primary,
            theme.colors.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.colors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(FIcons.images, size: 56, color: Color(0xFFFFFFFF)),
    );
  }

  Widget _buildFeatureHints(FThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildFeatureBadge(theme, FIcons.move, 'feature_drag'.tr),
        _buildFeatureBadge(theme, FIcons.type, 'feature_rename'.tr),
        _buildFeatureBadge(theme, FIcons.grid3x3, 'feature_preview'.tr),
      ],
    );
  }

  Widget _buildFeatureBadge(FThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colors.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colors.mutedForeground),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.typography.sm.copyWith(color: theme.colors.foreground),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(FThemeData theme) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        // 选择文件夹按钮
        Obx(
          () => FButton(
            onPress: controller.isLoading.value
                ? null
                : controller.selectFolder,
            prefix: controller.isLoading.value
                ? const SizedBox(width: 16, height: 16, child: FProgress())
                : const Icon(FIcons.folderOpen, size: 18),
            child: Text(
              controller.isLoading.value ? 'selecting'.tr : 'select_folder'.tr,
            ),
          ),
        ),
        // 带弹出框的最近文件夹按钮
        Obx(
          () => controller.recentFolders.isNotEmpty
              ? const RecentFoldersPopover()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
