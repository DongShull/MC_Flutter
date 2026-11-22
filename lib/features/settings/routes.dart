import 'package:go_router/go_router.dart';

import 'pages/activate_page.dart';
import 'pages/ai_defaults_page.dart';
import 'pages/appearance_page.dart';
import 'pages/app_push_page.dart';
import 'pages/app_settings_page.dart';
import 'pages/cloud_page.dart';
import 'pages/devices_page.dart';
import 'pages/downloaders_page.dart';
import 'pages/drives_page.dart';
import 'pages/external_access_page.dart';
import 'pages/im_push_page.dart';
import 'pages/import_watch_page.dart';
import 'pages/llm_page.dart';
import 'pages/logs_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/mcp_page.dart';
import 'pages/members_page.dart';
import 'pages/network_page.dart';
import 'pages/notifications_settings_page.dart';
import 'pages/overview_page.dart';
import 'pages/playback_page.dart';
import 'pages/plugins_page.dart';
import 'pages/profile_page.dart';
import 'pages/rule_sets_page.dart';
import 'pages/scheduled_tasks_page.dart';
import 'pages/scrape_page.dart';
import 'pages/settings_page.dart';
import 'pages/sites_page.dart';
import 'pages/subscription_settings_page.dart';
import 'pages/web_managed_page.dart';
import 'pages/webhook_page.dart';

/// settings 模块路由（挂载到 core/router.dart）。
/// P4：25 个 parity 分区全部原生路由，另有设备激活、规则集、定时任务。
const routeSettings = '/settings';

final List<GoRoute> routes = [
  GoRoute(path: routeSettings, builder: (context, state) => const SettingsPage()),
  GoRoute(
    path: '$routeSettings/overview',
    builder: (context, state) => const OverviewPage(),
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
    path: '$routeSettings/activate',
    builder: (context, state) => const ActivatePage(),
  ),
  GoRoute(
    path: '$routeSettings/notifications',
    builder: (context, state) => const NotificationsSettingsPage(),
  ),
  GoRoute(
    path: '$routeSettings/appearance',
    builder: (context, state) => const AppearancePage(),
  ),
  GoRoute(
    path: '$routeSettings/members',
    builder: (context, state) => const MembersPage(),
  ),
  GoRoute(
    path: '$routeSettings/subscription',
    builder: (context, state) => const SubscriptionSettingsPage(),
  ),
  GoRoute(
    path: '$routeSettings/rule-sets',
    builder: (context, state) => const RuleSetsPage(),
  ),
  GoRoute(
    path: '$routeSettings/sites',
    builder: (context, state) => const SitesPage(),
  ),
  GoRoute(
    path: '$routeSettings/downloaders',
    builder: (context, state) => const DownloadersPage(),
  ),
  GoRoute(
    path: '$routeSettings/import-watch',
    builder: (context, state) => const ImportWatchPage(),
  ),
  GoRoute(
    path: '$routeSettings/scrape',
    builder: (context, state) => const ScrapePage(),
  ),
  GoRoute(
    path: '$routeSettings/playback',
    builder: (context, state) => const PlaybackPage(),
  ),
  GoRoute(
    path: '$routeSettings/drives',
    builder: (context, state) => const DrivesPage(),
  ),
  GoRoute(
    path: '$routeSettings/app-push',
    builder: (context, state) => const AppPushPage(),
  ),
  GoRoute(
    path: '$routeSettings/im-push',
    builder: (context, state) => const ImPushPage(),
  ),
  GoRoute(
    path: '$routeSettings/webhook',
    builder: (context, state) => const WebhookPage(),
  ),
  GoRoute(
    path: '$routeSettings/llm',
    builder: (context, state) => const LlmPage(),
  ),
  GoRoute(
    path: '$routeSettings/mcp',
    builder: (context, state) => const McpPage(),
  ),
  GoRoute(
    path: '$routeSettings/ai',
    builder: (context, state) => const AiDefaultsPage(),
  ),
  GoRoute(
    path: '$routeSettings/cloud',
    builder: (context, state) => const CloudPage(),
  ),
  GoRoute(
    path: '$routeSettings/app',
    builder: (context, state) => const AppSettingsPage(),
  ),
  GoRoute(
    path: '$routeSettings/plugins',
    builder: (context, state) => const PluginsPage(),
  ),
  GoRoute(
    path: '$routeSettings/network',
    builder: (context, state) => const NetworkPage(),
  ),
  GoRoute(
    path: '$routeSettings/logs',
    builder: (context, state) => const LogsPage(),
  ),
  GoRoute(
    path: '$routeSettings/scheduled-tasks',
    builder: (context, state) => const ScheduledTasksPage(),
  ),
  GoRoute(
    path: '$routeSettings/external-access',
    builder: (context, state) => const ExternalAccessPage(),
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
