import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../controllers/browser_controller.dart';
import '../widgets/widgets.dart';

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

          // Right side minExtent = half of total width, so left side max = half
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
