import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../state/controllers.dart';
import '../state/sections.dart';
import '../widgets/settings_ui.dart';
import 'activate_page.dart';
import 'ai_defaults_page.dart';
import 'appearance_page.dart';
import 'app_push_page.dart';
import 'app_settings_page.dart';
import 'cloud_page.dart';
import 'devices_page.dart';
import 'downloaders_page.dart';
import 'drives_page.dart';
import 'external_access_page.dart';
import 'im_push_page.dart';
import 'import_watch_page.dart';
import 'llm_page.dart';
import 'logs_page.dart';
import 'maintenance_page.dart';
import 'mcp_page.dart';
import 'members_page.dart';
import 'network_page.dart';
import 'notifications_settings_page.dart';
import 'overview_page.dart';
import 'playback_page.dart';
import 'plugins_page.dart';
import 'profile_page.dart';
import 'rule_sets_page.dart';
import 'scheduled_tasks_page.dart';
import 'scrape_page.dart';
import 'sites_page.dart';
import 'subscription_settings_page.dart';
import 'webhook_page.dart';

/// 设置索引页（对应安卓 feature/settings 的 SettingsSectionScreen）。
/// 分区来自 [settingsSections] 注册表（P4：25 个 parity 分区全部原生实现，
/// 另有设备激活与定时任务两个附加分区）。
/// 手机（compact）：单列列表 + push 二级页；
/// 平板/TV（medium/expanded）：左侧分区菜单 + 右侧详情 master-detail，
/// TV 下菜单项包 McFocusRing（docs/design/06-multi-device.md §2）。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

/// 分区条目：手机走 [route] push，平板/TV 走 [detail] master-detail。
class _SettingsEntry {
  const _SettingsEntry({
    required this.group,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.route,
    required this.detail,
  });

  final String group;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String route;
  final Widget detail;
}

Widget? _detailFor(String id) => switch (id) {
      'overview' => const OverviewPage(),
      'profile' => const ProfilePage(),
      'devices' => const DevicesPage(),
      'activate' => const ActivatePage(),
      'notifications' => const NotificationsSettingsPage(),
      'appearance' => const AppearancePage(),
      'members' => const MembersPage(),
      'subscription' => const SubscriptionSettingsPage(),
      'sites' => const SitesPage(),
      'downloaders' => const DownloadersPage(),
      'import-watch' => const ImportWatchPage(),
      'scrape' => const ScrapePage(),
      'playback' => const PlaybackPage(),
      'drives' => const DrivesPage(),
      'app-push' => const AppPushPage(),
      'im-push' => const ImPushPage(),
      'webhook' => const WebhookPage(),
      'llm' => const LlmPage(),
      'mcp' => const McpPage(),
      'ai' => const AiDefaultsPage(),
      'cloud' => const CloudPage(),
      'app' => const AppSettingsPage(),
      'plugins' => const PluginsPage(),
      'network' => const NetworkPage(),
      'logs' => const LogsPage(),
      'scheduled-tasks' => const ScheduledTasksPage(),
      'external-access' => const ExternalAccessPage(),
      _ => null,
    };

IconData _iconFor(String id) => switch (id) {
      'overview' => Icons.dashboard,
      'profile' => McIcons.accountCircle,
      'devices' => McIcons.device,
      'activate' => Icons.phonelink_setup,
      'notifications' => McIcons.bellOn,
      'appearance' => Icons.palette,
      'members' => Icons.badge,
      'subscription' => Icons.bookmark,
      'sites' => Icons.public,
      'downloaders' => Icons.download,
      'import-watch' => Icons.move_to_inbox,
      'scrape' => Icons.image,
      'playback' => McIcons.playCircle,
      'drives' => Icons.add_to_drive,
      'app-push' => Icons.notifications_active,
      'im-push' => Icons.chat,
      'webhook' => Icons.webhook,
      'llm' => Icons.auto_awesome,
      'mcp' => Icons.extension,
      'ai' => Icons.psychology,
      'cloud' => Icons.cloud,
      'app' => McIcons.tools,
      'plugins' => Icons.extension,
      'network' => Icons.language,
      'logs' => Icons.terminal,
      'scheduled-tasks' => Icons.schedule,
      'external-access' => Icons.lan,
      _ => Icons.settings,
    };

