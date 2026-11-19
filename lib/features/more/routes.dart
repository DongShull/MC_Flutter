import 'package:go_router/go_router.dart';
import 'pages/more_page.dart';

/// more 模块路由（挂载到 core/router.dart）。
const routeMore = '/more';

final List<GoRoute> routes = [
  GoRoute(path: routeMore, builder: (context, state) => const MorePage()),
];
