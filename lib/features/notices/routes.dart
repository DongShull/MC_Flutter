import 'package:go_router/go_router.dart';
import 'pages/notices_page.dart';

/// notices 模块路由（挂载到 core/router.dart）。
const routeNotices = '/notices';

final List<GoRoute> routes = [
  GoRoute(path: routeNotices, builder: (context, state) => const NoticesPage()),
];
