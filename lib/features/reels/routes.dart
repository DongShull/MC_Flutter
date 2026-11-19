import 'package:go_router/go_router.dart';
import 'pages/reels_page.dart';

/// reels 模块路由（挂载到 core/router.dart）。
const routeReels = '/reels';

final List<GoRoute> routes = [
  GoRoute(path: routeReels, builder: (context, state) => const ReelsPage()),
];
