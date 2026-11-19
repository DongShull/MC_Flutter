import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/discover_page.dart';
import 'pages/person_page.dart';
import 'pages/title_detail_page.dart';

/// discover 模块路由（挂载到 core/router.dart）。
const routeDiscover = '/discover';

/// 搜索入口（指向 features/search 的 '/search'；跨 feature 只用路由名，不 import）。
const routeSearchEntry = '/search';

/// 发现侧条目详情（title_ref 形如 tmdb:movie:123 / douban:456）。
const routeDiscoverTitle = '/discover/title';

/// TMDB 影人页（发现侧走 TMDB id；与库内人物页分流）。
const routeDiscoverPerson = '/discover/person';

final List<GoRoute> routes = [
  GoRoute(path: routeDiscover, builder: (context, state) => const DiscoverPage()),
  GoRoute(
    path: routeDiscoverTitle,
    builder: (context, state) =>
        TitleDetailPage(titleRef: state.uri.queryParameters['ref'] ?? ''),
  ),
  GoRoute(
    path: routeDiscoverPerson,
    builder: (context, state) => PersonPage(
      personId: int.tryParse(state.uri.queryParameters['id'] ?? '') ?? 0,
    ),
  ),
];

/// pushNamed('/discover/title', arguments: ref) 的兼容入口（组内页面用）。
void pushTitle(BuildContext context, String ref) =>
    context.push('$routeDiscoverTitle?ref=${Uri.encodeComponent(ref)}');
