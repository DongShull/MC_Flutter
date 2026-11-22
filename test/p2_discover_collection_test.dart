// P2 发现榜单完整列表 + 豆瓣详情来源徽标。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/mc_api.dart';
import 'package:mc_flutter/core/api/models.dart';
import 'package:mc_flutter/features/discover/pages/collection_titles_page.dart';
import 'package:mc_flutter/features/discover/pages/title_detail_page.dart';

import 'p2_fakes.dart';

void main() {
  late FakeMcApi api;

  setUp(() {
    api = FakeMcApi();
    api.collectionTitlesData = const CollectionTitles(
      collection: DiscoveryCollectionInfo(
        collectionRef: 'douban/movie_top250',
        name: '豆瓣 Top250',
        description: '豆瓣评分最高的 250 部电影',
        isRanked: true,
        supportsFullListing: true,
      ),
      titles: [
        DiscoveredTitle(
          titleRef: 'douban:1',
          provider: 'douban',
          externalId: '1',
          mediaType: 'movie',
          title: '肖申克的救赎',
          originalTitle: 'The Shawshank Redemption',
          releaseYear: 1994,
          providerRating: 9.7,
          genres: ['剧情'],
        ),
      ],
      page: 1,
      totalPages: 1,
      totalResults: 1,
    );
  });

  testWidgets('榜单页按服务端顺序显示名次', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mcApiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: CollectionTitlesPage(
            collectionRef: 'douban/movie_top250',
            title: '豆瓣 Top250',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('豆瓣 Top250'), findsOneWidget);
    expect(find.text('豆瓣评分最高的 250 部电影'), findsOneWidget);
    expect(find.text('肖申克的救赎'), findsOneWidget);
    expect(find.text('第 1 名 · 1994 · 剧情'), findsOneWidget);
    expect(api.requests, contains('collection:douban/movie_top250'));
  });

  testWidgets('豆瓣详情显示豆瓣来源徽标', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          titleDetailProvider.overrideWith(_FakeDoubanDetailController.new),
        ],
        child: const MaterialApp(
          home: TitleDetailPage(titleRef: 'douban:1292052'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 标题在 AppBar 与海报卡各出现一次；断言来源徽标与评分只出现一次。
    expect(find.text('肖申克的救赎'), findsWidgets);
    expect(find.text('豆瓣'), findsOneWidget);
    expect(find.text('★ 9.7'), findsOneWidget);
  });
}

/// 不发网络的假控制器：直接给出豆瓣条目的已加载态。
class _FakeDoubanDetailController extends TitleDetailController {
  @override
  TitleDetailState build() => const TitleDetailState(
        loading: false,
        title: '肖申克的救赎',
        overview: '银行家安迪被冤入狱。',
        year: 1994,
        rating: 9.7,
        genres: ['剧情'],
        provider: 'douban',
      );

  @override
  Future<void> load(String titleRef) async {}
}
