import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/models.dart';
import 'activity_cards.dart';

/// 四个可切换指标（观看时长 / 播放次数 / 播完率 / 活跃成员）。
enum WatchMetric {
  watched,
  plays,
  completion,
  members;

  String get label => switch (this) {
        WatchMetric.watched => '观看时长',
        WatchMetric.plays => '播放次数',
        WatchMetric.completion => '播完率',
        WatchMetric.members => '活跃成员',
      };

  double ofTotals(PlaybackStatsTotals t) => switch (this) {
        WatchMetric.watched => t.watchedMs.toDouble(),
        WatchMetric.plays => t.plays.toDouble(),
        WatchMetric.completion =>
          t.plays > 0 ? t.completed / t.plays : 0.0,
        WatchMetric.members => t.activeMembers.toDouble(),
      };

  double ofDays(List<PlaybackStatsDayRow> rows) => switch (this) {
        WatchMetric.watched =>
          rows.fold<double>(0, (s, r) => s + r.watchedMs),
        WatchMetric.plays => rows.fold<double>(0, (s, r) => s + r.plays),
        WatchMetric.completion => () {
            final p = rows.fold<int>(0, (s, r) => s + r.plays);
            final c = rows.fold<int>(0, (s, r) => s + r.completed);
            return p > 0 ? c / p : 0.0;
          }(),
        WatchMetric.members => rows.isEmpty
            ? 0.0
            : rows.fold<double>(0, (s, r) => s + r.members) / rows.length,
      };

  bool get deltaInPoints => this == WatchMetric.completion;

  String formatValue(double v) => switch (this) {
        WatchMetric.watched => v >= 3600000
            ? '${(v / 3600000).toStringAsFixed(v >= 360000000 ? 0 : 1)} 小时'
            : mcFormatWatched(v.round()),
        WatchMetric.plays => '${v.round()} 次',
        WatchMetric.completion => '${(v * 100).round()}%',
        WatchMetric.members => _trim(v) == v.round().toString()
            ? '${v.round()} 人'
            : '日均 ${_trim(v)} 人',
      };

  (String value, String unit) kpiParts(double v) => switch (this) {
        WatchMetric.watched => v >= 3600000
            ? (
                (v / 3600000).toStringAsFixed(v >= 360000000 ? 0 : 1),
                '小时',
              )
            : ('${v > 0 ? math.max(1, (v / 60000).round()) : 0}', '分钟'),
        WatchMetric.plays => ('${v.round()}', '次'),
        WatchMetric.completion => ('${(v * 100).round()}', '%'),
        WatchMetric.members => (_trim(v), '人'),
      };

  static String _trim(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(1);
  }
}

/// 观看统计面板（1:1 对齐 iOS `WatchStats.swift`）：
/// 4 张交互 KPI 指标卡（各自精准环比）→ TOP 3 海报领奖台 → 柱状图 + 上期虚线叠加 →
/// 成员/终端/常看/播放方式(`by_tier`) 占比条 → 7×24 时段热力图。
class WatchStatsPanel extends StatefulWidget {
  const WatchStatsPanel({
    super.key,
    required this.stats,
    required this.days,
    this.memberId,
    this.members = const [],
    this.scope = 'visible',
    required this.onDaysChanged,
    required this.onMemberSelected,
    this.onScopeChanged,
    this.showHeaderFilters = true,
  });

  final PlaybackWatchStatsView stats;
  final int days;
  final int? memberId;
  final List<ActivityMemberOption> members;
  final String scope;
  final Future<void> Function(int) onDaysChanged;
  final Future<void> Function(int?) onMemberSelected;
  final Future<void> Function(String)? onScopeChanged;
  final bool showHeaderFilters;

  @override
  State<WatchStatsPanel> createState() => _WatchStatsPanelState();
}

