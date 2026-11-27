import 'package:go_router/go_router.dart';

import 'pages/share_page.dart';

/// share 模块路由（挂载到 core/router.dart）。
const routeShare = '/share';
const routeShareSlug = '/share/:slug';
const routeShareShort = '/s/:slug';
const routeShareShortPlay = '/s/:slug/play/:unit';

int? _parseInt(String? raw) => raw == null ? null : int.tryParse(raw.trim());

final List<GoRoute> routes = [
  GoRoute(
    path: routeShare,
    builder: (context, state) => SharePage(
      slug: state.uri.queryParameters['slug'] ?? '',
      origin: state.uri.queryParameters['origin'],
      initialItemId: _parseInt(state.uri.queryParameters['item']),
    ),
  ),
  GoRoute(
    path: routeShareSlug,
    builder: (context, state) => SharePage(
      slug: state.pathParameters['slug'] ?? '',
      origin: state.uri.queryParameters['origin'],
      initialItemId: _parseInt(state.uri.queryParameters['item']),
    ),
  ),
  GoRoute(
    path: routeShareShort,
    builder: (context, state) => SharePage(
      slug: state.pathParameters['slug'] ?? '',
      origin: state.uri.queryParameters['origin'],
      initialItemId: _parseInt(state.uri.queryParameters['item']),
    ),
  ),
  GoRoute(
    path: routeShareShortPlay,
    builder: (context, state) => SharePage(
      slug: state.pathParameters['slug'] ?? '',
      origin: state.uri.queryParameters['origin'],
      initialItemId: _parseInt(state.uri.queryParameters['item']),
      initialPlayUnit: state.pathParameters['unit'],
      initialStartSeconds: _parseInt(state.uri.queryParameters['t']),
    ),
  ),
];
