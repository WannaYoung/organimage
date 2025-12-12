import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import 'app/core/core.dart';
import 'app/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();
  final windowOptions = WindowOptions(
    minimumSize: const Size(800, 600),
    size: const Size(1200, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: Platform.isMacOS
        ? TitleBarStyle.hidden
        : TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('图片整理');
    await windowManager.show();
    await windowManager.focus();
  });

  Get.put(ThemeController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Locale _getInitialLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    if (deviceLocale.languageCode == 'zh') {
      if (deviceLocale.scriptCode == 'Hant' ||
          deviceLocale.countryCode == 'TW' ||
          deviceLocale.countryCode == 'HK') {
        return const Locale('zh', 'TW');
      }
      return const Locale('zh', 'CN');
    }
    return const Locale('en', 'US');
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final lightTheme = themeController.lightTheme;
      final darkTheme = themeController.darkTheme;
      final themeMode = themeController.themeMode.value;

      return GetMaterialApp(
        title: 'app_name'.tr,
        debugShowCheckedModeBanner: false,
        translations: AppTranslations(),
        locale: _getInitialLocale(),
        fallbackLocale: const Locale('en', 'US'),
        supportedLocales: FLocalizations.supportedLocales,
        localizationsDelegates: FLocalizations.localizationsDelegates,
        theme: lightTheme.toApproximateMaterialTheme(),
        darkTheme: darkTheme.toApproximateMaterialTheme(),
        themeMode: themeMode,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        builder: (context, child) {
          final brightness = themeMode == ThemeMode.system
              ? MediaQuery.platformBrightnessOf(context)
              : (themeMode == ThemeMode.dark
                    ? Brightness.dark
                    : Brightness.light);
          return FAnimatedTheme(
            data: brightness == Brightness.dark ? darkTheme : lightTheme,
            child: FToaster(child: child ?? const SizedBox.shrink()),
          );
        },
      );
    });
  }
}
