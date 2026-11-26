import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';
import '../widgets/settings_ui.dart';
import 'admin_pipeline_pages.dart';
import 'admin_system_pages.dart';
import 'devices_page.dart';
import 'maintenance_page.dart';
import 'playback_page.dart';
import 'profile_page.dart';

/// 全平台全量原生设置与管理中心（彻底干掉 iOS/Android 的「去网页端操作」甩锅页）：
/// - 手机（compact）：圆角分组卡片 + push 原生二级页；
/// - 平板 / 桌面 / TV（medium / expanded）：左侧银玻璃侧栏 + 右侧实时 Master-Detail 双栏布局。
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
          group: '个人与终端',
          icon: McIcons.accountCircle,
          title: '个人信息与账号',
          subtitle: displayName,
          phoneRoute: '/settings/profile',
          detail: const ProfilePage(),
        ),
        const _SettingsEntry(
          group: '个人与终端',
          icon: McIcons.device,
          title: '我的设备与配对审批',
          subtitle: '已登录终端、配对码批准与 API 令牌',
          phoneRoute: '/settings/devices',
          detail: DevicesPage(),
        ),
        const _SettingsEntry(
          group: '个人与终端',
          icon: McIcons.bellOn,
          title: '系统通知与提醒',
          subtitle: '服务器公告、入库通知与健康告警',
          route: '/notices',
        ),
        const _SettingsEntry(
          group: '播放与媒体',
          icon: McIcons.playCircle,
          title: '播放与硬件转码',
          subtitle: '软硬解策略、Trickplay 预览图与片头片尾自动跳过',
          phoneRoute: '/settings/playback',
          detail: PlaybackPage(),
        ),
        if (isAdmin) ...[
          const _SettingsEntry(
            group: '播放与媒体',
            icon: McIcons.mediaLibraryFill,
            title: '媒体库与异常文件管控',
            subtitle: '创建/扫描媒体库、服务端目录浏览、回收站与外链分享',
            route: '/library/manage',
          ),
          const _SettingsEntry(
            group: '播放与媒体',
            icon: McIcons.imageEdit,
            title: '刮削元数据与网盘挂载',
            subtitle: '语言优先级、NFO 落地、Fanart 与网盘直连',
            phoneRoute: '/settings/scrape',
            detail: ScrapeDrivesAdminPage(),
          ),
          const _SettingsEntry(
            group: '自动化追更引擎',
            icon: McIcons.dashboard,
            title: '自动化流水线巡检',
            subtitle: '端到端追更就绪度自检',
            phoneRoute: '/settings/overview',
            detail: AutomationOverviewPage(),
          ),
          const _SettingsEntry(
            group: '自动化追更引擎',
            icon: McIcons.listSettings2,
            title: '订阅策略与选种规则组',
            subtitle: '4K/HDR/关键词过滤与免费促销规则',
            phoneRoute: '/settings/rules',
            detail: RuleSetsAdminPage(),
          ),
          const _SettingsEntry(
            group: '自动化追更引擎',
            icon: McIcons.globe,
            title: 'PT 索引站点与插件同步',
            subtitle: '站点 Cookie/APIKey 管理、连通测速与同步令牌',
            phoneRoute: '/settings/sites',
            detail: SitesAdminPage(),
          ),
          const _SettingsEntry(
            group: '自动化追更引擎',
            icon: McIcons.downloadCloudOut,
            title: '下载器与目录监控',
            subtitle: 'qBittorrent / Transmission 与完成目录自动入库',
            phoneRoute: '/settings/downloaders',
            detail: DownloadersAdminPage(),
          ),
          const _SettingsEntry(
            group: '家庭、AI 与系统运维',
            icon: McIcons.team,
            title: '家庭成员与权限管理',
            subtitle: '新增成员、重置密码与角色分配',
            phoneRoute: '/settings/members',
            detail: MembersAdminPage(),
          ),
          const _SettingsEntry(
            group: '家庭、AI 与系统运维',
            icon: McIcons.aiStarFill,
            title: 'AI 大模型与 Webhook 集成',
            subtitle: 'LLM 供应商、默认助手模型与外部消息推送',
            phoneRoute: '/settings/ai',
            detail: AiIntegrationsAdminPage(),
          ),
          const _SettingsEntry(
            group: '家庭、AI 与系统运维',
            icon: McIcons.terminal,
            title: '网络代理、定时任务与实时日志',
            subtitle: 'LAN/WAN 双栈地址簿、代理测速、插件与日志查看',
            phoneRoute: '/settings/system',
            detail: NetworkTasksLogsAdminPage(),
          ),
          const _SettingsEntry(
            group: '家庭、AI 与系统运维',
            icon: McIcons.tools,
            title: '服务器维护与缓存清理',
            subtitle: '服务版本、进程重启与存储清理',
            phoneRoute: '/settings/maintenance',
            detail: MaintenancePage(),
          ),
        ],
        const _SettingsEntry(
          group: '关于与升级',
          icon: McIcons.dataupgrade,
          title: '检查版本更新',
          subtitle: '客户端与服务端热升级通道',
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
    final isAdmin = session?.isAdmin ?? true;
    final form = McFormWatch.of(context);
    final entries = _entries(isAdmin, session?.displayName);

    final topBar = McFloatingDetailBar(
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      title: '设置与控制中心',
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
                            onTap: () => _openEntry(entry, idx, isPhone: true),
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
                    width: 288,
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
