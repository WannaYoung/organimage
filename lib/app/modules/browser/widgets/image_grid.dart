import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants.dart';
import '../controllers/browser_controller.dart';
import 'image_thumbnail.dart';

class ImageGrid extends StatefulWidget {
  final BrowserController controller;

  const ImageGrid({super.key, required this.controller});

  @override
  State<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends State<ImageGrid> {
  late final FContinuousSliderController _sliderController;
  final ScrollController _scrollController = ScrollController();

  BrowserController get controller => widget.controller;

  String? _lastPath;

  @override
  void initState() {
    super.initState();
    _sliderController = FContinuousSliderController(
      selection: FSliderSelection(
        max:
            (controller.thumbnailSize.value - minThumbnailSize) /
            (maxThumbnailSize - minThumbnailSize),
      ),
    );
    _lastPath = controller.currentPath.value;
    // Listen for path changes to reset scroll position
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
    _sliderController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(context),
        const FDivider(),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = FTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Breadcrumb navigation
          Expanded(child: Obx(() => _buildBreadcrumb(context))),

          const SizedBox(width: 8),

          // Selection info
          Obx(() {
            if (controller.selectedImages.isNotEmpty) {
              return FBadge(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'selected_count'.trParams({
                        'count': '${controller.selectedImages.length}',
                      }),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: controller.clearSelection,
                      child: const Icon(FIcons.x, size: 14),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          const SizedBox(width: 8),

          // Image count
          Obx(
            () => FBadge(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FIcons.image, size: 14),
                  const SizedBox(width: 4),
                  Text('${controller.imageFiles.length}'),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Thumbnail size slider
          Icon(FIcons.minimize2, size: 14, color: theme.colors.mutedForeground),
          SizedBox(
            width: 120,
            child: FSlider(
              controller: _sliderController,
              onChange: (selection) {
                final value =
                    minThumbnailSize +
                    selection.offset.max *
                        (maxThumbnailSize - minThumbnailSize);
                controller.setThumbnailSize(value);
              },
            ),
          ),
          Icon(FIcons.maximize2, size: 14, color: theme.colors.mutedForeground),

          const SizedBox(width: 8),

          // Refresh button with tooltip
          FTooltip(
            tipBuilder: (context, _) => Text('refresh'.tr),
            child: FButton(
              onPress: controller.loadCurrentDirectory,
              child: const Icon(FIcons.refreshCw, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = FTheme.of(context);
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: FProgress());
      }

      if (controller.imageFiles.isEmpty) {
        return Center(
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
        );
      }

      return _buildImageGrid(context);
    });
  }

  Widget _buildImageGrid(BuildContext context) {
    return Obx(() {
      final size = controller.thumbnailSize.value;
      final files = controller.imageFiles.toList();

      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: size + 20,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return ImageThumbnail(
            key: ValueKey(file.path),
            imagePath: file.path,
            size: size,
            controller: controller,
            enableDrag: true,
          );
        },
      );
    });
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final currentPath = controller.currentPath.value;
    final rootPath = controller.rootPath.value;

    if (currentPath == null || rootPath == null) {
      return const SizedBox.shrink();
    }

    // Build path segments from root to current
    final relativePath = currentPath.substring(rootPath.length);
    final segments = relativePath
        .split(p.separator)
        .where((s) => s.isNotEmpty)
        .toList();
    final rootName = p.basename(rootPath);

    // Build breadcrumb items
    final items = <Widget>[];

    // Root item
    items.add(
      FBreadcrumbItem(
        onPress: () => controller.navigateToFolder(rootPath),
        current: segments.isEmpty,
        child: Text(rootName),
      ),
    );

    // Path segment items
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
