import 'package:go_router/go_router.dart';

import 'pages/detail_page.dart';
import 'pages/subtitle_gen_page.dart';

/// detail 模块路由（挂载到 core/router.dart）。
const routeDetail = '/detail';

/// 带参详情路由：/detail/:libraryId/:itemId（刷片 / 海报墙深链落点）。
const routeDetailItem = '/detail/:libraryId/:itemId';

/// 字幕生成页：/detail/:libraryId/:itemId/subtitles?fileId=…&title=…
String routeDetailSubtitles(int libraryId, int itemId, int fileId, String title) =>
    '/detail/$libraryId/$itemId/subtitles'
    '?fileId=$fileId&title=${Uri.encodeComponent(title)}';

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
    ),
  ),
  GoRoute(
    path: '$routeDetailItem/subtitles',
    builder: (context, state) => SubtitleGenPage(
      fileId: int.tryParse(state.uri.queryParameters['fileId'] ?? '') ?? -1,
      title: state.uri.queryParameters['title'] ?? '',
    ),
  ),
];
