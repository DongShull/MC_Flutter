import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';
import '../widgets/settings_ui.dart';
import 'devices_page.dart';
import 'maintenance_page.dart';
import 'playback_page.dart';
import 'profile_page.dart';
import 'web_managed_page.dart';

/// 设置索引页（对应安卓 feature/settings 的 SettingsSectionScreen：
/// 分组「账号 / 播放 / 服务器」，超管多一组维护入口）。
/// 手机（compact）：圆角分组卡片 + push 二级页；
/// 平板/TV（medium/expanded）：左侧毛玻璃菜单栏 + 右侧详情 master-detail，
/// TV 下菜单项包 McFocusRing。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsEntry {
  const _SettingsEntry({
    required this.group,
    required this.icon,
    required this.title,
    this.subtitle,
    this.route,
    this.phoneRoute,
    this.detail,
  });

  final String group;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? route;
  final String? phoneRoute;
  final Widget? detail;
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _selected = 0;

  List<_SettingsEntry> _entries(bool isAdmin, String? displayName) => [
        _SettingsEntry(
          group: '账号',
          icon: McIcons.accountCircle,
          title: '个人信息',
          subtitle: displayName,
          phoneRoute: '/settings/profile',
          detail: const ProfilePage(),
        ),
        const _SettingsEntry(
          group: '账号',
          icon: McIcons.device,
          title: '我的设备',
          subtitle: '已配对的登录设备与播放器',
          phoneRoute: '/settings/devices',
          detail: DevicesPage(),
        ),
        const _SettingsEntry(
          group: '账号',
          icon: McIcons.bellOn,
          title: '通知与提醒',
          subtitle: '服务器公告与告警',
          route: '/notices',
        ),
        const _SettingsEntry(
          group: '播放',
          icon: McIcons.playCircle,
          title: '播放设置',
          subtitle: '转码 / 预览图 / 缓存',
          phoneRoute: '/settings/playback',
          detail: PlaybackPage(),
        ),
        const _SettingsEntry(
          group: '服务器',
          icon: McIcons.globe,
          title: '网页托管',
          subtitle: '在浏览器里打开服务器管理页',
          phoneRoute: '/settings/web',
          detail: WebManagedPage(),
        ),
        if (isAdmin)
          const _SettingsEntry(
            group: '服务器',
            icon: McIcons.tools,
            title: '服务器维护',
            subtitle: '版本 / 重启 / 存储清理',
            phoneRoute: '/settings/maintenance',
            detail: MaintenancePage(),
          ),
        const _SettingsEntry(
          group: '服务器',
          icon: McIcons.dataupgrade,
          title: '检查更新',
          subtitle: '客户端版本与升级',
          route: '/update',
        ),
      ];

  void _openEntry(_SettingsEntry e, int index, {required bool isPhone}) {
    if (e.route != null) {
      context.push(e.route!);
      return;
    }
    if (isPhone && e.phoneRoute != null) {
      context.push(e.phoneRoute!);
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

    final topBar = McFloatingDetailBar(
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      title: '设置',
      titleVisible: true,
    );

    if (form == McDeviceForm.phone) {
      final groups = <String, List<(int, _SettingsEntry)>>{};
      for (var i = 0; i < entries.length; i++) {
        groups.putIfAbsent(entries[i].group, () => []).add((i, entries[i]));
      }
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Column(
          children: [
            topBar,
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 36),
                children: [
                  for (final group in groups.entries) ...[
                    McInsetGroup(
                      header: group.key,
                      dividerIndent: 48,
                      children: [
                        for (final (idx, entry) in group.value)
                          McInsetRow(
                            icon: entry.icon,
                            title: entry.title,
                            subtitle: entry.subtitle,
                            onTap: () =>
                                _openEntry(entry, idx, isPhone: true),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final clampedIndex = _selected.clamp(0, entries.length - 1);
    final selected = entries[clampedIndex];
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: McFormWatch(
        form: form,
        child: Column(
          children: [
            topBar,
            const Divider(height: 1, color: McTokens.line),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 280,
                    decoration: const BoxDecoration(
                      color: McTokens.surfaceSidebar,
                      border: Border(
                        right: BorderSide(color: McTokens.line, width: 1),
                      ),
                    ),
                    child: FocusTraversalGroup(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        children: [
                          for (var i = 0; i < entries.length; i++) ...[
                            if (i == 0 ||
                                entries[i].group != entries[i - 1].group)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 14, 10, 6),
                                child: Text(
                                  entries[i].group,
                                  style: McText.caption.copyWith(
                                    color: McTokens.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: McFocusRing(
                                borderRadius: 12,
                                child: _SidebarTile(
                                  entry: entries[i],
                                  selected: entries[i].detail != null &&
                                      i == clampedIndex,
                                  onTap: () => _openEntry(
                                    entries[i],
                                    i,
                                    isPhone: false,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SettingsEmbeddedScope(
                      child: KeyedSubtree(
                        key: ValueKey(clampedIndex),
                        child: selected.detail ??
                            Center(
                              child: Text('请在左侧选择分区', style: McText.sub.muted),
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _SettingsEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? McTokens.glassFillActive : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                entry.icon,
                size: 19,
                color: selected ? McTokens.text : McTokens.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: McText.sub.copyWith(
                        color: McTokens.text,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.faint,
                      ),
                  ],
                ),
              ),
              if (entry.route != null)
                const Icon(
                  McIcons.chevronRight,
                  size: 14,
                  color: McTokens.textFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
