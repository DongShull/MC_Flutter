import 'package:go_router/go_router.dart';

import 'pages/about_language_pages.dart';
import 'pages/admin_pipeline_pages.dart';
import 'pages/admin_system_pages.dart';
import 'pages/cloud_settings_page.dart';
import 'pages/devices_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/mcp_settings_page.dart';
import 'pages/notification_settings_page.dart';
import 'pages/playback_page.dart';
import 'pages/profile_page.dart';
import 'pages/push_channels_page.dart';
import 'pages/settings_page.dart';

/// settings 模块路由（全量原生接管 iOS / Web 全部设置与管理板块）。
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
    path: '$routeSettings/notifications',
    builder: (context, state) => const NotificationSettingsPage(),
  ),
  GoRoute(
    path: '$routeSettings/playback',
    builder: (context, state) => const PlaybackPage(),
  ),
  GoRoute(
    path: '$routeSettings/language',
    builder: (context, state) => const LanguageSettingsPage(),
  ),
  GoRoute(
    path: '$routeSettings/about',
    builder: (context, state) => const AboutPage(),
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
    path: '$routeSettings/push',
    builder: (context, state) => const PushChannelsPage(),
  ),
  GoRoute(
    path: '$routeSettings/webhook',
    builder: (context, state) => const WebhookSettingsPage(),
  ),
  GoRoute(
    path: '$routeSettings/ai',
    builder: (context, state) => const AiIntegrationsAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/mcp',
    builder: (context, state) => const McpSettingsPage(),
  ),
  GoRoute(
    path: '$routeSettings/cloud',
    builder: (context, state) => const CloudSettingsPage(),
  ),
  GoRoute(
    path: '$routeSettings/system',
    builder: (context, state) => const NetworkTasksLogsAdminPage(),
  ),
  GoRoute(
    path: '$routeSettings/maintenance',
    builder: (context, state) => const MaintenancePage(),
  ),
];
