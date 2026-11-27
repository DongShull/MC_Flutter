/// 订阅首页/海报墙共用的展示口径（1:1 对齐 iOS `SubscriptionsHomeModel.swift`）。
/// 纯函数层：不碰 UI，也不发请求；输入是 models.dart 的视图模型。
library;

import 'dart:ui';

import 'models.dart';

// ── 状态色调（对齐 iOS `SubsHomeTone`） ──
const subsToneInfo = Color(0xFF7FB0FF); // 下载中
const subsToneOk = Color(0xFF4ADE80); // 整理中 / 刚刚入库 / 新一集
const subsToneWarn = Color(0xFFF5C451); // 等待资源 / 找资源中
const subsToneRinse = Color(0xFF2DD4BF); // 洗版中
const subsToneToday = Color(0xFFDDD6FF); // 今天更新

// ── 时间小工具 ──

DateTime? subsDate(String? s) => SubsFormat.date(s);

int subsDateMs(String? s) => subsDate(s)?.millisecondsSinceEpoch ?? 0;

String pad2(int v) => v < 10 ? '0$v' : '$v';

String arrivalClockText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${pad2(d.hour)}:${pad2(d.minute)}';
}

String mmdd(DateTime d) => '${d.month}月${d.day}日';

String formatEstimated(int ms, int nowMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final n = DateTime.fromMillisecondsSinceEpoch(nowMs);
  final sameDay = d.year == n.year && d.month == n.month && d.day == n.day;
  final tomorrow =
      DateTime(n.year, n.month, n.day + 1) == DateTime(d.year, d.month, d.day);
  final hm = arrivalClockText(ms);
  if (sameDay) return '约 $hm';
  if (tomorrow) return '明日 $hm';
  return '${mmdd(d)} $hm';
}

String heroClockText(int ms, int nowMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final n = DateTime.fromMillisecondsSinceEpoch(nowMs);
  final sameDay = d.year == n.year && d.month == n.month && d.day == n.day;
  final tomorrow =
      DateTime(n.year, n.month, n.day + 1) == DateTime(d.year, d.month, d.day);
  final hm = arrivalClockText(ms);
  if (sameDay) return hm;
  if (tomorrow) return '明天 $hm';
  return '${d.month}/${d.day} $hm';
}

String subsFromNow(int ms, int nowMs) {
  final diff = nowMs - ms;
  if (diff <= 60 * 1000) return '刚刚';
  final min = diff ~/ 60000;
  if (min < 60) return '$min分钟';
  final hours = diff ~/ 3600000;
  if (hours < 24) return '$hours小时';
  final days = diff ~/ 86400000;
  return '$days天';
}

/// 集号压缩成区间：`[1,2,3,5]` → `E01–E03、E05`。
String episodeRangesText(List<int> episodes) {
  final sorted = episodes.toSet().toList()..sort();
  if (sorted.isEmpty) return '';
  final ranges = <(int, int)>[];
  for (final ep in sorted) {
    if (ranges.isNotEmpty && ep == ranges.last.$2 + 1) {
      ranges[ranges.length - 1] = (ranges.last.$1, ep);
    } else {
      ranges.add((ep, ep));
    }
  }
  return ranges
      .map((r) => r.$1 == r.$2 ? 'E${pad2(r.$1)}' : 'E${pad2(r.$1)}–E${pad2(r.$2)}')
      .join('、');
}

// ── 到达展示（ArrivalPresentation） ──

class ArrivalPresentation {
  const ArrivalPresentation(
    this.statusLabel, [
    this.timeLabel = '',
    this.estimatedAt = 0,
  ]);

  final String statusLabel;
  final String timeLabel;
  final int estimatedAt;

  bool get glows => statusLabel == '下载中' || statusLabel == '整理中';

  int get stageOrder => statusLabel == '下载中'
      ? 1
      : statusLabel == '整理中'
          ? 2
          : 0;

  Color? get tone => switch (statusLabel) {
        '下载中' => subsToneInfo,
        '整理中' => subsToneOk,
        '预计入库' => subsToneOk,
        '等待资源' => subsToneWarn,
        _ => null,
      };
}

int? etaSecondsFor(TodayArrivalView item, Map<String, int> etas) {
  final hash = item.infoHash;
  if (hash != null && hash.isNotEmpty) {
    final v = etas[hash.toLowerCase()];
    if (v != null && v >= 0) return v;
  }
  return null;
}