class _WatchStatsPanelState extends State<WatchStatsPanel> {
  WatchMetric _metric = WatchMetric.watched;
  int? _selectedBucket;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);
    final kpiMainAxisExtent = (98.0 + (textScale - 1.0) * 56.0).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeaderFilters) _buildFilterBar(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: kpiMainAxisExtent,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final m in WatchMetric.values)
                  _MetricCard(
                    metric: m,
                    stats: stats,
                    selected: m == _metric,
                    onTap: () => setState(() {
                      _metric = m;
                      _selectedBucket = null;
                    }),
                  ),
              ],
            ),
          ),
          if (stats.current.plays > 0 || stats.favorites.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FavoritePodium(
                favorites: stats.favorites,
                previous: stats.previousFavorites,
                drilled: widget.memberId != null,
                hiddenCount: stats.hiddenTitleCount,
                onShowAll: widget.onScopeChanged != null
                    ? () => widget.onScopeChanged!('all')
                    : null,
              ),
            ),
          ],
          if (stats.byDay.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TrendCard(
                stats: stats,
                metric: _metric,
                selectedIndex: _selectedBucket,
                onSelectIndex: (idx) => setState(() => _selectedBucket = idx),
              ),
            ),
          ],
          if (stats.byMember.isNotEmpty) ...[
            const SectionLabel(text: '按成员分布（点按可钻取）'),
            _BreakdownCard(
              total: stats.current.watchedMs.toDouble(),
              rows: [
                for (final row in stats.byMember)
                  _BreakdownEntry(
                    label: row.memberName.isEmpty
                        ? (row.memberId == 0 ? '超级管理员' : '成员 #${row.memberId}')
                        : row.memberName,
                    secondary: '${row.plays} 次 · 播完 ${row.completed}',
                    value: row.watchedMs.toDouble(),
                    valueLabel: mcFormatWatched(row.watchedMs),
                    selected: widget.memberId == row.memberId,
                    onTap: () => widget.onMemberSelected(
                      widget.memberId == row.memberId ? null : row.memberId,
                    ),
                  ),
              ],
            ),
          ],
          if (stats.byClient.isNotEmpty) ...[
            const SectionLabel(text: '播放终端'),
            _BreakdownCard(
              total: stats.current.watchedMs.toDouble(),
              rows: [
                for (final row in stats.byClient)
                  _BreakdownEntry(
                    label: row.client.isEmpty ? '未知客户端' : row.client,
                    secondary: '${row.plays} 次',
                    value: row.watchedMs.toDouble(),
                    valueLabel: mcFormatWatched(row.watchedMs),
                  ),
              ],
            ),
          ],
          if (stats.topTitles.isNotEmpty || stats.hiddenTitleCount > 0) ...[
            const SectionLabel(text: '最常观看'),
            _BreakdownCard(
              total: stats.current.watchedMs.toDouble(),
              expandable: true,
              rows: [
                for (final row in stats.topTitles)
                  _BreakdownEntry(
                    label: row.media.title.isEmpty ? '已删除条目' : row.media.title,
                    secondary: '${row.plays} 次',
                    value: row.watchedMs.toDouble(),
                    valueLabel: mcFormatWatched(row.watchedMs),
                    media: row.media,
                    onTap: (row.media.libraryId != null && row.media.browsable)
                        ? () => context.push(
                              '/detail/${row.media.libraryId}/${row.media.mediaItemId}',
                            )
                        : null,
                  ),
              ],
              footer: stats.hiddenTitleCount > 0
                  ? ActivityScopeFooter(
                      hiddenCount: stats.hiddenTitleCount,
                      scope: widget.scope,
                      hiddenText: '另有 ${stats.hiddenTitleCount} 部范围外作品未显示',
                      onToggleScope: (s) async {
                        if (widget.onScopeChanged != null) {
                          await widget.onScopeChanged!(s);
                        }
                      },
                    )
                  : null,
            ),
          ],
          if (stats.byTier.isNotEmpty) ...[
            const SectionLabel(text: '播放方式分布（直连 vs 转码）'),
            _DeliveryTierCard(tiers: stats.byTier),
          ],
          if (stats.byHour.isNotEmpty) ...[
            const SectionLabel(text: '时段热力（星期 × 小时）'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _WeekHeatmap(matrix: stats.byHour),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    String memberChipLabel() {
      final id = widget.memberId;
      if (id == null) return '全部成员';
      if (id == 0) return '超级管理员';
      for (final m in widget.members) {
        if (m.id == id) return m.displayName;
      }
      for (final row in widget.stats.byMember) {
        if (row.memberId == id && row.memberName.isNotEmpty) {
          return row.memberName;
        }
      }
      return '成员 #$id';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final d in const [7, 30, 90])
            McChip(
              label: '$d 天',
              compact: true,
              selected: widget.days == d,
              onTap: () => widget.onDaysChanged(d),
            ),
          PopupMenuButton<int>(
            tooltip: '按成员筛选',
            onSelected: (v) => widget.onMemberSelected(v < 0 ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: -1, child: Text('全部成员')),
              const PopupMenuItem(value: 0, child: Text('超级管理员')),
              for (final m in widget.members)
                PopupMenuItem(value: m.id, child: Text(m.displayName)),
            ],
            child: McChip(
              label: memberChipLabel(),
              icon: McIcons.user,
              compact: true,
              selected: widget.memberId != null,
            ),
          ),
          if (widget.onScopeChanged != null)
            McChip(
              label: widget.scope == 'all' ? '全部范围' : '我的范围',
              compact: true,
              selected: widget.scope == 'all',
              onTap: () => widget.onScopeChanged!(
                widget.scope == 'all' ? 'visible' : 'all',
              ),
            ),
        ],
      ),
    );
  }
}

