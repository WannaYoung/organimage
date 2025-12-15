import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants.dart';
import '../../controllers/browser_controller.dart';

class ImageGridToolbar extends StatelessWidget {
  final BrowserController controller;
  final FContinuousSliderController sliderController;

  const ImageGridToolbar({
    super.key,
    required this.controller,
    required this.sliderController,
  });

  // Builds the top toolbar including breadcrumb, counters and controls.
  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Breadcrumb navigation.
          Expanded(child: Obx(() => _buildBreadcrumb(context))),

          const SizedBox(width: 8),

          // Selection info.
          Obx(() {
            if (controller.selectedImages.isNotEmpty) {
              return FBadge(
                style: FBadgeStyle.primary(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'selected_count'.trParams({
                          'count': '${controller.selectedImages.length}',
                        }),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: controller.clearSelection,
                        child: Icon(
                          FIcons.x,
                          size: 14,
                          color: theme.colors.primaryForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          const SizedBox(width: 12),

          // Image count.
          Obx(
            () => FBadge(
              style: FBadgeStyle.secondary(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FIcons.image,
                      size: 20,
                      color: theme.colors.secondaryForeground,
                    ),
                    const SizedBox(width: 4),
                    Text('${controller.imageFiles.length}'),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Thumbnail size slider.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            decoration: BoxDecoration(
              color: theme.colors.secondary,
              borderRadius: BorderRadius.circular(80),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FIcons.zoomOut,
                  size: 14,
                  color: theme.colors.mutedForeground,
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: 160,
                    height: 25,
                    child: FSlider(
                      controller: sliderController,
                      style: (style) => style.copyWith(
                        childPadding: EdgeInsets.zero,
                        thumbSize: 15,
                        crossAxisExtent: 5,
                      ),
                      onChange: (selection) {
                        final value =
                            minThumbnailSize +
                            selection.offset.max *
                                (maxThumbnailSize - minThumbnailSize);
                        controller.setThumbnailSize(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  FIcons.zoomIn,
                  size: 14,
                  color: theme.colors.mutedForeground,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Refresh button.
          FTooltip(
            tipBuilder: (context, _) => Text('refresh'.tr),
            child: FButton.icon(
              style: FButtonStyle.ghost(),
              onPress: controller.loadCurrentDirectory,
              child: Icon(
                FIcons.refreshCw,
                size: 20,
                color: theme.colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds breadcrumb items from root to current directory.
  Widget _buildBreadcrumb(BuildContext context) {
    final currentPath = controller.currentPath.value;
    final rootPath = controller.rootPath.value;

    if (currentPath == null || rootPath == null) {
      return const SizedBox.shrink();
    }

    final relativePath = currentPath.substring(rootPath.length);
    final segments = relativePath
        .split(p.separator)
        .where((s) => s.isNotEmpty)
        .toList();
    final rootName = p.basename(rootPath);

    final items = <Widget>[];

    items.add(
      FBreadcrumbItem(
        onPress: () => controller.navigateToFolder(rootPath),
        current: segments.isEmpty,
        child: Text(rootName),
      ),
    );

    var accumulatedPath = rootPath;
    for (var i = 0; i < segments.length; i++) {
      accumulatedPath = p.join(accumulatedPath, segments[i]);
      final pathToNavigate = accumulatedPath;
      final isLast = i == segments.length - 1;

      items.add(
        FBreadcrumbItem(
          onPress: isLast
              ? null
              : () => controller.navigateToFolder(pathToNavigate),
          current: isLast,
          child: Text(segments[i]),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: FBreadcrumb(children: items),
    );
  }
}
