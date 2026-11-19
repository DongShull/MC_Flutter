import 'package:go_router/go_router.dart';

import 'pages/root_page.dart';

/// root 模块路由（挂载到 core/router.dart）。
const routeRoot = '/home';

final List<GoRoute> routes = [
  GoRoute(path: routeRoot, builder: (context, state) => const RootPage()),
];
