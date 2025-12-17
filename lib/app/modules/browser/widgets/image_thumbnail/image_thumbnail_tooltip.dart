import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/format_utils.dart';

/// 图片缩略图提示组件，显示文件信息
class ImageThumbnailTooltip extends StatefulWidget {
  final String imagePath;

  const ImageThumbnailTooltip({super.key, required this.imagePath});

  @override
  State<ImageThumbnailTooltip> createState() => _ImageThumbnailTooltipState();
}

class _ImageThumbnailTooltipState extends State<ImageThumbnailTooltip> {
  Future<_TooltipInfo>? _tooltipInfoFuture;

  // 加载文件元信息用于提示渲染
  Future<_TooltipInfo> _loadTooltipInfo() async {
    final file = File(widget.imagePath);
    final stat = await file.stat();
    final size = formatFileSize(stat.size);
    final modified = stat.modified;
    final dateStr =
        '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}';
    final fileName = p.basename(widget.imagePath);
    return _TooltipInfo(fileName: fileName, size: size, dateStr: dateStr);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    final labelStyle = theme.typography.sm.copyWith(
      color: theme.colors.mutedForeground,
    );
    final valueStyle = theme.typography.sm.copyWith(
      color: theme.colors.foreground,
    );

    _tooltipInfoFuture ??= _loadTooltipInfo();

    return FutureBuilder<_TooltipInfo>(
      future: _tooltipInfoFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Text(p.basename(widget.imagePath), style: valueStyle);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTooltipRow(
              labelStyle,
              valueStyle,
              'file_name'.tr,
              data.fileName,
            ),
            const SizedBox(height: 4),
            _buildTooltipRow(labelStyle, valueStyle, 'file_size'.tr, data.size),
            const SizedBox(height: 4),
            _buildTooltipRow(
              labelStyle,
              valueStyle,
              'modified_date'.tr,
              data.dateStr,
            ),
          ],
        );
      },
    );
  }

  // 提示中的单个标签/值行
  Widget _buildTooltipRow(
    TextStyle labelStyle,
    TextStyle valueStyle,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}

/// 悬停缩略图时显示的提示数据
class _TooltipInfo {
  final String fileName;
  final String size;
  final String dateStr;

  const _TooltipInfo({
    required this.fileName,
    required this.size,
    required this.dateStr,
  });
}
