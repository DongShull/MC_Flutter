import 'package:go_router/go_router.dart';

import 'pages/player_page.dart';
import 'state/player_controller.dart';

/// player 模块路由（挂载到 core/router.dart）。
/// extra 传 PlayerPageArgs（url / title / startPosition / 剧集元信息）。
const routePlayer = '/player';

final List<GoRoute> routes = [
  GoRoute(
    path: routePlayer,
    builder: (context, state) =>
        PlayerPage(args: state.extra as PlayerPageArgs?),
  ),
];
