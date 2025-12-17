import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import '../../controllers/browser_controller.dart';
import '../image_thumbnail/image_thumbnail.dart';

/// 图片网格交互组件，处理拖拽选择和外部文件拖放
class ImageGridInteractive extends StatefulWidget {
  final BrowserController controller;
  final ScrollController scrollController;
  final FocusNode focusNode;

  const ImageGridInteractive({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
  });

  @override
  State<ImageGridInteractive> createState() => _ImageGridInteractiveState();
}

class _ImageGridInteractiveState extends State<ImageGridInteractive> {
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};

  bool _isDragSelecting = false;
  Offset? _dragStartLocal;
  Offset? _dragCurrentLocal;
  bool _dragMoved = false;
  bool _dragAdditive = false;
  List<String> _dragBaseSelection = <String>[];

  bool _isExternalDragging = false;

  BrowserController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = FTheme.of(context);
      final size = controller.thumbnailSize.value;
      final files = controller.imageFiles.toList();

      final currentPaths = files.map((e) => e.path).toSet();
      _itemKeys.removeWhere((key, value) => !currentPaths.contains(key));

      final grid = GridView.builder(
        controller: widget.scrollController,
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

      final dropWrapped = _wrapWithExternalDropTarget(gridWithInteraction);

      if (!controller.canReorderInCurrentFolder) {
        return dropWrapped;
      }

      // 重排序拖放目标：在网格内拖放时提交重排序
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

  // 使用桌面外部文件拖放目标包裹子组件
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

  // 用户将外部文件拖拽到网格上时显示的覆盖层
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

  // 空白网格区域的矩形选择拖拽层
  Widget _buildDragSelectListenerLayer() {
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.kind != PointerDeviceKind.mouse) return;
          if (event.buttons != kPrimaryButton) return;

          if (!widget.focusNode.hasFocus) {
            widget.focusNode.requestFocus();
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
            _dragMoved = false;
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

          final start = _dragStartLocal;
          if (start != null && !_dragMoved) {
            final delta = (local - start).distance;
            if (delta >= 3) {
              _dragMoved = true;
            }
          }

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

          if (!_dragMoved && !_dragAdditive) {
            controller.clearSelection();
          }

          setState(() {
            _isDragSelecting = false;
            _dragStartLocal = null;
            _dragCurrentLocal = null;
            _dragMoved = false;
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
            _dragMoved = false;
            _dragAdditive = false;
            _dragBaseSelection = <String>[];
          });
        },
        child: const SizedBox.expand(),
      ),
    );
  }

  // 选择矩形覆盖层（框选）
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

  // 计算堆栈本地坐标中的选择矩形
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

  // 如果指针当前在任何网格项上则返回true
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

  // 收集与选择矩形重叠的图片路径
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
}
