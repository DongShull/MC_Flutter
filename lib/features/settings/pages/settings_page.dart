import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../../../core/session/permissions.dart';
import '../state/controllers.dart';
import '../widgets/settings_ui.dart';
import 'about_language_pages.dart';
import 'admin_pipeline_pages.dart';
import 'admin_system_pages.dart';
import 'cloud_settings_page.dart';
import 'devices_page.dart';
import 'maintenance_page.dart';
import 'mcp_settings_page.dart';
import 'notification_settings_page.dart';
import 'playback_page.dart';
import 'profile_page.dart';
import 'push_channels_page.dart';

/// 全平台全量原生设置与管理中心：
/// - 严格按 permissionsProvider 控制管理员分区可见性（默认非管理员）；
/// - 手机（compact）：圆角分组卡片 + push 原生二级页；
/// - 平板 / 桌面 / TV（medium / expanded）：左侧银玻璃侧栏 + 右侧 Master-Detail 双栏布局。
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

  List<_SettingsEntry> _entries({
    required bool isAdmin,
    required String? displayName,
    required McAppLanguage language,
  }) {
    final langLabel = language.nativeName;

    return [
      // ---- 个人与偏好（全员可见）----
      _SettingsEntry(
        group: '个人与终端',
        icon: McIcons.accountCircle,
        title: '个人信息',
        subtitle: displayName,
        phoneRoute: '/settings/profile',
        detail: const ProfilePage(),
      ),
      const _SettingsEntry(
        group: '个人与终端',
        icon: McIcons.device,
        title: '我的设备',
        subtitle: '已登录终端、配对审批与 API 令牌',
        phoneRoute: '/settings/devices',
        detail: DevicesPage(),
      ),
      const _SettingsEntry(
        group: '个人与终端',
        icon: McIcons.bellOn,
        title: '通知偏好',
        subtitle: '推送权限、事件开关、分库订阅与静音剧集',
        phoneRoute: '/settings/notifications',
        detail: NotificationSettingsPage(),
      ),
      const _SettingsEntry(
        group: '播放与媒体',
        icon: McIcons.playCircle,
        title: '播放设置',
        subtitle: '软硬解、已看判定、Trickplay、片段预切与远程转码',
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
          title: '刮削与整理',
          subtitle: '语言/分级顺序、Fanart、图片质量、命名模板与网盘挂载',
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
          title: '选种规则组',
          subtitle: '分辨率/编码/HDR/平台/免费促销与升降级规则',
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
          group: '家庭与通知通道',
          icon: McIcons.team,
          title: '家庭成员',
          subtitle: '成员权限、年龄分级、媒体库/站点范围与强制下线',
          phoneRoute: '/settings/members',
          detail: MembersAdminPage(),
        ),
        const _SettingsEntry(
          group: '家庭与通知通道',
          icon: McIcons.chat,
          title: 'IM 推送通道',
          subtitle: 'Telegram / 微信 / 企业微信 / 飞书 / 钉钉机器人绑定',
          phoneRoute: '/settings/push',
          detail: PushChannelsPage(),
        ),
        const _SettingsEntry(
          group: '家庭与通知通道',
          icon: McIcons.sendPlane,
          title: 'Webhook',
          subtitle: '事件订阅、模板与 HMAC 签名、投递记录排查',
          phoneRoute: '/settings/webhook',
          detail: WebhookSettingsPage(),
        ),
        const _SettingsEntry(
          group: 'AI 与云端服务',
          icon: McIcons.aiStarFill,
          title: '大模型、AI 默认与联网搜索',
          subtitle: 'LLM 供应商、助手/字幕默认模型与 Tavily/Brave 搜索',
          phoneRoute: '/settings/ai',
          detail: AiIntegrationsAdminPage(),
        ),
        const _SettingsEntry(
          group: 'AI 与云端服务',
          icon: McIcons.codeBox,
          title: 'MCP 服务',
          subtitle: '服务端点令牌、连通探测与可用工具目录',
          phoneRoute: '/settings/mcp',
          detail: McpSettingsPage(),
        ),
        const _SettingsEntry(
          group: 'AI 与云端服务',
          icon: McIcons.cloud,
          title: 'MovieClaw Cloud',
          subtitle: '云端配对、推送配额、统计上报与账号管理',
          phoneRoute: '/settings/cloud',
          detail: CloudSettingsPage(),
        ),
        const _SettingsEntry(
          group: '系统运维',
          icon: McIcons.terminal,
          title: '网络、定时任务与系统日志',
          subtitle: '代理分流、外部地址与端口、计划任务、插件与在线日志',
          phoneRoute: '/settings/system',
          detail: NetworkTasksLogsAdminPage(),
        ),
        const _SettingsEntry(
          group: '系统运维',
          icon: McIcons.tools,
          title: '更新、缓存与维护',
          subtitle: '服务端热更新、NER 模型、版本回退与磁盘清理',
          phoneRoute: '/settings/maintenance',
          detail: MaintenancePage(),
        ),
      ],
      // ---- 通用与关于（全员可见）----
      _SettingsEntry(
        group: '通用与关于',
        icon: McIcons.translate,
        title: '语言设置',
        subtitle: langLabel,
        phoneRoute: '/settings/language',
        detail: const LanguageSettingsPage(),
      ),
      const _SettingsEntry(
        group: '通用与关于',
        icon: McIcons.dataupgrade,
        title: '检查客户端更新',
        subtitle: '查看客户端与服务端最新版本通道',
        route: '/update',
      ),
      const _SettingsEntry(
        group: '通用与关于',
        icon: McIcons.information,
        title: '关于 MovieClaw',
        subtitle: '版本信息、隐私政策、开源许可与 TMDB 声明',
        phoneRoute: '/settings/about',
        detail: AboutPage(),
      ),
    ];
  }

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
    // 严格以 permissionsProvider 为准（绝不默认 true）
    final perms = ref.watch(permissionsProvider);
    final session = ref.watch(profileProvider).valueOrNull;
    final isAdmin = perms.isAdmin || (session?.isAdmin ?? false);
    final language = ref.watch(mcLanguageProvider);
    final form = McFormWatch.of(context);
    final entries = _entries(
      isAdmin: isAdmin,
      displayName: session?.displayName,
      language: language,
    );

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
