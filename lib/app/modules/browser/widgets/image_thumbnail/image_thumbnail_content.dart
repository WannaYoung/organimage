import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:path/path.dart' as p;

import '../../controllers/browser_controller.dart';

class ImageThumbnailContent extends StatelessWidget {
  final BrowserController controller;
  final String imagePath;
  final double size;
  final bool isSelected;

  const ImageThumbnailContent({
    super.key,
    required this.controller,
    required this.imagePath,
    required this.size,
    required this.isSelected,
  });

  // Resolves which file path should be displayed (original image or cached thumbnail).
  String _resolveDisplayPath() {
    if (!controller.useThumbnails.value) return imagePath;

    final thumbPath = controller.thumbnailService.resolveThumbnailPathSync(
      imagePath,
      controller.thumbnailSize.value,
    );

    if (thumbPath != null && File(thumbPath).existsSync()) {
      return thumbPath;
    }

    // Fallback to the other format (jpg/png) if the expected one does not exist.
    if (thumbPath != null) {
      final ext = p.extension(thumbPath).toLowerCase();
      if (ext == '.jpg') {
        final pngPath = '${thumbPath.substring(0, thumbPath.length - 4)}.png';
        if (File(pngPath).existsSync()) {
          return pngPath;
        }
      } else if (ext == '.png') {
        final jpgPath = '${thumbPath.substring(0, thumbPath.length - 4)}.jpg';
        if (File(jpgPath).existsSync()) {
          return jpgPath;
        }
      }
    }

    return imagePath;
  }

  // Builds the thumbnail UI content including border, image, and selection overlay.
  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    final isDark = theme.colors.brightness == Brightness.dark;
    final cacheSide = (size * 2).toInt();

    final displayPath = _resolveDisplayPath();
    final isUsingCachedThumbnail =
        controller.useThumbnails.value && displayPath != imagePath;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? theme.colors.primary
              : isDark
              ? theme.colors.border.withValues(alpha: 0.3)
              : const Color(0x00000000),
          width: isSelected ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x1A000000),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: Image.file(
                File(displayPath),
                fit: BoxFit.cover,
                cacheWidth: cacheSide,
                cacheHeight: isUsingCachedThumbnail ? cacheSide : null,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.colors.secondary,
                    child: Icon(
                      FIcons.imageOff,
                      color: theme.colors.mutedForeground,
                    ),
                  );
                },
              ),
            ),
            // File name overlay at bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
                child: Text(
                  p.basenameWithoutExtension(imagePath),
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    FIcons.check,
                    size: 14,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
