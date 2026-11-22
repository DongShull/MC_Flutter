import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/features/agent/pages/chat_page.dart';
import 'package:mc_flutter/features/agent/pages/skills_page.dart';
import 'package:mc_flutter/features/settings/pages/activate_page.dart';
import 'package:mc_flutter/features/settings/pages/ai_defaults_page.dart';
import 'package:mc_flutter/features/settings/pages/appearance_page.dart';
import 'package:mc_flutter/features/settings/pages/app_push_page.dart';
import 'package:mc_flutter/features/settings/pages/app_settings_page.dart';
import 'package:mc_flutter/features/settings/pages/cloud_page.dart';
import 'package:mc_flutter/features/settings/pages/devices_page.dart';
import 'package:mc_flutter/features/settings/pages/downloaders_page.dart';
import 'package:mc_flutter/features/settings/pages/drives_page.dart';
import 'package:mc_flutter/features/settings/pages/external_access_page.dart';
import 'package:mc_flutter/features/settings/pages/im_push_page.dart';
import 'package:mc_flutter/features/settings/pages/import_watch_page.dart';
import 'package:mc_flutter/features/settings/pages/llm_page.dart';
import 'package:mc_flutter/features/settings/pages/logs_page.dart';
import 'package:mc_flutter/features/settings/pages/mcp_page.dart';
import 'package:mc_flutter/features/settings/pages/members_page.dart';
import 'package:mc_flutter/features/settings/pages/network_page.dart';
import 'package:mc_flutter/features/settings/pages/notifications_settings_page.dart';
import 'package:mc_flutter/features/settings/pages/overview_page.dart';
import 'package:mc_flutter/features/settings/pages/plugins_page.dart';
import 'package:mc_flutter/features/settings/pages/rule_sets_page.dart';
import 'package:mc_flutter/features/settings/pages/scheduled_tasks_page.dart';
import 'package:mc_flutter/features/settings/pages/scrape_page.dart';
import 'package:mc_flutter/features/settings/pages/settings_page.dart';
import 'package:mc_flutter/features/settings/pages/sites_page.dart';
import 'package:mc_flutter/features/settings/pages/subscription_settings_page.dart';
import 'package:mc_flutter/features/settings/pages/web_managed_page.dart';
import 'package:mc_flutter/features/settings/pages/webhook_page.dart';

/// P4 页面冒烟测试：无服务端时页面应正常构建、标题可见、
/// 加载失败时出错误态（不崩溃、不挂起）。
/// 每个新/改页面至少一个用例。
Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(home: page)),
  );
  await tester.pumpAndSettle();
}

void main() {
  final pages = <String, Widget>{
    '总览': const OverviewPage(),
    '外观': const AppearancePage(),
    '通知与提醒': const NotificationsSettingsPage(),
    '设备激活': const ActivatePage(),
    '成员': const MembersPage(),
    '订阅设置': const SubscriptionSettingsPage(),
    '规则集': const RuleSetsPage(),
    '站点': const SitesPage(),
    '下载器': const DownloadersPage(),
    '导入监听': const ImportWatchPage(),
    '刮削': const ScrapePage(),
    '网盘': const DrivesPage(),
    '应用推送': const AppPushPage(),
    'IM 推送': const ImPushPage(),
    'Webhook': const WebhookPage(),
    '模型接入': const LlmPage(),
    'MCP': const McpPage(),
    'AI 设定': const AiDefaultsPage(),
    '云': const CloudPage(),
    '应用': const AppSettingsPage(),
    '插件': const PluginsPage(),
    '网络': const NetworkPage(),
    '系统日志': const LogsPage(),
    '定时任务': const ScheduledTasksPage(),
    '外部访问': const ExternalAccessPage(),
    '我的设备': const DevicesPage(),
    '网页托管': const WebManagedPage(),
    '设置': const SettingsPage(),
    'Agent 技能': const SkillsPage(),
  };

  for (final entry in pages.entries) {
    testWidgets('P4 page renders: ${entry.key}', (tester) async {
      await _pumpPage(tester, entry.value);
      expect(find.text(entry.key), findsWidgets);
    });
  }

  testWidgets('chat page shows attachment button', (tester) async {
    await _pumpPage(tester, const ChatPage());
    expect(find.text('AI 助手'), findsOneWidget);
    expect(find.byTooltip('添加图片'), findsOneWidget);
  });

  testWidgets('activate page asks for device code', (tester) async {
    await _pumpPage(tester, const ActivatePage());
    expect(find.text('设备码'), findsOneWidget);
    expect(find.text('查询'), findsOneWidget);
  });

  testWidgets('logs page shows filter field', (tester) async {
    await _pumpPage(tester, const LogsPage());
    expect(find.text('过滤关键字'), findsOneWidget);
  });
}