DownloadTaskView? taskFor(
  TodayArrivalView item,
  Map<String, DownloadTaskView> tasks,
) {
  final hash = item.infoHash;
  if (hash != null && hash.isNotEmpty) {
    return tasks[hash.toLowerCase()];
  }
  return null;
}

ArrivalPresentation arrivalPresentation(
  TodayArrivalView item,
  int? etaSeconds,
  int nowMs, {
  DownloadTaskView? task,
}) {
  if (item.status == 'downloaded' || task?.state == 'completed') {
    final doneMs = subsDateMs(item.downloadedAt);
    final readyAt = doneMs > 0 && item.estimatedDownloadToImportMinutes > 0
        ? doneMs + item.estimatedDownloadToImportMinutes * 60000
        : 0;
    final time = readyAt > nowMs ? arrivalClockText(readyAt) : '即将';
    return ArrivalPresentation('整理中', time, readyAt > nowMs ? readyAt : 0);
  }
  if (item.status == 'grabbed') {
    final liveEta = (task != null && task.state == 'downloading')
        ? task.etaSeconds
        : etaSeconds;
    final etaSec = (liveEta != null && liveEta >= 0)
        ? liveEta
        : (item.estimatedDownloadToImportMinutes > 0
            ? item.estimatedDownloadToImportMinutes * 60
            : null);
    final at = etaSec != null
        ? nowMs + (etaSec + item.estimatedDownloadToImportMinutes * 60) * 1000
        : 0;
    return ArrivalPresentation(
      '下载中',
      at > 0 ? arrivalClockText(at) : '稍后',
      at,
    );
  }

  final f = item.forecast;
  if (f != null && f.usable) {
    final predMs = subsDateMs(f.predictedAt);
    if (predMs > 0) {
      final delayMs = item.estimatedReleaseToImportMinutes * 60000;
      var est = predMs + delayMs;
      if (est < nowMs) {
        final probe = subsDateMs(item.nextProbeAt);
        est = probe > 0
            ? (probe > nowMs ? probe : nowMs) + delayMs
            : 0;
      }
      final stage = predMs <= nowMs ? '等待资源' : '预计入库';
      if (est > 0) {
        return ArrivalPresentation(stage, arrivalClockText(est), est);
      }
    }
  }
  if (item.daysAhead > 0 && (item.expectedDay ?? '').isNotEmpty) {
    final day = subsDate(item.expectedDay);
    if (day != null) {
      return ArrivalPresentation('等待资源', '${mmdd(day)} 播出');
    }
  }
  final probe = subsDateMs(item.nextProbeAt);
  if (probe > nowMs) {
    return ArrivalPresentation('等待资源', '${arrivalClockText(probe)} 探测');
  }
  return const ArrivalPresentation('等待资源', '待定');
}

// ── Hero ──

class HeroGroup {
  HeroGroup({
    required this.subscriptionId,
    required this.arrival,
    required this.arrivals,
    required this.presentation,
    required this.daysAhead,
    this.progress,
    this.readyAt = 0,
  });

  final int subscriptionId;
  final TodayArrivalView arrival;
  final List<TodayArrivalView> arrivals;
  final ArrivalPresentation presentation;
  final int daysAhead;

  /// 下载中平均进度 0..1（仅下载中且有下载器快照时非空）。
  final double? progress;

  /// 整理中预计可看时刻 ms（downloadedAt + estimatedDownloadToImportMinutes）。
  final int readyAt;

  String get episodeLabel {
    if (arrival.mediaKind != 'tv') return '电影';
    final bySeason = <int, List<int>>{};
    for (final a in arrivals) {
      bySeason.putIfAbsent(a.seasonNumber, () => []).add(a.episodeNumber);
    }
    final seasons = bySeason.keys.toList()..sort();
    return seasons
        .map((s) => 'S${pad2(s)}${episodeRangesText(bySeason[s]!)}')
        .join(' · ');
  }
}

