import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../../controllers/browser_controller.dart';
import 'image_grid_interactive.dart';

/// 图片网格主体组件，包含图片列表和加载状态
class ImageGridBody extends StatefulWidget {
  final BrowserController controller;

  const ImageGridBody({super.key, required this.controller});

  @override
  State<ImageGridBody> createState() => _ImageGridBodyState();
}

class _ImageGridBodyState extends State<ImageGridBody> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  BrowserController get controller => widget.controller;

  String? _lastPath;

  @override
  void initState() {
    super.initState();
    _lastPath = controller.currentPath.value;

    // 导航到不同文件夹时重置滚动位置
    ever(controller.currentPath, (path) {
      if (path != _lastPath) {
        _lastPath = path;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 提供选择的键盘快捷键处理
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyA, control: true):
            SelectAllIntent(),
        SingleActivator(LogicalKeyboardKey.keyA, meta: true): SelectAllIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SelectAllIntent: CallbackAction<SelectAllIntent>(
            onInvoke: (intent) {
              controller.selectAllImages();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = FTheme.of(context);
    return Obx(() {
      final child = controller.imageFiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FIcons.imageOff,
                    size: 64,
                    color: theme.colors.mutedForeground,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no_images'.tr,
                    style: theme.typography.base.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'drag_hint'.tr,
                    style: theme.typography.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            )
          : ImageGridInteractive(
              controller: controller,
              scrollController: _scrollController,
              focusNode: _focusNode,
            );

      return Stack(children: [child, _buildLoadingOverlay(theme)]);
    });
  }

  // 在控制器处于加载状态时显示覆盖层
  Widget _buildLoadingOverlay(FThemeData theme) {
    if (!controller.isLoading.value) return const SizedBox.shrink();
    final messageKey = controller.loadingMessageKey.value;
    final message = messageKey == null ? 'loading'.tr : messageKey.tr;
    return Positioned.fill(
      child: AbsorbPointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.background.withValues(alpha: 0.88),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: theme.colors.secondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 30, height: 30, child: FProgress()),
                  const SizedBox(width: 12),
                  Text(
                    message,
                    style: theme.typography.base.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 全选意图
class SelectAllIntent extends Intent {
  const SelectAllIntent();
}
