import 'package:flutter/material.dart';

import '../../../core/designsystem/theme.dart';
import '../state/models.dart';

/// 追踪明细（按季分组，每工单 = 状态圆点 + 中文调度解释）。
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
            style: McText.caption.faint,
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
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text('第 $season 季', style: McText.sub.semibold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(McTokens.cardRadius),
              border: Border.all(color: McTokens.line, width: 1),
            ),
            child: Column(
              children: [
                for (final w in bySeason[season]!) _unitTile(w),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _unitTile(WantedView w) {
    final done = w.status == 'imported';
    final busy = w.status == 'grabbed' || w.status == 'downloaded';
    final dot = done
        ? McTokens.ok
        : busy
            ? McTokens.info
            : w.status == 'failed'
                ? McTokens.danger
                : McTokens.textFaint;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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
              style: McText.caption.copyWith(color: McTokens.text),
            ),
          ),
          if (w.grabTitle != null && w.grabTitle!.isNotEmpty)
            Flexible(
              child: Text(
                w.grabTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.micro.faint,
              ),
            ),
        ],
      ),
    );
  }
}
