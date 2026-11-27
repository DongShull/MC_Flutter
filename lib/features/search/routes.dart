import 'package:go_router/go_router.dart';
import 'pages/search_page.dart';

/// search 模块路由（挂载到 core/router.dart）。
const routeSearch = '/search';

final List<GoRoute> routes = [
  GoRoute(
    path: routeSearch,
    builder: (context, state) {
      final qp = state.uri.queryParameters;
      final alsoRaw = state.uri.queryParametersAll['also'] ?? const <String>[];
      final also = <String>[
        for (final entry in alsoRaw)
          for (final part in entry.split(','))
            if (part.trim().isNotEmpty) part.trim(),
      ];
      return SearchPage(
        initialQuery: qp['q'],
        initialMode: qp['tab'],
        initialScope: qp['scope'],
        initialAlso: also,
        initialSnapshotId: int.tryParse(qp['snapshot'] ?? ''),
        forSubscriptionId: int.tryParse(qp['for_sub'] ?? ''),
        initialBrowse: qp['browse'] == '1',
      );
    },
  ),
];
