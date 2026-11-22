import 'package:go_router/go_router.dart';
import 'pages/search_page.dart';

/// search 模块路由（挂载到 core/router.dart）。
const routeSearch = '/search';

/// 查询参数：
/// - `mode`: 'library' / 'torrents'（详情页“搜索资源”带 `mode=torrents&q=片名`）；
/// - `q`: 初始关键词；
/// - `forSub` / `forSubTitle`: 手动选种目标订阅（订阅页“补缺资源”带入）。
final List<GoRoute> routes = [
  GoRoute(
    path: routeSearch,
    builder: (context, state) => SearchPage(
      initialMode: state.uri.queryParameters['mode'],
      initialQuery: state.uri.queryParameters['q'],
      grabSubscriptionId:
          int.tryParse(state.uri.queryParameters['forSub'] ?? ''),
      grabTitle: state.uri.queryParameters['forSubTitle'],
    ),
  ),
];
