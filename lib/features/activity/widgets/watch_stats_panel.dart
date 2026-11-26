import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/models.dart';
import 'activity_cards.dart';

/// 观看统计面板（银玻璃冷银/极光蓝图表配色 + 等宽指标卡 + 7×24 热力图）。
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

  String _deltaLabel(
    PlaybackStatsTotals current,
    PlaybackStatsTotals previous,
  ) {
    if (previous.watchedMs <= 0) return '';
    final diff = current.watchedMs - previous.watchedMs;
    final pct = (diff / previous.watchedMs * 100).toStringAsFixed(0);
    return diff >= 0 ? '↑ $pct%' : '↓ $pct%';
  }

  int _maxDay(List<PlaybackStatsDayRow> rows) {
    var max = 0;
    for (final r in rows) {
      if (r.watchedMs > max) max = r.watchedMs;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in const [7, 30, 90])
                  McChip(
                    label: '$d 天',
                    compact: true,
                    selected: days == d,
                    onTap: () => onDaysChanged(d),
                  ),
                if (memberId != null)
                  McChip(
                    label: '取消成员筛选',
                    icon: McIcons.close2,
                    compact: true,
                    selected: true,
                    onTap: () => onMemberSelected(null),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
          if (stats.byDay.isNotEmpty) ...[
            const SectionLabel(text: '逐日时长'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                height: 168,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (_maxDay(stats.byDay) <= 0 ? 1 : _maxDay(stats.byDay))
                        .toDouble(),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => McTokens.surfaceSolid,
                        getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                          mcFormatWatched(rod.toY.toInt()),
                          McText.caption.copyWith(color: McTokens.text).tabular,
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
                          reservedSize: 24,
                          interval: (stats.byDay.length / 6)
                              .ceilToDouble()
                              .clamp(1, 30),
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= stats.byDay.length) {
                              return const SizedBox.shrink();
                            }
                            final d = stats.byDay[i].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                d.length >= 10 ? d.substring(5) : d,
                                style: McText.micro
                                    .copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: McTokens.textFaint,
                                    )
                                    .tabular,
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
                              width: stats.byDay.length > 20 ? 5 : 9,
                              borderRadius: BorderRadius.circular(3),
                              gradient: stats.byDay[i].watchedMs > 0
                                  ? const LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Color(0xB37FB0FF),
                                        McTokens.accentStrong,
                                      ],
                                    )
                                  : null,
                              color: stats.byDay[i].watchedMs > 0
                                  ? null
                                  : McTokens.surfaceInset,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (stats.byHour.isNotEmpty) ...[
            const SectionLabel(text: '时段热力'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _WeekHeatmap(matrix: stats.byHour),
            ),
          ],
          if (stats.topTitles.isNotEmpty) ...[
            const SectionLabel(text: '最常观看'),
            for (final row in stats.topTitles.take(3))
              McInsetRow(
                icon: McIcons.movie,
                title: row.media.title,
                subtitle:
                    '${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}'
                    '${row.members > 0 ? ' · ${row.members} 位成员' : ''}',
              ),
          ],
          if (stats.byMember.isNotEmpty) ...[
            const SectionLabel(text: '成员排行'),
            for (final row in stats.byMember)
              McInsetRow(
                icon: McIcons.user,
                title: row.memberName,
                subtitle: '${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}',
                showChevron: true,
                onTap: () => onMemberSelected(row.memberId),
              ),
          ],
          if (stats.byClient.isNotEmpty) ...[
            const SectionLabel(text: '播放终端'),
            for (final row in stats.byClient)
              McInsetRow(
                icon: McIcons.device2,
                title: row.client.isEmpty ? '未知客户端' : row.client,
                subtitle: '${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}',
              ),
          ],
          if (stats.previousAvailable && stats.favorites.isNotEmpty) ...[
            const SectionLabel(text: '收藏常看'),
            for (final row in stats.favorites.take(3))
              McInsetRow(
                icon: McIcons.heart2Fill,
                iconColor: McTokens.danger,
                title: row.media.title,
                subtitle: '${row.plays} 次 · ${mcFormatWatched(row.watchedMs)}',
              ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.delta = '',
  });

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: McTokens.line, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: McText.micro.copyWith(color: McTokens.textMuted)),
            const SizedBox(height: 5),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(value, style: McText.titleSm.tabular),
            ),
            if (delta.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                delta,
                style: McText.micro
                    .copyWith(
                      color: delta.startsWith('↑')
                          ? McTokens.ok
                          : McTokens.textFaint,
                    )
                    .tabular,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekHeatmap extends StatelessWidget {
  const _WeekHeatmap({required this.matrix});

  final List<List<int>> matrix;

  static const _dayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  Color _cell(int ms, int max) {
    if (ms <= 0 || max <= 0) return McTokens.surfaceInset;
    final t = (ms / max).clamp(0.0, 1.0);
    return Color.lerp(const Color(0x2E7FB0FF), McTokens.accentStrong, t)!;
  }

  @override
  Widget build(BuildContext context) {
    var max = 0;
    for (final row in matrix) {
      for (final v in row) {
        if (v > max) max = v;
      }
    }
    return SizedBox(
      height: 122,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var d = 0; d < 7; d++)
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      _dayLabels[d],
                      style: McText.micro.copyWith(
                        fontWeight: FontWeight.w400,
                        color: McTokens.textFaint,
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
          const SizedBox(height: 3),
          SizedBox(
            height: 14,
            child: Row(
              children: [
                const SizedBox(width: 18),
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: h % 6 == 0
                        ? Text(
                            '$h',
                            style: McText.micro
                                .copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: McTokens.textFaint,
                                )
                                .tabular,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
