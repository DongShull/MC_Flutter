/// 订阅首页/海报墙共用的展示口径（逐条对齐鸿蒙 subscriptions/SubscriptionsHomeModel.ets）。
/// 纯函数层：不碰 UI，也不发请求；输入是 models.dart 的视图模型。
library;

import 'dart:ui';

import 'models.dart';

// ── 状态色调（对齐鸿蒙 Theme.info/ok/warn 与各 chip 色） ──
const subsToneInfo = Color(0xFF6AA7FF); // 下载中
const subsToneOk = Color(0xFF34C77B); // 整理中 / 新到
const subsToneWarn = Color(0xFFF5B84C); // 等待资源 / 找资源中
const subsToneRinse = Color(0xFF5EEAD4); // 洗版中
const subsToneToday = Color(0xFFA78BFA); // 今天更新

// ── 时间小工具 ──

DateTime? subsDate(String? s) =>
    (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

int subsDateMs(String? s) => subsDate(s)?.millisecondsSinceEpoch ?? 0;

String pad2(int v) => v < 10 ? '0$v' : '$v';

/// HH:mm（议程左列与 ETA 时刻）。
String arrivalClockText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${pad2(d.hour)}:${pad2(d.minute)}';
}

String mmdd(DateTime d) => '${d.month}月${d.day}日';

/// 预计入库时刻：同日「约 HH:mm」/ 明日 / M月D日 HH:mm。
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

/// 多久之前（只给量词，调用方拼「入库」等）。
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

// ── 到达展示（ArrivalPresentation + arrivalPresentation 状态机） ──

class ArrivalPresentation {
  const ArrivalPresentation(this.statusLabel,
      [this.timeLabel = '', this.estimatedAt = 0]);

  final String statusLabel;
  final String timeLabel;
  final int estimatedAt;

  bool get glows => statusLabel == '下载中' || statusLabel == '整理中';

  /// 排序权重：整理中(2) > 下载中(1) > 其余(0)。
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

/// 下载任务 ETA（秒）；拿不到时回退估算的下载→入库分钟。
int? etaSecondsFor(TodayArrivalView item, Map<String, int> etas) {
  final hash = item.infoHash;
  if (hash != null && hash.isNotEmpty) {
    final v = etas[hash.toLowerCase()];
    if (v != null) return v;
  }
  return null;
}

/// 单个到达的状态机：downloaded→整理中；grabbed→下载中(+ETA)；
/// 其余用出种预测 → 预计入库；再退「等待资源」+ 待定文案。
ArrivalPresentation arrivalPresentation(
    TodayArrivalView item, int? etaSeconds, int nowMs) {
  final relMin = item.estimatedReleaseToImportMinutes;
  switch (item.status) {
    case 'downloaded':
      return const ArrivalPresentation('整理中');
    case 'grabbed':
      final etaSec = etaSeconds ??
          (item.estimatedDownloadToImportMinutes > 0
              ? item.estimatedDownloadToImportMinutes * 60
              : null);
      final at = etaSec != null ? nowMs + (etaSec + relMin * 60) * 1000 : 0;
      return ArrivalPresentation(
          '下载中', at > 0 ? formatEstimated(at, nowMs) : '稍后', at);
    default:
      final f = item.forecast;
      if (f != null && f.usable) {
        final at = subsDateMs(f.predictedAt);
        if (at > 0) {
          return ArrivalPresentation('预计入库', formatEstimated(at, nowMs), at);
        }
      }
      if (item.daysAhead > 0 && (item.expectedDay ?? '').isNotEmpty) {
        final day = subsDate(item.expectedDay)!;
        return ArrivalPresentation('等待资源', '${mmdd(day)} 播出');
      }
      final probe = subsDateMs(item.nextProbeAt);
      if (probe > nowMs) {
        return ArrivalPresentation('等待资源', '${arrivalClockText(probe)} 探测');
      }
      return const ArrivalPresentation('等待资源', '时间待更新');
  }
}

// ── Hero ──

/// 同一部剧的一条「正在发生」聚合（按订阅分桶后的 blocking 展示）。
class HeroGroup {
  HeroGroup({
    required this.subscriptionId,
    required this.arrival,
    required this.presentation,
    required this.daysAhead,
  });

