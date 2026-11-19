import 'package:go_router/go_router.dart';

import 'pages/share_page.dart';

/// share 模块路由（挂载到 core/router.dart）。
const routeShare = '/share';

/// 访客分享深链：/share/:slug（设计文档 05 §4.3，进独立壳）。
/// origin 经查询参数 ?origin= 传入；缺省回落当前会话服务器。
const routeShareSlug = '/share/:slug';

final List<GoRoute> routes = [
  GoRoute(
    path: routeShare,
    builder: (context, state) => SharePage(
      slug: state.uri.queryParameters['slug'] ?? '',
      origin: state.uri.queryParameters['origin'],
    ),
  ),
  GoRoute(
    path: routeShareSlug,
    builder: (context, state) => SharePage(
      slug: state.pathParameters['slug'] ?? '',
      origin: state.uri.queryParameters['origin'],
    ),
  ),
];
