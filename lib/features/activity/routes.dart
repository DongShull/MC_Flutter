import 'package:go_router/go_router.dart';
import 'pages/activity_page.dart';

/// activity 模块路由（挂载到 core/router.dart）。
const routeActivity = '/activity';

final List<GoRoute> routes = [
  GoRoute(path: routeActivity, builder: (context, state) => const ActivityPage()),
];
