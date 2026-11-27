import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/auth/session_watch.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/session_store.dart';
import '../../offline/embed.dart';
import '../state/controllers.dart';
import '../widgets/conversations_section.dart';
import '../widgets/downloads_section.dart';
import '../widgets/profile_actions.dart';
import '../widgets/profile_card.dart';
import '../widgets/section_picker.dart';
import '../widgets/server_section.dart';

/// 「我的」页分段（会话 / 下载 / 服务器）。
enum MoreSection { conversations, downloads, server }

/// 「我的」主标签页（1:1 对齐 iOS `MorePage.swift`）：
/// - 顶栏右上扫码按钮直接拉起二维码扫描（`scanFirst: true`）；
/// - 分段按 `isAdmin`、`canDownloadVideo`、`hasDownloads` 与在线状态动态裁剪；
/// - 服务器分段胶囊圆点：有未处理告警亮红点，仅待更新亮信息蓝点。
class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});

  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage> {
  MoreSection _selectedSection = MoreSection.conversations;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(moreProvider.notifier).load());
  }

  /// 对齐 iOS `MorePageSection.available(isAdmin:canDownload:hasDownloads:isOffline:)`。
  List<MoreSection> _availableSections({
    required bool isAdmin,
    required bool canDownload,
    required bool hasDownloads,
    required bool isOffline,
  }) =>
      [
        if (isAdmin && !isOffline) MoreSection.conversations,
        if (canDownload || hasDownloads) MoreSection.downloads,
        if (!isOffline) MoreSection.server,
      ];

  String _roleLabel(String role) => switch (role) {
        'admin' => '超级管理员',
        'member' => '成员',
        '' => '',
        _ => '访客',
      };

  String _labelOf(MoreSection s) => switch (s) {
        MoreSection.conversations => McStrings.sectionConversations,
        MoreSection.downloads => McStrings.sectionDownloads,
        MoreSection.server => McStrings.sectionServer,
      };

  IconData _iconOf(MoreSection s) => switch (s) {
        MoreSection.conversations => McIcons.comment,
        MoreSection.downloads => McIcons.fileDownload,
        MoreSection.server => McIcons.server,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(moreProvider);
    final perms = ref.watch(mcPermissionsProvider);
    final offline = ref.watch(offlineProvider);
    final form = ref.watch(mcFormProvider);
    final wide = form != McDeviceForm.phone;
    final data = state.valueOrNull;
    final session = data?.session;

    final username = (session?['username'] ?? perms.username).toString();
    final meNickname = (session?['nickname'] ?? perms.nickname).toString();
    final nickname = meNickname.isNotEmpty
        ? meNickname
        : (username.isNotEmpty ? username : McStrings.notLoggedIn);
    final isAdmin = perms.isAdmin || (session?['role'] ?? '').toString() == 'admin';
    final roleLabel = _roleLabel(
      (session?['role'] ?? perms.role).toString(),
    );

    final hasDownloads =
        offline.activeUnits.isNotEmpty || offline.doneUnits.isNotEmpty;
    final isOffline = data?.isOffline ?? false;
    final sections = _availableSections(
      isAdmin: isAdmin,
      canDownload: perms.canDownloadVideo,
      hasDownloads: hasDownloads,
      isOffline: isOffline,
    );
    final visibleSection = sections.contains(_selectedSection)
        ? _selectedSection
        : (sections.isNotEmpty ? sections.first : null);
    final selectedIdx =
        visibleSection == null ? 0 : sections.indexOf(visibleSection);

    final noticeCount = data?.noticeCount ?? 0;
    final updatePending = data?.updatePending ?? false;
    final serverIdx = sections.indexOf(MoreSection.server);
    final showServerBadge =
        isAdmin && serverIdx >= 0 && (noticeCount > 0 || updatePending);
    final serverBadgeColor =
        noticeCount > 0 ? McTokens.danger : McTokens.info;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (isAdmin &&
              visibleSection == MoreSection.conversations &&
              n.metrics.axis == Axis.vertical &&
              n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            ref.read(moreProvider.notifier).loadMoreSessions();
          }
          return false;
        },
        child: RefreshIndicator(
          edgeOffset: MediaQuery.paddingOf(context).top + 56,
          color: McTokens.accentStrong,
          backgroundColor: McTokens.surfaceSolid,
          onRefresh: () => ref.read(moreProvider.notifier).load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              McSliverTopBar(
                title: McStrings.moreTab,
                actions: [
                  if (!isOffline) ...[
                    McGlassIconButton(
                      icon: McIcons.scan,
                      tooltip: '扫码批准设备登录',
                      onTap: () => ProfileActions.approveLogin(
                        context,
                        ref,
                        scanFirst: true,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
                onSearch: isOffline ? null : () => context.push('/search'),
              ),
              if (state.isLoading && data == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: McLoadingView(),
                )
              else if (state.hasError && data == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: McErrorView(
                    text: McStrings.networkError,
                    onRetry: () => ref.read(moreProvider.notifier).load(),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 760 : double.infinity,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProfileCard(
                              nickname: nickname,
                              username: username,
                              roleLabel: roleLabel,
                              avatarUrl: (data?.session?['avatar_url'] ??
                                      appSession.avatarUrl)
                                  ?.toString(),
                              onSwitchAccount: () =>
                                  ProfileActions.switchAccount(context),
                              onApproveLogin: () =>
                                  ProfileActions.approveLogin(context, ref),
                              onLogout: () =>
                                  ProfileActions.logout(context, ref),
                            ),
                            if (sections.length > 1)
                              SectionPicker(
                                labels: [for (final s in sections) _labelOf(s)],
                                icons: [for (final s in sections) _iconOf(s)],
                                selected: selectedIdx,
                                badgeIndex:
                                    showServerBadge ? serverIdx : null,
                                badgeColor: serverBadgeColor,
                                onSelect: (i) => setState(
                                  () => _selectedSection = sections[i],
                                ),
                              ),
                            const SizedBox(height: 8),
                            if (visibleSection == MoreSection.conversations)
                              const ConversationsSection()
                            else if (visibleSection == MoreSection.downloads)
                              const DownloadsSection()
                            else if (visibleSection == MoreSection.server)
                              ServerSection(
                                host: ref.watch(sessionStoreProvider).baseUrl ??
                                    '',
                                isAdmin: isAdmin,
                                noticeCount: noticeCount,
                                updateLabel: data?.pendingUpdateLabel,
                              ),
                            if (visibleSection == MoreSection.conversations &&
                                (data?.loadingMore ?? false))
                              const SizedBox(
                                height: 48,
                                child: McLoadingView(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
