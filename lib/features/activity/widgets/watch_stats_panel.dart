import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/models/format.dart';
import '../state/models.dart';
import 'activity_cards.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 观看统计面板（对齐 WatchStatsPanel.kt）：
/// 周期切换 7/30/90 天、指标卡、逐日柱状、TOP 作品、四维分解、成员钻取。
/// 7×24 观看热力图由 _WeekHeatmap 自绘（CustomPaint，无第三方热力图库）。
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
              avatar: const Icon(McIcons.close2, size: 16),
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
              leading: const Icon(McIcons.movie, size: 20),
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
              leading: const Icon(McIcons.user, size: 20),
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
              leading: const Icon(McIcons.device2, size: 20),
              title: Text(row.client.isEmpty ? '未知客户端' : row.client),
              subtitle: Text('${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}'),
            ),
        ],
        // 逐日柱状（fl_chart，对齐飞牛图表库选型）
        if (stats.byDay.isNotEmpty) ...[
          const SectionLabel(text: '逐日时长'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxDay(stats.byDay).toDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                        mcFormatWatched(rod.toY.toInt()),
                        theme.textTheme.bodySmall!,
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: (stats.byDay.length / 6).ceilToDouble().clamp(1, 30),
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= stats.byDay.length) {
                            return const SizedBox.shrink();
                          }
                          final d = stats.byDay[i].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              d.length >= 10 ? d.substring(5) : d,
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < stats.byDay.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: stats.byDay[i].watchedMs.toDouble(),
                            width: 10,
                            borderRadius: BorderRadius.circular(3),
                            color: theme.colorScheme.primary.withValues(
                              alpha: stats.byDay[i].watchedMs > 0 ? 0.85 : 0.2,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        // 7×24 观看热力图（行=周一..周日，列=0..23 时）
        if (stats.byHour.isNotEmpty) ...[
          const SectionLabel(text: '时段热力'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _WeekHeatmap(matrix: stats.byHour, theme: theme),
          ),
        ],
        // 最近播放流水
        if (stats.previousAvailable && stats.favorites.isNotEmpty) ...[
          const SectionLabel(text: '收藏常看'),
          for (final row in stats.favorites.take(3))
            ListTile(
              dense: true,
              leading: const Icon(McIcons.heart2, size: 20),
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


/// 7×24 观看热力图：CustomPaint 自绘格子矩阵，色深按时长占比。
class _WeekHeatmap extends StatelessWidget {
  const _WeekHeatmap({required this.matrix, required this.theme});

  final List<List<int>> matrix;
  final ThemeData theme;

  static const _dayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  Color _cell(int ms, int max, ColorScheme scheme) {
    if (ms <= 0 || max <= 0) return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final t = (ms / max).clamp(0.0, 1.0);
    return Color.lerp(scheme.primary.withValues(alpha: 0.25), scheme.primary, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    var max = 0;
    for (final row in matrix) {
      for (final v in row) {
        if (v > max) max = v;
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelW = 18.0;
        const labelH = 14.0;
        final cellH = ((constraints.maxHeight - labelH) / 7).floorToDouble().clamp(10.0, 22.0);
        return SizedBox(
          height: 7 * cellH + labelH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelW,
                        child: Text(
                          _dayLabels[d],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (var h = 0; h < 24; h++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _cell(
                                  d < matrix.length && h < matrix[d].length
                                      ? matrix[d][h]
                                      : 0,
                                  max,
                                  scheme,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              // 小时刻度：0/6/12/18
              SizedBox(
                height: labelH,
                child: Row(
                  children: [
                    const SizedBox(width: labelW),
                    for (var h = 0; h < 24; h++)
                      Expanded(
                        child: h % 6 == 0
                            ? Text('$h', style: theme.textTheme.labelSmall)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
