import 'package:go_router/go_router.dart';

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

/// 全部路由：每个功能模块只导出自己的 routes.dart，这里统一挂载。
final mcRouter = GoRouter(
  initialLocation: feat_onboarding.routeOnboarding,
  routes: [
    ...feat_onboarding.routes,
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
