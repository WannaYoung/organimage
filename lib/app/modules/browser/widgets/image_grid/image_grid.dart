import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../../core/constants.dart';
import '../../controllers/browser_controller.dart';

import 'image_grid_body.dart';
import 'image_grid_toolbar.dart';

/// 图片网格组件，显示图片列表和工具栏
class ImageGrid extends StatefulWidget {
  final BrowserController controller;

  const ImageGrid({super.key, required this.controller});

  @override
  State<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends State<ImageGrid> {
  // 用于将滑块选择映射到缩略图大小的控制器
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
  // 组合工具栏和网格主体
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
