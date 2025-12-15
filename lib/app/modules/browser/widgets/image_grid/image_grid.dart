import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../../core/constants.dart';
import '../../controllers/browser_controller.dart';

import 'image_grid_body.dart';
import 'image_grid_toolbar.dart';

class ImageGrid extends StatefulWidget {
  final BrowserController controller;

  const ImageGrid({super.key, required this.controller});

  @override
  State<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends State<ImageGrid> {
  // Controller used to map slider selection to thumbnail size.
  late final FContinuousSliderController _sliderController;

  BrowserController get controller => widget.controller;

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
  }

  @override
  void dispose() {
    _sliderController.dispose();
    super.dispose();
  }

  @override
  // Composes toolbar and grid body.
  Widget build(BuildContext context) {
    return Column(
      children: [
        ImageGridToolbar(
          controller: controller,
          sliderController: _sliderController,
        ),
        const FDivider(),
        Expanded(child: ImageGridBody(controller: controller)),
      ],
    );
  }
}
