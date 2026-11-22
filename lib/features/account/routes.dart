import 'package:go_router/go_router.dart';

import 'pages/account_page.dart';

/// account 模块路由（挂载到 core/router.dart）。
/// P4：设备管理已合并到 settings 的唯一实现（/settings/devices），
/// 本模块不再保留 /account/devices 路由。
const routeAccount = '/account';

final List<GoRoute> routes = [
  GoRoute(path: routeAccount, builder: (context, state) => const AccountPage()),
];
