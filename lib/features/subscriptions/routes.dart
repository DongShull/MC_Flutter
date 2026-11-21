import 'package:go_router/go_router.dart';

import 'pages/subscription_detail_page.dart';
import 'pages/subscription_wall_page.dart';

/// subscriptions 模块路由（挂载到 core/router.dart）。
const routeSubscriptions = '/subscriptions';

final List<GoRoute> routes = [
  GoRoute(
    path: '$routeSubscriptions/wall',
    builder: (context, state) => SubscriptionWallPage(
      kind: state.uri.queryParameters['kind'],
    ),
  ),
  GoRoute(
    path: '$routeSubscriptions/wall/:id',
    builder: (context, state) => SubscriptionWallPage(
      subscriptionId: int.tryParse(state.pathParameters['id'] ?? ''),
    ),
  ),
  GoRoute(
    path: '$routeSubscriptions/detail/:id',
    builder: (context, state) => SubscriptionDetailPage(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
];