/// 活动总览页的「最近 7 天观看摘要」紧凑卡（对齐 iOS `ActivityWeeklyWatchCard`）。
class ActivityWeeklyWatchCard extends StatelessWidget {
  const ActivityWeeklyWatchCard({
    super.key,
    required this.stats,
    required this.onTap,
  });

  final PlaybackWatchStatsView stats;
  final VoidCallback onTap;

  static const _weekdays = ['日', '一', '二', '三', '四', '五', '六'];

  String _weekdayLabel(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date.length >= 10 ? date.substring(8) : date;
    return _weekdays[dt.weekday % 7];
  }

  @override
  Widget build(BuildContext context) {
    final bars = stats.byDay.length > 7
        ? stats.byDay.sublist(stats.byDay.length - 7)
        : stats.byDay;
    final maxMs = bars.fold<int>(0, (m, r) => r.watchedMs > m ? r.watchedMs : m);
    final totalMinutes = (stats.current.watchedMs / 60000).round();
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    String? deltaText;
    Color deltaColor = McTokens.textMuted;
    if (stats.previousAvailable) {
      final cur = stats.current.watchedMs;
      final prev = stats.previous.watchedMs;
      if (prev <= 0) {
        if (cur > 0) {
          deltaText = '本周新增';
          deltaColor = McTokens.ok;
        }
      } else {
        final pct = (((cur - prev) / prev) * 100).round();
        if (pct == 0) {
          deltaText = '与前 7 天持平';
          deltaColor = McTokens.textFaint;
        } else if (pct > 0) {
          deltaText = '较前 7 天 ↑ $pct%';
          deltaColor = McTokens.ok;
        } else {
          deltaText = '较前 7 天 ↓ ${-pct}%';
          deltaColor = McTokens.textMuted;
        }
      }
    }

    return McPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('最近 7 天', style: McText.caption.muted),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (hours > 0) ...[
                            TextSpan(
                              text: '$hours',
                              style: McText.display.tabular,
                            ),
                            TextSpan(text: ' 小时 ', style: McText.sub.muted),
                          ],
                          if (mins > 0 || hours == 0) ...[
                            TextSpan(
                              text: '$mins',
                              style: McText.display.tabular,
                            ),
                            TextSpan(text: ' 分钟', style: McText.sub.muted),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (deltaText != null)
                  Text(
                    deltaText,
                    style: McText.caption
                        .copyWith(color: deltaColor, fontWeight: FontWeight.w600)
                        .tabular,
                  ),
              ],
            ),
            if (bars.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 82,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (maxMs <= 0 ? 1 : maxMs).toDouble(),
                    barTouchData: const BarTouchData(enabled: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= bars.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _weekdayLabel(bars[i].date),
                                style: McText.micro.faint,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < bars.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: bars[i].watchedMs.toDouble(),
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                              color: i == bars.length - 1
                                  ? McTokens.info
                                  : McTokens.info.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.stats,
    required this.selected,
    required this.onTap,
  });

  final WatchMetric metric;
  final PlaybackWatchStatsView stats;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = metric.ofTotals(stats.current);
    final previous = metric.ofTotals(stats.previous);
    final (value, unit) = metric.kpiParts(current);

