import 'package:go_router/go_router.dart';

import 'pages/admin_pipeline_pages.dart';
import 'pages/admin_system_pages.dart';
import 'pages/devices_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/playback_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'pages/web_managed_page.dart';

/// settings 模块路由（全量原生接管 Web 23 个设置与后台板块）。
const routeSettings = '/settings';

final List<GoRoute> routes = [
  GoRoute(
    path: routeSettings,
    builder: (context, state) => const SettingsPage(),
  ),
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
    path: '$routeSettings/overview',
    builder: (context, state) => const AutomationOverviewPage(),
  ),
  GoRoute(
    path: '$routeSettings/members',
    builder: (context, state) => const MembersAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/rules',
    builder: (context, state) => const RuleSetsAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/sites',
    builder: (context, state) => const SitesAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/downloaders',
    builder: (context, state) => const DownloadersAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/scrape',
    builder: (context, state) => const ScrapeDrivesAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/ai',
    builder: (context, state) => const AiIntegrationsAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/system',
    builder: (context, state) => const NetworkTasksLogsAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/maintenance',
    builder: (context, state) => const MaintenancePage(),
  ),
  GoRoute(
    path: '$routeSettings/web',
    builder: (context, state) => WebManagedPage(
      title: state.uri.queryParameters['title'] ?? '网页控制台',
      description: state.uri.queryParameters['description'] ?? '',
    ),
  ),
];
