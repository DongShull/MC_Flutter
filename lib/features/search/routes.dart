import 'package:go_router/go_router.dart';
import 'pages/search_page.dart';

/// search 模块路由（挂载到 core/router.dart）。
const routeSearch = '/search';

final List<GoRoute> routes = [
  GoRoute(
    path: routeSearch,
    builder: (context, state) => SearchPage(
      initialQuery: state.uri.queryParameters['q'],
      initialMode: state.uri.queryParameters['tab'],
      forSubscriptionId:
          int.tryParse(state.uri.queryParameters['for_sub'] ?? ''),
    ),
  ),
];