List<HeroGroup> heroGroups(
  List<TodayArrivalView> today,
  Map<String, int> etas,
  int nowMs, {
  Map<String, DownloadTaskView> tasks = const {},
}) {
  final buckets = <(int, int), List<TodayArrivalView>>{};
  final order = <(int, int)>[];
  for (final item in today) {
    if (item.daysAhead < 0) continue;
    final key = (item.subscriptionId, item.daysAhead);
    if (!buckets.containsKey(key)) {
      order.add(key);
      buckets[key] = [];
    }
    buckets[key]!.add(item);
  }

  // 每部订阅取最近的那一天
  final nearestBySub = <int, HeroGroup>{};
  for (final key in order) {
    final rows = buckets[key]!;
    final first = rows.first;
    ArrivalPresentation? blocking;
    final dlProgress = <double>[];
    var maxReadyAt = 0;

    for (final r in rows) {
      final t = taskFor(r, tasks);
      final pres = arrivalPresentation(
        r,
        etaSecondsFor(r, etas),
        nowMs,
        task: t,
      );
      if (blocking == null ||
          pres.stageOrder < blocking.stageOrder ||
          (pres.stageOrder == blocking.stageOrder &&
              pres.estimatedAt > blocking.estimatedAt)) {
        blocking = pres;
      }
      if (r.status == 'grabbed' && t?.progress != null) {
        dlProgress.add(t!.progress!.clamp(0.0, 1.0));
      }
      if (r.status == 'downloaded') {
        final doneMs = subsDateMs(r.downloadedAt);
        if (doneMs > 0 && r.estimatedDownloadToImportMinutes > 0) {
          final ready = doneMs + r.estimatedDownloadToImportMinutes * 60000;
          if (ready > maxReadyAt) maxReadyAt = ready;
        }
      }
    }

    final avgProgress = dlProgress.isEmpty
        ? null
        : dlProgress.reduce((a, b) => a + b) / dlProgress.length;
    final group = HeroGroup(
      subscriptionId: first.subscriptionId,
      arrival: first,
      arrivals: rows,
      presentation: blocking ?? const ArrivalPresentation('预计入库'),
      daysAhead: first.daysAhead,
      progress: avgProgress,
      readyAt: maxReadyAt,
    );
    final prev = nearestBySub[first.subscriptionId];
    if (prev == null || group.daysAhead < prev.daysAhead) {
      nearestBySub[first.subscriptionId] = group;
    }
  }
  return nearestBySub.values.toList();
}

class HeroSlide {
  HeroSlide({
    required this.subscriptionId,
    required this.media,
    required this.eyebrow,
    this.eyebrowTone,
    this.clockLabel = '',
    this.clock = '',
    this.detail = '',
    this.footnote = '',
    this.progress = 0,
    this.playArrival,
    this.resumePercent = 0,
  });

  final int subscriptionId;
  final MediaBrief media;
  final String eyebrow;
  final Color? eyebrowTone;
  final String clockLabel;
  final String clock;
  final String detail;
  final String footnote;
  final double progress; // 0~1，0 = 不画
  /// 非空时主按钮为「播放 / 继续播放」，直达实际新到的 `seasonNumber` & `episodeNumber`！
  final RecentArrivalView? playArrival;
  final int resumePercent;

  bool get playable => playArrival != null;
}

bool heroClockIsNumeric(String clock) => clock.contains(RegExp(r'[0-9]'));

