import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import 'services/storage_service.dart';

/// Available theme colors
enum ThemeColor { zinc, slate, red, rose, orange, green, blue, yellow, violet }

/// Theme controller for managing app theme and locale
class ThemeController extends GetxController {
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final Rx<ThemeColor> themeColor = ThemeColor.zinc.obs;
  final Rx<Locale> locale = const Locale('en', 'US').obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load theme mode
    final savedThemeMode = await StorageService.getThemeMode();
    if (savedThemeMode != null) {
      switch (savedThemeMode) {
        case 'light':
          themeMode.value = ThemeMode.light;
          break;
        case 'dark':
          themeMode.value = ThemeMode.dark;
          break;
        default:
          themeMode.value = ThemeMode.system;
      }
    }

    // Load language
    final savedLanguage = await StorageService.getLanguage();
    if (savedLanguage != null) {
      switch (savedLanguage) {
        case 'zh_CN':
          locale.value = const Locale('zh', 'CN');
          break;
        case 'zh_TW':
          locale.value = const Locale('zh', 'TW');
          break;
        default:
          locale.value = const Locale('en', 'US');
      }
      Get.updateLocale(locale.value);
    } else if (Get.locale != null) {
      locale.value = Get.locale!;
    }

    // Load theme color
    final savedThemeColor = await StorageService.getThemeColor();
    if (savedThemeColor != null) {
      try {
        themeColor.value = ThemeColor.values.firstWhere(
          (c) => c.name == savedThemeColor,
          orElse: () => ThemeColor.zinc,
        );
      } catch (_) {
        themeColor.value = ThemeColor.zinc;
      }
    }
  }

  void setLocale(Locale newLocale) {
    locale.value = newLocale;
    Get.updateLocale(newLocale);
    // Save to storage
    final langCode = '${newLocale.languageCode}_${newLocale.countryCode}';
    StorageService.setLanguage(langCode);
  }

  FThemeData get lightTheme => _getThemes().$1;
  FThemeData get darkTheme => _getThemes().$2;

  (FThemeData, FThemeData) _getThemes() {
    switch (themeColor.value) {
      case ThemeColor.zinc:
        return (FThemes.zinc.light, FThemes.zinc.dark);
      case ThemeColor.slate:
        return (FThemes.slate.light, FThemes.slate.dark);
      case ThemeColor.red:
        return (FThemes.red.light, FThemes.red.dark);
      case ThemeColor.rose:
        return (FThemes.rose.light, FThemes.rose.dark);
      case ThemeColor.orange:
        return (FThemes.orange.light, FThemes.orange.dark);
      case ThemeColor.green:
        return (FThemes.green.light, FThemes.green.dark);
      case ThemeColor.blue:
        return (FThemes.blue.light, FThemes.blue.dark);
      case ThemeColor.yellow:
        return (FThemes.yellow.light, FThemes.yellow.dark);
      case ThemeColor.violet:
        return (FThemes.violet.light, FThemes.violet.dark);
    }
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    // Save to storage
    String? modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
    }
    StorageService.setThemeMode(modeStr);
  }

  void setThemeColor(ThemeColor color) {
    themeColor.value = color;
    // Save to storage
    StorageService.setThemeColor(color.name);
  }

  String get themeModeLabel {
    switch (themeMode.value) {
      case ThemeMode.system:
        return 'follow_system'.tr;
      case ThemeMode.light:
        return 'light_mode'.tr;
      case ThemeMode.dark:
        return 'dark_mode'.tr;
    }
  }

  String getColorLabel(ThemeColor color) {
    switch (color) {
      case ThemeColor.zinc:
        return 'color_zinc'.tr;
      case ThemeColor.slate:
        return 'color_slate'.tr;
      case ThemeColor.red:
        return 'color_red'.tr;
      case ThemeColor.rose:
        return 'color_rose'.tr;
      case ThemeColor.orange:
        return 'color_orange'.tr;
      case ThemeColor.green:
        return 'color_green'.tr;
      case ThemeColor.blue:
        return 'color_blue'.tr;
      case ThemeColor.yellow:
        return 'color_yellow'.tr;
      case ThemeColor.violet:
        return 'color_violet'.tr;
    }
  }

  Color getColorPreview(ThemeColor color) {
    switch (color) {
      case ThemeColor.zinc:
        return const Color(0xFF71717A);
      case ThemeColor.slate:
        return const Color(0xFF64748B);
      case ThemeColor.red:
        return const Color(0xFFDC2626);
      case ThemeColor.rose:
        return const Color(0xFFE11D48);
      case ThemeColor.orange:
        return const Color(0xFFF97316);
      case ThemeColor.green:
        return const Color(0xFF16A34A);
      case ThemeColor.blue:
        return const Color(0xFF2563EB);
      case ThemeColor.yellow:
        return const Color(0xFFFACC15);
      case ThemeColor.violet:
        return const Color(0xFF7C3AED);
    }
  }
}
