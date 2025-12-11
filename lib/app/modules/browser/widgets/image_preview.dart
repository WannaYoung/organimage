import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/utils/file_utils.dart';

/// Show image preview dialog with navigation and zoom
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Image gallery with mouse wheel zoom support
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
                loadingBuilder: (context, event) => Center(
                  child: CircularProgressIndicator(
                    value: event == null
                        ? null
                        : event.cumulativeBytesLoaded /
                              (event.expectedTotalBytes ?? 1),
                  ),
                ),
                backgroundDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
            ),

            // Top bar
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
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Previous button
            if (widget.imageList.length > 1 && _currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavigationButton(
                    icon: Icons.chevron_left,
                    onPressed: _goToPrevious,
                  ),
                ),
              ),

            // Next button
            if (widget.imageList.length > 1 &&
                _currentIndex < widget.imageList.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavigationButton(
                    icon: Icons.chevron_right,
                    onPressed: _goToNext,
                  ),
                ),
              ),

            // Bottom bar with zoom controls
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
                      // Zoom out button
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white70,
                        ),
                        onPressed: _zoomOut,
                        tooltip: '-',
                      ),
                      // Zoom percentage
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
                      // Zoom in button
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white70,
                        ),
                        onPressed: _zoomIn,
                        tooltip: '+',
                      ),
                      const SizedBox(width: 16),
                      // Reset button
                      IconButton(
                        icon: const Icon(
                          Icons.fit_screen,
                          color: Colors.white70,
                        ),
                        onPressed: _resetZoom,
                        tooltip: 'reset'.tr,
                      ),
                      const SizedBox(width: 24),
                      // Hints
                      _HintChip(icon: Icons.mouse, label: 'scroll_zoom'.tr),
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
    return Material(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
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