List<HeroSlide> buildHeroSlides(SubsHome home, int nowMs) {
  final used = <int>{};
  final slides = <HeroSlide>[];

  void push(HeroSlide s) {
    if (used.contains(s.subscriptionId) || slides.length >= 5) return;
    used.add(s.subscriptionId);
    slides.add(s);
  }

  final groups = [
    ...heroGroups(home.today, home.etas, nowMs, tasks: home.tasksByHash),
  ];

  // 1) 正在发生（整理中 > 下载中）
  final pipeline = groups.where((g) => g.presentation.stageOrder > 0).toList()
    ..sort((a, b) {
      final pa = a.presentation.stageOrder, pb = b.presentation.stageOrder;
      if (pa != pb) return pb - pa;
      return a.presentation.estimatedAt - b.presentation.estimatedAt;
    });
  for (final g in pipeline) {
    final sub = home.subById(g.subscriptionId);
    if (sub == null) continue;
    final pres = g.presentation;
    final epLabel = g.episodeLabel;
    if (pres.statusLabel == '整理中') {
      final hasReady = g.readyAt > nowMs;
      push(
        HeroSlide(
          subscriptionId: g.subscriptionId,
          media: sub.media,
          eyebrow: '整理中',
          eyebrowTone: subsToneOk,
          clockLabel: g.arrival.mediaKind == 'movie'
              ? (hasReady ? '已下载 · 预计可看' : '下载完成')
              : (hasReady ? '$epLabel · 预计可看' : '$epLabel · 下载完成'),
          clock: hasReady ? heroClockText(g.readyAt, nowMs) : '马上就好',
        ),
      );
    } else {
      final pct = g.progress != null
          ? ' · ${(g.progress! * 100).round()}%'
          : '';
      final hasEta = pres.estimatedAt > 0;
      push(
        HeroSlide(
          subscriptionId: g.subscriptionId,
          media: sub.media,
          eyebrow: '下载中$pct',
          eyebrowTone: subsToneInfo,
          clockLabel: hasEta
              ? (g.arrival.mediaKind == 'movie'
                  ? '预计可看'
                  : '$epLabel · 预计可看')
              : '',
          clock: hasEta ? heroClockText(pres.estimatedAt, nowMs) : '',
          detail: hasEta
              ? ''
              : (g.arrival.mediaKind == 'movie'
                  ? '正在下载'
                  : '$epLabel · 正在下载'),
          footnote: hasEta ? '' : '下载完成后自动入库',
          progress: g.progress ?? _pipelineProgress(sub),
        ),
      );
    }
  }

  // 2) 刚到（≤48h）
  final sortedRecent = [...home.recent]
    ..sort((a, b) => subsDateMs(b.importedAt) - subsDateMs(a.importedAt));
  for (final r in sortedRecent) {
    final imported = subsDateMs(r.importedAt);
    if (imported <= 0 || nowMs - imported > 48 * 3600000) continue;
    if (used.contains(r.subscriptionId)) continue;
    push(_recentSlide(r, nowMs));
  }

  // 3) 今天 / 即将更新（不在途的）
  final upcoming = groups.where((g) => g.presentation.stageOrder == 0).toList()
    ..sort((a, b) {
      if (a.daysAhead != b.daysAhead) return a.daysAhead - b.daysAhead;
      return a.presentation.estimatedAt - b.presentation.estimatedAt;
    });
  for (final g in upcoming) {
    if (used.contains(g.subscriptionId)) continue;
    final sub = home.subById(g.subscriptionId);
    if (sub == null) continue;
    final pres = g.presentation;
    final epLabel = g.episodeLabel;
    if (g.daysAhead > 0) {
      final dayStr = (g.arrival.expectedDay ?? '').isNotEmpty &&
              subsDate(g.arrival.expectedDay) != null
          ? mmdd(subsDate(g.arrival.expectedDay)!)
          : '';
      push(
        HeroSlide(
          subscriptionId: g.subscriptionId,
          media: sub.media,
          eyebrow: '即将更新',
          eyebrowTone: const Color(0x9EFFFFFF),
          clockLabel: dayStr.isNotEmpty ? '$epLabel · $dayStr' : epLabel,
          clock: g.daysAhead == 1
              ? '明天'
              : _weekdayOf(g.arrival.expectedDay) ?? '${g.daysAhead}天后',
        ),
      );
    } else {
      push(
        HeroSlide(
          subscriptionId: g.subscriptionId,
          media: sub.media,
          eyebrow: pres.statusLabel == '等待资源' ? '等待资源' : '今天更新',
          eyebrowTone: pres.statusLabel == '等待资源' ? subsToneWarn : subsToneToday,
          clockLabel: pres.estimatedAt > 0 ? '$epLabel · 预计入库' : '',
          clock: pres.estimatedAt > 0
              ? heroClockText(pres.estimatedAt, nowMs)
              : '',
          detail: pres.estimatedAt > 0 ? '' : epLabel,
          footnote: pres.estimatedAt > 0 ? '' : pres.timeLabel,
        ),
      );
    }
  }

  // 4) 更早的入库
  for (final r in sortedRecent) {
    if (used.contains(r.subscriptionId)) continue;
    push(_recentSlide(r, nowMs));
  }

  // 5) 全空：在追前 3 的歇着版式
  if (slides.isEmpty) {
    final ranked = [...home.subs]..sort((a, b) {
        final la = a.status == 'active' ? 0 : 1;
        final lb = b.status == 'active' ? 0 : 1;
        if (la != lb) return la - lb;
        return subsDateMs(b.updatedAt) - subsDateMs(a.updatedAt);
      });
    for (final sub in ranked.take(3)) {
      final st = home.standing(sub);
      push(
        HeroSlide(
          subscriptionId: sub.id,
          media: sub.media,
          eyebrow: st.chipText ?? '追踪中',
          eyebrowTone: st.chipColor,
          detail: home.meta(sub),
          footnote: sub.media.kind == 'tv'
              ? (sub.status == 'active' ? '新集播出后自动搜索入库' : '')
              : (sub.progress.imported > 0 ? '已在媒体库中' : '出现合适资源后自动下载'),
        ),
      );
    }
  }
  return slides;
}