    String? deltaText;
    int direction = 0;
    if (stats.previousAvailable) {
      if (metric.deltaInPoints) {
        final pts = ((current - previous) * 100).round();
        direction = pts.sign;
        deltaText = pts == 0 ? '持平' : '${pts.abs()} 百分点';
      } else if (previous <= 0) {
        if (current > 0) {
          deltaText = '新增';
          direction = 1;
        }
      } else {
        final ratio = (current - previous) / previous;
        final pct = (ratio.abs() * 100).round();
        direction = ratio > 0 ? 1 : (ratio < 0 ? -1 : 0);
        deltaText = direction == 0 ? '持平' : '$pct%';
      }
    }

    final deltaColor = direction > 0
        ? McTokens.ok
        : direction < 0
            ? McTokens.danger
            : McTokens.textMuted;

    return McPressable(
      onTap: onTap,
      scaleDown: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? McTokens.info.withValues(alpha: 0.1)
              : McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? McTokens.info.withValues(alpha: 0.65)
                : McTokens.line,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.micro.muted,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: McText.titleLg.tabular,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text(unit, maxLines: 1, style: McText.caption.faint),
              ],
            ),
            Row(
              children: [
                if (deltaText != null) ...[
                  Flexible(
                    flex: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: direction == 0
                            ? const Color(0x14FFFFFF)
                            : deltaColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        direction > 0
                            ? '▲ $deltaText'
                            : direction < 0
                                ? '▼ $deltaText'
                                : deltaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.micro
                            .copyWith(color: deltaColor, fontSize: 10)
                            .tabular,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    stats.previousAvailable
                        ? '上期 ${metric.formatValue(previous)}'
                        : '暂无上期',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.micro.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: McTokens.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 主趋势图（当前周期柱状 + 上一周期虚线对比 + 点击明细条） ──

class _TrendBucket {
  const _TrendBucket({
    required this.index,
    required this.current,
    this.previous,
    required this.label,
    this.previousLabel,
    required this.shortDate,
  });

  final int index;
  final double current;
  final double? previous;
  final String label;
  final String? previousLabel;
  final String shortDate;
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.stats,
    required this.metric,
    required this.selectedIndex,
    required this.onSelectIndex,
  });

  final PlaybackWatchStatsView stats;
  final WatchMetric metric;
  final int? selectedIndex;
  final ValueChanged<int?> onSelectIndex;

  static List<List<PlaybackStatsDayRow>> _bucketize(
    List<PlaybackStatsDayRow> rows,
    int size,
  ) {
    final out = <List<PlaybackStatsDayRow>>[];
    var end = rows.length;
    while (end > 0) {
      out.insert(0, rows.sublist(math.max(0, end - size), end));
      end -= size;
    }
    return out;
  }

  static String _dayLabel(String raw) {
    final parts = raw.split('-');
    if (parts.length == 3) {
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (m != null && d != null) return '$m月$d日';
    }
    return raw;
  }

  static String _bucketLabel(List<PlaybackStatsDayRow> rows) {
    if (rows.isEmpty) return '';
    if (rows.length == 1) return _dayLabel(rows.first.date);
    return '${_dayLabel(rows.first.date)} – ${_dayLabel(rows.last.date)}';
  }

  static double _niceMax(double v) {
    if (v <= 0) return 1;
    final exp = (math.log(v) / math.ln10).floor();
    final base = math.pow(10, exp).toDouble();
    for (final step in const [1.0, 2.0, 5.0, 10.0]) {
      if (v <= step * base) return step * base;
    }
    return 10 * base;
  }

  @override
  Widget build(BuildContext context) {
    final weekly = stats.byDay.length > 35;
    final size = weekly ? 7 : 1;
    final curBuckets = _bucketize(stats.byDay, size);
    final prevBuckets = _bucketize(stats.previousByDay, size);
    final showPrevious =
        stats.previousAvailable && prevBuckets.length == curBuckets.length;

    final points = <_TrendBucket>[
      for (var i = 0; i < curBuckets.length; i++)
        _TrendBucket(
          index: i,
          current: metric.ofDays(curBuckets[i]),
          previous: showPrevious ? metric.ofDays(prevBuckets[i]) : null,
          label: _bucketLabel(curBuckets[i]),
          previousLabel: showPrevious ? _bucketLabel(prevBuckets[i]) : null,
          shortDate: curBuckets[i].first.date.length >= 10
              ? curBuckets[i].first.date.substring(5)
              : curBuckets[i].first.date,
        ),
    ];

    var maxVal = 0.0;
    for (final p in points) {
      if (p.current > maxVal) maxVal = p.current;
      if ((p.previous ?? 0) > maxVal) maxVal = p.previous!;
    }
    final yMax = _niceMax(maxVal);
    final selected = (selectedIndex != null &&
            selectedIndex! >= 0 &&
            selectedIndex! < points.length)
        ? points[selectedIndex!]
        : null;
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.8);
    final bottomAxisHeight = (22.0 * textScale).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                metric.label,
                style: McText.caption.copyWith(
                  color: McTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(weekly ? '按周汇总' : '按日分布', style: McText.micro.faint),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              height: 180 + (bottomAxisHeight - 22.0),
              child: Stack(
                children: [
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      minY: 0,
                      maxY: yMax,
                      barTouchData: BarTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          final idx = response?.spot?.touchedBarGroupIndex;
                          if (idx != null && idx != selectedIndex) {
                            onSelectIndex(idx);
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          getTooltipItem: (_, __, ___, ____) => null,
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yMax / 4,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: McTokens.line,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: bottomAxisHeight,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= points.length) {
                                return const SizedBox.shrink();
                              }
                              final lastIdx = points.length - 1;
                              final step =
                                  (points.length / 5).ceil().clamp(1, 30);
                              final minGap = math.max(1, (step * 0.65).ceil());
                              if (i != lastIdx &&
                                  (i % step != 0 || (lastIdx - i) < minGap)) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                space: 5,
                                fitInside: SideTitleFitInsideData.fromTitleMeta(
                                  meta,
                                  distanceFromEdge: 0,
                                ),
                                child: Text(
                                  points[i].shortDate,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: McText.micro.faint.tabular,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (final p in points)
                          BarChartGroupData(
                            x: p.index,
                            barRods: [
                              BarChartRodData(
                                toY: p.current,
                                width: points.length > 20 ? 5 : 10,
                                borderRadius: BorderRadius.circular(3),
                                color: (selectedIndex == null ||
                                        selectedIndex == p.index)
                                    ? McTokens.info
                                    : McTokens.info.withValues(alpha: 0.45),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (showPrevious && points.length > 1)
                    IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomAxisHeight),
                        child: LineChart(
                          LineChartData(
                            minX: -0.5,
                            maxX: points.length - 0.5,
                            minY: 0,
                            maxY: yMax,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (final p in points)
                                    FlSpot(
                                      p.index.toDouble(),
                                      p.previous ?? 0,
                                    ),
                                ],
                                isCurved: false,
                                color: Colors.white.withValues(alpha: 0.4),
                                barWidth: 1.5,
                                dashArray: [4, 4],
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.label,
                    style: McText.micro.copyWith(
                      color: McTokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: McTokens.info,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '本期 ${metric.formatValue(selected.current)}',
                        style: McText.caption
                            .copyWith(color: McTokens.text)
                            .tabular,
                      ),
                    ],
                  ),
                  if (selected.previous != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 2,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '上期 ${metric.formatValue(selected.previous!)}'
                          '${selected.previousLabel != null ? '（${selected.previousLabel}）' : ''}',
                          style: McText.caption.muted.tabular,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: McTokens.info,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text('本期', style: McText.micro.faint),
              if (showPrevious) ...[
                const SizedBox(width: 14),
                Container(
                  width: 14,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text('上期对照（虚线）', style: McText.micro.faint),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Netflix 风格 TOP 3 海报领奖台（FavoritePodium） ──

class FavoritePodium extends StatelessWidget {
  const FavoritePodium({
    super.key,
    required this.favorites,
    required this.previous,
    required this.drilled,
    required this.hiddenCount,
    this.onShowAll,
  });

  final List<PlaybackStatsTitleRow> favorites;
  final List<PlaybackStatsTitleRow> previous;
  final bool drilled;
  final int hiddenCount;
  final VoidCallback? onShowAll;

  static const _rankLabels = ['TOP 1', 'TOP 2', 'TOP 3'];

  ({String text, Color color})? _rankChange(
    PlaybackStatsTitleRow row,
    int rank,
  ) {
    if (previous.isEmpty) return null;
    final was = previous
        .indexWhere((p) => p.media.mediaItemId == row.media.mediaItemId);
    if (was < 0) return (text: '新上榜', color: McTokens.info);
    if (was == rank) return (text: '蝉联', color: McTokens.ok);
    final up = was > rank;
    return (
      text: '${up ? '▲' : '▼'} 上期第 ${was + 1}',
      color: up ? McTokens.ok : McTokens.textMuted,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      if (hiddenCount <= 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: McTokens.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'TOP 3 热门作品在当前可见范围外（隐藏 $hiddenCount 部）',
                style: McText.caption.muted,
              ),
            ),
            if (onShowAll != null)
              McPressable(
                onTap: onShowAll,
                child: Text(
                  '显示全部',
                  style: McText.caption.copyWith(color: McTokens.info),
                ),
              ),
          ],
        ),
      );
    }

    final heroPoster =
        McImageUrls.resolve(favorites.first.media.posterUrl, widthPx: 240);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          if (heroPoster.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Opacity(
                  opacity: 0.35,
                  child: CachedNetworkImage(
                    imageUrl: heroPoster,
                    httpHeaders: mcImageHeaders(),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xE00B0D13),
                    Color(0xBF0B0D13),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: McTokens.line),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: McTokens.info,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TOP 3',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: McTokens.onAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      drilled ? '本期看得最多' : '本期最受欢迎',
                      style: McText.sub.copyWith(
                        color: McTokens.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      drilled ? '按观看时长' : '按观看人数',
                      style: McText.micro.faint,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (var rank = 0;
                    rank < math.min(3, favorites.length);
                    rank++) ...[
                  if (rank > 0) const SizedBox(height: 14),
                  _buildPodiumRow(context, favorites[rank], rank),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumRow(
    BuildContext context,
    PlaybackStatsTitleRow row,
    int rank,
  ) {
    final hero = rank == 0;
    final poster = McImageUrls.resolve(row.media.posterUrl, widthPx: 240);
    final canOpen = row.media.libraryId != null && row.media.browsable;
    final change = _rankChange(row, rank);
    final facts = [
      if (row.media.year != null) '${row.media.year}',
      row.media.kind == 'tv' ? '剧集' : '电影',
    ].join(' · ');

    return McPressable(
      onTap: canOpen
          ? () => context
              .push('/detail/${row.media.libraryId}/${row.media.mediaItemId}')
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: hero ? 48 : 38,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.65),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ).createShader(bounds),
              child: Text(
                '${rank + 1}',
                style: TextStyle(
                  fontSize: hero ? 66 : 50,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: hero ? 82 : 60,
              height: hero ? 122 : 90,
              color: McTokens.posterPlaceholder,
              child: poster.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: poster,
                      httpHeaders: mcImageHeaders(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                        McIcons.film,
                        color: McTokens.textFaint,
                      ),
                    )
                  : const Icon(McIcons.film, color: McTokens.textFaint),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _rankLabels[rank],
                  style: McText.micro.copyWith(
                    letterSpacing: 1.5,
                    color: McTokens.textFaint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.media.title.isEmpty ? '已删除条目' : row.media.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (hero ? McText.titleSm : McText.sub).copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(facts, style: McText.micro.faint),
                ],
                const SizedBox(height: 4),
                Text(
                  [
                    if (!drilled && row.members > 0) '${row.members} 人看过',
                    '${row.plays} 次播放',
                    mcFormatWatched(row.watchedMs),
                  ].join(' · '),
                  style: McText.caption.muted.tabular,
                ),
                if (change != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: change.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      change.text,
                      style: McText.micro.copyWith(color: change.color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 分解占比条卡片 ──

class _BreakdownEntry {
  const _BreakdownEntry({
    required this.label,
    this.secondary,
    required this.value,
    required this.valueLabel,
    this.selected = false,
    this.media,
    this.onTap,
  });

  final String label;
  final String? secondary;
  final double value;
  final String valueLabel;
  final bool selected;
  final MediaActivityTarget? media;
  final VoidCallback? onTap;
}

class _BreakdownCard extends StatefulWidget {
  const _BreakdownCard({
    required this.total,
    required this.rows,
    this.expandable = false,
    this.footer,
  });

  final double total;
  final List<_BreakdownEntry> rows;
  final bool expandable;
  final Widget? footer;

  @override
  State<_BreakdownCard> createState() => _BreakdownCardState();
}

class _BreakdownCardState extends State<_BreakdownCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const limit = 5;
    final visible = (!widget.expandable || _expanded || widget.rows.length <= limit)
        ? widget.rows.take(widget.expandable ? widget.rows.length : limit).toList()
        : widget.rows.take(limit).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: McTokens.line),
            _buildRow(visible[i]),
          ],
          if (widget.expandable && widget.rows.length > limit) ...[
            const Divider(height: 1, color: McTokens.line),
            McPressable(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _expanded ? '收起' : '展开全部 ${widget.rows.length} 部',
                    style: McText.caption.copyWith(color: McTokens.info),
                  ),
                ),
              ),
            ),
          ],
          if (widget.footer != null) ...[
            const Divider(height: 1, color: McTokens.line),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: widget.footer!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_BreakdownEntry row) {
    final share = widget.total > 0
        ? ((row.value / widget.total) * 100).round().clamp(0, 100)
        : 0;
    final poster = row.media != null
        ? McImageUrls.resolve(row.media!.posterUrl, widthPx: 96)
        : '';
    return McPressable(
      onTap: row.onTap,
      child: Container(
        color: row.selected ? const Color(0x0FFFFFFF) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (row.media != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  width: 24,
                  height: 36,
                  color: McTokens.posterPlaceholder,
                  child: poster.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: poster,
                          httpHeaders: mcImageHeaders(),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.sub.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (row.secondary != null) ...[
                        const SizedBox(width: 6),
                        Text(row.secondary!, style: McText.micro.faint.tabular),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '${row.valueLabel} · $share%',
                        style: McText.micro.muted.tabular,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: math.max(0.01, share / 100.0),
                      minHeight: 3,
                      color: row.selected ? McTokens.ok : McTokens.info,
                      backgroundColor: const Color(0x14FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 播放方式档位分布卡（`by_tier`：直连 vs 重封装/转码堆叠条 + 逐档位占比）。
class _DeliveryTierCard extends StatelessWidget {
  const _DeliveryTierCard({required this.tiers});

  final List<PlaybackStatsTierRow> tiers;

  Color _tierColor(int tier) => switch (tier) {
        0 => McTokens.ok, // 直连
        1 || 2 => McTokens.info, // 重封装 / 音频转码
        3 => McTokens.warning, // 硬件转码
        _ => McTokens.danger, // 软件转码
      };

  @override
  Widget build(BuildContext context) {
    final total = tiers.fold<int>(0, (s, r) => s + r.plays);
    if (total <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final row in tiers)
                    if (row.plays > 0)
                      Expanded(
                        flex: row.plays,
                        child: Container(
                          color: _tierColor(row.tier),
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final row in tiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _tierColor(row.tier),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.label.isEmpty ? '档位 ${row.tier}' : row.label,
                      style: McText.caption.copyWith(color: McTokens.text),
                    ),
                  ),
                  Text(
                    '${row.plays} 次 · ${(row.plays * 100 / total).round()}%',
                    style: McText.caption.muted.tabular,
                  ),
                ],
              ),
            ),
        ],
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
    final axisLabelStyle = McText.micro
        .copyWith(
          fontWeight: FontWeight.w400,
          color: McTokens.textFaint,
        )
        .tabular;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 108,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          _dayLabels[d],
                          maxLines: 1,
                          softWrap: false,
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
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(width: 22),
            Expanded(
              child: Text(
                '0',
                maxLines: 1,
                softWrap: false,
                style: axisLabelStyle,
              ),
            ),
            Expanded(
              child: Text(
                '6',
                maxLines: 1,
                softWrap: false,
                style: axisLabelStyle,
              ),
            ),
            Expanded(
              child: Text(
                '12',
                maxLines: 1,
                softWrap: false,
                style: axisLabelStyle,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '18',
                    maxLines: 1,
                    softWrap: false,
                    style: axisLabelStyle,
                  ),
                  Text(
                    '24',
                    maxLines: 1,
                    softWrap: false,
                    style: axisLabelStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
