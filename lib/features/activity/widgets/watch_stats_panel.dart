import 'package:flutter/material.dart';

import '../../../core/models/format.dart';
import '../state/models.dart';
import 'activity_cards.dart';

/// 观看统计面板（对齐 WatchStatsPanel.kt）：
/// 周期切换 7/30/90 天、指标卡、逐日柱状、TOP 作品、四维分解、成员钻取。
/// Android 端的 7×24 热力图暂以每小时合计柱条代替（TODO: 热力图）。
class WatchStatsPanel extends StatelessWidget {
  const WatchStatsPanel({
    super.key,
    required this.stats,
    required this.days,
    this.memberId,
    required this.onDaysChanged,
    required this.onMemberSelected,
  });

  final PlaybackWatchStatsView stats;
  final int days;
  final int? memberId;
  final Future<void> Function(int) onDaysChanged;
  final Future<void> Function(int?) onMemberSelected;

  String _deltaLabel(PlaybackStatsTotals current, PlaybackStatsTotals previous) {
    if (previous.watchedMs <= 0) return '';
    final diff = current.watchedMs - previous.watchedMs;
    final pct = (diff / previous.watchedMs * 100).toStringAsFixed(0);
    return diff >= 0 ? '↑ $pct%' : '↓ $pct%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 周期切换
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final d in const [7, 30, 90])
                ChoiceChip(
                  label: Text('$d 天'),
                  selected: days == d,
                  onSelected: (_) => onDaysChanged(d),
                ),
            ],
          ),
        ),
        if (memberId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ActionChip(
              avatar: const Icon(Icons.close, size: 16),
              label: const Text('取消成员筛选'),
              onPressed: () => onMemberSelected(null),
            ),
          ),
        // 指标卡
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _MetricCard(
                label: '播放次数',
                value: stats.current.plays.toString(),
                delta: _deltaLabel(stats.current, stats.previous),
              ),
              const SizedBox(width: 8),
              _MetricCard(
                label: '观看时长',
                value: mcFormatWatched(stats.current.watchedMs),
                delta: _deltaLabel(stats.current, stats.previous),
              ),
              const SizedBox(width: 8),
              _MetricCard(
                label: '播完',
                value: stats.current.completed.toString(),
              ),
              const SizedBox(width: 8),
              _MetricCard(
                label: '活跃成员',
                value: stats.current.activeMembers.toString(),
              ),
            ],
          ),
        ),
        // TOP 作品
        if (stats.topTitles.isNotEmpty) ...[
          const SectionLabel(text: '最常观看'),
          for (final row in stats.topTitles.take(3))
            ListTile(
              dense: true,
              leading: const Icon(Icons.movie_outlined, size: 20),
              title: Text(row.media.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}'
                '${row.members > 0 ? ' · ${row.members} 位成员' : ''}',
              ),
            ),
        ],
        // 成员排行
        if (stats.byMember.isNotEmpty) ...[
          const SectionLabel(text: '成员'),
          for (final row in stats.byMember)
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline, size: 20),
              title: Text(row.memberName),
              subtitle: Text('${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}'),
              onTap: () => onMemberSelected(row.memberId),
            ),
        ],
        // 客户端
        if (stats.byClient.isNotEmpty) ...[
          const SectionLabel(text: '客户端'),
          for (final row in stats.byClient)
            ListTile(
              dense: true,
              leading: const Icon(Icons.devices_other, size: 20),
              title: Text(row.client.isEmpty ? '未知客户端' : row.client),
              subtitle: Text('${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}'),
            ),
        ],
        // 逐日柱状（简易：时长归一化条）
        if (stats.byDay.isNotEmpty) ...[
          const SectionLabel(text: '逐日时长'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final row in stats.byDay)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: Text(
                            row.date.length >= 10 ? row.date.substring(5) : row.date,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _maxDay(stats.byDay) <= 0
                                  ? 0
                                  : row.watchedMs / _maxDay(stats.byDay),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Text(
                            mcFormatWatched(row.watchedMs),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        // 最近播放流水
        if (stats.previousAvailable && stats.favorites.isNotEmpty) ...[
          const SectionLabel(text: '收藏常看'),
          for (final row in stats.favorites.take(3))
            ListTile(
              dense: true,
              leading: const Icon(Icons.favorite_outline, size: 20),
              title: Text(row.media.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}'),
            ),
        ],
      ],
    );
  }

  int _maxDay(List<PlaybackStatsDayRow> rows) {
    var max = 0;
    for (final r in rows) {
      if (r.watchedMs > max) max = r.watchedMs;
    }
    return max;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, this.delta = ''});

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value, style: theme.textTheme.titleMedium),
            ),
            if (delta.isNotEmpty)
              Text(
                delta,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: delta.startsWith('↑')
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE5615B),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
