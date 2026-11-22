/// 跳过片头 / 片尾规则（P3 纯 Dart 移植）。
///
/// 来源：安卓 `apps/android-core/playback/SkipSegments.kt`
/// （对照 Apple 端 `SkipSegments.swift`；设计见
/// `docs/design/skip-intro.md`）。服务端整季比对认出来的区间随播放
/// 会话下发，客户端只管按播放位置用，不做任何计算。
/// 单元测试见 `test/skip_segments_test.dart`（用例照搬 Kotlin
/// `SkipSegmentsTest.kt` 的关键口径）。
library;

import 'player_page_args.dart';
import 'session/playback_session_api.dart';

/// 跳过片头 / 片尾（[PlaybackSkipSegment] 是会话下发的区间）。
abstract final class SkipSegments {
  /// 离区间尾不足这么多毫秒就不再给「跳过」：按下去只省一两秒，
  /// 还会撞上区间尾的画面切换。
  static const tailMs = 3000;

  /// 自动播下一集的倒计时 8 秒（5 秒来不及反应）。
  static const autoNextMs = 8000;

  /// 连续自动播了这么多集、期间没人碰过播放器，就不再自动播
  /// （人多半睡着了，也别让 NAS 白转一晚上）。
  static const autoNextMaxStreak = 3;

  /// 最后这么多毫秒兜底给「下一集」卡片（只提示，不倒计时）。
  static const upNextTailMs = 40000;

  /// 当前位置该给哪个「跳过」按钮；一直放到结尾的片尾交给
  /// 「即将播放」卡片，两者不同时出现。
  static PlaybackSkipSegment? active(
      List<PlaybackSkipSegment>? segments, int positionMs) {
    if (segments == null) return null;
    for (final segment in segments) {
      if (segment.type == 'outro' && segment.toEnd) continue;
      if (positionMs >= segment.startMs &&
          positionMs < segment.endMs - tailMs) {
        return segment;
      }
    }
    return null;
  }

  /// 已经进了一直放到结尾的片尾：「即将播放」卡片不必等到最后 40 秒。
  static bool isInOutro(List<PlaybackSkipSegment>? segments, int positionMs) {
    if (segments == null) return false;
    return segments.any((s) =>
        s.type == 'outro' && s.toEnd && positionMs >= s.startMs);
  }

  /// 卡片要不要倒计时自动播下一集：只在服务端**认出了**一直放到结尾
  /// 的片尾时才倒计时——按「最后 40 秒」猜片尾的话字幕还没放完
  /// 画面就被抢走。[streak] 是连续自动播了几集。
  static bool autoNextArmed(
      List<PlaybackSkipSegment>? segments, int positionMs, int streak) {
    return streak < autoNextMaxStreak && isInOutro(segments, positionMs);
  }

  /// 「已跳过片头 · 撤回」停留多久；「本剧以后自动跳过片头 · 不用」
  /// 同样长，给人时间反悔。
  static const skipNoticeMs = 5000;

  /// 不带按钮的提示（「本剧不再自动跳过片头」）停留多久。
  static const infoNoticeMs = 3000;

  /// 自然播进这一段时直接跳过、还是只给按钮（[active] 已保证离段尾
  /// 超过 [tailMs]）。总开关关了一律只给按钮；广告、预告没人想看，
  /// 直接跳；片头因人因剧而异，[introLearned]（这部剧手动跳过过片头）
  /// 才跳；其他类型（含非结尾片尾、未来类型）不猜，只给按钮。
  static bool autoSkips(
      PlaybackSkipSegment segment, bool enabled, bool introLearned) {
    if (!enabled) return false;
    return switch (segment.type) {
      'ad' || 'preview' => true,
      'intro' => introLearned,
      _ => false,
    };
  }

  /// 跳过后的提示里怎么称呼这一段：「已跳过片头」。
  static String name(PlaybackSkipSegment segment) => switch (segment.type) {
        'intro' => '片头',
        'outro' => '片尾',
        'ad' => '广告',
        'preview' => '预告',
        _ => '此段',
      };

  static String label(PlaybackSkipSegment segment) => switch (segment.type) {
        'intro' => '跳过片头',
        'outro' => '跳过片尾',
        'ad' => '跳过广告',
        'preview' => '跳过预告',
        _ => '跳过此段',
      };

  /// 手动跳过段优先于最后 40 秒的兜底卡片，不能让「下一集」盖住
  /// 「跳过预告」。有没有下一集、关没关卡片由调用方判断。
  static bool shouldShowUpNext(
    List<PlaybackSkipSegment>? segments,
    int positionMs,
    int? durationMs, {
    bool ended = false,
  }) {
    if (ended) return true;
    if (active(segments, positionMs) != null) return false;
    if (isInOutro(segments, positionMs)) return true;
    if (durationMs == null || durationMs <= 0) return false;
    final remaining = durationMs - positionMs;
    return remaining >= 1 && remaining <= upNextTailMs;
  }
}

/// 跳过按钮那个角落的自动跳过提示（§5）：
/// 「已跳过片头 · 撤回」「本剧以后自动跳过片头 · 不用」
/// 「本剧不再自动跳过片头」。
class SkipNotice {
  const SkipNotice(this.id, this.kind, {this.segment});

  final int id;
  final SkipNoticeKind kind;
  final PlaybackSkipSegment? segment;

  String get text => switch (kind) {
        SkipNoticeKind.skipped =>
          '已跳过${segment != null ? SkipSegments.name(segment!) : '此段'}',
        SkipNoticeKind.learned => '本剧以后自动跳过片头',
        SkipNoticeKind.forgot => '本剧不再自动跳过片头',
      };

  int get durationMs => kind == SkipNoticeKind.forgot
      ? SkipSegments.infoNoticeMs
      : SkipSegments.skipNoticeMs;
}

enum SkipNoticeKind { skipped, learned, forgot }

/// 一个播放单元：电影季集都是 0。
class PlaybackUnit {
  const PlaybackUnit({
    required this.mediaItemId,
    required this.season,
    required this.episode,
  });

  final int mediaItemId;
  final int season;
  final int episode;

  bool get isEpisode => season > 0 || episode > 0;
}

/// 换集：只在本季、有在位文件的集里找，缺集跳过；不跨季
/// （同 Apple 端 nextEpisode）。[EpisodeItem.owned]/[EpisodeItem.fileId]
/// 为空即缺集。
/// 与 Kotlin 的一处差别：Kotlin 入参即当季列表（只按集号过滤），
/// Dart 侧入参可能跨季，故显式按 [PlaybackUnit.season] 过滤。
abstract final class EpisodeNavigation {
  static EpisodeItem? next(List<EpisodeItem> episodes, PlaybackUnit unit) {
    if (!unit.isEpisode) return null;
    EpisodeItem? best;
    for (final e in episodes) {
      if (e.season != unit.season) continue;
      if (e.episode > unit.episode && e.owned && e.fileId != null) {
        if (best == null || e.episode < best.episode) best = e;
      }
    }
    return best;
  }

  static EpisodeItem? previous(List<EpisodeItem> episodes, PlaybackUnit unit) {
    if (!unit.isEpisode) return null;
    EpisodeItem? best;
    for (final e in episodes) {
      if (e.season != unit.season) continue;
      if (e.episode < unit.episode && e.owned && e.fileId != null) {
        if (best == null || e.episode > best.episode) best = e;
      }
    }
    return best;
  }
}
