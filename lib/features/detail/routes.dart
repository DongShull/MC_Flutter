import 'package:go_router/go_router.dart';

import 'pages/detail_page.dart';

/// detail 模块路由（挂载到 core/router.dart）。
const routeDetail = '/detail';

/// 带参详情路由：/detail/:libraryId/:itemId（刷片 / 海报墙深链落点，支持 ?season=&episode=）。
const routeDetailItem = '/detail/:libraryId/:itemId';

final List<GoRoute> routes = [
  GoRoute(
    path: routeDetail,
    builder: (context, state) => const DetailPage(),
  ),
  GoRoute(
    path: routeDetailItem,
    builder: (context, state) => DetailPage(
      libraryId: int.tryParse(state.pathParameters['libraryId'] ?? '') ?? -1,
      itemId: int.tryParse(state.pathParameters['itemId'] ?? '') ?? -1,
      initialSeason: int.tryParse(state.uri.queryParameters['season'] ?? ''),
      initialEpisode: int.tryParse(state.uri.queryParameters['episode'] ?? ''),
    ),
  ),
];
