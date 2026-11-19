import 'package:go_router/go_router.dart';
import 'pages/update_page.dart';

/// update 模块路由（挂载到 core/router.dart）。
const routeUpdate = '/update';

final List<GoRoute> routes = [
  GoRoute(path: routeUpdate, builder: (context, state) => const UpdatePage()),
];