HeroSlide _recentSlide(RecentArrivalView r, int nowMs) {
  final imported = subsDateMs(r.importedAt);
  final fresh = imported > 0 && nowMs - imported <= 24 * 3600000;
  final age = imported > 0 ? '${subsFromNow(imported, nowMs)}前入库' : '已入库';
  final extra = r.units.length > 1 ? ' · 共 ${r.units.length} 集' : '';
  return HeroSlide(
    subscriptionId: r.subscriptionId,
    media: r.media,
    eyebrow: fresh
        ? '刚刚入库'
        : (r.media.kind == 'tv' ? '新一集' : '新入库'),
    eyebrowTone: subsToneOk,
    detail: _recentLabel(r),
    footnote: '$age$extra',
    progress: 0,
    playArrival: r,
    resumePercent: r.progressPercent ?? 0,
  );
}

String? _weekdayOf(String? day) {
  final d = subsDate(day);
  if (d == null) return null;
  return switch (d.weekday) {
    1 => '周一',
    2 => '周二',
    3 => '周三',
    4 => '周四',
    5 => '周五',
    6 => '周六',
    _ => '周日',
  };
}

double _pipelineProgress(SubscriptionView sub) {
  final p = sub.progress;
  if (p.total <= 0) return 0;
  final v = (p.grabbed + p.downloaded) / p.total;
  return v.clamp(0.0, 1.0);
}

String _recentLabel(RecentArrivalView r) {
  if (r.media.kind != 'tv') {
    final y = r.media.year ?? 0;
    return y > 0 ? '$y · 电影' : '电影';
  }
  final code = 'S${pad2(r.seasonNumber)}E${pad2(r.episodeNumber)}';
  final name = r.episodeName ?? '';
  return name.isNotEmpty ? '$code · $name' : code;
}

// ── 日程 ──

class DayGroup {
  DayGroup({
    required this.subscriptionId,
    required this.title,
    required this.kind,
    required this.arrivals,
  });

  final int subscriptionId;
  final String title;
  final String kind;
  final List<TodayArrivalView> arrivals;

  String label() {
    if (kind != 'tv') return '电影';
    final bySeason = <int, List<int>>{};
    for (final a in arrivals) {
      bySeason.putIfAbsent(a.seasonNumber, () => []).add(a.episodeNumber);
    }
    final seasons = bySeason.keys.toList()..sort();
    return seasons
        .map((s) => 'S${pad2(s)}${episodeRangesText(bySeason[s]!)}')
        .join(' · ');
  }

