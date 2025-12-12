import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
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

  final FocusNode _focusNode = FocusNode();
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};

  bool _isDragSelecting = false;
  Offset? _dragStartLocal;
  Offset? _dragCurrentLocal;
  bool _dragAdditive = false;
  List<String> _dragBaseSelection = <String>[];

  bool _isExternalDragging = false;

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
    _focusNode.dispose();
    super.dispose();
  }

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
          child: Column(
            children: [
              _buildToolbar(context),
              const FDivider(),
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
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
                style: FBadgeStyle.primary(),
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
              );
            }
            return const SizedBox.shrink();
          }),

          const SizedBox(width: 8),

          // Image count
          Obx(
            () => FBadge(
              style: FBadgeStyle.secondary(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FIcons.image,
                    size: 14,
                    color: theme.colors.secondaryForeground,
                  ),
                  const SizedBox(width: 4),
                  Text('${controller.imageFiles.length}'),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Thumbnail size slider with icons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FIcons.minimize2,
                  size: 14,
                  color: theme.colors.mutedForeground,
                ),
                SizedBox(
                  width: 100,
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
                Icon(
                  FIcons.maximize2,
                  size: 14,
                  color: theme.colors.mutedForeground,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Refresh button with tooltip
          FTooltip(
            tipBuilder: (context, _) => Text('refresh'.tr),
            child: FButton(
              style: FButtonStyle.outline(),
              onPress: controller.loadCurrentDirectory,
              child: Icon(
                FIcons.refreshCw,
                size: 16,
                color: theme.colors.foreground,
              ),
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
      final theme = FTheme.of(context);
      final size = controller.thumbnailSize.value;
      final files = controller.imageFiles.toList();

      final currentPaths = files.map((e) => e.path).toSet();
      _itemKeys.removeWhere((key, value) => !currentPaths.contains(key));

      final grid = GridView.builder(
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
          final itemKey = _itemKeys.putIfAbsent(file.path, () => GlobalKey());
          return Container(
            key: itemKey,
            child: ImageThumbnail(
              key: ValueKey(file.path),
              imagePath: file.path,
              size: size,
              controller: controller,
              enableDrag: true,
            ),
          );
        },
      );

      final gridWithInteraction = Stack(
        key: _stackKey,
        children: [
          grid,
          _buildExternalDragOverlay(theme),
          _buildDragSelectListenerLayer(),
          _buildSelectionOverlay(theme),
        ],
      );

      // External drop: import images into current folder.
      final dropWrapped = _wrapWithExternalDropTarget(gridWithInteraction);

      if (!controller.canReorderInCurrentFolder) {
        return dropWrapped;
      }

      return DragTarget<List<String>>(
        onWillAcceptWithDetails: (details) {
          return controller.isReordering.value &&
              controller.selectedImages.length == 1;
        },
        onAcceptWithDetails: (details) {
          controller.commitReorderAndRenumber();
        },
        builder: (context, candidateData, rejectedData) {
          return dropWrapped;
        },
      );
    });
  }

  Widget _wrapWithExternalDropTarget(Widget child) {
    return DropTarget(
      onDragEntered: (details) {
        setState(() {
          _isExternalDragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _isExternalDragging = false;
        });
      },
      onDragDone: (details) {
        setState(() {
          _isExternalDragging = false;
        });
        final paths = details.files.map((f) => f.path).toList();
        controller.importExternalImagesToCurrentFolder(paths);
      },
      child: child,
    );
  }

  // Overlay shown when user is dragging external files over the grid.
  Widget _buildExternalDragOverlay(FThemeData theme) {
    if (!_isExternalDragging) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.primary.withValues(alpha: 0.08),
            border: Border.all(color: theme.colors.primary, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              'drag_hint'.tr,
              style: theme.typography.base.copyWith(
                color: theme.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Drag-select layer for rectangular selection on empty grid area.
  Widget _buildDragSelectListenerLayer() {
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.kind != PointerDeviceKind.mouse) return;
          if (event.buttons != kPrimaryButton) return;

          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }

          if (_isPointerOnAnyItem(event.position)) return;

          final keyboard = HardwareKeyboard.instance;
          final isCtrl = keyboard.isControlPressed || keyboard.isMetaPressed;

          final stackBox =
              _stackKey.currentContext?.findRenderObject() as RenderBox?;
          if (stackBox == null) return;
          final local = stackBox.globalToLocal(event.position);

          setState(() {
            _isDragSelecting = true;
            _dragAdditive = isCtrl;
            _dragBaseSelection = controller.selectedImages.toList();
            _dragStartLocal = local;
            _dragCurrentLocal = local;
          });
        },
        onPointerMove: (event) {
          if (!_isDragSelecting) return;
          final stackBox =
              _stackKey.currentContext?.findRenderObject() as RenderBox?;
          if (stackBox == null) return;
          final local = stackBox.globalToLocal(event.position);

          setState(() {
            _dragCurrentLocal = local;
          });

          final rect = _getSelectionRect();
          if (rect == null) return;

          final selected = _getPathsIntersectingRect(rect);
          controller.applyDragSelection(
            selected,
            additive: _dragAdditive,
            baseSelection: _dragBaseSelection,
          );
        },
        onPointerUp: (event) {
          if (!_isDragSelecting) return;
          setState(() {
            _isDragSelecting = false;
            _dragStartLocal = null;
            _dragCurrentLocal = null;
            _dragAdditive = false;
            _dragBaseSelection = <String>[];
          });
        },
        onPointerCancel: (event) {
          if (!_isDragSelecting) return;
          setState(() {
            _isDragSelecting = false;
            _dragStartLocal = null;
            _dragCurrentLocal = null;
            _dragAdditive = false;
            _dragBaseSelection = <String>[];
          });
        },
        child: const SizedBox.expand(),
      ),
    );
  }

  // Selection rectangle overlay (rubber band).
  Widget _buildSelectionOverlay(FThemeData theme) {
    final rect = _getSelectionRect();
    if (rect == null) return const SizedBox.shrink();
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.primary.withValues(alpha: 0.12),
            border: Border.all(color: theme.colors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Rect? _getSelectionRect() {
    final start = _dragStartLocal;
    final current = _dragCurrentLocal;
    if (!_isDragSelecting || start == null || current == null) return null;

    final left = start.dx < current.dx ? start.dx : current.dx;
    final top = start.dy < current.dy ? start.dy : current.dy;
    final right = start.dx > current.dx ? start.dx : current.dx;
    final bottom = start.dy > current.dy ? start.dy : current.dy;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _isPointerOnAnyItem(Offset globalPosition) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return false;
    final local = stackBox.globalToLocal(globalPosition);

    for (final entry in _itemKeys.entries) {
      final itemBox =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (itemBox == null || !itemBox.hasSize) continue;
      final topLeft = stackBox.globalToLocal(
        itemBox.localToGlobal(Offset.zero),
      );
      final rect = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        itemBox.size.width,
        itemBox.size.height,
      );
      if (rect.contains(local)) return true;
    }

    return false;
  }

  List<String> _getPathsIntersectingRect(Rect selectionRect) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return <String>[];

    final selected = <String>[];
    for (final entry in _itemKeys.entries) {
      final itemBox =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (itemBox == null || !itemBox.hasSize) continue;
      final topLeft = stackBox.globalToLocal(
        itemBox.localToGlobal(Offset.zero),
      );
      final rect = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        itemBox.size.width,
        itemBox.size.height,
      );

      if (rect.overlaps(selectionRect)) {
        selected.add(entry.key);
      }
    }

    return selected;
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

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}
