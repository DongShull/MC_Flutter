import 'package:go_router/go_router.dart';

import 'pages/account_page.dart';

/// account 模块路由（挂载到 core/router.dart）。
/// `/account/devices` 统一重定向至新版 `/settings/devices`，避免两套设备管理页互相冲突。
const routeAccount = '/account';

final List<GoRoute> routes = [
  GoRoute(path: routeAccount, builder: (context, state) => const AccountPage()),
  GoRoute(
    path: '$routeAccount/devices',
    redirect: (context, state) {
      final q = state.uri.queryParameters;
      if (q.isEmpty) return '/settings/devices';
      return Uri(path: '/settings/devices', queryParameters: q).toString();
    },
  ),
];