  /// 组内下载中的平均进度 0..1（仅在有下载器快照时非空）。
  double? liveProgress(Map<String, DownloadTaskView> tasks) {
    final vals = <double>[];
    for (final a in arrivals) {
      if (a.status != 'grabbed') continue;
      final t = taskFor(a, tasks);
      if (t?.progress != null) {
        vals.add(t!.progress!.clamp(0.0, 1.0));
      }
    }
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  /// 整理中的预计可看时刻 ms（组内取最晚）。
  int readyAtMs() {
    var best = 0;
    for (final a in arrivals) {
      if (a.status != 'downloaded') continue;
      final done = subsDateMs(a.downloadedAt);
      if (done > 0 && a.estimatedDownloadToImportMinutes > 0) {
        final ready = done + a.estimatedDownloadToImportMinutes * 60000;
        if (ready > best) best = ready;
      }
    }
    return best;
  }
}

List<DayGroup> dayGroups(List<TodayArrivalView> today, int daysAhead) {
  final out = <DayGroup>[];
  final ids = <int>[];
  for (final item in today) {
    if (item.daysAhead != daysAhead) continue;
    final at = ids.indexOf(item.subscriptionId);
    if (at < 0) {
      ids.add(item.subscriptionId);
      out.add(
        DayGroup(
          subscriptionId: item.subscriptionId,
          title: item.mediaTitle,
          kind: item.mediaKind,
          arrivals: [item],
        ),
      );
    } else {
      out[at].arrivals.add(item);
    }
  }
  return out;
}

ArrivalPresentation groupPresentation(
  DayGroup g,
  Map<String, int> etas,
  int nowMs, {
  Map<String, DownloadTaskView> tasks = const {},
}) {
  ArrivalPresentation? blocking;
  for (final item in g.arrivals) {
    final pres = arrivalPresentation(
      item,
      etaSecondsFor(item, etas),
      nowMs,
      task: taskFor(item, tasks),
    );
    if (blocking == null ||
        pres.stageOrder < blocking.stageOrder ||
        (pres.stageOrder == blocking.stageOrder &&
            pres.estimatedAt > blocking.estimatedAt)) {
      blocking = pres;
    }
  }
  return blocking ?? const ArrivalPresentation('预计入库');
}

String groupTime(
  DayGroup g,
  Map<String, int> etas,
  int nowMs, {
  Map<String, DownloadTaskView> tasks = const {},
}) {
  final pres = groupPresentation(g, etas, nowMs, tasks: tasks);
  if (pres.statusLabel == '整理中') {
    final ready = g.readyAtMs();
    return ready > nowMs ? arrivalClockText(ready) : '即将';
  }
  if (pres.statusLabel == '下载中' && pres.estimatedAt <= 0) return '稍后';
  return pres.estimatedAt > 0 ? arrivalClockText(pres.estimatedAt) : '待定';
}

int siteTodayMs(List<TodayArrivalView> today) {
  if (today.isEmpty) return DateTime.now().millisecondsSinceEpoch;
  final anchor = subsDate(today.first.expectedDay);
  if (anchor == null) return DateTime.now().millisecondsSinceEpoch;
  return anchor.millisecondsSinceEpoch - today.first.daysAhead * 86400000;
}

class ScheduleDay {
  ScheduleDay({
    required this.daysAhead,
    required this.count,
    required this.dateMs,
  });

  final int daysAhead;
  final int count;
  final int dateMs;

  String get weekday {
    if (daysAhead == 0) return '今天';
    return switch (DateTime.fromMillisecondsSinceEpoch(dateMs).weekday) {
      1 => '周一',
      2 => '周二',
      3 => '周三',
      4 => '周四',
      5 => '周五',
      6 => '周六',
      _ => '周日',
    };
  }

  String get dateLabel => mmdd(DateTime.fromMillisecondsSinceEpoch(dateMs));

  int get dayNumber => DateTime.fromMillisecondsSinceEpoch(dateMs).day;
}

List<ScheduleDay> scheduleDays(List<TodayArrivalView> today) {
  final start = siteTodayMs(today);
  final n = DateTime.fromMillisecondsSinceEpoch(start);
  final dayStart = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  final hasDay7 = today.any((t) => t.daysAhead == 7);
  final count = hasDay7 ? 8 : 7;
  return [
    for (var d = 0; d < count; d++)
      ScheduleDay(
        daysAhead: d,
        count: dayGroups(today, d).length,
        dateMs: dayStart + d * 86400000,
      ),
  ];
}

// ── 横滑行/海报墙共用的 Shelf 口径（SubsHome） ──

class ShelfStanding {
  const ShelfStanding(
    this.phase, {
    this.rank = 0,
    this.chipText,
    this.chipColor,
  });

  final String phase; // active / paused / done
  final int rank;
  final String? chipText;
  final Color? chipColor;
}

class ShelfSplit {
  const ShelfSplit(this.active, this.paused, this.done);

  final List<SubscriptionView> active;
  final List<SubscriptionView> paused;
  final List<SubscriptionView> done;

