import 'package:go_router/go_router.dart';

import 'pages/devices_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/playback_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'pages/web_managed_page.dart';

/// settings 模块路由（挂载到 core/router.dart）。
const routeSettings = '/settings';

final List<GoRoute> routes = [
  GoRoute(path: routeSettings, builder: (context, state) => const SettingsPage()),
  GoRoute(
    path: '$routeSettings/profile',
    builder: (context, state) => const ProfilePage(),
  ),
  GoRoute(
    path: '$routeSettings/devices',
    builder: (context, state) => const DevicesPage(),
  ),
  GoRoute(
    path: '$routeSettings/playback',
    builder: (context, state) => const PlaybackPage(),
  ),
  GoRoute(
    path: '$routeSettings/maintenance',
    builder: (context, state) => const MaintenancePage(),
  ),
  GoRoute(
    path: '$routeSettings/web',
    builder: (context, state) => WebManagedPage(
      title: state.uri.queryParameters['title'] ?? '网页托管',
      description: state.uri.queryParameters['description'] ?? '',
    ),
  ),
];
