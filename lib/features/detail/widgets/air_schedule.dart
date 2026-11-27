import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 播出日历逻辑与组件（1:1 对齐 iOS `AirScheduleLogic.swift` & `AirSchedule.swift`）。

enum AirTone { owned, missing, today, todayFree, upcoming, absent }

enum AirDotKind { today, finale, missing, owned, upcoming }

class AirDay {
  const AirDay({
    required this.date,
    required this.episodes,
    required this.past,
    required this.today,
    required this.finale,
  });

  final String date;
  final List<EpisodeEntry> episodes;
  final bool past;
  final bool today;
  final bool finale;
}

sealed class AirRowItem {
  const AirRowItem();
}

class AirGroupRow extends AirRowItem {
  const AirGroupRow(this.group);
  final int group;
}

class AirGapRow extends AirRowItem {
  const AirGapRow({required this.afterDate, required this.text});
  final String afterDate;
  final String text;
}

class AirDayRow extends AirRowItem {
  const AirDayRow(this.day);
  final AirDay day;
}

abstract final class AirScheduleLogic {
  static final Map<String, DateTime> _parsedCache = {};

  static DateTime? parseDate(String? raw) {
    if (raw == null || raw.length < 10) return null;
    final key = raw.substring(0, 10);
    final cached = _parsedCache[key];
    if (cached != null) return cached;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final dt = DateTime.utc(y, m, d);
    if (_parsedCache.length >= 4096) _parsedCache.clear();
    _parsedCache[key] = dt;
    return dt;
  }

  static int daysBetween(String from, String to) {
    final a = parseDate(from);
    final b = parseDate(to);
    if (a == null || b == null) return 0;
    return b.difference(a).inDays;
  }

  /// 0=周一 .. 6=周日
  static int weekdayIndex(DateTime dt) => (dt.weekday - 1) % 7;

  static String weekdayShort(String day) {
    final dt = parseDate(day);
    if (dt == null) return '';
    return _weekdayName(weekdayIndex(dt));
  }

