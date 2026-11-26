import 'package:flutter/material.dart';

import 'theme.dart';

/// 全 App 复用的占位页：功能未实现时统一显示，避免各模块重复造轮子。
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: McText.title),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint!, style: McText.sub.muted),
          ],
        ],
      ),
    );
  }
}
