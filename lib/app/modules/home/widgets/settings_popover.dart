import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../../../core/theme_controller.dart';

class SettingsPopover extends StatelessWidget {
  const SettingsPopover({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    final themeController = Get.find<ThemeController>();

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
              // Header
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

              // Theme mode section
              _buildThemeModeSection(theme, themeController),
              const SizedBox(height: 12),
              const FDivider(),
              const SizedBox(height: 12),

              // Language section
              _buildLanguageSection(theme, themeController),
              const SizedBox(height: 12),
              const FDivider(),
              const SizedBox(height: 12),

              // Theme color section
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
                  'English',
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
                  '简体中文',
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
                  '繁體中文',
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
}