  List<SubscriptionView> get resting => [...paused, ...done];
  List<SubscriptionView> get all => [...active, ...paused, ...done];
}

class SubsHome {
  SubsHome(
    this.subs,
    this.today,
    this.recent,
    this.etas, {
    int? nowMs,
    List<DownloadTaskView> tasks = const [],
  })  : nowMs = nowMs ?? DateTime.now().millisecondsSinceEpoch,
        tasksByHash = {
          for (final t in tasks)
            if (t.infoHash.isNotEmpty) t.infoHash.toLowerCase(): t,
        };

  final List<SubscriptionView> subs;
  final List<TodayArrivalView> today;
  final List<RecentArrivalView> recent;
  final Map<String, int> etas;
  final Map<String, DownloadTaskView> tasksByHash;
  final int nowMs;

  DateTime get now => DateTime.fromMillisecondsSinceEpoch(nowMs);

  SubscriptionView? subById(int id) {
    for (final s in subs) {
      if (s.id == id) return s;
    }
    return null;
  }

  RecentArrivalView? recentOf(int subscriptionId) {
    for (final r in recent) {
      if (r.subscriptionId == subscriptionId) return r;
    }
    return null;
  }

  int freshCount(SubscriptionView sub) {
    var n = 0;
    for (final r in recent) {
      if (r.subscriptionId != sub.id) continue;
      final imported = subsDateMs(r.importedAt);
      if (imported > 0 && nowMs - imported <= 48 * 3600000) {
        n += r.units.isNotEmpty ? r.units.length : 1;
      }
    }
    return n;
  }

  int? nearestArrivalDays(SubscriptionView sub) {
    int? best;
    for (final a in today) {
      if (a.subscriptionId != sub.id || a.daysAhead < 0) continue;
      if (best == null || a.daysAhead < best) best = a.daysAhead;
    }
    return best;
  }

  int _missingAired(SubscriptionView sub) {
    final seasons = sub.seasonCollection.where((s) => s.seasonNumber > 0).toList();
    if (seasons.isEmpty) return 0;
    final selected = sub.selectedSeasons.where((s) => s > 0).toSet();
    final scoped = selected.isEmpty
        ? [seasons.reduce((a, b) => a.seasonNumber > b.seasonNumber ? a : b)]
        : seasons.where((s) => selected.contains(s.seasonNumber)).toList();
    var missing = 0;
    for (final s in scoped) {
      if (s.airedCount > s.ownedCount) {
        missing += s.airedCount - s.ownedCount;
      }
    }
    return missing;
  }

  ShelfStanding standing(SubscriptionView sub) {
    final p = sub.progress;
    if (sub.status == 'paused') {
      return const ShelfStanding('paused', chipText: '已暂停');
    }
    final isTv = sub.media.kind == 'tv';
    final missing = isTv ? _missingAired(sub) : 0;
    final pending = missing > 0 || p.wanted + p.grabbed + p.downloaded > 0;
    if (p.upgrading > 0 && !pending) {
      return const ShelfStanding(
        'active',
        rank: 8,
        chipText: '洗版中',
        chipColor: subsToneRinse,
      );
    }
    if (p.downloaded > 0) {
      return const ShelfStanding(
        'active',
        rank: 0,
        chipText: '整理中',
        chipColor: subsToneOk,
      );
    }
    if (p.grabbed > 0) {
      return const ShelfStanding(
        'active',
        rank: 0,
        chipText: '下载中',
        chipColor: subsToneInfo,
      );
    }
    final donePhase = !pending &&
        ((!isTv && p.imported > 0) ||
            sub.status == 'completed');
    if (donePhase) {
      return ShelfStanding(
        'done',
        chipText: isTv ? '已收齐' : '已入库',
        chipColor: subsToneOk,
      );
    }
    final fresh = isTv ? freshCount(sub) : 0;
    if (fresh > 0) {
      return ShelfStanding(
        'active',
        rank: 1,
        chipText: fresh > 1 ? '新$fresh集' : '新一集',
        chipColor: subsToneOk,
      );
    }
    final days = nearestArrivalDays(sub);
    if (days != null && days == 0) {
      return const ShelfStanding(
        'active',
        rank: 2,
        chipText: '今天更新',
        chipColor: subsToneToday,
      );
    }
    if (days != null && days == 1) {
      return const ShelfStanding('active', rank: 3, chipText: '明天更新');
    }
    if (isTv && missing > 0) {
      return ShelfStanding(
        'active',
        rank: 5,
        chipText: '缺$missing集',
        chipColor: subsToneWarn,
      );
    }
    if (!isTv) {
      final st = sub.media.status ?? '';
      final released = st.isEmpty ||
          st == 'Released' ||
          st == 'released' ||
          st == 'released_web';
      if (!released) {
        return const ShelfStanding('active', rank: 7, chipText: '未上映');
      }
      return const ShelfStanding(
        'active',
        rank: 5,
        chipText: '找资源中',
        chipColor: subsToneWarn,
      );
    }
    return const ShelfStanding('active', rank: 6);
  }

