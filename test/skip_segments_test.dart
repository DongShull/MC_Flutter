import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/player/player_page_args.dart';
import 'package:mc_flutter/core/player/session/playback_session_api.dart';
import 'package:mc_flutter/core/player/skip_segments.dart';

/// 用例照搬 Kotlin `SkipSegmentsTest.kt`（与 Apple 端 / web 同一组用例）。
PlaybackSkipSegment seg(String type, int start, int end,
        {bool toEnd = false}) =>
    PlaybackSkipSegment(type: type, startMs: start, endMs: end, toEnd: toEnd);

void main() {
  final ad = seg('ad', 0, 20000);
  final intro = seg('intro', 60000, 150000);
  final credits = seg('outro', 2550000, 2700000, toEnd: true);
  final midOutro = seg('outro', 2400000, 2500000);

  test('片头区间内给跳过片头，区间外不给', () {
    expect(SkipSegments.active([intro], 59999), isNull);
    expect(SkipSegments.active([intro], 60000), intro);
    expect(
        SkipSegments.label(SkipSegments.active([intro], 100000)!), '跳过片头');
    expect(SkipSegments.active([intro], 150000), isNull);
  });

  test('离段尾不足 3 秒不再给跳过', () {
    expect(
        SkipSegments.active([intro], 150000 - SkipSegments.tailMs - 1),
        intro);
    expect(
        SkipSegments.active([intro], 150000 - SkipSegments.tailMs), isNull);
  });

  test('标签按类型走，未知类型只给“跳过此段”', () {
    expect(SkipSegments.label(SkipSegments.active([ad, intro], 5000)!),
        '跳过广告');
    expect(SkipSegments.label(seg('preview', 0, 20000)), '跳过预告');
    expect(SkipSegments.label(seg('other', 0, 20000)), '跳过此段');
    expect(SkipSegments.label(seg('future-type', 0, 20000)), '跳过此段');
    expect(
        SkipSegments.label(
            SkipSegments.active([midOutro], 2450000)!),
        '跳过片尾');
  });

  test('自动连播只在认出的片尾倒计时，连续 3 集后停', () {
    expect(SkipSegments.autoNextMs, 8000);
    expect(SkipSegments.autoNextArmed([credits], 2549999, 0), isFalse);
    expect(SkipSegments.autoNextArmed([credits], 2560000, 0), isTrue);
    expect(
        SkipSegments.autoNextArmed(
            [credits], 2560000, SkipSegments.autoNextMaxStreak - 1),
        isTrue);
    expect(
        SkipSegments.autoNextArmed(
            [credits], 2560000, SkipSegments.autoNextMaxStreak),
        isFalse);
    expect(SkipSegments.autoNextArmed([midOutro], 2450000, 0), isFalse);
    expect(SkipSegments.autoNextArmed(null, 2690000, 0), isFalse);
  });

  test('一直放到结尾的片尾进 UpNext 卡片，不给跳过按钮', () {
    expect(SkipSegments.active([credits], 2600000), isNull);
    expect(SkipSegments.isInOutro([credits], 2549999), isFalse);
    expect(SkipSegments.isInOutro([credits], 2550000), isTrue);
    expect(SkipSegments.isInOutro([midOutro], 2450000), isFalse);
  });

  test('广告/预告/其他段即使 toEnd 也不自动连播', () {
    for (final type in ['ad', 'preview', 'other']) {
      final value = seg(type, 2550000, 2700000, toEnd: true);
      expect(SkipSegments.active([value], 2600000), value);
      expect(SkipSegments.autoNextArmed([value], 2600000, 0), isFalse);
    }
  });

  test('广告与片头分开：中间的剧情段不给跳过', () {
    expect(SkipSegments.active([ad, intro], 5000)?.endMs, 20000);
    expect(SkipSegments.active([ad, intro], 30000), isNull);
    expect(SkipSegments.active([ad, intro], 70000)?.endMs, 150000);
  });

  test('手动跳过段优先于最后 40 秒的兜底卡片', () {
    for (final type in ['preview', 'ad', 'outro', 'other']) {
      final value = seg(type, 2660000, 2690000);
      expect(
          SkipSegments.shouldShowUpNext([value], 2670000, 2700000),
          isFalse);
      expect(
          SkipSegments.shouldShowUpNext([value], 2690000, 2700000),
          isTrue);
      expect(
          SkipSegments.shouldShowUpNext([value], 2700000, 2700000,
              ended: true),
          isTrue);
    }
    expect(SkipSegments.shouldShowUpNext([], 2670000, 2700000), isTrue);
    expect(
        SkipSegments.shouldShowUpNext([credits], 2600000, 2700000),
        isTrue);
  });

  test('最后 40 秒兜底窗口边界', () {
    expect(SkipSegments.shouldShowUpNext(null, 2659999, 2700000), isFalse);
    expect(SkipSegments.shouldShowUpNext(null, 2660000, 2700000), isTrue);
    // 剩 0 不算（播完由 ended 管）；片长未知不给。
    expect(SkipSegments.shouldShowUpNext(null, 2700000, 2700000), isFalse);
    expect(SkipSegments.shouldShowUpNext(null, 2690000, null), isFalse);
  });

  test('自动跳过规则：广告/预告直接跳；片头要学过才跳；其他只给按钮', () {
    expect(SkipSegments.autoSkips(ad, true, false), isTrue);
    expect(SkipSegments.autoSkips(seg('preview', 0, 1), true, false),
        isTrue);
    expect(SkipSegments.autoSkips(intro, true, true), isTrue);
    expect(SkipSegments.autoSkips(intro, true, false), isFalse);
    expect(SkipSegments.autoSkips(midOutro, true, true), isFalse);
    expect(SkipSegments.autoSkips(seg('other', 0, 1), true, false), isFalse);
    expect(SkipSegments.autoSkips(ad, false, false), isFalse);
  });

  test('跳过提示文案与停留时长', () {
    const notice =
        SkipNotice(1, SkipNoticeKind.skipped, segment: null);
    expect(notice.text, '已跳过此段');
    expect(notice.durationMs, SkipSegments.skipNoticeMs);
    expect(
        const SkipNotice(2, SkipNoticeKind.learned).text,
        '本剧以后自动跳过片头');
    expect(
        const SkipNotice(3, SkipNoticeKind.forgot).text,
        '本剧不再自动跳过片头');
    expect(
        const SkipNotice(3, SkipNoticeKind.forgot).durationMs,
        SkipSegments.infoNoticeMs);
    expect(
        SkipNotice(4, SkipNoticeKind.skipped, segment: intro).text,
        '已跳过片头');
  });

  test('换集：只在本季、有在位文件的集里找，缺集跳过，不跨季', () {
    EpisodeItem ep(int season, int n,
            {bool owned = true, int? fileId = 1}) =>
        EpisodeItem(
            season: season, episode: n, name: 'E$n', owned: owned,
            fileId: fileId);
    final episodes = [
      ep(1, 1),
      ep(1, 2, owned: false),
      ep(1, 3, fileId: null),
      ep(1, 4),
      ep(2, 1),
    ];
    const unit = PlaybackUnit(mediaItemId: 7, season: 1, episode: 1);
    expect(EpisodeNavigation.next(episodes, unit)?.episode, 4);
    expect(EpisodeNavigation.previous(episodes, unit), isNull);
    const unit4 = PlaybackUnit(mediaItemId: 7, season: 1, episode: 4);
    expect(EpisodeNavigation.previous(episodes, unit4)?.episode, 1);
    // 电影（季集都是 0）不换集。
    const movie = PlaybackUnit(mediaItemId: 7, season: 0, episode: 0);
    expect(EpisodeNavigation.next(episodes, movie), isNull);
  });

  test('缺失 segments 时什么都不给', () {
    expect(SkipSegments.active(null, 1000), isNull);
    expect(SkipSegments.active([], 1000), isNull);
    expect(SkipSegments.isInOutro(null, 1000), isFalse);
  });
}
