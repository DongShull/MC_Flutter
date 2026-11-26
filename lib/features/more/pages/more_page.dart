import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/session_store.dart';
import '../state/controllers.dart';
import '../widgets/conversations_section.dart';
import '../widgets/downloads_section.dart';
import '../widgets/profile_actions.dart';
import '../widgets/profile_card.dart';
import '../widgets/section_picker.dart';
import '../widgets/server_section.dart';

/// 「我的」页分段（会话 / 下载 / 服务器）。
enum MoreSection { conversations, downloads, server }

/// 「我的」主标签页（Tab 5，1:1 对齐 iOS `MoreView.swift`）：
/// - 纯黑画布 + 沉浸顶栏（左上大标题「我的」，右上批准登录扫码玻璃圆钮与全局搜索圆钮）；
/// - 居中大头像个人卡 → 三段液态胶囊切换器 `[ 会话 | 下载 | 服务器 ]` → 分段内容。
class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});

  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage> {
  int _sectionIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(moreProvider.notifier).load());
  }

  List<MoreSection> _availableSections(bool isAdmin) => [
    if (isAdmin) MoreSection.conversations,
    MoreSection.downloads,
    MoreSection.server,
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
    final form = ref.watch(mcFormProvider);
    final wide = form != McDeviceForm.phone;
    final data = state.valueOrNull;
    final session = data?.session;
    final username = (session?['username'] ?? '').toString();
    final meNickname = (session?['nickname'] ?? '').toString();
    final nickname = meNickname.isNotEmpty
        ? meNickname
        : (username.isNotEmpty ? username : McStrings.notLoggedIn);
    final isAdmin = (session?['role'] ?? '').toString() == 'admin';
    final roleLabel = _roleLabel((session?['role'] ?? '').toString());
    final sections = _availableSections(isAdmin);
    final selected = _sectionIndex < sections.length
        ? _sectionIndex
        : sections.length - 1;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (isAdmin &&
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
                  McGlassIconButton(
                    icon: McIcons.scan,
                    tooltip: '批准设备登录',
                    onTap: () => ProfileActions.approveLogin(context, ref),
                  ),
                  const SizedBox(width: 4),
                ],
                onSearch: () => context.push('/search'),
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
                              avatarUrl:
                                  (data?.session?['avatar_url'] ??
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
                                selected: selected,
                                badgeIndex:
                                    isAdmin && (data?.noticeCount ?? 0) > 0
                                    ? sections.indexOf(MoreSection.server)
                                    : null,
                                onSelect: (i) =>
                                    setState(() => _sectionIndex = i),
                              ),
                            const SizedBox(height: 8),
                            switch (sections[selected]) {
                              MoreSection.conversations =>
                                const ConversationsSection(),
                              MoreSection.downloads => const DownloadsSection(),
                              MoreSection.server => ServerSection(
                                host:
                                    ref.watch(sessionStoreProvider).baseUrl ??
                                    '',
                                isAdmin: isAdmin,
                                noticeCount: data?.noticeCount ?? 0,
                                updateLabel: data?.pendingUpdateLabel,
                              ),
                            },
                            if (sections[selected] ==
                                    MoreSection.conversations &&
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