  static String _weekdayName(int idx) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[idx.clamp(0, 6)];
  }

  static String shortDate(String day) {
    final dt = parseDate(day);
    if (dt == null) return day;
    return '${dt.month}月${dt.day}日';
  }

  static int weekOffset(String today, String day) {
    final todayDt = parseDate(today);
    if (todayDt == null) return 0;
    final d = daysBetween(today, day) + weekdayIndex(todayDt);
    return (d / 7).floor();
  }

  static String groupTitle(int group) => switch (group) {
        0 => '本周',
        1 => '下周',
        _ => '之后',
      };

  static AirTone tone(EpisodeEntry ep, SeasonAirSchedule schedule) {
    if (ep.owned) return AirTone.owned;
    if (schedule.missingEpisodes.contains(ep.episodeNumber)) {
      return AirTone.missing;
    }
    if (ep.airDate == null || ep.airDate!.isEmpty) return AirTone.upcoming;
    final offset = daysBetween(schedule.today, ep.airDate!);
    if (offset > 0) return AirTone.upcoming;
    if (offset == 0) {
      return schedule.subscriptionId != null
          ? AirTone.today
          : AirTone.todayFree;
    }
    return AirTone.absent;
  }

  static bool airsToday(EpisodeEntry ep, SeasonAirSchedule? schedule) {
    if (schedule == null || ep.owned) return false;
    final t = tone(ep, schedule);
    return t == AirTone.today || t == AirTone.todayFree;
  }

  static bool isUnaired(EpisodeEntry ep, SeasonAirSchedule? schedule) {
    if (schedule == null || ep.owned) return false;
    final t = tone(ep, schedule);
    return t == AirTone.today ||
        t == AirTone.todayFree ||
        t == AirTone.upcoming;
  }

  static ({int owned, int missing, int upcoming}) counts(
    List<EpisodeEntry> episodes,
    SeasonAirSchedule schedule,
  ) {
    final owned = episodes.where((e) => e.owned).length;
    final upcoming = episodes.where((e) {
      if (e.owned) return false;
      if (e.airDate == null || e.airDate!.isEmpty) return true;
      return daysBetween(schedule.today, e.airDate!) > 0;
    }).length;
    return (
      owned: owned,
      missing: schedule.missingEpisodes.length,
      upcoming: upcoming,
    );
  }

  static List<AirDay> airDays(
    List<EpisodeEntry> episodes,
    SeasonAirSchedule schedule,
  ) {
    final byDate = <String, List<EpisodeEntry>>{};
    for (final ep in episodes) {
      final raw = ep.airDate;
      if (raw == null || raw.length < 10) continue;
      final key = raw.substring(0, 10);
      byDate.putIfAbsent(key, () => []).add(ep);
    }
    final last = (schedule.lastAirDate != null &&
            schedule.lastAirDate!.length >= 10)
        ? schedule.lastAirDate!.substring(0, 10)
        : null;
    final keys = byDate.keys.toList()..sort();
    return [
      for (final day in keys)
        AirDay(
          date: day,
          episodes: byDate[day]!,
          past: daysBetween(schedule.today, day) < 0,
          today: daysBetween(schedule.today, day) == 0,
          finale: day == last,
        ),
    ];
  }

  static List<AirRowItem> rows(
    List<AirDay> list,
    SeasonAirSchedule schedule, {
    required bool grouped,
  }) {
    final result = <AirRowItem>[];
    int? currentGroup;
    for (var i = 0; i < list.length; i++) {
      final day = list[i];
      final group = math.min(weekOffset(schedule.today, day.date), 2);
      if (grouped && group != currentGroup) {
        currentGroup = group;
        result.add(AirGroupRow(group));
      }
      if (i > 0) {
        final gapText = gap(list[i - 1].date, day.date, schedule.weekdays);
        if (gapText != null) {
          result.add(AirGapRow(afterDate: list[i - 1].date, text: gapText));
        }
      }
      result.add(AirDayRow(day));
    }
    return result;
  }

  static String rangeLabel(List<EpisodeEntry> episodes) {
    final nums = episodes.map((e) => e.episodeNumber).toList()..sort();
    if (nums.isEmpty) return '';
    if (nums.first == nums.last) return '第 ${nums.first} 集';
    return '第 ${nums.first}–${nums.last} 集';
  }

  static String? cadence(List<int> weekdays) {
    final days = weekdays.toSet().toList()..sort();
    if (days.isEmpty) return null;
    if (days.length == 7) return '每天更新';
    if (days.length == 1) return '每${_weekdayName(days.first)}更新';
    var contiguous = true;
    for (var i = 1; i < days.length; i++) {
      if (days[i] != days[i - 1] + 1) {
        contiguous = false;
        break;
      }
    }
    if (contiguous) {
      return '${_weekdayName(days.first)}至${_weekdayName(days.last)}更新';
    }
    return '${days.map(_weekdayName).join('、')}更新';
  }

  static String? finale(SeasonAirSchedule schedule) {
    final last = schedule.lastAirDate;
    if (last == null || last.isEmpty) return null;
    if (daysBetween(schedule.today, last) == 0) return '今日大结局';
    return '${shortDate(last)}完结';
  }

  static String relative(String day, SeasonAirSchedule schedule) {
    final offset = daysBetween(schedule.today, day);
    if (offset == 1) return '明天';
    if (offset > 1) return '$offset 天后';
    if (offset == 0) return '今天';
    return '${-offset} 天前';
  }

  static List<int> missingInDay(AirDay day, SeasonAirSchedule schedule) => day
      .episodes
      .where((e) => schedule.missingEpisodes.contains(e.episodeNumber))
      .map((e) => e.episodeNumber)
      .toList();

  static String? missingText(List<int> numbers) {
    if (numbers.isEmpty) return null;
    return numbers.length == 1
        ? '缺第 ${numbers.first} 集'
        : '缺 ${numbers.length} 集';
  }

  static bool canFind(SeasonAirSchedule schedule, {required bool canSubscribe}) =>
      canSubscribe &&
      schedule.subscriptionId != null &&
      schedule.missingEpisodes.isNotEmpty;

  static String findTitle(SeasonAirSchedule schedule) {
    if (schedule.missingEpisodes.length == 1) {
      return '补第 ${schedule.missingEpisodes.first} 集';
    }
    return '补 ${schedule.missingEpisodes.length} 集';
  }

  /// 检测两个播出日之间是否跳过了常规更新日（真停更/断更提示）。
  static String? gap(String previous, String next, List<int> weekdays) {
    final skipped = daysBetween(previous, next) - 1;
    final start = parseDate(previous);
    final end = parseDate(next);
    if (skipped <= 0 || start == null || end == null || weekdays.isEmpty) {
      return null;
    }
    var breaks = false;
    for (var offset = 1; offset <= skipped; offset++) {
      final dt = start.add(Duration(days: offset));
      if (weekdays.contains(weekdayIndex(dt))) {
        breaks = true;
        break;
      }
    }
    if (!breaks) return null;
    if (skipped >= 7) return '停更 $skipped 天';
    final firstName = _weekdayName(weekdayIndex(start.add(const Duration(days: 1))));
    if (skipped == 1) return '$firstName停更';
    final lastName =
        _weekdayName(weekdayIndex(end.subtract(const Duration(days: 1))));
    return '$firstName至$lastName停更';
  }

  static String? expectedAt(
    List<EpisodeEntry> episodes,
    SeasonAirSchedule schedule,
  ) {
    final pending = episodes
        .where((e) => !e.owned)
        .map((e) => e.episodeNumber)
        .toSet();
    if (pending.isEmpty || schedule.subscriptionId == null) return null;
    final arrivals =
        schedule.arrivals.where((a) => pending.contains(a.episodeNumber)).toList();
    if (arrivals.any((a) => a.stage == 'organizing' || a.stage == 'downloading')) {
      return null;
    }
    final times = arrivals
        .map((a) => a.expectedAt)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
    return times.isEmpty ? null : times.first;
  }

  static String expectedTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final clock =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return clock;
    }
    return '${dt.month}月${dt.day}日 $clock';
  }

  static ({String text, Color color})? arrival(
    List<EpisodeEntry> episodes,
    SeasonAirSchedule schedule,
  ) {
    final at = expectedAt(episodes, schedule);
    if (at != null) {
      return (text: '预计 ${expectedTime(at)}', color: McTokens.info);
    }
    final pending = episodes
        .where((e) => !e.owned)
        .map((e) => e.episodeNumber)
        .toSet();
    if (pending.isEmpty) {
      return (text: '已入库', color: McTokens.ok);
    }
    if (schedule.subscriptionId == null) {
      return (text: '未订阅', color: McTokens.textMuted);
    }
    final arrivals =
        schedule.arrivals.where((a) => pending.contains(a.episodeNumber)).toList();
    if (arrivals.any((a) => a.stage == 'organizing')) {
      return (text: '整理入库中', color: McTokens.info);
    }
    if (arrivals.any((a) => a.stage == 'downloading')) {
      return (text: '下载中', color: McTokens.info);
    }
    if (arrivals.isNotEmpty) {
      return (text: '等待片源', color: McTokens.textMuted);
    }
    return null;
  }

  static AirDotKind dot(AirDay day, SeasonAirSchedule schedule) {
    if (day.today) return AirDotKind.today;
    if (day.finale) return AirDotKind.finale;
    if (day.past && missingInDay(day, schedule).isNotEmpty) {
      return AirDotKind.missing;
    }
    if (day.past && day.episodes.every((e) => e.owned)) {
      return AirDotKind.owned;
    }
    return AirDotKind.upcoming;
  }
}

