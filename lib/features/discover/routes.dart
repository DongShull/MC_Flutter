import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/discover_collection_page.dart';
import 'pages/person_page.dart';
import 'pages/title_detail_page.dart';
import 'state/discover_controller.dart' show DiscTitle;

/// discover 模块路由（挂载到 core/router.dart）。
const routeDiscover = '/discover';

/// 搜索入口（指向 features/search 的 '/search'；跨 feature 只用路由名，不 import）。
const routeSearchEntry = '/search';

/// 发现侧条目详情（title_ref 形如 tmdb:movie:123 / douban:456）。
const routeDiscoverTitle = '/discover/title';

/// 榜单全列表（collectionRef 形如 tmdb:movie:popular / douban:movie:movie_top250）。
const routeDiscoverCollection = '/discover/collection/:collectionRef';

/// TMDB 影人页（发现侧走 TMDB id；与库内人物页分流）。
const routeDiscoverPerson = '/discover/person';

final List<GoRoute> routes = [
  GoRoute(
    path: routeDiscoverTitle,
    builder: (context, state) => TitleDetailPage(
      titleRef: state.uri.queryParameters['ref'] ?? '',
      seed: state.extra is DiscTitle ? state.extra! as DiscTitle : null,
    ),
  ),
  GoRoute(
    path: routeDiscoverCollection,
    builder: (context, state) {
      final rawRef = state.pathParameters['collectionRef'] ?? '';
      final decodedRef = Uri.decodeComponent(rawRef);
      final extraMap = state.extra is Map
          ? (state.extra! as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      return DiscoverCollectionPage(
        collectionRef: decodedRef,
        initialTitle: state.uri.queryParameters['title'] ??
            extraMap['title']?.toString(),
        initialSource: state.uri.queryParameters['source'] ??
            state.uri.queryParameters['provider'] ??
            extraMap['source']?.toString(),
      );
    },
  ),
  GoRoute(
    path: routeDiscoverPerson,
    builder: (context, state) => PersonPage(
      personId: int.tryParse(state.uri.queryParameters['id'] ?? '') ?? 0,
    ),
  ),
];

/// 进入发现条目详情页（附带首屏预渲染 seed）。
void pushTitle(BuildContext context, String ref, {DiscTitle? seed}) =>
    context.push(
      '$routeDiscoverTitle?ref=${Uri.encodeComponent(ref)}',
      extra: seed,
    );

/// 进入榜单全列表页。
void pushCollection(
  BuildContext context, {
  required String collectionRef,
  String? title,
  String? source,
}) {
  final q = <String, String>{
    if (title != null && title.isNotEmpty) 'title': title,
    if (source != null && source.isNotEmpty) 'source': source,
  };
  final encodedRef = Uri.encodeComponent(collectionRef);
  final uri = Uri(
    path: '/discover/collection/$encodedRef',
    queryParameters: q.isEmpty ? null : q,
  );
  context.push(uri.toString());
}
