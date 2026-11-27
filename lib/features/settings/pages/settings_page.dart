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
    required this.id,
    required this.group,
    required this.icon,
    required this.title,
    this.subtitle,
    this.route,
    this.phoneRoute,
    this.detail,
  });

  final String id;
  final String group;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? route;
  final String? phoneRoute;
  final Widget? detail;
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _selectedId = 'profile';

  List<_SettingsEntry> _entries({
    required bool isAdmin,
    required String? displayName,
    required McAppLanguage language,
    required McL10n l10n,
  }) {
    final langLabel = language.nativeName;

    return [
      // ---- 个人与偏好（全员可见）----
      _SettingsEntry(
        id: 'profile',
        group: l10n.settingsGroupPersonal,
        icon: McIcons.accountCircle,
        title: l10n.settingsProfile,
        subtitle: displayName,
        phoneRoute: '/settings/profile',
        detail: const ProfilePage(),
      ),
      _SettingsEntry(
        id: 'devices',
        group: l10n.settingsGroupPersonal,
        icon: McIcons.device,
        title: l10n.settingsMyDevices,
        subtitle: '已登录终端、配对审批与 API 令牌',
        phoneRoute: '/settings/devices',
        detail: const DevicesPage(),
      ),
      _SettingsEntry(
        id: 'notifications',
        group: l10n.settingsGroupPersonal,
        icon: McIcons.bellOn,
        title: l10n.settingsNotificationPrefs,
        subtitle: '推送权限、事件开关、分库订阅与静音剧集',
        phoneRoute: '/settings/notifications',
        detail: const NotificationSettingsPage(),
      ),
      _SettingsEntry(
        id: 'playback',
        group: l10n.settingsGroupPlayback,
        icon: McIcons.playCircle,
        title: l10n.settingsPlaybackTitle,
        subtitle: '软硬解、已看判定、Trickplay、片段预切与远程转码',
        phoneRoute: '/settings/playback',
        detail: const PlaybackPage(),
      ),
      if (isAdmin) ...[
        _SettingsEntry(
          id: 'library_manage',
          group: l10n.settingsGroupPlayback,
          icon: McIcons.mediaLibraryFill,
          title: l10n.settingsEntryLibraryManage,
          subtitle: '创建/扫描媒体库、服务端目录浏览、回收站与外链分享',
          route: '/library/manage',
        ),
        _SettingsEntry(
          id: 'scrape',
          group: l10n.settingsGroupPlayback,
          icon: McIcons.imageEdit,
          title: l10n.settingsEntryScrape,
          subtitle: '语言/分级顺序、Fanart、图片质量、命名模板与网盘挂载',
          phoneRoute: '/settings/scrape',
          detail: const ScrapeDrivesAdminPage(),
        ),
        _SettingsEntry(
          id: 'overview',
          group: l10n.settingsGroupAutomation,
          icon: McIcons.dashboard,
          title: l10n.settingsEntryOverview,
          subtitle: '端到端追更就绪度自检',
          phoneRoute: '/settings/overview',
          detail: const AutomationOverviewPage(),
        ),
        _SettingsEntry(
          id: 'rules',
          group: l10n.settingsGroupAutomation,
          icon: McIcons.listSettings2,
          title: l10n.settingsEntryRules,
          subtitle: '分辨率/编码/HDR/平台/免费促销与升降级规则',
          phoneRoute: '/settings/rules',
          detail: const RuleSetsAdminPage(),
        ),
        _SettingsEntry(
          id: 'sites',
          group: l10n.settingsGroupAutomation,
          icon: McIcons.globe,
          title: l10n.settingsEntrySites,
          subtitle: '站点 Cookie/APIKey 管理、连通测速与同步令牌',
          phoneRoute: '/settings/sites',
          detail: const SitesAdminPage(),
        ),
        _SettingsEntry(
          id: 'downloaders',
          group: l10n.settingsGroupAutomation,
          icon: McIcons.downloadCloudOut,
          title: l10n.settingsEntryDownloaders,
          subtitle: 'qBittorrent / Transmission 与完成目录自动入库',
          phoneRoute: '/settings/downloaders',
          detail: const DownloadersAdminPage(),
        ),
        _SettingsEntry(
          id: 'members',
          group: l10n.settingsGroupFamilyNotify,
          icon: McIcons.team,
          title: l10n.settingsEntryMembers,
          subtitle: '成员权限、年龄分级、媒体库/站点范围与强制下线',
          phoneRoute: '/settings/members',
          detail: const MembersAdminPage(),
        ),
        _SettingsEntry(
          id: 'push',
          group: l10n.settingsGroupFamilyNotify,
          icon: McIcons.chat,
          title: l10n.settingsEntryPush,
          subtitle: 'Telegram / 微信 / 企业微信 / 飞书 / 钉钉机器人绑定',
          phoneRoute: '/settings/push',
          detail: const PushChannelsPage(),
        ),
        _SettingsEntry(
          id: 'webhook',
          group: l10n.settingsGroupFamilyNotify,
          icon: McIcons.sendPlane,
          title: l10n.settingsEntryWebhook,
          subtitle: '事件订阅、模板与 HMAC 签名、投递记录排查',
          phoneRoute: '/settings/webhook',
          detail: const WebhookSettingsPage(),
        ),
        _SettingsEntry(
          id: 'ai',
          group: l10n.settingsGroupAiCloud,
          icon: McIcons.aiStarFill,
          title: l10n.settingsEntryAi,
          subtitle: 'LLM 供应商、助手/字幕默认模型与 Tavily/Brave 搜索',
          phoneRoute: '/settings/ai',
          detail: const AiIntegrationsAdminPage(),
        ),
        _SettingsEntry(
          id: 'mcp',
          group: l10n.settingsGroupAiCloud,
          icon: McIcons.codeBox,
          title: l10n.settingsEntryMcp,
          subtitle: '服务端点令牌、连通探测与可用工具目录',
          phoneRoute: '/settings/mcp',
          detail: const McpSettingsPage(),
        ),
        _SettingsEntry(
          id: 'cloud',
          group: l10n.settingsGroupAiCloud,
          icon: McIcons.cloud,
          title: l10n.settingsEntryCloud,
          subtitle: '云端配对、推送配额、统计上报与账号管理',
          phoneRoute: '/settings/cloud',
          detail: const CloudSettingsPage(),
        ),
        _SettingsEntry(
          id: 'system',
          group: l10n.settingsGroupOps,
          icon: McIcons.terminal,
          title: l10n.settingsEntrySystem,
          subtitle: '代理分流、外部地址与端口、计划任务、插件与在线日志',
          phoneRoute: '/settings/system',
          detail: const NetworkTasksLogsAdminPage(),
        ),
        _SettingsEntry(
          id: 'maintenance',
          group: l10n.settingsGroupOps,
          icon: McIcons.tools,
          title: l10n.settingsEntryMaintenance,
          subtitle: '服务端热更新、NER 模型、版本回退与磁盘清理',
          phoneRoute: '/settings/maintenance',
          detail: const MaintenancePage(),
        ),
      ],
      // ---- 通用与关于（全员可见）----
      _SettingsEntry(
        id: 'language',
        group: l10n.settingsGroupGeneral,
        icon: McIcons.translate,
        title: l10n.settingsLanguagePageTitle,
        subtitle: langLabel,
        phoneRoute: '/settings/language',
        detail: const LanguageSettingsPage(),
      ),
      _SettingsEntry(
        id: 'update',
        group: l10n.settingsGroupGeneral,
        icon: McIcons.dataupgrade,
        title: l10n.settingsEntryCheckUpdate,
        subtitle: '查看客户端与服务端最新版本通道',
        route: '/update',
      ),
      _SettingsEntry(
        id: 'about',
        group: l10n.settingsGroupGeneral,
        icon: McIcons.information,
        title: l10n.aboutTitle,
        subtitle: '版本信息、隐私政策、开源许可与 TMDB 声明',
        phoneRoute: '/settings/about',
        detail: const AboutPage(),
      ),
    ];
  }

  void _openEntry(_SettingsEntry e, {required bool usePush}) {
    if (e.route != null) {
      context.push(e.route!);
      return;
    }
    if (usePush && e.phoneRoute != null) {
      context.push(e.phoneRoute!);
      return;
    }
    setState(() => _selectedId = e.id);
  }

  @override
  Widget build(BuildContext context) {
    // 严格以 permissionsProvider 为准（绝不默认 true）
    final perms = ref.watch(permissionsProvider);
    final session = ref.watch(profileProvider).valueOrNull;
    final isAdmin = perms.isAdmin || (session?.isAdmin ?? false);
    final language = ref.watch(mcLanguageProvider);
    final l10n = McL10n.of(context);
    final form = McFormWatch.of(context);
    final width = MediaQuery.widthOf(context);
    final useSplitLayout = form != McDeviceForm.phone && width >= 720;
    final entries = _entries(
      isAdmin: isAdmin,
      displayName: session?.displayName,
      language: language,
      l10n: l10n,
    );

    final topBar = McFloatingDetailBar(
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      title: l10n.settingsHubTitle,
      titleVisible: true,
    );

    if (!useSplitLayout) {
      final groups = <String, List<_SettingsEntry>>{};
      for (final entry in entries) {
        groups.putIfAbsent(entry.group, () => []).add(entry);
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
                        for (final entry in group.value)
                          McInsetRow(
                            icon: entry.icon,
                            title: entry.title,
                            subtitle: entry.subtitle,
                            onTap: () => _openEntry(entry, usePush: true),
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

    final selected = entries.firstWhere(
      (e) => e.id == _selectedId && e.detail != null,
      orElse: () => entries.firstWhere(
        (e) => e.detail != null,
        orElse: () => entries.first,
      ),
    );
    final sidebarWidth = width < 960 ? 240.0 : 288.0;

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
                    width: sidebarWidth,
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
                                      entries[i].id == selected.id,
                                  onTap: () => _openEntry(
                                    entries[i],
                                    usePush: false,
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
                        key: ValueKey(selected.id),
                        child: selected.detail ??
                            Center(
                              child: Text(
                                l10n.settingsSelectSectionHint,
                                style: McText.sub.muted,
                              ),
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
