import 'package:go_router/go_router.dart';

import 'pages/account_page.dart';
import 'pages/devices_page.dart';

/// account 模块路由（挂载到 core/router.dart）。
const routeAccount = '/account';

final List<GoRoute> routes = [
  GoRoute(path: routeAccount, builder: (context, state) => const AccountPage()),
  GoRoute(
    path: '$routeAccount/devices',
    builder: (context, state) => const DevicesPage(),
  ),
];
