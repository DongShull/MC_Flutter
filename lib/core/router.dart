import 'package:go_router/go_router.dart';

import 'session/session_store.dart';

import '../features/onboarding/routes.dart' as feat_onboarding;
import '../features/root/routes.dart' as feat_root;
import '../features/root/pages/root_page.dart';
import '../features/discover/pages/discover_page.dart';
import '../features/library/pages/library_home_page.dart';
import '../features/subscriptions/pages/subscriptions_page.dart';
import '../features/activity/pages/activity_page.dart';
import '../features/more/pages/more_page.dart';
import '../features/library/routes.dart' as feat_library;
import '../features/discover/routes.dart' as feat_discover;
import '../features/search/routes.dart' as feat_search;
import '../features/detail/routes.dart' as feat_detail;
import '../features/player/routes.dart' as feat_player;
import '../features/subscriptions/routes.dart' as feat_subscriptions;
import '../features/activity/routes.dart' as feat_activity;
import '../features/offline/routes.dart' as feat_offline;
import '../features/reels/routes.dart' as feat_reels;
import '../features/account/routes.dart' as feat_account;
import '../features/notices/routes.dart' as feat_notices;
import '../features/agent/routes.dart' as feat_agent;
import '../features/settings/routes.dart' as feat_settings;
import '../features/share/routes.dart' as feat_share;
import '../features/update/routes.dart' as feat_update;
import '../features/more/routes.dart' as feat_more;

/// 全部路由：每个功能模块只导出自己的 routes.dart，这里统一挂载。
final mcRouter = GoRouter(
  initialLocation: feat_onboarding.routeOnboarding,
  // 启动已恢复会话（main 里 appSession.restore）→ 先过启动页（展示身份）再进主界面；
  // 未登录时启动页/主界面不可直达，回登录页。
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final onOnboarding = loc == feat_onboarding.routeOnboarding;
    final onSplash = loc == feat_onboarding.routeSplash;
    if (onOnboarding && appSession.isReady) return feat_onboarding.routeSplash;
    if (onSplash && !appSession.isReady) return feat_onboarding.routeOnboarding;
    return null;
  },
  routes: [
    ...feat_onboarding.routes,
    // 五 Tab 主壳：真实页面按 branch 保活（IndexedStack），RootShell 只出 chrome。
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => RootShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryHomePage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/subscriptions',
            builder: (context, state) => const SubscriptionsPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/activity',
            builder: (context, state) => const ActivityPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/more',
            builder: (context, state) => const MorePage(),
          ),
        ]),
      ],
    ),
    ...feat_root.routes,
    ...feat_library.routes,
    ...feat_discover.routes,
    ...feat_search.routes,
    ...feat_detail.routes,
    ...feat_player.routes,
    ...feat_subscriptions.routes,
    ...feat_activity.routes,
    ...feat_offline.routes,
    ...feat_reels.routes,
    ...feat_account.routes,
    ...feat_notices.routes,
    ...feat_agent.routes,
    ...feat_settings.routes,
    ...feat_share.routes,
    ...feat_update.routes,
    ...feat_more.routes,
  ],
);
