import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../state/controllers.dart';
import '../widgets/settings_ui.dart';
import 'devices_page.dart';
import 'maintenance_page.dart';
import 'playback_page.dart';
import 'profile_page.dart';
import 'web_managed_page.dart';

/// 设置索引页（对应安卓 feature/settings 的 SettingsSectionScreen：
/// 分组「账号 / 播放 / 服务器」，超管多一组维护入口）。
/// 手机（compact）：单列列表 + push 二级页（现状零差异）；
/// 平板/TV（medium/expanded）：左侧分区菜单 + 右侧详情 master-detail，
/// TV 下菜单项包 McFocusRing（docs/design/06-multi-device.md §2）。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

/// 分区条目：本域分区带 [detail]（master-detail 右栏），
/// 跨域入口（通知/更新）只带 [route]，点击仍走路由 push。
class _SettingsEntry {
  const _SettingsEntry({
    required this.group,
    required this.icon,
    required this.title,
    this.subtitle,
    this.route,
    this.detail,
  });

  final String group;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? route;
  final Widget? detail;
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _selected = 0;

  List<_SettingsEntry> _entries(bool isAdmin, String? displayName) => [
        _SettingsEntry(
          group: '账号',
          icon: Icons.person_outline,
          title: '个人信息',
          subtitle: displayName,
          detail: const ProfilePage(),
        ),
        const _SettingsEntry(
          group: '账号',
          icon: Icons.devices_other,
          title: '我的设备',
          subtitle: '已配对的登录设备与播放器',
          detail: DevicesPage(),
        ),
        const _SettingsEntry(
          group: '账号',
          icon: Icons.notifications_none,
          title: '通知与提醒',
          subtitle: '服务器公告与告警',
          route: '/notices',
        ),
        const _SettingsEntry(
          group: '播放',
          icon: Icons.play_circle_outline,
          title: '播放设置',
          subtitle: '转码 / 预览图 / 缓存',
          detail: PlaybackPage(),
        ),
        const _SettingsEntry(
          group: '服务器',
          icon: Icons.public,
          title: '网页托管',
          subtitle: '在浏览器里打开服务器管理页',
          detail: WebManagedPage(),
        ),
        if (isAdmin)
          const _SettingsEntry(
            group: '服务器',
            icon: Icons.build_outlined,
            title: '服务器维护',
            subtitle: '版本 / 重启 / 存储清理',
            detail: MaintenancePage(),
          ),
        const _SettingsEntry(
          group: '服务器',
          icon: Icons.system_update_outlined,
          title: '检查更新',
          subtitle: '客户端版本与升级',
          route: '/update',
        ),
      ];

  void _openEntry(_SettingsEntry e, int index) {
    if (e.route != null) {
      context.push(e.route!);
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

    // 手机：单列列表 + push 二级页（与原实现零差异）。
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
                onTap: () => _openEntry(entries[i], i),
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
                          selected: entries[i].detail != null && i == _selected,
                          onTap: () => _openEntry(entries[i], i),
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
                child: selected.detail ??
                    const Center(child: Text('请在左侧选择分区')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
