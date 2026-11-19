import 'package:go_router/go_router.dart';

import 'pages/collection_pages.dart';
import 'pages/library_detail_page.dart';
import 'pages/library_home_page.dart';
import 'pages/library_customize_page.dart';
import 'pages/person_kind_pages.dart';

/// library 模块路由（挂载到 core/router.dart）。
const routeLibrary = '/library';

/// 子页面路由（本 feature 内新增）。
const routeLibraryCollections = '/library/collections';
const routeLibraryCustomize = '/library/customize';

String routeLibraryDetail(int libraryId) => '/library/detail/$libraryId';
String routeLibraryCollection(int collectionId) => '/library/collection/$collectionId';
String routeLibraryPerson(int personId, {String? name}) =>
    '/library/person/$personId${name == null ? '' : '?name=${Uri.encodeComponent(name)}'}';
String routeLibraryKind(String kind) => '/library/kind/$kind';

final List<GoRoute> routes = [
  GoRoute(
    path: routeLibrary,
    builder: (context, state) => const LibraryHomePage(),
  ),
  GoRoute(
    path: routeLibraryCollections,
    builder: (context, state) => const LibraryCollectionsPage(),
  ),
  GoRoute(
    path: routeLibraryCustomize,
    builder: (context, state) => const LibraryCustomizePage(),
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
    builder: (context, state) =>
        KindWallPage(kind: state.pathParameters['kind']!),
  ),
];
