import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

const _successColor = Color(0xFF22C55E);
const _errorColor = Color(0xFFEF4444);
const _infoColor = Color(0xFF3B82F6);

/// 在底部中央显示成功提示
void showSuccessToast(String message) {
  final context = Get.context;
  if (context == null) return;
  final theme = FTheme.of(context);
  showFToast(
    context: context,
    icon: const Icon(FIcons.circleCheck, color: _successColor),
    title: Text(message, style: TextStyle(color: theme.colors.foreground)),
    alignment: FToastAlignment.bottomCenter,
  );
}

/// 在底部中央显示错误提示
void showErrorToast(String message) {
  final context = Get.context;
  if (context == null) return;
  final theme = FTheme.of(context);
  showFToast(
    context: context,
    icon: const Icon(FIcons.circleX, color: _errorColor),
    title: Text(message, style: TextStyle(color: theme.colors.foreground)),
    alignment: FToastAlignment.bottomCenter,
  );
}

/// 在底部中央显示信息提示
void showInfoToast(String message) {
  final context = Get.context;
  if (context == null) return;
  final theme = FTheme.of(context);
  showFToast(
    context: context,
    icon: const Icon(FIcons.info, color: _infoColor),
    title: Text(message, style: TextStyle(color: theme.colors.foreground)),
    alignment: FToastAlignment.bottomCenter,
  );
}