  String collectionMeta(SubscriptionView sub) {
    final seasons = sub.seasonCollection.where((s) => s.seasonNumber > 0).toList()
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    if (seasons.isEmpty) return '仅追新集';
    final latest = seasons.last;
    if (latest.episodeCount != null &&
        latest.ownedCount >= latest.episodeCount!) {
      final owned = seasons.where((s) => s.ownedCount > 0).length;
      return seasons.length > 1
          ? '已收齐 $owned 季'
          : '已收齐全 ${latest.ownedCount} 集';
    }
    return '第 ${latest.seasonNumber} 季 ${latest.ownedCount}/${latest.episodeCount ?? '?'}';
  }

  String meta(SubscriptionView sub, {String? phase}) {
    final ph = phase ?? standing(sub).phase;
    final isTv = sub.media.kind == 'tv';
    final year = sub.media.year ?? 0;
    final imported = sub.progress.imported;
    if (!isTv) {
      final owned = imported > 0 || ph == 'done';
      if (year <= 0) return owned ? '已入库' : '电影';
      return owned ? '$year · 已入库' : '$year';
    }
    final line = collectionMeta(sub);
    return ph == 'done' ? '已收齐 · $line' : line;
  }

  double seasonProgress(SubscriptionView sub) {
    final seasons = sub.seasonCollection.where((s) => s.seasonNumber > 0).toList();
    if (seasons.isEmpty) return -1;
    final latest = seasons.last;
    final total = latest.episodeCount ?? 0;
    if (total <= 0) return -1;
    return (latest.ownedCount / total).clamp(0.0, 1.0);
  }

  ShelfSplit shelfSplit(String kind) {
    final active = <SubscriptionView>[];
    final paused = <SubscriptionView>[];
    final done = <SubscriptionView>[];
    for (final s in subs) {
      if (s.media.kind != kind) continue;
      switch (standing(s).phase) {
        case 'paused':
          paused.add(s);
        case 'done':
          done.add(s);
        default:
          active.add(s);
      }
    }
    int updatedDesc(SubscriptionView a, SubscriptionView b) {
      final ta = subsDateMs(a.updatedAt), tb = subsDateMs(b.updatedAt);
      if (ta != tb) return tb - ta;
      return a.media.title.compareTo(b.media.title);
    }

    active.sort((a, b) {
      final r = standing(a).rank - standing(b).rank;
      return r != 0 ? r : updatedDesc(a, b);
    });
    paused.sort(updatedDesc);
    done.sort(updatedDesc);
    return ShelfSplit(active, paused, done);
  }

  String countSummary(String kind) {
    final split = shelfSplit(kind);
    final all = split.all.length;
    if (split.active.isEmpty || split.active.length == all) return '共 $all 部';
    return '${split.active.length} 部进行中 · 共 $all 部';
  }

  String restingLabel(String kind) {
    final split = shelfSplit(kind);
    final labels = <String>[];
    if (split.paused.isNotEmpty) labels.add('已暂停');
    if (split.done.isNotEmpty) {
      labels.add(kind == 'tv' ? '已收齐' : '已入库');
    }
    return labels.join('·');
  }
}

int recentFreshCount(RecentArrivalView r, {int? nowMs}) {
  final t = DateTime.tryParse(r.importedAt ?? '');
  if (t == null) return r.units.length;
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  return t.millisecondsSinceEpoch >= now - 48 * 3600000 ? r.units.length : 0;
}

String recentAgeText(RecentArrivalView r, {int? nowMs}) {
  final t = DateTime.tryParse(r.importedAt ?? '');
  if (t == null) return '';
  return subsFromNow(
    t.millisecondsSinceEpoch,
    nowMs ?? DateTime.now().millisecondsSinceEpoch,
  );
}