/// 跨域入口在 master-detail 右栏的占位：只放一个跳转按钮，
/// 不直接 import 别的功能目录的页面（模块铁律）。
class _OpenRouteDetail extends StatelessWidget {
  const _OpenRouteDetail({required this.route, required this.label});

  final String route;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton(
          onPressed: () => context.push(route),
          child: Text(label),
        ),
      );
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _selected = 0;

  List<_SettingsEntry> _entries(bool isAdmin, String? displayName) {
    final entries = <_SettingsEntry>[];
    for (final s in visibleSections(isAdmin)) {
      final detail = _detailFor(s.id);
      if (detail == null) continue;
      entries.add(_SettingsEntry(
        group: s.group,
        icon: _iconFor(s.id),
        title: s.title,
        subtitle: s.id == 'profile'
            ? displayName
            : (s.subtitle.isEmpty ? null : s.subtitle),
        route: s.route,
        detail: detail,
      ));
    }
    // 规则集：订阅设置的附属页，不占 web 分区名额，挂在“下载”组。
    entries.add(const _SettingsEntry(
      group: '下载',
      icon: Icons.rule,
      title: '规则集',
      subtitle: '订阅抓取的资源筛选规则',
      route: '/settings/rule-sets',
      detail: RuleSetsPage(),
    ));
    // 服务器维护与检查更新：沿用既有页（维护是 app 分区的运维视角）。
    if (isAdmin) {
      entries.add(const _SettingsEntry(
        group: '系统',
        icon: McIcons.tools,
        title: '服务器维护',
        subtitle: '版本 / 重启 / 存储清理',
        route: '/settings/maintenance',
        detail: MaintenancePage(),
      ));
    }
    entries.add(const _SettingsEntry(
      group: '系统',
      icon: Icons.system_update_outlined,
      title: '检查更新',
      subtitle: '客户端版本与升级',
      route: '/update',
      // 跨域页（update feature）：master-detail 右栏只放跳转按钮，
      // 不直接 import 别的功能目录的页面（模块铁律）。
      detail: _OpenRouteDetail(route: '/update', label: '打开检查更新'),
    ));
    // 按分组顺序排：注册表已按组排好，附加项插到组内末尾。
    entries.sort((a, b) {
      final ga = settingsGroups.indexOf(a.group);
      final gb = settingsGroups.indexOf(b.group);
      if (ga != gb) return ga.compareTo(gb);
      return 0;
    });
    return entries;
  }

  void _openEntry(
      _SettingsEntry e, int index, McDeviceForm form) {
    // 手机一律 push 路由；平板/TV 用 master-detail 右栏。
    if (form == McDeviceForm.phone) {
      context.push(e.route);
      return;
    }
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(profileProvider).valueOrNull;
    final isAdmin = session?.isAdmin ?? false;
    final form = ref.watch(mcFormProvider);
    final entries = _entries(isAdmin, session?.displayName);

    // 手机：单列列表 + push 二级页。
    if (form == McDeviceForm.phone) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i == 0 || entries[i].group != entries[i - 1].group)
                SettingsGroupLabel(entries[i].group),
              SettingsRow(
                icon: entries[i].icon,
                title: entries[i].title,
                subtitle: entries[i].subtitle,
                onTap: () => _openEntry(entries[i], i, form),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // 平板/TV：master-detail（左分区菜单右详情）。
    final selected = entries[_selected.clamp(0, entries.length - 1)];
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: McFormWatch(
        form: form,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
              child: FocusTraversalGroup(
                child: ListView(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i == 0 || entries[i].group != entries[i - 1].group)
                        SettingsGroupLabel(entries[i].group),
                      McFocusRing(
                        child: ListTile(
                          leading: Icon(entries[i].icon),
                          title: Text(entries[i].title),
                          subtitle: entries[i].subtitle == null ||
                                  entries[i].subtitle!.isEmpty
                              ? null
                              : Text(entries[i].subtitle!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                          selected: i == _selected,
                          onTap: () => _openEntry(entries[i], i, form),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_selected),
                child: selected.detail,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
