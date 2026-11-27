import 'package:go_router/go_router.dart';

import 'pages/activity_page.dart';
import 'pages/activity_subpages.dart';

/// activity 模块路由（挂载到 core/router.dart）。
const routeActivity = '/activity';
const routeActivityActive = '/activity/active';
const routeActivityFinished = '/activity/finished';
const routeActivityBoost = '/activity/boost';
const routeActivityPlays = '/activity/plays';
const routeActivityStats = '/activity/stats';

final List<GoRoute> routes = [
  GoRoute(
    path: routeActivity,
    builder: (context, state) {
      final view = state.uri.queryParameters['view'];
      return switch (view) {
        'active' => const ActivityTasksPage(active: true),
        'finished' || 'history' => const ActivityTasksPage(active: false),
        'boost' => const ActivityBoostPage(),
        'plays' => const WatchHistoryPage(),
        'stats' => const WatchStatsPage(),
        _ => const ActivityPage(),
      };
    },
  ),
  GoRoute(
    path: routeActivityActive,
    builder: (context, state) => const ActivityTasksPage(active: true),
  ),
  GoRoute(
    path: routeActivityFinished,
    builder: (context, state) => const ActivityTasksPage(active: false),
  ),
  GoRoute(
    path: routeActivityBoost,
    builder: (context, state) => const ActivityBoostPage(),
  ),
  GoRoute(
    path: routeActivityPlays,
    builder: (context, state) => const WatchHistoryPage(),
  ),
  GoRoute(
    path: routeActivityStats,
    builder: (context, state) => const WatchStatsPage(),
  ),
];
