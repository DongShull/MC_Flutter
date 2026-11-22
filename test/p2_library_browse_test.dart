// P2 媒体库浏览闭环：收藏夹 / 观看历史 / 媒体库管理三页，
// FakeMcApi 预设数据，验证列表渲染与恢复/清空动作走通 McApi。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/mc_api.dart';
import 'package:mc_flutter/core/api/models.dart';
import 'package:mc_flutter/features/library/pages/favorites_page.dart';
import 'package:mc_flutter/features/library/pages/library_manage_page.dart';
import 'package:mc_flutter/features/library/pages/watch_history_page.dart';

import 'p2_fakes.dart';

void main() {
  late FakeMcApi api;

  setUp(() {
    api = FakeMcApi();
    api.favoritesPage = const FavoritesPageView(
      items: [
        FavoriteItemView(
          mediaItemId: 1,
          kind: 'movie',
          libraryId: 2,
          title: '收藏影片',
          year: 2024,
          rating: 8.5,
        ),
      ],
      total: 1,
    );
    api.historyPage = const PlaybackHistoryView(
      entries: [
        PlaybackLogEntry(
          id: 1,
          memberName: '东叔',
          media: MediaActivityTarget(
            mediaItemId: 3,
            libraryId: 2,
            browsable: true,
            kind: 'movie',
            title: '看过影片',
            year: 2023,
          ),
          client: 'android',
          deviceName: 'Pixel',
          startedAt: '2026-11-22T10:00:00Z',
          watchedMs: 60000,
          progressPercent: 50,
        ),
      ],
      hasMore: false,
    );
    api.trashedData = {
      'items': [
        {
          'key': 'k1',
          'library': {'id': 2, 'name': '电影库'},
          'media_item': {
            'id': 5,
            'title': '待回收影片',
            'year': 2020,
            'kind': 'movie',
          },
          'files': [
            {'id': 11, 'file_name': 'a.mkv', 'size_bytes': 100},
          ],
        },
      ],
    };
    api.duplicatesData = {
      'scan': {
        'status': 'succeeded',
        'percent': 100,
        'scanned_at': '2026-11-22T09:00:00Z',
        'upgrading_units': 0,
        'keep_old_items': 0,
      },
      'tiers': [
        {
          'key': 'safe',
          'label': '放心清',
          'hint': '完全相同的副本',
          'units': 1,
          'files': 2,
          'bytes': 200,
        },
      ],
      'review_groups': [],
      'total_units': 1,
      'total_files': 2,
      'total_bytes': 200,
      'total_items': 1,
      'items': [
        {
          'library': {'id': 2, 'name': '电影库'},
          'media_item': {
            'id': 6,
            'title': '重复影片',
            'year': 2021,
            'kind': 'movie',
          },
          'seasons': [],
        },
      ],
    };
    api.librariesData = const [
      LibraryView(id: 2, name: '电影库', kind: 'movie'),
    ];
  });

  Widget wrap(Widget child) => ProviderScope(
        overrides: [mcApiProvider.overrideWithValue(api)],
        child: MaterialApp(home: child),
      );

  testWidgets('收藏夹列出收藏条目', (tester) async {
    await tester.pumpWidget(wrap(const FavoritesPage()));
    await tester.pumpAndSettle();
    expect(find.text('收藏影片'), findsOneWidget);
    expect(find.text('2024 · ★ 8.5'), findsOneWidget);
    expect(api.requests, contains('favorites'));
  });

  testWidgets('观看历史列出记录与进度', (tester) async {
    await tester.pumpWidget(wrap(const WatchHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('看过影片'), findsOneWidget);
    expect(find.text('2023 · 看到 50%'), findsOneWidget);
    expect(find.text('东叔 · Pixel'), findsOneWidget);
    expect(api.requests, contains('history'));
  });

  testWidgets('观看历史清空：确认后调 DELETE 并变空态', (tester) async {
    await tester.pumpWidget(wrap(const WatchHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('看过影片'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(find.text('清空观看历史'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.text('还没有观看记录'), findsOneWidget);
    expect(api.requests, contains('clear-history'));
  });

  testWidgets('媒体库管理：回收站恢复与重复文件结论', (tester) async {
    await tester.pumpWidget(wrap(const LibraryManagePage()));
    await tester.pumpAndSettle();

    expect(find.text('回收站'), findsOneWidget);
    expect(find.text('待回收影片'), findsOneWidget);
    expect(find.text('重复文件'), findsOneWidget);
    expect(find.text('放心清'), findsOneWidget);
    expect(find.text('重复影片'), findsOneWidget);
    expect(find.text('元数据刷新'), findsOneWidget);
    // 「电影库」在长列表底部（懒加载，首屏不可见）：先滚到它再断言。
    await tester.scrollUntilVisible(find.text('电影库'), 300);
    // 「电影库」精确命中只在元数据刷新区的库名一行；
    // 回收站/重复行里它是拼接字串的一部分，不单独成 Text。
    expect(find.text('电影库'), findsOneWidget);

    // 滚回顶部再点恢复（上面 scrollUntilVisible 已把回收站滚出视口）。
    await tester.scrollUntilVisible(find.text('恢复'), -300);
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(find.text('待回收影片'), findsNothing);
    expect(api.requests, contains('restore'));
  });
}
