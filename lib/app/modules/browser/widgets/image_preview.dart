import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/utils/format_utils.dart';

/// 显示图片预览对话框，支持导航和缩放
void showImagePreview(
  BuildContext context, {
  required String imagePath,
  required List<String> imageList,
}) {
  final initialIndex = imageList.indexOf(imagePath);
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => ImagePreviewDialog(
      imageList: imageList,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    ),
  );
}

/// 图片预览对话框组件
class ImagePreviewDialog extends StatefulWidget {
  final List<String> imageList;
  final int initialIndex;

  const ImagePreviewDialog({
    super.key,
    required this.imageList,
    required this.initialIndex,
  });

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  late PageController _pageController;
  late int _currentIndex;
  final _focusNode = FocusNode();
  final Map<int, PhotoViewController> _photoControllers = {};
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  PhotoViewController _getController(int index) {
    return _photoControllers.putIfAbsent(index, () => PhotoViewController());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    for (final controller in _photoControllers.values) {
      controller.dispose();
    }
    _photoControllers.clear();
    super.dispose();
  }

  void _zoomIn() {
    final controller = _getController(_currentIndex);
    final newScale = (controller.scale ?? 1.0) * 1.25;
    controller.scale = newScale.clamp(0.5, 5.0);
    setState(() {
      _currentScale = controller.scale ?? 1.0;
    });
  }

  void _zoomOut() {
    final controller = _getController(_currentIndex);
    final newScale = (controller.scale ?? 1.0) / 1.25;
    controller.scale = newScale.clamp(0.5, 5.0);
    setState(() {
      _currentScale = controller.scale ?? 1.0;
    });
  }

  void _resetZoom() {
    final controller = _getController(_currentIndex);
    controller.scale = 1.0;
    controller.position = Offset.zero;
    setState(() {
      _currentScale = 1.0;
    });
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.imageList.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getFileInfo(String path) {
    try {
      final file = File(path);
      final size = file.lengthSync();
      return '${p.basename(path)}  |  ${formatFileSize(size)}';
    } catch (e) {
      return p.basename(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _goToPrevious();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _goToNext();
          } else if (event.logicalKey == LogicalKeyboardKey.equal ||
              event.logicalKey == LogicalKeyboardKey.add) {
            _zoomIn();
          } else if (event.logicalKey == LogicalKeyboardKey.minus) {
            _zoomOut();
          } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
            _resetZoom();
          }
        }
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0x00000000)),
        child: Stack(
          children: [
            // 图片画廊，支持鼠标滚轮缩放
            Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  if (event.scrollDelta.dy < 0) {
                    _zoomIn();
                  } else {
                    _zoomOut();
                  }
                }
              },
              child: PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                pageController: _pageController,
                itemCount: widget.imageList.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _currentScale = _getController(index).scale ?? 1.0;
                  });
                },
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions.customChild(
                    controller: _getController(index),
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained * 0.5,
                    maxScale: PhotoViewComputedScale.covered * 5,
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: widget.imageList[index],
                    ),
                    child: Image.file(
                      File(widget.imageList[index]),
                      fit: BoxFit.contain,
                    ),
                  );
                },
                loadingBuilder: (context, event) =>
                    Center(child: const FProgress()),
                backgroundDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
            ),

            // 顶部栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 25,
                  bottom: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getFileInfo(widget.imageList[_currentIndex]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${_currentIndex + 1} / ${widget.imageList.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      FButton(
                        style: FButtonStyle.ghost(),
                        onPress: () => Navigator.of(context).pop(),
                        child: const Icon(FIcons.x, color: Color(0xFFFFFFFF)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 上一张按钮
            if (widget.imageList.length > 1 && _currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavigationButton(
                    icon: FIcons.chevronLeft,
                    onPressed: _goToPrevious,
                  ),
                ),
              ),

            // 下一张按钮
            if (widget.imageList.length > 1 &&
                _currentIndex < widget.imageList.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavigationButton(
                    icon: FIcons.chevronRight,
                    onPressed: _goToNext,
                  ),
                ),
              ),

            // 底部栏，包含缩放控件
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 缩小按钮
                      FTooltip(
                        tipBuilder: (context, _) => const Text('-'),
                        child: FButton(
                          style: FButtonStyle.ghost(),
                          onPress: _zoomOut,
                          child: const Icon(
                            FIcons.circleMinus,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                      ),
                      // 缩放百分比
                      Container(
                        width: 60,
                        alignment: Alignment.center,
                        child: Text(
                          '${(_currentScale * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // 放大按钮
                      FTooltip(
                        tipBuilder: (context, _) => const Text('+'),
                        child: FButton(
                          style: FButtonStyle.ghost(),
                          onPress: _zoomIn,
                          child: const Icon(
                            FIcons.circlePlus,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 重置按钮
                      FTooltip(
                        tipBuilder: (context, _) => Text('reset'.tr),
                        child: FButton(
                          style: FButtonStyle.ghost(),
                          onPress: _resetZoom,
                          child: const Icon(
                            FIcons.maximize,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // 提示
                      _HintChip(icon: FIcons.mouse, label: 'scroll_zoom'.tr),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NavigationButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x61000000),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: const Color(0xFFFFFFFF), size: 32),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
