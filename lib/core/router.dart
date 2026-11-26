import 'package:go_router/go_router.dart';

import 'session/session_store.dart';
import 'shell/app_shell.dart';

import '../features/onboarding/routes.dart' as feat_onboarding;
import '../features/root/routes.dart' as feat_root;
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

/// 全局路由表：绑定 `appSession` 监听，自动守护未登录路由并放行访客分享与扫码。
final mcRouter = GoRouter(
  initialLocation: feat_onboarding.routeOnboarding,
  refreshListenable: appSession,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (loc == '/') {
      return appSession.isReady
          ? feat_root.routeRoot
          : feat_onboarding.routeOnboarding;
    }
    final isGuestRoute = loc == feat_onboarding.routeOnboarding ||
        loc.startsWith('${feat_onboarding.routeOnboarding}/') ||
        loc.startsWith('/share') ||
        loc == '/player';
    final onOnboarding = loc == feat_onboarding.routeOnboarding;
    final onSplash = loc == feat_onboarding.routeSplash;
    if (onOnboarding && appSession.isReady) return feat_onboarding.routeSplash;
    if (onSplash && !appSession.isReady) return feat_onboarding.routeOnboarding;
    if (!appSession.isReady && !isGuestRoute) {
      return feat_onboarding.routeOnboarding;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, __) => appSession.isReady
          ? feat_root.routeRoot
          : feat_onboarding.routeOnboarding,
    ),
    ...feat_onboarding.routes,
    GoRoute(
      path: feat_root.routeRoot,
      builder: (context, state) => const MainShell(),
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
