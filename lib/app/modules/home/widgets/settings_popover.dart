import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../../../core/theme_controller.dart';
import '../controllers/home_controller.dart';

/// 设置弹出框组件
class SettingsPopover extends StatelessWidget {
  const SettingsPopover({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    final themeController = Get.find<ThemeController>();
    final homeController = Get.find<HomeController>();

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
      popoverAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      popoverBuilder: (context, popoverController) => Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    FIcons.settings,
                    size: 20,
                    color: theme.colors.foreground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'settings'.tr,
                    style: theme.typography.base.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const FDivider(),
              const SizedBox(height: 12),

              // 主题模式部分
              _buildThemeModeSection(theme, themeController),
              const SizedBox(height: 12),
              const FDivider(),
              const SizedBox(height: 12),

              // 语言部分
              _buildLanguageSection(theme, themeController),
              const SizedBox(height: 12),
              const FDivider(),
              const SizedBox(height: 12),

              _buildThumbnailSection(theme, homeController),
              const SizedBox(height: 12),
              const FDivider(),
              const SizedBox(height: 12),

              // 主题颜色部分
              _buildThemeColorSection(theme, themeController),
            ],
          ),
        ),
      ),
      builder: (context, popoverController, child) => FButton(
        onPress: popoverController.toggle,
        child: const Icon(FIcons.settings, size: 20),
      ),
    );
  }

  Widget _buildThemeModeSection(
    FThemeData theme,
    ThemeController themeController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'appearance_mode'.tr,
          style: theme.typography.sm.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Column(
            children: [
              FRadio(
                label: Text(
                  'follow_system'.tr,
                  style: TextStyle(color: theme.colors.foreground),
                ),
                value: themeController.themeMode.value == ThemeMode.system,
                onChange: (v) {
                  if (v) themeController.setThemeMode(ThemeMode.system);
                },
              ),
              const SizedBox(height: 4),
              FRadio(
                label: Text(
                  'light_mode'.tr,
                  style: TextStyle(color: theme.colors.foreground),
                ),
                value: themeController.themeMode.value == ThemeMode.light,
                onChange: (v) {
                  if (v) themeController.setThemeMode(ThemeMode.light);
                },
              ),
              const SizedBox(height: 4),
              FRadio(
                label: Text(
                  'dark_mode'.tr,
                  style: TextStyle(color: theme.colors.foreground),
                ),
                value: themeController.themeMode.value == ThemeMode.dark,
                onChange: (v) {
                  if (v) themeController.setThemeMode(ThemeMode.dark);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection(
    FThemeData theme,
    ThemeController themeController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'language'.tr,
          style: theme.typography.sm.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Column(
            children: [
              FRadio(
                label: Text(
                  'lang_en'.tr,
                  style: TextStyle(color: theme.colors.foreground),
                ),
                value: themeController.locale.value.languageCode == 'en',
                onChange: (v) {
                  if (v) {
                    themeController.setLocale(const Locale('en', 'US'));
                  }
                },
              ),
              const SizedBox(height: 4),
              FRadio(
                label: Text(
                  'lang_zh_cn'.tr,
                  style: TextStyle(color: theme.colors.foreground),
                ),
                value:
                    themeController.locale.value.languageCode == 'zh' &&
                    themeController.locale.value.countryCode == 'CN',
                onChange: (v) {
                  if (v) {
                    themeController.setLocale(const Locale('zh', 'CN'));
                  }
                },
              ),
              const SizedBox(height: 4),
              FRadio(
                label: Text(
                  'lang_zh_tw'.tr,
                  style: TextStyle(color: theme.colors.foreground),
                ),
                value:
                    themeController.locale.value.languageCode == 'zh' &&
                    themeController.locale.value.countryCode == 'TW',
                onChange: (v) {
                  if (v) {
                    themeController.setLocale(const Locale('zh', 'TW'));
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeColorSection(
    FThemeData theme,
    ThemeController themeController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'theme_color'.tr,
          style: theme.typography.sm.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ThemeColor.values.map((color) {
              final isSelected = themeController.themeColor.value == color;
              return GestureDetector(
                onTap: () => themeController.setThemeColor(color),
                child: FTooltip(
                  tipBuilder: (context, _) =>
                      Text(themeController.getColorLabel(color)),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: themeController.getColorPreview(color),
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(color: theme.colors.foreground, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            FIcons.check,
                            size: 16,
                            color: Color(0xFFFFFFFF),
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailSection(
    FThemeData theme,
    HomeController homeController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'browse_mode'.tr,
          style: theme.typography.sm.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => FCheckbox(
            style: (style) => style.copyWith(
              labelTextStyle: FWidgetStateMap.all(
                theme.typography.sm.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              descriptionTextStyle: FWidgetStateMap.all(
                theme.typography.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
            label: Text('thumbnail_mode'.tr),
            description: Text('thumbnail_mode_desc'.tr),
            semanticsLabel: 'thumbnail_mode'.tr,
            value: homeController.useThumbnails.value,
            onChange: (value) {
              homeController.setUseThumbnails(value);
            },
          ),
        ),
      ],
    );
  }
}
