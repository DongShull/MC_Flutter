import 'package:go_router/go_router.dart';

import 'pages/collection_pages.dart';
import 'pages/favorites_page.dart';
import 'pages/library_customize_page.dart';
import 'pages/library_detail_page.dart';
import 'pages/library_manage_page.dart';
import 'pages/person_kind_pages.dart';

/// library 模块路由（挂载到 core/router.dart）。
const routeLibrary = '/library';

/// 子页面路由（本 feature 内）。
const routeLibraryCollections = '/library/collections';
const routeLibraryCustomize = '/library/customize';
const routeLibraryFavorites = '/library/favorites';
const routeLibraryManage = '/library/manage';

String routeLibraryDetail(
  int libraryId, {
  Map<String, String>? query,
}) {
  if (query == null || query.isEmpty) return '/library/detail/$libraryId';
  final qp = Uri(queryParameters: query).query;
  return '/library/detail/$libraryId?$qp';
}

String routeLibraryCollection(int collectionId) =>
    '/library/collection/$collectionId';

String routeLibraryPerson(int personId, {String? name}) =>
    '/library/person/$personId${name == null ? '' : '?name=${Uri.encodeComponent(name)}'}';

String routeLibraryKind(
  String kind, {
  String? genre,
  String? watch,
  String? sort,
  String? order,
}) {
  final params = <String, String>{
    if (genre != null && genre.isNotEmpty) 'g': genre,
    if (watch != null && watch.isNotEmpty) 'w': watch,
    if (sort != null && sort.isNotEmpty) 'sort': sort,
    if (order != null && order.isNotEmpty) 'order': order,
  };
  if (params.isEmpty) return '/library/kind/$kind';
  return '/library/kind/$kind?${Uri(queryParameters: params).query}';
}

/// 解析 `/library/manage?tab=...` 的页签参数（同时兼容命名与数字下标）。
/// 顺序对齐 `LibraryManagePage`：0 媒体库 / 1 待处理 / 2 重复文件 / 3 回收站 / 4 活跃分享。
int parseLibraryManageTab(String? raw) {
  final value = raw?.trim().toLowerCase() ?? '';
  return switch (value) {
    'libraries' || 'library' => 0,
    'issues' || 'pending' => 1,
    'duplicates' || 'duplicate' => 2,
    'trash' || 'recycle' => 3,
    'shares' || 'share' => 4,
    _ => (int.tryParse(value) ?? 0).clamp(0, 4),
  };
}

final List<GoRoute> routes = [
  GoRoute(
    path: routeLibraryCollections,
    builder: (context, state) => const LibraryCollectionsPage(),
  ),
  GoRoute(
    path: routeLibraryFavorites,
    builder: (context, state) => const LibraryFavoritesPage(),
  ),
  GoRoute(
    path: routeLibraryCustomize,
    builder: (context, state) => const LibraryCustomizePage(),
  ),
  GoRoute(
    path: routeLibraryManage,
    builder: (context, state) => LibraryManagePage(
      initialTab: parseLibraryManageTab(state.uri.queryParameters['tab']),
      initialItemId: int.tryParse(state.uri.queryParameters['item'] ?? ''),
      openCreate: state.uri.queryParameters['create'] == '1',
    ),
  ),
  GoRoute(
    path: '/library/detail/:libraryId',
    builder: (context, state) => LibraryDetailPage(
      libraryId: int.parse(state.pathParameters['libraryId']!),
      query: state.uri.queryParameters,
    ),
  ),
  GoRoute(
    path: '/library/collection/:collectionId',
    builder: (context, state) => CollectionDetailPage(
      collectionId: int.parse(state.pathParameters['collectionId']!),
    ),
  ),
  GoRoute(
    path: '/library/person/:personId',
    builder: (context, state) => LibraryPersonPage(
      personId: int.parse(state.pathParameters['personId']!),
      personName: state.uri.queryParameters['name'],
    ),
  ),
  GoRoute(
    path: '/library/kind/:kind',
    builder: (context, state) => KindWallPage(
      kind: state.pathParameters['kind']!,
      initialGenre: state.uri.queryParameters['g'],
      initialWatch: state.uri.queryParameters['w'],
      initialSort: state.uri.queryParameters['sort'],
      initialOrder: state.uri.queryParameters['order'],
    ),
  ),
];
