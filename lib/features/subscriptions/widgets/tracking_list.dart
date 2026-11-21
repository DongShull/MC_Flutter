import 'package:flutter/material.dart';

import '../state/models.dart';

/// 追踪明细（对齐 SubscriptionDetailContent：按季分组，每工单 = 状态徽标 + 中文调度解释）。
class TrackingList extends StatelessWidget {
  const TrackingList({super.key, required this.sub});

  final SubscriptionView sub;

  @override
  Widget build(BuildContext context) {
    if (sub.wanted.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            sub.media.kind == 'movie' ? '影片暂无追踪明细' : '暂无追踪工单',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
          ),
        ),
      );
    }
    final bySeason = <int, List<WantedView>>{};
    for (final w in sub.wanted) {
      bySeason.putIfAbsent(w.seasonNumber, () => []).add(w);
    }
    final seasons = bySeason.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final season in seasons) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              '第 $season 季',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          ...bySeason[season]!.map(_unitTile),
        ],
      ],
    );
  }

  Widget _unitTile(WantedView w) {
    final done = w.status == 'imported';
    final busy = w.status == 'grabbed' || w.status == 'downloaded';
    final dot = done
        ? const Color(0xFF34C77B)
        : busy
            ? const Color(0xFF6AA7FF)
            : w.status == 'failed'
                ? const Color(0xFFE5615B)
                : Colors.white24;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '第 ${w.episodeNumber} 集 · ${wantedStatusNote(w)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (w.grabTitle != null && w.grabTitle!.isNotEmpty)
            Flexible(
              child: Text(
                w.grabTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
