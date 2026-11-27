import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../../../core/session/permissions.dart';
import '../logic/torrent_search_logic.dart';
import '../models/search_models.dart';
import '../state/search_controller.dart';
import '../widgets/download_target_sheet.dart';
import '../widgets/torrent_widgets.dart';

/// 全平台三合一统一搜索页（1:1 对齐 iOS `SearchHomeView` + `SearchResultsView` + `TorrentResultsView`）：
/// - 权限裁剪三垂直（影视 / 站点资源 / 媒体库）；
/// - 服务端搜索历史分组（同关键词多范围折叠）+ 离线快照回放；
/// - 预设范围 token + PT 空关键词浏览最新资源；
/// - 影视双源叠排（豆瓣 + TMDB 独立错误提示）；
/// - 媒体库实时防抖海报墙 + 人物行 + 游标翻页；
/// - PT 站点 SSE 流式搜索 + 进度条 + 站点状态弹层（单站重试）+ 跨站分页 + 3 视图 + 7 排序 + 12 维自排除筛选 + 下载目标预检弹窗。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery,
    this.initialMode,
    this.initialScope,
    this.initialAlso = const [],
    this.initialSnapshotId,
    this.forSubscriptionId,
    this.initialBrowse = false,
  });

  final String? initialQuery;
  final String? initialMode;
  final String? initialScope;
  final List<String> initialAlso;
  final int? initialSnapshotId;
  final int? forSubscriptionId;
  final bool initialBrowse;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _input =
      TextEditingController(text: widget.initialQuery ?? '');
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final hasArgs = (widget.initialQuery != null &&
              widget.initialQuery!.isNotEmpty) ||
          (widget.initialMode != null && widget.initialMode!.isNotEmpty) ||
          widget.initialScope != null ||
          widget.initialSnapshotId != null ||
          widget.forSubscriptionId != null ||
          widget.initialBrowse;
      if (hasArgs) {
        await ref.read(searchProvider.notifier).applyRouteArgs(
              query: widget.initialQuery,
              tab: widget.initialMode,
              scopeEncoded: widget.initialScope,
              also: widget.initialAlso,
              snapshotId: widget.initialSnapshotId,
              forSubscriptionId: widget.forSubscriptionId,
              browse: widget.initialBrowse,
            );
      } else {
        ref.read(searchProvider.notifier).clearGrabTarget();
        final cur = ref.read(searchProvider).query;
        if (cur.isNotEmpty && _input.text.isEmpty) {
          _input.text = cur;
        }
        if (mounted) _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncInput(String q) {
    _input.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
  }

  void _submit(String q, {SearchScope? scope}) {
    FocusScope.of(context).unfocus();
    _syncInput(q);
    ref.read(searchProvider.notifier).submitSearch(q, scope: scope);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  String _hintFor(SearchState s) => switch (s.vertical) {
        SearchVertical.media => '搜索 TMDB / 豆瓣电影与剧集…',
        SearchVertical.torrent => s.scope.label != null
            ? '在「${s.scope.label}」中搜索资源（留空浏览最新）…'
            : '搜索 PT 站点资源（留空回车浏览最新）…',
        SearchVertical.library => '搜索本地媒体库影片、剧集与影人…',
      };

  /// 发起种子下载：超管查偏好记忆（命中有效记忆先弹确认条，失效带原因开完整弹窗）；成员直接开库选择弹窗。
  void _startDownload(TorrentHit hit) {
    final s = ref.read(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final perms = ref.read(permissionsProvider);
    final st = s.downloadStates[hit.rowKey] ?? TorrentSubmitState.idle;
    if (st == TorrentSubmitState.submitting ||
        st == TorrentSubmitState.done ||
        st == TorrentSubmitState.exists) {
      return;
    }
    final req = DownloadTargetRequest.fromHit(
      hit,
      keyword: s.submittedQuery.isNotEmpty ? s.submittedQuery : s.query,
    );
    if (req == null) return;

    void onSubmitted(DownloadSubmitResult res) {
      notifier.setDownloadState(
        req.hitKey,
        res.alreadyExists ? TorrentSubmitState.exists : TorrentSubmitState.done,
      );
      McToast.success(
        res.alreadyExists
            ? '种子已在下载队列中'
            : (res.savePath != null
                ? '已提交至 ${res.downloaderName}（${res.savePath}）'
                : '已提交至 ${res.downloaderName}'),
      );
      if (perms.isAdmin) notifier.refreshDownloadPrefs();
    }

    if (!perms.isAdmin) {
      DownloadTargetSheet.show(
        context,
        request: req,
        onSubmitted: onSubmitted,
      );
      return;
    }

    final prefs = notifier.prefsStore;
    final remembered = prefs.byCategory[req.category];
    if (remembered == null) {
      DownloadTargetSheet.show(
        context,
        request: req,
        onSubmitted: onSubmitted,
      );
      return;
    }

    String? invalidReason;
    if (remembered.kind == 'smart' && req.identity == null) {
      invalidReason = '此种子未能自动识别作品身份，请手动确认作品或保存目录';
    } else if (remembered.downloaderId != null &&
        remembered.downloaderName == null) {
      invalidReason = '之前记住的下载器已不可用，请重新选择';
    } else if (prefs.isStaleDir(remembered)) {
      invalidReason = '之前记住的目录「${remembered.savePath ?? ''}」已不在可用路径中';
    }

    if (invalidReason != null) {
      DownloadTargetSheet.show(
        context,
        request: req.withReason(invalidReason),
        remembered: remembered,
        onSubmitted: onSubmitted,
      );
      return;
    }

    DownloadConfirmSheet.show(
      context,
      request: req,
      target: remembered,
      onConfirm: () async {
        final out = await notifier.confirmRememberedDownload(req, remembered);
        if (!mounted) return;
        if (out.needsDialog) {
          DownloadTargetSheet.show(
            context,
            request: req.withReason('智能入库需要确认作品身份，请点选对应条目'),
            remembered: remembered,
            onSubmitted: onSubmitted,
          );
        } else if (out.error != null) {
          McToast.error(out.error!);
        } else if (out.result != null) {
          final res = out.result!;
          McToast.success(
            res.alreadyExists
                ? '种子已在下载队列中'
                : (res.savePath != null
                    ? '已提交至 ${res.downloaderName}（${res.savePath}）'
                    : '已提交至 ${res.downloaderName}'),
          );
        }
      },
      onChange: () {
        DownloadTargetSheet.show(
          context,
          request: req,
          remembered: remembered,
          onSubmitted: onSubmitted,
        );
      },
      onForget: () async {
        await notifier.forgetDownloadPref(remembered.category);
        if (!mounted) return;
        DownloadTargetSheet.show(
          context,
          request: req.withReason(
            '已取消记住「${TorrentCategories.label(remembered.category)}」的保存位置',
          ),
          onSubmitted: onSubmitted,
        );
      },
    );
  }

  Future<void> _grabForSubscription(TorrentHit hit) async {
    final s = ref.read(searchProvider);
    final target = s.grabTarget;
    if (target == null) return;
    final out = await ref.read(searchProvider.notifier).grabForSubscription(hit);
    if (!mounted) return;
    if (out.error != null) {
      McToast.error(out.error!);
    } else if (out.unitCount != null) {
      McToast.success('已投给「${target.title}」（覆盖 ${out.unitCount} 项）');
    }
  }

  void _openTorrentActions(TorrentHit hit, {bool fromGallery = false}) {
    final s = ref.read(searchProvider);
    final perms = ref.read(permissionsProvider);
    TorrentActionsSheet.show(
      context,
      hit: hit,
      perms: perms,
      downloadState: s.downloadStates[hit.rowKey] ?? TorrentSubmitState.idle,
      grabState: s.grabStates[hit.rowKey] ?? TorrentSubmitState.idle,
      grabTarget: s.grabTarget,
      showsImages: true,
      onOpenImages: () => _openTorrentLightbox(hit),
      onGrab: () => _grabForSubscription(hit),
      onDownload: () => _startDownload(hit),
    );
  }

  void _openTorrentLightbox(TorrentHit hit) {
    final s = ref.read(searchProvider);
    final perms = ref.read(permissionsProvider);
    TorrentScreenshotLightbox.show(
      context,
      hit: hit,
      perms: perms,
      downloadState: s.downloadStates[hit.rowKey] ?? TorrentSubmitState.idle,
      grabState: s.grabStates[hit.rowKey] ?? TorrentSubmitState.idle,
      grabTarget: s.grabTarget,
      onGrab: () => _grabForSubscription(hit),
      onDownload: () => _startDownload(hit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final topPad = MediaQuery.paddingOf(context).top;
    final visibleVerticals = s.access.available
        .where((v) => !s.browsing || v == SearchVertical.torrent)
        .toList();
    final showTorrentToolbar = s.vertical == SearchVertical.torrent &&
        s.showingResults &&
        s.access.canTorrent;
    final showClearBtn =
        s.query.isNotEmpty || _input.text.isNotEmpty || s.browsing;
    final showStandaloneScopeChip = s.vertical == SearchVertical.torrent &&
        !s.scope.isAll &&
        s.scope.label != null &&
        !showTorrentToolbar;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          // 顶部搜索栏 + 返回 + 范围/视图工具钮
          Padding(
            padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 8),
            child: Row(
              children: [
                McGlassIconButton(
                  icon: McIcons.arrowLeftS,
                  iconSize: 22,
                  tooltip: '返回',
                  onTap: _back,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: McTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(McTokens.pillRadius),
                      border: Border.all(color: McTokens.lineStrong, width: 1),
                    ),
                    padding: EdgeInsets.only(
                      left: 12,
                      right: showClearBtn ? 0 : 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          McIcons.search,
                          size: 16,
                          color: McTokens.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            focusNode: _focusNode,
                            style: McText.body,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (v) => _submit(v),
                            onChanged: notifier.onQueryChanged,
                            decoration: InputDecoration(
                              isCollapsed: true,
                              filled: false,
                              hintText: _hintFor(s),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (showClearBtn)
                          Tooltip(
                            message: '清空搜索',
                            child: Semantics(
                              button: true,
                              label: '清空搜索',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _input.clear();
                                  notifier.onQueryChanged('');
                                },
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Color(0x29FFFFFF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        McIcons.close,
                                        size: 12,
                                        color: McTokens.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (showTorrentToolbar) ...[
                  const SizedBox(width: 6),
                  _ScopeMenuButton(
                    scope: s.scope,
                    tabs: s.tabs,
                    onPick: notifier.switchScope,
                  ),
                  const SizedBox(width: 4),
                  _ViewModeButton(
                    view: s.torrentView,
                    onPick: notifier.setTorrentView,
                  ),
                ],
              ],
            ),
          ),

          // 垂直切换条（按权限裁剪）+ 搜索首页态的当前范围清除胶囊
          if (visibleVerticals.length > 1 || showStandaloneScopeChip)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (visibleVerticals.length > 1)
                      for (var i = 0; i < visibleVerticals.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        McChip(
                          label: visibleVerticals[i].label,
                          icon: switch (visibleVerticals[i]) {
                            SearchVertical.media => McIcons.compass,
                            SearchVertical.torrent => McIcons.fileSeed,
                            SearchVertical.library => McIcons.mediaLibraryFill,
                          },
                          selected: s.vertical == visibleVerticals[i],
                          onTap: () =>
                              notifier.switchVertical(visibleVerticals[i]),
                        ),
                      ],
                    if (showStandaloneScopeChip) ...[
                      if (visibleVerticals.length > 1)
                        const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF57637A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                '范围：${s.scope.label!}',
                                style: McText.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: '清除搜索范围',
                              child: Semantics(
                                button: true,
                                label: '清除搜索范围',
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    notifier.switchScope(SearchScope.all);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    child: Icon(
                                      McIcons.close,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const Divider(height: 1, color: McTokens.line),

          // 主内容区
          Expanded(
            child: !s.access.ready
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : !s.access.canOpenSearch
                    ? const McEmptyView(
                        icon: McIcons.search,
                        title: '暂无搜索权限',
                        text: '当前账号未开通影视、资源或可见媒体库搜索权限。',
                      )
                    : (!s.showingResults
                        ? _SearchHomeBody(
                            state: s,
                            onSubmit: _submit,
                            onBrowse: (scope) {
                              FocusScope.of(context).unfocus();
                              _input.clear();
                              notifier.browseTorrents(scope: scope);
                            },
                            onPickHistory: (item) {
                              FocusScope.of(context).unfocus();
                              _syncInput(item.keyword);
                              notifier.openHistoryItem(item);
                            },
                          )
                        : switch (s.vertical) {
                            SearchVertical.media => _MediaResultsBody(
                                onSwitchToTorrent: s.access.canTorrent
                                    ? () => notifier
                                        .switchVertical(SearchVertical.torrent)
                                    : null,
                              ),
                            SearchVertical.library => _LibraryResultsBody(
                                onPickSuggestion: (q) {
                                  _syncInput(q);
                                  notifier.onQueryChanged(q);
                                },
                                onSwitchToMedia: s.access.canMedia
                                    ? () => notifier
                                        .switchVertical(SearchVertical.media)
                                    : null,
                              ),
                            SearchVertical.torrent => _TorrentResultsBody(
                                onTapHit: (hit) => _openTorrentActions(hit),
                                onOpenPosterImages: _openTorrentLightbox,
                                onOpenPosterActions: (hit) =>
                                    _openTorrentActions(hit, fromGallery: true),
                              ),
                          }),
          ),
        ],
      ),
    );
  }
}

/// 顶部范围切换菜单钮（全部分类 / 内置分类 / 自定义预设）。
class _ScopeMenuButton extends StatelessWidget {
  const _ScopeMenuButton({
    required this.scope,
    required this.tabs,
    required this.onPick,
  });

  final SearchScope scope;
  final List<SearchTab> tabs;
  final ValueChanged<SearchScope> onPick;

  @override
  Widget build(BuildContext context) {
    final presets = tabs.where((t) => t.isPreset).toList();
    final builtIn = tabs.where((t) => !t.isPreset).toList();
    return PopupMenuButton<SearchScope>(
      tooltip: '搜索范围',
      onSelected: (picked) {
        HapticFeedback.selectionClick();
        onPick(picked);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: SearchScope.all,
          child: Row(
            children: [
              const Icon(TorrentCategories.allIcon, size: 16),
              const SizedBox(width: 8),
              const Expanded(child: Text('全部分类')),
              if (scope.isAll)
                const Icon(McIcons.check, size: 15, color: McTokens.accentStrong),
            ],
          ),
        ),
        if (builtIn.isNotEmpty) const PopupMenuDivider(),
        for (final t in builtIn)
          PopupMenuItem(
            value: t.scope,
            child: Row(
              children: [
                Icon(t.icon, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(t.label)),
                if (scope == t.scope)
                  const Icon(
                    McIcons.check,
                    size: 15,
                    color: McTokens.accentStrong,
                  ),
              ],
            ),
          ),
        if (presets.isNotEmpty) ...[
          const PopupMenuDivider(),
          for (final t in presets)
            PopupMenuItem(
              value: t.scope,
              child: Row(
                children: [
                  Icon(t.icon, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.label)),
                  if (scope == t.scope)
                    const Icon(
                      McIcons.check,
                      size: 15,
                      color: McTokens.accentStrong,
                    ),
                ],
              ),
            ),
        ],
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 78),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scope.isAll
                ? McTokens.surfaceInset
                : McTokens.accentStrong.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(McTokens.pillRadius),
            border: Border.all(
              color: scope.isAll ? McTokens.lineStrong : McTokens.accentStrong,
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            scope.label ?? '全部',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.caption.copyWith(
              color: McTokens.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部 3 视图切换菜单钮（作品分组 / 原始列表 / 海报图览）。
class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({required this.view, required this.onPick});

  final TorrentResultView view;
  final ValueChanged<TorrentResultView> onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TorrentResultView>(
      tooltip: '切换视图',
      onSelected: (picked) {
        HapticFeedback.selectionClick();
        onPick(picked);
      },
      itemBuilder: (_) => [
        for (final v in TorrentResultView.values)
          PopupMenuItem(
            value: v,
            child: Row(
              children: [
                Icon(v.icon, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(v.label)),
                if (v == view)
                  const Icon(
                    McIcons.check,
                    size: 15,
                    color: McTokens.accentStrong,
                  ),
              ],
            ),
          ),
      ],
      child: IgnorePointer(
        child: McGlassIconButton(
          icon: view.icon,
          iconSize: 18,
          onTap: () {},
        ),
      ),
    );
  }
}

// ── 搜索首页（服务端分组历史 + 空词浏览最新资源 + 在其他范围搜索） ──

class _SearchHomeBody extends ConsumerWidget {
  const _SearchHomeBody({
    required this.state,
    required this.onSubmit,
    required this.onBrowse,
    required this.onPickHistory,
  });

  final SearchState state;
  final void Function(String query, {SearchScope? scope}) onSubmit;
  final ValueChanged<SearchScope> onBrowse;
  final ValueChanged<SearchHistoryItem> onPickHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(searchProvider.notifier);
    final kw = state.query.trim();
    final groups = state.groupedHistory;
    final torrentActive =
        state.vertical == SearchVertical.torrent && state.access.canTorrent;

    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 40 + bottomPad),
      children: [
        // 输入了关键词时，顶部给「搜索“…”」一键提交行
        if (kw.isNotEmpty) ...[
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              McInsetRow(
                icon: McIcons.search,
                iconColor: McTokens.accent,
                title: '搜索「$kw」',
                subtitle: switch (state.vertical) {
                  SearchVertical.media => '同时检索豆瓣与 TMDB 影视资料',
                  SearchVertical.torrent => state.scope.label != null
                      ? '在「${state.scope.label}」范围内搜索'
                      : '在全部分类与已启用站点中搜索',
                  SearchVertical.library => '搜索本地媒体库',
                },
                onTap: () => onSubmit(kw),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],

        // 服务端分组搜索历史（影视/资源各自展示）
        if (state.vertical != SearchVertical.library) ...[
          if (state.historyLoading && groups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (groups.isNotEmpty) ...[
            Row(
              children: [
                const Text('最近搜索', style: McText.titleSm),
                const Spacer(),
                TextButton(
                  onPressed: notifier.clearServerHistory,
                  child: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final g in groups) _buildHistoryGroup(context, ref, g),
              ],
            ),
            const SizedBox(height: 20),
          ] else if (!torrentActive && kw.isEmpty) ...[
            McEmptyView(
              icon: state.vertical == SearchVertical.media
                  ? McIcons.compass
                  : McIcons.search,
              title: state.vertical == SearchVertical.media
                  ? '搜索全球影视库'
                  : '搜索你的本地媒体库',
              text: state.vertical == SearchVertical.media
                  ? '同时检索豆瓣与 TMDB，查看详情或一键加入追更订阅'
                  : '输入片名、原名、导演或演员姓名立即查找',
            ),
          ],
        ] else if (kw.isEmpty) ...[
          const McEmptyView(
            icon: McIcons.search,
            title: '搜索你的本地媒体库',
            text: '支持片名、别名、拼音首字母与演职员，输入即出结果',
          ),
        ],

        // 资源模式：空词显示「浏览最新资源」；输入了词显示「在其他范围搜索」
        if (torrentActive) ...[
          if (kw.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('浏览最新资源', style: McText.titleSm),
            ),
            McInsetGroup(
              margin: EdgeInsets.zero,
              footer: '点选任一分类或自定义预设，无需输入关键词即可浏览各站最新种子',
              children: [
                McInsetRow(
                  icon: TorrentCategories.allIcon,
                  iconColor: McTokens.accent,
                  title: '全部分类',
                  showChevron: true,
                  onTap: () => onBrowse(SearchScope.all),
                ),
                for (final tab in state.tabs)
                  McInsetRow(
                    icon: tab.icon,
                    iconColor: McTokens.accent,
                    title: tab.label,
                    subtitle: tab.summary,
                    showChevron: true,
                    onTap: () => onBrowse(tab.scope),
                  ),
              ],
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('在其他范围搜索', style: McText.titleSm),
            ),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                if (!state.scope.isAll)
                  McInsetRow(
                    icon: TorrentCategories.allIcon,
                    iconColor: McTokens.accent,
                    title: '全部分类',
                    onTap: () => onSubmit(kw, scope: SearchScope.all),
                  ),
                for (final tab in state.tabs)
                  if (tab.scope != state.scope)
                    McInsetRow(
                      icon: tab.icon,
                      iconColor: McTokens.accent,
                      title: tab.label,
                      subtitle: tab.summary,
                      onTap: () => onSubmit(kw, scope: tab.scope),
                    ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildHistoryGroup(
    BuildContext context,
    WidgetRef ref,
    HistoryGroup group,
  ) {
    final notifier = ref.read(searchProvider.notifier);
    final latest = group.items.first;
    final children = group.items.skip(1).toList();

    String detailLine(SearchHistoryItem item) {
      final time = mcFromNowIso(item.lastSearchedAt, empty: '');
      if (item.hasSnapshot) return time.isEmpty ? '快照' : '$time · 快照';
      return time;
    }

    Future<void> confirmDeleteGroup() async {
      if (group.items.length == 1) {
        await notifier.deleteHistoryGroup(group);
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除搜索记录'),
          content: Text(
            '确定删除「${group.keyword}」相关的全部 ${group.items.length} 条记录？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: McTokens.dangerSolid,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (ok == true) await notifier.deleteHistoryGroup(group);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        McInsetRow(
          icon: McIcons.history1,
          iconColor: McTokens.textFaint,
          title: group.keyword,
          subtitle: '${latest.scopeLabel} · ${detailLine(latest)}',
          trailing: IconButton(
            tooltip: '删除',
            icon: const Icon(
              McIcons.close,
              size: 15,
              color: McTokens.textFaint,
            ),
            onPressed: confirmDeleteGroup,
          ),
          onTap: () => onPickHistory(latest),
        ),
        for (final sub in children)
          McInsetRow(
            icon: McIcons.arrowRightDownLine,
            iconColor: McTokens.textFaint,
            title: sub.scopeLabel,
            subtitle: detailLine(sub),
            trailing: IconButton(
              tooltip: '删除此条',
              icon: const Icon(
                McIcons.close,
                size: 14,
                color: McTokens.textFaint,
              ),
              onPressed: () => notifier.deleteHistoryItem(sub.id),
            ),
            onTap: () => onPickHistory(sub),
          ),
      ],
    );
  }
}

// ── 影视双源叠排结果（豆瓣 + TMDB 独立分区与错误态 + 快照回放） ──

class _MediaResultsBody extends ConsumerWidget {
  const _MediaResultsBody({this.onSwitchToTorrent});

  final VoidCallback? onSwitchToTorrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);
    final perms = ref.watch(permissionsProvider);
    final settled = (s.doubanHits != null || s.doubanError != null) &&
        (s.tmdbHits != null || s.tmdbError != null);
    final allEmpty =
        (s.doubanHits?.isEmpty ?? true) && (s.tmdbHits?.isEmpty ?? true);

    return LayoutBuilder(
      builder: (context, constraints) {
        final form = McFormWatch.of(context);
        final pad = form == McDeviceForm.phone
            ? McTokens.pagePadding
            : McTokens.pagePaddingWide;
        final cols = mcGridCrossAxisCount(form, constraints, cellExtent: 126);

        final bottomPad = MediaQuery.paddingOf(context).bottom;

        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 14, pad, 44 + bottomPad),
          children: [
            if (s.mediaSnapshotAt != null && s.mediaSnapshotAt!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SnapshotBanner(
                  snapshotAt: s.mediaSnapshotAt!,
                  onResearch: () =>
                      ref.read(searchProvider.notifier).researchMedia(),
                ),
              ),
            if (settled && allEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Text(
                      (s.doubanError ?? s.tmdbError) != null
                          ? '影视检索遇到问题'
                          : '未找到相关影视作品',
                      style: McText.titleSm,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.doubanError ??
                          s.tmdbError ??
                          '换个片名试试，或直接搜索 PT 站点资源',
                      textAlign: TextAlign.center,
                      style: McText.sub,
                    ),
                    if (onSwitchToTorrent != null) ...[
                      const SizedBox(height: 16),
                      McActionPill(
                        label: '搜索站点资源',
                        icon: McIcons.fileSeed,
                        primary: true,
                        onTap: onSwitchToTorrent,
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              _providerSection(
                context,
                ref,
                label: '豆瓣',
                items: s.doubanHits,
                error: s.doubanError,
                cols: cols,
                perms: perms,
              ),
              const SizedBox(height: 24),
              _providerSection(
                context,
                ref,
                label: 'TMDB',
                items: s.tmdbHits,
                error: s.tmdbError,
                cols: cols,
                perms: perms,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _providerSection(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required List<MediaSearchHit>? items,
    required String? error,
    required int cols,
    required McPermissions perms,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x4D000000),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: McTokens.lineStrong, width: 0.8),
              ),
              child: Text(
                label,
                style: McText.micro.copyWith(color: McTokens.accent),
              ),
            ),
            if (items != null && items.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text('${items.length} 条结果', style: McText.caption.muted.tabular),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (items == null && error == null)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.54,
            ),
            itemCount: cols * 2,
            itemBuilder: (_, __) => const McShimmerBox(
              height: 200,
              radius: McTokens.posterRadius,
            ),
          )
        else if (error != null && (items == null || items.isEmpty))
          Text(error, style: McText.sub)
        else if (items == null || items.isEmpty)
          const Text('该数据源暂无匹配结果', style: McText.sub)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 18,
              crossAxisSpacing: 12,
              childAspectRatio: 0.515,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final hit = items[i];
              return McPosterCard(
                title: hit.title,
                posterUrl: hit.posterUrl,
                width: null,
                subtitle: [
                  if (hit.year != null) '${hit.year}',
                  hit.mediaType == 'tv' ? '剧集' : '电影',
                ].join(' · '),
                rating: (hit.rating ?? 0) > 0 ? hit.rating : null,
                badge: hit.inLibrary ? '已入库' : null,
                badgeDotColor: hit.inLibrary ? McTokens.ok : null,
                onTap: () => context.push(
                  '/discover/title?ref=${Uri.encodeComponent(hit.titleRef)}',
                ),
                contextActions: [
                  McPosterMenuAction(
                    icon: McIcons.film,
                    label: '查看影视详情',
                    onTap: () => context.push(
                      '/discover/title?ref=${Uri.encodeComponent(hit.titleRef)}',
                    ),
                  ),
                  if (hit.inLibrary &&
                      hit.libraryId != null &&
                      hit.mediaItemId != null)
                    McPosterMenuAction(
                      icon: McIcons.play2Fill,
                      label: '前往媒体库观看',
                      onTap: () => context.push(
                        '/detail/${hit.libraryId}/${hit.mediaItemId}',
                      ),
                    ),
                  if (perms.canSubscribe)
                    McPosterMenuAction(
                      icon: McIcons.bookmarkFill,
                      label: hit.inLibrary ? '管理订阅' : '加入追更订阅',
                      onTap: () async {
                        final out = await showSubscribeSheet(
                          context,
                          ref,
                          titleRef: hit.titleRef,
                        );
                        if (!context.mounted || out == null) return;
                        if (out == SubscribeSheetOutcome.created) {
                          McToast.success('已加入追更订阅');
                        } else {
                          context.push('/subscriptions');
                        }
                      },
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

// ── 媒体库搜索结果（联想胶囊 + 人物行 + 响应式海报墙 + 无限游标分页） ──

class _LibraryResultsBody extends ConsumerWidget {
  const _LibraryResultsBody({
    required this.onPickSuggestion,
    this.onSwitchToMedia,
  });

  final ValueChanged<String> onPickSuggestion;
  final VoidCallback? onSwitchToMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);
    final kwLower = s.query.trim().toLowerCase();
    final seenSug = <String>{kwLower};
    final suggestions = s.librarySuggestions.where((sug) {
      final k = sug.text.trim().toLowerCase();
      return sug.type == 'title' && k.isNotEmpty && seenSug.add(k);
    }).toList();

    if (s.librarySearching && s.libraryHits.isEmpty && s.libraryPeople.isEmpty) {
      return const McLoadingView(label: '正在搜索媒体库…');
    }
    if (s.libraryError != null &&
        s.libraryHits.isEmpty &&
        s.libraryPeople.isEmpty) {
      return McErrorView(
        text: s.libraryError!,
        onRetry: () => ref.read(searchProvider.notifier).submitSearch(s.query),
      );
    }
    if (!s.librarySearching &&
        s.libraryHits.isEmpty &&
        s.libraryPeople.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
        child: Column(
          children: [
            const Text('媒体库里还没有相关内容', style: McText.titleSm),
            const SizedBox(height: 6),
            const Text(
              '可以到「影视」里搜搜看，找到后一键订阅自动下载入库',
              textAlign: TextAlign.center,
              style: McText.sub,
            ),
            if (onSwitchToMedia != null) ...[
              const SizedBox(height: 16),
              McActionPill(
                label: '去影视搜索',
                icon: McIcons.compass,
                primary: true,
                onTap: onSwitchToMedia,
              ),
            ],
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) {
          ref.read(searchProvider.notifier).loadMoreLibrary();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final form = McFormWatch.of(context);
          final pad = form == McDeviceForm.phone
              ? McTokens.pagePadding
              : McTokens.pagePaddingWide;
          final cols = mcGridCrossAxisCount(form, constraints, cellExtent: 126);

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (suggestions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final sug = suggestions[i];
                          final reason = sug.informativeReason;
                          return McChip(
                            compact: true,
                            label: reason != null
                                ? '${sug.text} · $reason'
                                : sug.text,
                            onTap: () => onPickSuggestion(sug.text),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (s.libraryPeople.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: pad),
                          child: const Text('人物', style: McText.titleSm),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: pad),
                            itemCount: s.libraryPeople.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final p = s.libraryPeople[i];
                              final avatar = McImageUrls.resolve(
                                p.avatarUrl,
                                widthPx: 160,
                              );
                              final initChar = p.name.trim().isNotEmpty
                                  ? p.name.trim().substring(0, 1)
                                  : '?';
                              return GestureDetector(
                                onTap: p.tmdbPersonId != null
                                    ? () => context.push(
                                          '/library/person/${p.tmdbPersonId}',
                                        )
                                    : null,
                                child: SizedBox(
                                  width: 84,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0x14FFFFFF),
                                              Color(0x05FFFFFF),
                                            ],
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Center(
                                              child: Text(
                                                initChar,
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0x59FFFFFF),
                                                ),
                                              ),
                                            ),
                                            if (avatar.isNotEmpty)
                                              CachedNetworkImage(
                                                imageUrl: avatar,
                                                httpHeaders: mcImageHeaders(),
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    const SizedBox.shrink(),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: McText.caption.copyWith(
                                          color: McTokens.text,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${p.itemCount} 部作品',
                                        style: McText.micro.faint.tabular,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (s.libraryHits.isNotEmpty) ...[
                if (s.libraryPeople.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 14, pad, 10),
                      child: const Text('作品', style: McText.titleSm),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.49,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final hit = s.libraryHits[i];
                        final subParts = <String>[
                          if (hit.year != null) '${hit.year}',
                          if (hit.footnote != null) hit.footnote!,
                        ];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            McPosterCard(
                              title: hit.itemName,
                              posterUrl: hit.posterUrl,
                              width: null,
                              subtitle: subParts.isEmpty
                                  ? null
                                  : subParts.join(' · '),
                              onTap: () => context.push(
                                '/detail/${hit.targetLibraryId}/${hit.itemId}',
                              ),
                            ),
                            if (hit.matchHint != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                hit.matchHint!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: McText.micro.faint,
                              ),
                            ],
                          ],
                        );
                      },
                      childCount: s.libraryHits.length,
                    ),
                  ),
                ),
              ],
              if (s.libraryNextCursor != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: s.libraryLoadingMore
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : McGlassButton(
                              onTap: () => ref
                                  .read(searchProvider.notifier)
                                  .loadMoreLibrary(),
                              tone: McGlassTone.secondary,
                              child: Text(
                                '加载更多',
                                style: McText.caption.semibold,
                              ),
                            ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── 站点资源 PT 流式搜索结果（进度条 + 站点状态 + 12 维分面 + 7 排序 + 3 视图 + 跨站分页） ──

class _TorrentResultsBody extends ConsumerWidget {
  const _TorrentResultsBody({
    required this.onTapHit,
    required this.onOpenPosterImages,
    required this.onOpenPosterActions,
  });

  final ValueChanged<TorrentHit> onTapHit;
  final ValueChanged<TorrentHit> onOpenPosterImages;
  final ValueChanged<TorrentHit> onOpenPosterActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final perms = ref.watch(permissionsProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: 48 + bottomPad),
      children: [
        // 手动选种横幅（for_sub 模式）
        if (s.grabTarget != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: McTokens.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: McTokens.info.withValues(alpha: 0.32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在为「${s.grabTarget!.title}」手动选种，点击任一资源即可投给该订阅',
                    style: McText.caption.copyWith(
                      color: const Color(0xFF99C7FF),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.push(
                      '/subscriptions/detail/${s.grabTarget!.id}',
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          McIcons.arrowLeftS,
                          size: 14,
                          color: Color(0xFF99C7FF),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '返回订阅详情',
                          style: McText.caption.copyWith(
                            color: const Color(0xFF99C7FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 状态行（条数 + 站点状态胶囊 + 另含同搜词 + 快照回放条）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (s.torrentPhase == TorrentStreamPhase.streaming) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: McTokens.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已找到 ${s.torrentItems.length} 条',
                      style: McText.caption.muted.tabular,
                    ),
                  ] else if (s.torrentPhase == TorrentStreamPhase.done) ...[
                    Text(
                      s.torrentFilters.isActive
                          ? '筛选出 ${s.torrentFiltered.length} / ${s.torrentItems.length} 条'
                          : '共 ${s.torrentItems.length} 条结果',
                      style: McText.caption.muted.tabular,
                    ),
                  ] else if (s.torrentPhase == TorrentStreamPhase.connecting) ...[
                    Text('正在连接搜索服务…', style: McText.caption.muted),
                  ],
                  const Spacer(),
                  if (s.torrentSites.isNotEmpty)
                    SiteStatusPill(
                      streaming: s.torrentStreaming,
                      settledCount: s.torrentSettledCount,
                      totalSites: s.torrentSites.length,
                      failedCount: s.torrentFailedCount,
                      onTap: () => SiteStatusSheet.show(
                        context,
                        sites: s.torrentSites,
                        totalElapsedMs: s.torrentTotalElapsedMs,
                        canRetry: s.torrentSnapshotAt == null,
                        isAdmin: perms.isAdmin,
                        onRetrySite: notifier.retrySite,
                      ),
                    ),
                ],
              ),
              if (s.torrentAlsoSearched.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '另含：${s.torrentAlsoSearched.join(' · ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.faint,
                ),
              ],
              if (s.torrentSnapshotAt != null &&
                  s.torrentSnapshotAt!.isNotEmpty &&
                  s.torrentPhase == TorrentStreamPhase.done) ...[
                const SizedBox(height: 6),
                _SnapshotBanner(
                  snapshotAt: s.torrentSnapshotAt!,
                  onResearch: notifier.researchTorrents,
                ),
              ],
            ],
          ),
        ),

        if (s.torrentPhase == TorrentStreamPhase.done &&
            s.torrentSites.isEmpty &&
            s.torrentSnapshotAt == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '尚未配置已启用的 PT 索引站点，请在「设置 → 索引站点」中添加。',
              style: McText.sub,
            ),
          ),

        // 排序 + 12 维自排除筛选胶囊条
        if (s.torrentSites.isNotEmpty) ...[
          const SizedBox(height: 4),
          TorrentConditionChipsBar(
            sort: s.torrentSort,
            smartSortKeys: s.torrentSmartSortKeys,
            filters: s.torrentFilters,
            facets: s.torrentFacets,
            okSites: s.torrentOkSites,
            siteNameOf: s.siteNameOf,
            onChangeSort: notifier.setTorrentSort,
            onToggleFacet: notifier.toggleTorrentFacet,
            onClearDim: notifier.clearTorrentDim,
            onClearAllFilters: notifier.clearAllTorrentFilters,
          ),
        ],

        // 流式顶部进度条
        if (s.torrentStreaming)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TorrentStreamProgressBar(
              settledCount: s.torrentSettledCount,
              totalSites: s.torrentSites.length,
            ),
          ),

        // 结果主体
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _buildResultsBody(context, s, notifier),
        ),
      ],
    );
  }

  Widget _buildResultsBody(
    BuildContext context,
    SearchState s,
    SearchController notifier,
  ) {
    if (s.torrentStreaming && s.torrentItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                s.torrentSites.isEmpty
                    ? '正在连接搜索服务…'
                    : '正在并发检索 ${s.torrentSites.length} 个站点…',
                style: McText.sub,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 5; i++) ...[
            Opacity(
              opacity: (1 - i * 0.15).clamp(0.25, 1.0),
              child: const McShimmerBox(height: 76, radius: 16),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    if (s.torrentPhase == TorrentStreamPhase.error && s.torrentItems.isEmpty) {
      return McErrorView(
        title: '搜索失败',
        text: s.torrentFatalError ?? '种子检索失败，请稍后重试',
        onRetry: notifier.researchTorrents,
      );
    }

    if (s.torrentSorted.isEmpty) {
      if (s.torrentItems.isNotEmpty) {
        return McEmptyView(
          title: '当前筛选条件下没有匹配资源',
          text: '试试放宽部分筛选条件或一键清空筛选',
          actionLabel: '清空筛选',
          onRetry: notifier.clearAllTorrentFilters,
        );
      }
      if (s.torrentPhase == TorrentStreamPhase.done) {
        return McEmptyView(
          icon: McIcons.fileSeed,
          title: '未找到匹配的种子资源',
          text: s.browsing ? '换个分类或预设试试' : '试试更换关键词、英文原名或扩大搜索范围',
        );
      }
      return const SizedBox.shrink();
    }

    Widget content;
    switch (s.torrentView) {
      case TorrentResultView.poster:
        content = _buildPosterView(context, s);
      case TorrentResultView.group when s.torrentEntities.length >= 2:
        final buckets = TorrentSearchLogic.buckets(s.torrentSorted);
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final b in buckets)
              TorrentGroupSection(
                entityKey: b.key,
                rows: b.rows,
                entity: s.torrentEntities[b.key],
                onTapHit: onTapHit,
                onOpenImages: onOpenPosterImages,
              ),
          ],
        );
      default:
        content = Column(
          children: [
            for (final hit in s.torrentSorted) ...[
              TorrentRowCard(
                hit: hit,
                rawTitles: s.torrentView == TorrentResultView.list,
                onTap: () => onTapHit(hit),
                onOpenImages: () => onOpenPosterImages(hit),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (s.torrentPhase == TorrentStreamPhase.done &&
            s.torrentSnapshotAt == null &&
            s.torrentItems.isNotEmpty &&
            !s.torrentExhausted)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: McGlassButton(
                onTap: s.torrentLoadingMore ? null : notifier.loadMoreTorrents,
                tone: McGlassTone.secondary,
                radius: McTokens.pillRadius,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Text(
                  s.torrentLoadingMore
                      ? '正在加载第 ${s.torrentPage + 1} 页…'
                      : '加载第 ${s.torrentPage + 1} 页',
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (s.torrentPhase == TorrentStreamPhase.done &&
            s.torrentExhausted &&
            s.torrentItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: Text(
                '已加载全部 ${s.torrentPage} 页结果',
                style: McText.caption.faint,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPosterView(BuildContext context, SearchState s) {
    final withPoster =
        s.torrentSorted.where((h) => h.posterUrl != null).toList();
    final withoutPoster =
        s.torrentSorted.where((h) => h.posterUrl == null).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 168).floor().clamp(2, 6);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (withPoster.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.50,
                ),
                itemCount: withPoster.length,
                itemBuilder: (_, i) {
                  final hit = withPoster[i];
                  return TorrentPosterCard(
                    hit: hit,
                    onOpenImages: () => onOpenPosterImages(hit),
                    onOpenActions: () => onOpenPosterActions(hit),
                  );
                },
              ),
            if (withoutPoster.isNotEmpty) ...[
              if (withPoster.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Text(
                    '以下 ${withoutPoster.length} 条资源未提供海报图',
                    style: McText.caption.muted,
                  ),
                ),
              for (final hit in withoutPoster) ...[
                TorrentRowCard(
                  hit: hit,
                  onTap: () => onTapHit(hit),
                  onOpenImages: () => onOpenPosterImages(hit),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// 快照回放顶部提示条（快照时间 · 重新搜索）。
class _SnapshotBanner extends StatelessWidget {
  const _SnapshotBanner({
    required this.snapshotAt,
    required this.onResearch,
  });

  final String snapshotAt;
  final VoidCallback onResearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(McIcons.clock, size: 13, color: McTokens.textMuted),
        const SizedBox(width: 5),
        Text(
          '快照于 ${mcFromNowIso(snapshotAt, empty: snapshotAt)}',
          style: McText.caption.muted,
        ),
        const SizedBox(width: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onResearch();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              '重新搜索',
              style: McText.caption.copyWith(
                color: McTokens.accentStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