/// 还没播的集的 16:9 剧照位卡片（对齐 iOS `UnairedStill`）：
/// - 今天播出：蓝色描边 + 「今日播出」+ 实时入库状态；
/// - 之后播出：虚线框 + 播出日/星期 + 倒计时；
/// - 无日期：「待定档」。
class UnairedStill extends StatelessWidget {
  const UnairedStill({
    super.key,
    required this.episode,
    required this.schedule,
    required this.today,
    this.radius = 10,
  });

  final EpisodeEntry episode;
  final SeasonAirSchedule schedule;
  final bool today;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (today) {
      final status = AirScheduleLogic.arrival([episode], schedule);
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11151D),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: const Color(0xBF3B82F6),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '今日播出',
              style: McText.caption.copyWith(
                color: McTokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (status != null) ...[
              const SizedBox(height: 3),
              Text(
                status.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.micro.copyWith(color: status.color),
              ),
            ],
          ],
        ),
      );
    }

    return CustomPaint(
      painter: _DashedRRectPainter(
        radius: radius,
        color: Colors.white.withValues(alpha: 0.25),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0F13),
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (episode.airDate != null && episode.airDate!.isNotEmpty) ...[
              Text(
                '${AirScheduleLogic.shortDate(episode.airDate!)} '
                '${AirScheduleLogic.weekdayShort(episode.airDate!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption
                    .copyWith(
                      color: McTokens.text.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w600,
                    )
                    .tabular,
              ),
              const SizedBox(height: 3),
              Text(
                AirScheduleLogic.relative(episode.airDate!, schedule),
                style: McText.micro.muted.tabular,
              ),
            ] else
              Text(
                '待定档',
                style: McText.caption.copyWith(
                  color: McTokens.text.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 4.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 7.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.radius != radius || old.color != color;
}

/// 分集标题下的交互式播出日历摘要条（点击弹出 `AirScheduleSheet`）。
class AirSchedule extends StatelessWidget {
  const AirSchedule({
    super.key,
    this.schedule,
    this.legacyBanner,
    this.episodes = const [],
    this.onOpenSheet,
  });

  final SeasonAirSchedule? schedule;
  final AirScheduleBanner? legacyBanner;
  final List<EpisodeEntry> episodes;
  final VoidCallback? onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    if (s != null) {
      return _buildRichSummary(s);
    }
    final text = legacyBanner?.text ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: McTokens.pagePadding,
        vertical: 6,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: McTokens.line, width: 1),
        ),
        child: Row(
          children: [
            const Icon(McIcons.clockFill, size: 15, color: McTokens.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption.copyWith(color: McTokens.text).tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichSummary(SeasonAirSchedule s) {
    final days = AirScheduleLogic.airDays(episodes, s);
    AirDay? next;
    for (final d in days) {
      if (!d.past) {
        next = d;
        break;
      }
    }
    final counts = AirScheduleLogic.counts(episodes, s);
    final cadence = AirScheduleLogic.cadence(s.weekdays);
    final remaining = counts.upcoming > 0 ? '余 ${counts.upcoming} 集' : null;
    final finale = AirScheduleLogic.finale(s);
    final metaParts = [
      if (cadence != null) cadence,
      if (remaining != null) remaining,
      if (finale != null) finale,
    ];

    String? sideValue;
    String? sideCaption;
    Color sideColor = McTokens.text;
    if (next != null) {
      if (next.today) {
        if (next.episodes.every((e) => e.owned)) {
          sideValue = '已入库';
          sideColor = McTokens.ok;
        } else {
          final at = AirScheduleLogic.expectedAt(next.episodes, s);
          if (at != null) {
            sideValue = AirScheduleLogic.expectedTime(at);
            sideCaption = '预计入库';
            sideColor = McTokens.info;
          } else {
            final arr = AirScheduleLogic.arrival(next.episodes, s);
            if (arr != null) {
              sideValue = arr.text;
              sideColor = arr.color;
            }
          }
        }
      } else {
        sideValue = AirScheduleLogic.relative(next.date, s);
        sideCaption = AirScheduleLogic.shortDate(next.date);
      }
    }

    final tag = next == null
        ? null
        : (next.today ? '今天' : AirScheduleLogic.weekdayShort(next.date));
    final headline = next == null
        ? null
        : (next.finale
            ? '${AirScheduleLogic.rangeLabel(next.episodes)} 大结局'
            : '${AirScheduleLogic.rangeLabel(next.episodes)}更新');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        4,
        McTokens.pagePadding,
        8,
      ),
      child: McPressable(
        onTap: onOpenSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: McTokens.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (next != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: next.today
                                  ? McTokens.text
                                  : Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag ?? '',
                              style: McText.micro.copyWith(
                                color: next.today
                                    ? const Color(0xFF111318)
                                    : McTokens.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              headline ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.sub
                                  .copyWith(
                                    color: McTokens.text,
                                    fontWeight: FontWeight.w600,
                                  )
                                  .tabular,
                            ),
                          ),
                        ],
                      ),
                    if (metaParts.isNotEmpty) ...[
                      if (next != null) const SizedBox(height: 5),
                      Text(
                        metaParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.muted.tabular,
                      ),
                    ],
                  ],
                ),
              ),
              if (sideValue != null) ...[
                Container(
                  width: 0.5,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      sideValue,
                      style: McText.sub
                          .copyWith(
                            color: sideColor,
                            fontWeight: FontWeight.w600,
                          )
                          .tabular,
                    ),
                    if (sideCaption != null)
                      Text(sideCaption, style: McText.micro.muted.tabular),
                  ],
                ),
              ],
              if (onOpenSheet != null) ...[
                const SizedBox(width: 6),
                const Icon(
                  McIcons.chevronRight,
                  size: 15,
                  color: McTokens.textFaint,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 交互式播出日历弹层（1:1 对齐 iOS `AirScheduleSheet`）。
Future<void> showAirScheduleSheet({
  required BuildContext context,
  required String title,
  required String seasonLabel,
  required List<EpisodeEntry> episodes,
  required SeasonAirSchedule schedule,
  required bool canSubscribe,
  required DetailController controller,
  VoidCallback? onSubscribe,
}) {
  return showMcSheet<void>(
    context: context,
    maxWidth: 600,
    builder: (_) => _AirScheduleSheet(
      title: title,
      seasonLabel: seasonLabel,
      episodes: episodes,
      schedule: schedule,
      canSubscribe: canSubscribe,
      controller: controller,
      onSubscribe: onSubscribe,
    ),
  );
}

class _AirScheduleSheet extends StatefulWidget {
  const _AirScheduleSheet({
    required this.title,
    required this.seasonLabel,
    required this.episodes,
    required this.schedule,
    required this.canSubscribe,
    required this.controller,
    this.onSubscribe,
  });

  final String title;
  final String seasonLabel;
  final List<EpisodeEntry> episodes;
  final SeasonAirSchedule schedule;
  final bool canSubscribe;
  final DetailController controller;
  final VoidCallback? onSubscribe;

  @override
  State<_AirScheduleSheet> createState() => _AirScheduleSheetState();
}

class _AirScheduleSheetState extends State<_AirScheduleSheet> {
  bool _pastOpen = false;
  bool _searching = false;

  bool get _canFind => AirScheduleLogic.canFind(
        widget.schedule,
        canSubscribe: widget.canSubscribe,
      );

  Future<void> _findMissing({int? season, int? episode}) async {
    final subId = widget.schedule.subscriptionId;
    if (subId == null || _searching) return;
    setState(() => _searching = true);
    final res = await widget.controller.searchMissingEpisode(
      subId,
      season: season,
      episode: episode,
    );
    if (!mounted) return;
    setState(() => _searching = false);
    if (res.error != null) {
      McToast.error(res.error!);
    } else {
      McToast.success(
        res.resetCount > 0
            ? '已重新排队搜索 ${res.resetCount} 个缺集'
            : '已提交缺集搜索请求',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = AirScheduleLogic.airDays(widget.episodes, widget.schedule);
    final past = days.where((d) => d.past).toList();
    final coming = days.where((d) => !d.past).toList();
    final counts = AirScheduleLogic.counts(widget.episodes, widget.schedule);
    final finale = AirScheduleLogic.finale(widget.schedule);
    final cadence = AirScheduleLogic.cadence(widget.schedule.weekdays);
    final subtitleParts = [
      widget.title,
      widget.seasonLabel,
      if (cadence != null) cadence,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.84,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 36),
                const Expanded(
                  child: Text(
                    '播出日历',
                    textAlign: TextAlign.center,
                    style: McText.titleSm,
                  ),
                ),
                McGlassIconButton(
                  icon: McIcons.close,
                  iconSize: 16,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (counts.upcoming > 0) ...[
                        Text(
                          '还剩 ${counts.upcoming} 集',
                          style: McText.titleLg.tabular,
                        ),
                        if (finale != null) ...[
                          const SizedBox(width: 10),
                          Text(finale, style: McText.sub.muted),
                        ],
                      ] else if (finale != null)
                        Text(finale, style: McText.titleLg.tabular),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (past.isNotEmpty) ...[
                      _buildPastSummary(past),
                      const SizedBox(height: 6),
                    ],
                    if (_pastOpen) ..._buildRows(past, grouped: false),
                    ..._buildRows(coming, grouped: true),
                    if (widget.schedule.region != null &&
                        widget.schedule.region!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                        child: Text(
                          '播出日期参考 ${widget.schedule.region} 地区放送日历。',
                          style: McText.micro.faint,
                        ),
                      ),
                    if (widget.schedule.subscriptionId != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                        child: Text(
                          '预计入库时间根据历史订阅抓取节奏动态推算。',
                          style: McText.micro.faint,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.schedule.subscriptionId == null &&
                widget.onSubscribe != null) ...[
              const SizedBox(height: 14),
              McActionPill(
                label: '订阅追更',
                icon: McIcons.bookmarkFill,
                primary: true,
                expanded: true,
                height: 44,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSubscribe!();
                },
              ),
              const SizedBox(height: 6),
              Text(
                '订阅后自动追踪新集与补齐缺集，并在播出当天显示预计入库时刻。',
                textAlign: TextAlign.center,
                style: McText.micro.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPastSummary(List<AirDay> past) {
    final allEps = [for (final d in past) ...d.episodes];
    final range = AirScheduleLogic.rangeLabel(allEps);
    final missing = allEps
        .where((e) => widget.schedule.missingEpisodes.contains(e.episodeNumber))
        .map((e) => e.episodeNumber)
        .toList();
    final owned = allEps.where((e) => e.owned).length;
    final allOwned = owned == allEps.length;
    final dateText = past.length == 1
        ? '已播出 · ${AirScheduleLogic.shortDate(past.first.date)}'
        : '已播出 · ${AirScheduleLogic.shortDate(past.first.date)}–'
            '${AirScheduleLogic.shortDate(past.last.date)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _pastOpen = !_pastOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: (missing.isEmpty ? McTokens.ok : McTokens.warning)
                            .withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: missing.isEmpty
                          ? const Icon(
                              McIcons.check,
                              size: 13,
                              color: McTokens.ok,
                            )
                          : Text(
                              '!',
                              style: McText.sub.copyWith(
                                color: McTokens.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            range,
                            style: McText.sub
                                .copyWith(
                                  color: McTokens.text,
                                  fontWeight: FontWeight.w600,
                                )
                                .tabular,
                          ),
                          Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.micro.muted.tabular,
                          ),
                        ],
                      ),
                    ),
                    if (missing.isNotEmpty) ...[
                      if (!_canFind)
                        Text(
                          AirScheduleLogic.missingText(missing) ?? '',
                          style: McText.caption.copyWith(
                            color: McTokens.warning,
                          ),
                        ),
                    ] else
                      Text(
                        allOwned ? '已入库' : '已有 $owned 集',
                        style: McText.caption
                            .copyWith(
                              color:
                                  allOwned ? McTokens.ok : McTokens.textMuted,
                            )
                            .tabular,
                      ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _pastOpen ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        McIcons.chevronRight,
                        size: 15,
                        color: McTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_canFind) ...[
            const SizedBox(width: 8),
            _findButton(
              AirScheduleLogic.findTitle(widget.schedule),
              filled: true,
              onTap: _findMissing,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRows(List<AirDay> list, {required bool grouped}) {
    final items = AirScheduleLogic.rows(list, widget.schedule, grouped: grouped);
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      switch (item) {
        case AirGroupRow(:final group):
          widgets.add(
            Padding(
              padding: EdgeInsets.fromLTRB(10, i == 0 ? 4 : 14, 10, 4),
              child: Text(
                AirScheduleLogic.groupTitle(group),
                style: McText.caption.copyWith(
                  color: McTokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        case AirGapRow(:final text):
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(text, style: McText.micro.muted),
                  ),
                  Expanded(
                    child: Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ],
              ),
            ),
          );
        case AirDayRow(:final day):
          widgets.add(_buildDayRow(day));
      }
    }
    return widgets;
  }

  Widget _buildDayRow(AirDay day) {
    final dayMissing = AirScheduleLogic.missingInDay(day, widget.schedule);
    final dotKind = AirScheduleLogic.dot(day, widget.schedule);

    Widget statusWidget;
    if (day.past) {
      if (day.episodes.every((e) => e.owned)) {
        statusWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(McIcons.check, size: 12, color: McTokens.ok),
            const SizedBox(width: 3),
            Text('已入库', style: McText.caption.copyWith(color: McTokens.ok)),
          ],
        );
      } else if (dayMissing.isEmpty) {
        statusWidget = Text('未在库', style: McText.caption.muted);
      } else if (_canFind) {
        statusWidget = _findButton(
          dayMissing.length == 1 ? '补第 ${dayMissing.first} 集' : '补集',
          filled: false,
          onTap: () => _findMissing(
            season: day.episodes.first.seasonNumber,
            episode: dayMissing.first,
          ),
        );
      } else {
        statusWidget = const SizedBox.shrink();
      }
    } else if (day.today) {
      final arr = AirScheduleLogic.arrival(day.episodes, widget.schedule);
      statusWidget = arr == null
          ? const SizedBox.shrink()
          : Text(
              arr.text,
              style: McText.caption.copyWith(
                color: arr.color,
                fontWeight: FontWeight.w600,
              ),
            );
    } else {
      statusWidget = Text(
        AirScheduleLogic.relative(day.date, widget.schedule),
        style: McText.caption.muted.tabular,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: day.today
            ? McTokens.info.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.today ? '今天' : AirScheduleLogic.weekdayShort(day.date),
            style: McText.micro.copyWith(
              color: day.today ? McTokens.info : McTokens.textMuted,
              fontWeight: day.today ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(
                  AirScheduleLogic.shortDate(day.date),
                  style: McText.sub
                      .copyWith(
                        color: McTokens.text,
                        fontWeight: FontWeight.w600,
                      )
                      .tabular,
                ),
              ),
              _dot(dotKind),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        AirScheduleLogic.rangeLabel(day.episodes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.ui
                            .copyWith(fontWeight: FontWeight.w600)
                            .tabular,
                      ),
                    ),
                    if (day.finale) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: McTokens.warning,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '大结局',
                          style: McText.micro.copyWith(
                            color: const Color(0xFF241A02),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              statusWidget,
            ],
          ),
          if (day.past && dayMissing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 88, top: 2),
              child: Text(
                AirScheduleLogic.missingText(dayMissing) ?? '',
                style: McText.caption.copyWith(color: McTokens.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(AirDotKind kind) {
    return switch (kind) {
      AirDotKind.today => Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: McTokens.info,
            shape: BoxShape.circle,
          ),
        ),
      AirDotKind.finale => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: McTokens.warning, width: 2),
          ),
        ),
      AirDotKind.missing => Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: McTokens.warning,
            shape: BoxShape.circle,
          ),
        ),
      AirDotKind.owned => Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: McTokens.ok,
            shape: BoxShape.circle,
          ),
        ),
      AirDotKind.upcoming => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
        ),
    };
  }

  Widget _findButton(
    String label, {
    required bool filled,
    required VoidCallback onTap,
  }) {
    return McPressable(
      onTap: _searching ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? McTokens.warning : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: filled
                ? Colors.transparent
                : McTokens.warning.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          _searching ? '搜索中…' : label,
          style: McText.micro.copyWith(
            color: filled ? const Color(0xFF241A02) : McTokens.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
