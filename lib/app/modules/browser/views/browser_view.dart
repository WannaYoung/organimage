import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../controllers/browser_controller.dart';
import '../widgets/widgets.dart';

/// 浏览器主视图，包含侧边栏和图片网格
class BrowserView extends GetView<BrowserController> {
  const BrowserView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.colors.background),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          const sidebarWidth = 280.0;
          final contentWidth = totalWidth - sidebarWidth - 10;

          // 右侧最小宽度 = 总宽度的一半，所以左侧最大宽度 = 一半
          final rightMinExtent = totalWidth / 2;

          return FResizable(
            axis: Axis.horizontal,
            divider: FResizableDivider.dividerWithThumb,
            children: [
              FResizableRegion(
                initialExtent: sidebarWidth,
                minExtent: 200,
                builder: (context, data, child) =>
                    Sidebar(controller: controller),
              ),
              FResizableRegion(
                initialExtent: contentWidth > 400 ? contentWidth : 400,
                minExtent: rightMinExtent,
                builder: (context, data, child) =>
                    ImageGrid(controller: controller),
              ),
            ],
          );
        },
      ),
    );
  }
}
