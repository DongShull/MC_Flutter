import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/l10n/mc_l10n.dart';
import 'package:mc_flutter/core/navigation/external_media_link.dart';
import 'package:mc_flutter/features/detail/state/detail_controller.dart';
import 'package:mc_flutter/features/library/routes.dart';
import 'package:mc_flutter/features/library/state/library_detail_controller.dart';
import 'package:mc_flutter/features/notices/state/models.dart';
import 'package:mc_flutter/features/player/widgets/player_bottom_controls.dart';
import 'package:mc_flutter/features/player/widgets/player_gesture_layer.dart';

void main() {
  group('P0 交互回归测试', () {
    test('LibraryDetailArg 非空 query 键序无关且 hashCode 稳定（防止 Riverpod 无限重建）', () {
      const a = LibraryDetailArg(
        libraryId: 7,
        initialQuery: {'actor': '42', 'sort': 'title', 'order': 'asc'},
      );
      const b = LibraryDetailArg(
        libraryId: 7,
        initialQuery: {'order': 'asc', 'actor': '42', 'sort': 'title'},
      );
      const c = LibraryDetailArg(
        libraryId: 7,
        initialQuery: {'actor': '99', 'sort': 'title', 'order': 'asc'},
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('parseLibraryManageTab 同时兼容命名与数字参数', () {
      expect(parseLibraryManageTab('libraries'), 0);
      expect(parseLibraryManageTab('issues'), 1);
      expect(parseLibraryManageTab('duplicates'), 2);
      expect(parseLibraryManageTab('trash'), 3);
      expect(parseLibraryManageTab('shares'), 4);
      expect(parseLibraryManageTab('2'), 2);
      expect(parseLibraryManageTab('99'), 4);
      expect(parseLibraryManageTab(null), 0);
    });

    test('Notice 与 AppWebPathResolver 正确路由 ingest / plugins / account-devices', () {
      final ingestNotice = Notice.fromJson({
        'id': 1,
        'source': 'ingest',
        'kind': 'warn',
        'title': '导入监控异常',
      });
      final pluginNotice = Notice.fromJson({
        'id': 2,
        'source': 'plugins',
        'kind': 'info',
        'title': '插件更新',
      });

      expect(
        ingestNotice.resolveWebHref(),
        '/settings/downloaders?section=import-watch',
      );
      expect(
        pluginNotice.resolveWebHref(),
        '/settings/plugins?tab=builtin',
      );
      expect(
        AppWebPathResolver.resolve('/account/devices'),
        '/settings/devices',
      );
      expect(
        AppWebPathResolver.resolve('/settings/import-watch'),
        '/settings/downloaders?section=import-watch',
      );
    });

    test('DetailState 默认 loading=true 防止详情页首帧黑屏闪烁', () {
      const state = DetailState();
      expect(state.loading, isTrue);
    });

    test('McL10n 切换英文后导航/设置/切换提示即时翻译', () {
      final zh = McL10n.forLocale(const Locale('zh', 'CN'));
      final en = McL10n.forLocale(const Locale('en'));
      expect(zh.settingsTitle, isNot(en.settingsTitle));
      expect(zh.settingsLanguagePageTitle, isNot(en.settingsLanguagePageTitle));
      expect(
        zh.languageSwitched('English'),
        isNot(en.languageSwitched('English')),
      );
    });

    testWidgets('PlayerBottomControls 在 360px 竖屏手机宽度下零溢出', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: PlayerBottomControls(
                  isEpisode: true,
                  hasNext: true,
                  onNext: () {},
                  onEpisodes: () {},
                  onCast: () {},
                  speed: 1.25,
                  onPickSpeed: (_) {},
                  onNotice: (_) {},
                  onPickAudio: (_) {},
                  onPickSubtitle: (_) {},
                  showOrientationToggle: true,
                  isLandscape: false,
                  onToggleOrientation: () {},
                  onAirPlay: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('1.25'), findsOneWidget);
    });

    testWidgets('PlayerGestureLayer 边缘防误触生效且垂直滑动传累计偏移', (tester) async {
      var scrubStarted = false;
      final deltas = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: PlayerGestureLayer(
                enabled: true,
                canHold: true,
                onTap: () {},
                onDoubleTap: (_) {},
                onScrubStart: () => scrubStarted = true,
                onScrubTo: (_) {},
                onScrubEnd: () {},
                onAdjustStart: (_) {},
                onAdjust: (_, delta) => deltas.add(delta),
                onAdjustEnd: () {},
                onHoldStart: () {},
                onHoldEnd: () {},
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      // 1. 左侧 10dp 边缘内水平滑动应被边缘防误触拦截，不触发快进
      final edgeGesture = await tester.startGesture(const Offset(10, 150));
      await edgeGesture.moveBy(const Offset(60, 0));
      await edgeGesture.up();
      await tester.pump();
      expect(scrubStarted, isFalse);

      // 2. 右半屏垂直向上滑动应传出单调递增的累计 delta（不再二次积分）
      final volGesture = await tester.startGesture(const Offset(320, 200));
      await volGesture.moveBy(const Offset(0, -30));
      await volGesture.moveBy(const Offset(0, -30));
      await volGesture.up();
      await tester.pump();

      expect(deltas, isNotEmpty);
      expect(deltas.last, greaterThan(deltas.first));
      expect(deltas.last, lessThanOrEqualTo(1.0));
    });
  });
}
