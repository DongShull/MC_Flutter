import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/session/session_store.dart';
import '../../../core/designsystem/state_views.dart';
import '../state/controllers.dart';
import '../widgets/account_switcher_sheet.dart';
import '../widgets/conversations_section.dart';
import '../widgets/downloads_section.dart';
import '../widgets/profile_card.dart';
import '../widgets/section_picker.dart';
import '../widgets/server_section.dart';

/// 「我的」页分段（对齐鸿蒙 MoreSection）。
enum MoreSection { conversations, downloads, server }

/// 「我的」主 tab（对齐鸿蒙 MorePage 结构）：
/// ProfileCard → SectionPicker → 会话 / 下载 / 服务器段。
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

  /// 可用分段：会话段仅管理员；下载为客户端本机能力常显；服务器段常显。
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(moreProvider);
    final form = ref.watch(mcFormProvider);
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
    // 分段集变化（如角色刷新）时防越界：回退第一段。
    final selected =
        _sectionIndex < sections.length ? _sectionIndex : sections.length - 1;

    final body = state.isLoading && data == null
        ? const McLoadingView()
        : state.hasError
            ? McErrorView(
                text: McStrings.networkError,
                onRetry: () => ref.read(moreProvider.notifier).load(),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (isAdmin &&
                      n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                    ref.read(moreProvider.notifier).loadMoreSessions();
                  }
                  return false;
                },
                child: ListView(
                  children: [
                    ProfileCard(
                      nickname: nickname,
                      username: username,
                      roleLabel: roleLabel,
                      avatarUrl: appSession.avatarUrl,
                      onSwitchAccount: () => showAccountSwitcherSheet(context),
                    ),
                    if (sections.length > 1)
                      SectionPicker(
                        labels: [
                          for (final s in sections) _labelOf(s),
                        ],
                        icons: [
                          for (final s in sections) _iconOf(s),
                        ],
                        selected: selected,
                        badgeIndex: isAdmin && (data?.noticeCount ?? 0) > 0
                            ? sections.indexOf(MoreSection.server)
                            : null,
                        onSelect: (i) => setState(() => _sectionIndex = i),
                      ),
                    switch (sections[selected]) {
                      MoreSection.conversations => const ConversationsSection(),
                      MoreSection.downloads => const DownloadsSection(),
                      MoreSection.server => ServerSection(
                          host: ref.watch(sessionStoreProvider).baseUrl ?? '',
                          isAdmin: isAdmin,
                          noticeCount: data?.noticeCount ?? 0,
                          updateLabel: data?.pendingUpdateLabel,
                        ),
                    },
                    if (sections[selected] == MoreSection.conversations &&
                        (data?.loadingMore ?? false))
                      const SizedBox(
                        height: 52,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              );

    return Scaffold(
      appBar: AppBar(title: const Text(McStrings.moreTab)),
      body: form == McDeviceForm.phone
          ? body
          // 平板/TV：内容限宽居中（外壳由根 McAdaptiveScaffold 负责）。
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: body,
              ),
            ),
    );
  }

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
}