  final int subscriptionId;
  final TodayArrivalView arrival;
  final ArrivalPresentation presentation;
  final int daysAhead;
}

/// 按 (订阅 + days_ahead) 分桶，桶内取 blocking presentation，保留首次出现顺序。
List<HeroGroup> heroGroups(
  List<TodayArrivalView> today,
  Map<String, int> etas,
  int nowMs,
) {
  final out = <HeroGroup>[];
  final ids = <int>[];
  for (final item in today) {
    if (item.daysAhead < 0) continue;
    final at = ids.indexOf(item.subscriptionId);
    if (at < 0) {
      ids.add(item.subscriptionId);
      out.add(HeroGroup(
        subscriptionId: item.subscriptionId,
        arrival: item,
        presentation:
            arrivalPresentation(item, etaSecondsFor(item, etas), nowMs),
        daysAhead: item.daysAhead,
      ));
    } else {
      // 同订阅取天数更近的一条
      if (item.daysAhead < out[at].daysAhead) {
        out[at] = HeroGroup(
          subscriptionId: item.subscriptionId,
          arrival: item,
          presentation:
              arrivalPresentation(item, etaSecondsFor(item, etas), nowMs),
          daysAhead: item.daysAhead,
        );
      }
    }
  }
  return out;
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
    this.playable = false,
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
  final bool playable;
  final int resumePercent;
}

bool heroClockIsNumeric(String clock) => clock.contains(RegExp(r'[0-9]'));

/// 轮播取片顺序：正在发生（整理中>下载中）→ 刚到(≤48h) → 今天 → 更早入库 →
/// 预告；一部一张、上限 5；全空退回「在追前 3」的歇着版式。
List<HeroSlide> buildHeroSlides(SubsHome home, int nowMs) {
  final used = <int>{};
  final slides = <HeroSlide>[];

  void push(HeroSlide s) {
    if (used.contains(s.subscriptionId) || slides.length >= 5) return;
    used.add(s.subscriptionId);
    slides.add(s);
  }

  // 1) 正在发生
  final groups = [...heroGroups(home.today, home.etas, nowMs)]..sort((a, b) {
      final pa = a.presentation.stageOrder, pb = b.presentation.stageOrder;
      if (pa != pb) return pb - pa; // 整理中在前
      return a.presentation.estimatedAt - b.presentation.estimatedAt;
    });
  for (final g in groups) {
    final sub = home.subById(g.subscriptionId);
    if (sub == null) continue;
    final pres = g.presentation;
    final clock = pres.estimatedAt > 0
        ? formatEstimated(pres.estimatedAt, nowMs)
        : g.daysAhead == 0
            ? '今天更新'
            : g.daysAhead == 1
                ? '明天更新'
                : '${g.daysAhead}天后更新';
    push(HeroSlide(
      subscriptionId: g.subscriptionId,
      media: sub.media,
      eyebrow: pres.statusLabel,
      eyebrowTone: pres.tone,
      clockLabel: _episodeLabel(g.arrival),
      clock: clock,
      progress: _pipelineProgress(sub),
      playable: home.recentOf(g.subscriptionId) != null,
      resumePercent: home.recentOf(g.subscriptionId)?.progressPercent ?? 0,
    ));
  }

  // 2) 刚到（≤48h）
  for (final r in home.recent) {
    final imported = subsDateMs(r.importedAt);
    if (imported <= 0 || nowMs - imported > 48 * 3600000) continue;
    if (used.contains(r.subscriptionId)) continue;
    final sub = home.subById(r.subscriptionId);
    push(_recentSlide(sub, r));
  }

  // 3) 今天/预告（不在途的）
  for (final g in groups) {
    if (used.contains(g.subscriptionId)) continue;
    final sub = home.subById(g.subscriptionId);
    if (sub == null || g.presentation.glows) continue;
    final pres = g.presentation;
    push(HeroSlide(
      subscriptionId: g.subscriptionId,
      media: sub.media,
      eyebrow: home.standing(sub).chipText ?? '追踪中',
      eyebrowTone: home.standing(sub).chipColor,
      clockLabel: _episodeLabel(g.arrival),
      clock:
          pres.estimatedAt > 0 ? formatEstimated(pres.estimatedAt, nowMs) : '',
      detail: pres.estimatedAt > 0 ? '' : pres.timeLabel,
      footnote: home.meta(sub),
      progress: _pipelineProgress(sub),
      playable: home.recentOf(g.subscriptionId) != null,
      resumePercent: home.recentOf(g.subscriptionId)?.progressPercent ?? 0,
    ));
  }

  // 4) 更早的入库
  for (final r in home.recent) {
    if (used.contains(r.subscriptionId)) continue;
    push(_recentSlide(home.subById(r.subscriptionId), r));
  }

  // 5) 全空：在追前 3 的歇着版式
  if (slides.isEmpty) {
    for (final sub in home.shelfSplit('tv').active.take(3)) {
      final st = home.standing(sub);
      push(HeroSlide(
        subscriptionId: sub.id,
        media: sub.media,
        eyebrow: st.chipText ?? '追踪中',
        eyebrowTone: st.chipColor,
        detail: home.meta(sub),
        footnote: home.collectionMeta(sub),
      ));
    }
    for (final sub in home.shelfSplit('movie').active) {
      if (slides.length >= 3) break;
      final st = home.standing(sub);
      push(HeroSlide(
        subscriptionId: sub.id,
        media: sub.media,
        eyebrow: st.chipText ?? '追踪中',
        eyebrowTone: st.chipColor,
        detail: home.meta(sub),
        footnote: home.collectionMeta(sub),
      ));
    }
  }
  return slides;
}

HeroSlide _recentSlide(SubscriptionView? sub, RecentArrivalView r) => HeroSlide(
      subscriptionId: r.subscriptionId,
      media: r.media,
      eyebrow: '刚刚入库',
      eyebrowTone: subsToneOk,
      clockLabel: _recentLabel(r),
      clock: r.importedAt != null
          ? subsFromNow(
              subsDateMs(r.importedAt), DateTime.now().millisecondsSinceEpoch)
          : '',
      progress: 0,
      playable: true,
      resumePercent: r.progressPercent ?? 0,
    );

double _pipelineProgress(SubscriptionView sub) {
  final p = sub.progress;
  if (p.total <= 0) return 0;
  final v = (p.grabbed + p.downloaded) / p.total;
  return v.clamp(0.0, 1.0);
}

String _episodeLabel(TodayArrivalView a) {
  if (a.mediaKind != 'tv') return '电影';
  return 'S${pad2(a.seasonNumber)}E${pad2(a.episodeNumber)}';
}

String _recentLabel(RecentArrivalView r) {
  if (r.media.kind != 'tv') {
    final y = r.media.year ?? 0;
    return y > 0 ? '$y  ·  电影' : '电影';
  }
  final code = 'S${pad2(r.seasonNumber)}E${pad2(r.episodeNumber)}';
  final name = r.episodeName ?? '';
  return name.isNotEmpty ? '$code  ·  $name' : code;
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

  /// 议程行第二行：单集「SxxExx · 名」，多集「N 集」。
  String label() {
    if (kind != 'tv') return '电影';
    if (arrivals.length == 1) {
      final a = arrivals.first;
      return 'S${pad2(a.seasonNumber)}E${pad2(a.episodeNumber)}';
    }
    return '${arrivals.length} 集';
  }
}

/// 当天议程：按订阅合并（保留首次出现顺序）。
List<DayGroup> dayGroups(List<TodayArrivalView> today, int daysAhead) {
  final out = <DayGroup>[];
  final ids = <int>[];
  for (final item in today) {
    if (item.daysAhead != daysAhead) continue;
    final at = ids.indexOf(item.subscriptionId);
    if (at < 0) {
      ids.add(item.subscriptionId);
      out.add(DayGroup(
        subscriptionId: item.subscriptionId,
        title: item.mediaTitle,
        kind: item.mediaKind,
        arrivals: [item],
      ));
    } else {
      out[at].arrivals.add(item);
    }
  }
  return out;
}

/// 组内「最卡的那一步」：stageOrder 大者赢，同 order 取 estimatedAt 大者。
ArrivalPresentation groupPresentation(
    DayGroup g, Map<String, int> etas, int nowMs) {
  ArrivalPresentation? blocking;
  for (final item in g.arrivals) {
    final pres = arrivalPresentation(item, etaSecondsFor(item, etas), nowMs);
    if (blocking == null ||
        pres.stageOrder > blocking.stageOrder ||
        (pres.stageOrder == blocking.stageOrder &&
            pres.estimatedAt > blocking.estimatedAt)) {
      blocking = pres;
    }
  }
  return blocking ?? const ArrivalPresentation('预计入库');
}

/// 议程左列时刻：整理中→「即将」、下载中无ETA→「稍后」、有预计→HH:mm、否则「待定」。
String groupTime(DayGroup g, Map<String, int> etas, int nowMs) {
  final pres = groupPresentation(g, etas, nowMs);
  if (pres.statusLabel == '整理中') return '即将';
  if (pres.statusLabel == '下载中' && pres.estimatedAt <= 0) return '稍后';
  return pres.estimatedAt > 0 ? arrivalClockText(pres.estimatedAt) : '待定';
}

/// 站点日历「今天」00:00（本地日历）：由任一到达的 expected_day 反推。
int siteTodayMs(List<TodayArrivalView> today) {
  if (today.isEmpty) return 0;
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

  String get weekday =>
      switch (DateTime.fromMillisecondsSinceEpoch(dateMs).weekday) {
        1 => '周一',
        2 => '周二',
        3 => '周三',
        4 => '周四',
        5 => '周五',
        6 => '周六',
        _ => '周日',
      };

  String get dateLabel => mmdd(DateTime.fromMillisecondsSinceEpoch(dateMs));

  int get dayNumber => DateTime.fromMillisecondsSinceEpoch(dateMs).day;
}

/// 七天日期条：count 按合并后的组数算。
List<ScheduleDay> scheduleDays(List<TodayArrivalView> today) {
  final start = siteTodayMs(today);
  final n = DateTime.fromMillisecondsSinceEpoch(start);
  final dayStart = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  return [
    for (var d = 0; d < 7; d++)
      ScheduleDay(
        daysAhead: d,
        count: dayGroups(today, d).length,
        dateMs: dayStart + d * 86400000,
      ),
  ];
}

// ── 横滑行/海报墙共用的 Shelf 口径（SubsHome） ──

class ShelfStanding {
  const ShelfStanding(this.phase,
      {this.rank = 0, this.chipText, this.chipColor});

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

