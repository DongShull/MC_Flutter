import 'package:go_router/go_router.dart';

import 'pages/offline_library_page.dart';
import 'pages/offline_page.dart';

/// offline 模块路由（挂载到 core/router.dart）。
const routeOffline = '/offline';
const routeOfflineLibrary = '/offline/library';

final List<GoRoute> routes = [
  GoRoute(
    path: routeOffline,
    builder: (context, state) => const OfflinePage(),
  ),
  GoRoute(
    path: routeOfflineLibrary,
    builder: (context, state) => const OfflineLibraryPage(),
  ),
];
