import 'package:go_router/go_router.dart';
import 'pages/offline_page.dart';

/// offline 模块路由（挂载到 core/router.dart）。
const routeOffline = '/offline';

final List<GoRoute> routes = [
  GoRoute(path: routeOffline, builder: (context, state) => const OfflinePage()),
];
