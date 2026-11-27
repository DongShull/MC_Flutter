import 'package:go_router/go_router.dart';

import 'session/permissions.dart';
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

const _adminOnlySettingsPrefixes = <String>[
  '/settings/members',
  '/settings/rules',
  '/settings/sites',
  '/settings/downloaders',
  '/settings/scrape',
  '/settings/ai',
  '/settings/system',
  '/settings/maintenance',
  '/settings/cloud',
  '/settings/push',
  '/settings/mcp',
  '/settings/overview',
];

const _adminOnlyPrefixes = <String>[
  '/activity',
  '/agent',
  '/notices',
  '/library/manage',
];

bool _matchesPrefix(String loc, String prefix) =>
    loc == prefix || loc.startsWith('$prefix/');

/// 路由级角色与能力守卫（对齐 iOS `Permissions+Routes.swift`）：
/// 返回需要重定向的目标路径；允许访问返回 `null`。
String? _guardRouteForPermissions(String loc, McPermissions perms) {
  if (!perms.isAdmin) {
    for (final prefix in _adminOnlySettingsPrefixes) {
      if (_matchesPrefix(loc, prefix)) {
        return '/settings/profile';
      }
    }
    for (final prefix in _adminOnlyPrefixes) {
      if (_matchesPrefix(loc, prefix)) {
        return feat_root.routeRoot;
      }
    }
  }
  if (!perms.canSubscribe && _matchesPrefix(loc, '/subscriptions')) {
    return feat_root.routeRoot;
  }
  return null;
}

/// 全局路由表：绑定 `appSession` 监听，自动守护未登录路由、角色/能力守卫、
/// 放行访客分享与添加账号/重登流程，并消除冷启动额外等待。
final mcRouter = GoRouter(
  initialLocation: feat_onboarding.routeOnboarding,
  refreshListenable: appSession,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final mode = state.uri.queryParameters['mode'];
    final isAddOrRelogin = mode == 'add' || mode == 'relogin';

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

    // 已登录时：允许 `/onboarding?mode=add` 与 `/onboarding?mode=relogin`（修复添加账号死锁）；
    // 普通冷启动落到 `/onboarding` 直接秒进 `/home`（消除 1.35s 启动页阻塞）。
    if (onOnboarding && appSession.isReady) {
      if (isAddOrRelogin) return null;
      final resume = appSession.takeResumeLocation();
      if (resume != null &&
          resume.isNotEmpty &&
          !resume.startsWith(feat_onboarding.routeOnboarding) &&
          _guardRouteForPermissions(
                Uri.tryParse(resume)?.path ?? resume,
                appSession.permissions,
              ) ==
              null) {
        return resume;
      }
      return feat_root.routeRoot;
    }

    if (onSplash && !appSession.isReady) {
      return feat_onboarding.routeOnboarding;
    }

    if (!appSession.isReady && !isGuestRoute) {
      return feat_onboarding.routeOnboarding;
    }

    if (appSession.isReady) {
      return _guardRouteForPermissions(loc, appSession.permissions);
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
      builder: (context, state) {
        final tabIdx = switch (state.uri.queryParameters['tab']) {
          'subscriptions' => 1,
          'discover' => 2,
          'activity' => 3,
          'more' => 4,
          _ => 0,
        };
        return MainShell(initialTab: tabIdx);
      },
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