  List<SubscriptionView> get all => [...active, ...paused, ...done];
}

class SubsHome {
  SubsHome(this.subs, this.today, this.recent, this.etas, {int? nowMs})
      : nowMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;

  final List<SubscriptionView> subs;
  final List<TodayArrivalView> today;
  final List<RecentArrivalView> recent;
  final Map<String, int> etas;
  final int nowMs;

  DateTime get now => DateTime.fromMillisecondsSinceEpoch(nowMs);

  SubscriptionView? subById(int id) {
    for (final s in subs) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 最近一条入库（可播入口）；没有返回 null。
  RecentArrivalView? recentOf(int subscriptionId) {
    for (final r in recent) {
      if (r.subscriptionId == subscriptionId) return r;
    }
    return null;
  }

  /// 48h 内新到的集数（「新 N 集」chip）。
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

  /// 最近一次预计到达还有几天（没有 → null）。
  int? nearestArrivalDays(SubscriptionView sub) {
    int? best;
    for (final a in today) {
      if (a.subscriptionId != sub.id || a.daysAhead < 0) continue;
      if (best == null || a.daysAhead < best) best = a.daysAhead;
    }
    return best;
  }

  int _airedShort(SubscriptionView sub) {
    var aired = 0;
    for (final s in sub.seasonCollection) {
      aired += s.airedCount;
    }
    return aired;
  }

  /// 状态口径（对应鸿蒙 standing）：phase + chip 文案/色 + 横滑排序权重。
  ShelfStanding standing(SubscriptionView sub) {
    final p = sub.progress;
    if (sub.status == 'paused') {
      return const ShelfStanding('paused', chipText: '已暂停');
    }
    final isTv = sub.media.kind == 'tv';
    final total = p.total;
    final donePhase =
        sub.status == 'completed' && p.upgrading == 0 && !sub.followFuture;
    if (p.downloaded > 0) {
      return ShelfStanding(donePhase ? 'done' : 'active',
          rank: 0, chipText: '整理中', chipColor: subsToneOk);
    }
    if (p.grabbed > 0) {
      return ShelfStanding(donePhase ? 'done' : 'active',
          rank: 0, chipText: '下载中', chipColor: subsToneInfo);
    }
    final collected = total > 0 && p.imported >= total;
    if (collected && p.upgrading > 0) {
      return ShelfStanding(donePhase ? 'done' : 'active',
          rank: 4, chipText: '洗版中', chipColor: subsToneRinse);
    }
    if (donePhase) {
      return ShelfStanding('done',
          chipText: isTv ? '已收齐' : '已入库', chipColor: subsToneOk);
    }
    final fresh = isTv ? freshCount(sub) : 0;
    if (fresh > 0) {
      return ShelfStanding('active',
          rank: 1,
          chipText: fresh > 1 ? '新$fresh集' : '新一集',
          chipColor: subsToneOk);
    }
    final days = nearestArrivalDays(sub);
    if (days != null && days == 0) {
      return const ShelfStanding('active',
          rank: 2, chipText: '今天更新', chipColor: subsToneToday);
    }
    if (days != null && days == 1) {
      return const ShelfStanding('active', rank: 3, chipText: '明天更新');
    }
    if (p.upgrading > 0) {
      return const ShelfStanding('active',
          rank: 4, chipText: '洗版中', chipColor: subsToneRinse);
    }
    if (isTv && p.wanted > 0 && _airedShort(sub) > 0) {
      return ShelfStanding('active',
          rank: 2, chipText: '缺${p.wanted}集', chipColor: subsToneWarn);
    }
    if (!isTv) {
      final released =
          sub.media.status == 'released' || sub.media.status == 'released_web';
      if (!released) {
        return const ShelfStanding('active', rank: 5, chipText: '未上映');
      }
      return const ShelfStanding('active',
          rank: 2, chipText: '找资源中', chipColor: subsToneWarn);
    }
    return const ShelfStanding('active', rank: 5);
  }

  /// 剧集的合集一句话：第 N 季 owned/total / 已收齐 N 季 / 已收齐全 N 集。
  String collectionMeta(SubscriptionView sub) {
    final seasons = sub.seasonCollection;
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

  /// 卡片第二行（对应鸿蒙 subsHome.meta）。
  String meta(SubscriptionView sub, {String? phase}) {
    final ph = phase ?? standing(sub).phase;
    final isTv = sub.media.kind == 'tv';
    final year = sub.media.year ?? 0;
    final imported = sub.progress.imported;
    if (!isTv) {
      final owned = imported > 0 || ph == 'done';
      return owned ? '$year · 已入库' : '$year';
    }
    final line = collectionMeta(sub);
    return ph == 'done' ? '已收齐 · $line' : line;
  }

  /// 最新季进度（0~1；-1 = 没有可算的）。
  double seasonProgress(SubscriptionView sub) {
    final seasons = sub.seasonCollection;
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

    active.sort((a, b) => standing(a).rank - standing(b).rank);
    paused.sort(updatedDesc);
    done.sort(updatedDesc);
    return ShelfSplit(active, paused, done);
  }

  String countSummary(String kind) {
    final split = shelfSplit(kind);
    final all = split.all.length;
    if (split.active.isEmpty) return '共 $all 部';
    return '${split.active.length} 部进行中 · 共 $all 部';
  }

  /// 横滑行歇着区分隔的竖排小字（可同时有暂停与收齐）。
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

/// 刚刚入库条目的「新到」判定：48h 内入库 → units 全算新集；无时间戳按全量新到。
int recentFreshCount(RecentArrivalView r, {int? nowMs}) {
  final t = DateTime.tryParse(r.importedAt ?? '');
  if (t == null) return r.units.length;
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  return t.millisecondsSinceEpoch >= now - 48 * 3600000 ? r.units.length : 0;
}

/// ISO 入库时间的相对文案（刚刚/X分钟/X小时/X天）。
String recentAgeText(RecentArrivalView r, {int? nowMs}) {
  final t = DateTime.tryParse(r.importedAt ?? '');
  if (t == null) return '';
  return subsFromNow(
      t.millisecondsSinceEpoch, nowMs ?? DateTime.now().millisecondsSinceEpoch);
}
