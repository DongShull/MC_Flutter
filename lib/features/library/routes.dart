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
      initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
      initialItemId: int.tryParse(state.uri.queryParameters['item'] ?? ''),
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
