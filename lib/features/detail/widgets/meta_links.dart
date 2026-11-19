import 'package:flutter/material.dart';

import '../state/detail_controller.dart';

/// 元信息行组（标签列 + 值列）：音轨行 / 字幕行 / 系列行 / 合集行
/// （对齐 ItemDetailScreen.kt 的标签行组；系列与合集是文字链接，最多 3 个，多收「还有 N 个」）。
class MetaLinks extends StatelessWidget {
  const MetaLinks({
    super.key,
    required this.entry,
    this.onSeriesTap,
    this.onCollectionTap,
  });

  final DetailEntry entry;
  final ValueChanged<int>? onSeriesTap;
  final ValueChanged<String>? onCollectionTap;

  Widget _row(BuildContext context, String label, Widget value) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _links(BuildContext context, List<String> items, ValueChanged<String> onTap) {
    final shown = items.take(3).toList();
    final rest = items.length - shown.length;
    final textTheme = Theme.of(context).textTheme;
    final linkStyle = textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.primary);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0)
            Text(' / ', style: textTheme.bodySmall?.copyWith(color: Colors.white38)),
          InkWell(
            onTap: () => onTap(shown[i]),
            child: Text(shown[i], style: linkStyle),
          ),
        ],
        if (rest > 0)
          Text(' 还有 $rest 个', style: textTheme.bodySmall?.copyWith(color: Colors.white38)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.audioTracks.isNotEmpty)
          _row(context, '音轨', Text(entry.audioTracks.join(' / '),
              style: Theme.of(context).textTheme.bodySmall)),
        if (entry.subtitleTracks.isNotEmpty)
          _row(context, '字幕', Text(entry.subtitleTracks.join(' / '),
              style: Theme.of(context).textTheme.bodySmall)),
        if (entry.seriesName != null && entry.seriesCollectionId != null)
          _row(
            context,
            '系列',
            _links(context, [entry.seriesName!], (_) => onSeriesTap?.call(entry.seriesCollectionId!)),
          ),
        if (entry.collections.isNotEmpty)
          _row(context, '合集', _links(context, entry.collections, onCollectionTap ?? (_) {})),
      ],
    );
  }
}
