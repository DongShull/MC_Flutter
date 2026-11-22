import '../../../core/image/image_urls.dart';
// IMPLEMENTED — 1:1 重写自 MovieClaw feature/search/SearchScreen.kt（库内搜索分支）。
// P2：增加资源（种子）搜索分支：SSE 流式站点结果 + 下载目标选择
// （安卓 SearchViewModel / DownloadTargetSheet 对应物）。
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/search_controller.dart';
import '../state/torrent_controller.dart';
import '../state/torrent_models.dart';
import '../widgets/torrent_sheets.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 搜索页：库内搜索（搜索框 + 历史 + 联想 + 结果）与资源搜索
/// （种子：分类页签 + 站点分块结果 + 下载目标选择）两个分区，
/// 上次停留的分区由 [SearchModeMemory] 恢复。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    this.initialMode,
    this.initialQuery,
    this.grabSubscriptionId,
    this.grabTitle,
  });

  /// 初始分区：'library' / 'torrents'（路由 `?mode=` 传入；null = 按记忆）。
  final String? initialMode;

  /// 初始关键词（路由 `?q=` 传入，如详情页“搜索资源”）。
  final String? initialQuery;

  /// 手动选种目标订阅（路由 `?forSub=` 传入订阅 id）。
  final int? grabSubscriptionId;

  /// 手动选种目标订阅标题（路由 `?forSubTitle=` 传入）。
  final String? grabTitle;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _input;

  /// 资源弹窗（操作面板 / 确认条 / 落点弹窗）是否已打开：
  /// 同一时间只开一张，内容随控制器状态切换。
  bool _torrentSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mode = widget.initialMode;
      if (mode == 'torrents' || mode == 'library') {
        ref.read(searchProvider.notifier).rememberMode(mode!);
      }
      final q = widget.initialQuery;
      if (q != null && q.isNotEmpty) {
        _input.text = q;
        if (ref.read(searchProvider).mode == 'torrents') {
          final torrent = ref.read(torrentSearchProvider.notifier);
          torrent.onQuery(q);
          unawaited(torrent.submit());
        } else {
          ref.read(searchProvider.notifier).search(q);
        }
      }
      final grabId = widget.grabSubscriptionId;
      if (grabId != null) {
        ref
            .read(torrentSearchProvider.notifier)
            .prefillGrabTarget(grabId, widget.grabTitle ?? '订阅');
      }
      unawaited(
          ref.read(torrentSearchProvider.notifier).loadSearchTabs());
      unawaited(ref.read(torrentSearchProvider.notifier).loadHistory());
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _isTorrents => ref.read(searchProvider).mode == 'torrents';

  void _submit(String q) {
    FocusScope.of(context).unfocus();
    _input.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    if (_isTorrents) {
      final torrent = ref.read(torrentSearchProvider.notifier);
      torrent.onQuery(q);
      unawaited(torrent.submit());
    } else {
      ref.read(searchProvider.notifier).search(q);
    }
  }

  void _switchMode(String mode) {
    ref.read(searchProvider.notifier).rememberMode(mode);
    if (mode == 'torrents') {
      _input.text = ref.read(torrentSearchProvider).query;
    } else {
      _input.text = ref.read(searchProvider).query;
    }
    setState(() {});
  }

  /// 资源弹窗与控制器状态同步：开一张可变内容的弹窗；
  /// 用户划掉弹窗时关掉面板与落点流程。
  void _syncTorrentSheet(TorrentSearchState s) {
    final shouldShow = s.actionHit != null || s.download.isOpen;
    if (shouldShow && !_torrentSheetOpen) {
      _torrentSheetOpen = true;
      unawaited(showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _TorrentSheetHost(),
      ).whenComplete(() {
        _torrentSheetOpen = false;
        if (!mounted) return;
        final st = ref.read(torrentSearchProvider);
        final notifier = ref.read(torrentSearchProvider.notifier);
        if (st.actionHit != null) notifier.closeActions();
        if (st.download.isOpen) notifier.closeTargetSheet();
      }));
    } else if (!shouldShow && _torrentSheetOpen) {
      _torrentSheetOpen = false;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(searchProvider);
    final torrent = ref.watch(torrentSearchProvider);
    ref.listen<TorrentSearchState>(
      torrentSearchProvider,
      (_, next) => _syncTorrentSheet(next),
    );
    // 资源搜索的提示（提交成功 / 投递结果）用 SnackBar 显示一次。
    ref.listen<TorrentSearchState>(
      torrentSearchProvider,
      (prev, next) {
        if (next.notice != null && next.notice != prev?.notice) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(next.notice!)));
          ref.read(torrentSearchProvider.notifier).consumeNotice();
        }
      },
    );
    final isTorrents = s.mode == 'torrents';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _input,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            onChanged: (v) {
              if (isTorrents) {
                ref.read(torrentSearchProvider.notifier).onQuery(v);
              } else {
                ref.read(searchProvider.notifier).onQuery(v);
              }
            },
            decoration: InputDecoration(
              isDense: true,
              hintText:
                  isTorrents ? '搜索资源（站点种子）' : '搜索库内影片、剧集与影人',
              prefixIcon: const Icon(McIcons.search, size: 20),
              suffixIcon: (isTorrents ? torrent.query : s.query).isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(McIcons.close2, size: 18),
                      onPressed: () {
                        _input.clear();
                        if (isTorrents) {
                          ref
                              .read(torrentSearchProvider.notifier)
                              .onQuery('');
                        } else {
                          ref.read(searchProvider.notifier).onQuery('');
                        }
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('库内'),
                  selected: !isTorrents,
                  onSelected: (_) => _switchMode('library'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('资源'),
                  selected: isTorrents,
                  onSelected: (_) => _switchMode('torrents'),
                ),
                if (torrent.grabTarget != null && isTorrents) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '为订阅「${torrent.grabTarget!.$2}」选种',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: isTorrents
                ? _TorrentBody(onPick: _submit)
                : (s.query.trim().isEmpty
                    ? _HistorySection(onPick: _submit)
                    : _ResultBody(onPick: _submit)),
          ),
        ],
      ),
    );
  }
}

/// 资源搜索结果区：分类页签 + 站点分块（逐站出结果）+ 种子行。
/// 点行开资源操作面板（查看详情 / 投给订阅 / 下载）。
class _TorrentBody extends ConsumerWidget {
  const _TorrentBody({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(torrentSearchProvider);
    final notifier = ref.read(torrentSearchProvider.notifier);
    if (s.query.trim().isEmpty) {
      return _TorrentHistory(onPick: onPick);
    }
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final tab in s.searchTabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tab.type == 'preset'
                        ? (tab.name ?? tab.id)
                        : (TorrentCategory.of(tab.id)?.label ?? tab.id)),
                    selected: s.activeTab?.id == tab.id &&
                        s.activeTab?.type == tab.type,
                    onSelected: (_) {
                      notifier.onTab(tab);
                      if (s.keyword.isNotEmpty) unawaited(notifier.submit());
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _TorrentResults(s: s),
        ),
      ],
    );
  }
}

class _TorrentHistory extends ConsumerWidget {
  const _TorrentHistory({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(torrentSearchProvider.select((s) => s.history));
    if (history.isEmpty) {
      return const Center(
        child: Text('输入关键词搜索各站点的种子',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            const Icon(McIcons.history1, size: 16, color: Colors.white54),
            const SizedBox(width: 6),
            const Text('搜索历史', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () => ref
                  .read(torrentSearchProvider.notifier)
                  .clearHistory(),
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in history)
              InputChip(
                label: Text(q),
                onPressed: () => onPick(q),
                onDeleted: () => ref
                    .read(torrentSearchProvider.notifier)
                    .removeHistory(q),
              ),
          ],
        ),
      ],
    );
  }
}

class _TorrentResults extends ConsumerWidget {
  const _TorrentResults({required this.s});

  final TorrentSearchState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(torrentSearchProvider.notifier);
    if (s.searching && s.blocks.isEmpty) {
      return const McLoadingView();
    }
    if (s.error != null && s.blocks.isEmpty) {
      return McErrorView(
        text: s.error!,
        onRetry: () => unawaited(notifier.submit()),
      );
    }
    if (!s.searching && s.blocks.isEmpty) {
      return Center(
        child: Text('没有找到「${s.keyword}」相关的资源',
            style: const TextStyle(color: Colors.white54)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final block in s.blocks) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${block.siteName}${block.items.isEmpty ? '' : ' · ${block.items.length} 条'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (block.error != null)
                  Expanded(
                    child: Text(block.error!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  )
                else if (block.elapsedMs > 0)
                  Text('${(block.elapsedMs / 1000).toStringAsFixed(1)}s',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          for (final hit in block.items) ...[
            _TorrentHitTile(hit: hit),
            const SizedBox(height: 8),
          ],
        ],
        if (s.searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (s.done != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                '共 ${s.done!.total} 条 · ${s.totalHits} 条已展示',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
      ],
    );
  }
}

/// 种子行：标题 + 站点/分类/大小/做种数 + 按行下载状态。
class _TorrentHitTile extends ConsumerWidget {
  const _TorrentHitTile({required this.hit});

  final TorrentHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(torrentSearchProvider);
    final downloadState =
        s.downloadStates[hitKey(hit)] ?? TorrentSubmitState.idle;
    final grabState = s.grabStates[hitKey(hit)] ?? TorrentSubmitState.idle;
    final showGrab = s.grabTarget != null &&
        grabState != TorrentSubmitState.done &&
        grabState != TorrentSubmitState.exists;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            ref.read(torrentSearchProvider.notifier).openActions(hit),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (hit.posterUrl != null && hit.posterUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl:
                        McImageUrls.resolve(hit.posterUrl, widthPx: 160),
                    httpHeaders: mcImageHeaders(),
                    width: 40,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 60,
                  decoration: BoxDecoration(
                    color: McColors.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(McIcons.downloadCloudOutFill, color: Colors.white24, size: 20),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (hit.siteName.isNotEmpty) hit.siteName,
                        if (hit.category != null)
                          TorrentCategory.of(hit.category)?.label ??
                              hit.category!,
                        if (hit.size != null && hit.size!.isNotEmpty)
                          hit.size!,
                        if (hit.seeders > 0) '做种 ${hit.seeders}',
                      ].join(' · '),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    if (hit.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          hit.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white38),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showGrab)
                    TextButton(
                      onPressed: () => ref
                          .read(torrentSearchProvider.notifier)
                          .grabForSubscription(hit),
                      child: Text(grabState.grabLabel),
                    ),
                  TextButton(
                    onPressed: downloadState == TorrentSubmitState.submitting
                        ? null
                        : () => ref
                            .read(torrentSearchProvider.notifier)
                            .startDownload(hit),
                    child: Text(downloadState.downloadLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 资源弹窗宿主：同一张 bottom sheet 内按控制器状态切换内容
/// （操作面板 → 确认条 → 落点弹窗），关闭时由 [_SearchPageState]
/// 的 `whenComplete` 回调关掉对应流程。
class _TorrentSheetHost extends ConsumerWidget {
  const _TorrentSheetHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(torrentSearchProvider);
    final notifier = ref.read(torrentSearchProvider.notifier);
    final hit = s.actionHit;
    if (hit != null) {
      final downloadState =
          s.downloadStates[hitKey(hit)] ?? TorrentSubmitState.idle;
      final grabState = s.grabStates[hitKey(hit)] ?? TorrentSubmitState.idle;
      final canGrab = s.grabTarget != null;
      // 管理员才有直接下载；成员的下载走订阅投递或无权限（与安卓
      // TorrentActionsSheet 的权限口径一致：成员看不到「下载」）。
      final canDownload = s.isAdmin ?? false;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hit.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (hit.siteName.isNotEmpty) hit.siteName,
                  if (hit.category != null)
                    TorrentCategory.of(hit.category)?.label ?? hit.category!,
                  if (hit.size != null && hit.size!.isNotEmpty) hit.size!,
                ].join(' · '),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (hit.detailUrl != null && hit.detailUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('查看详情'),
                  onTap: () async {
                    final uri = Uri.tryParse(hit.detailUrl!);
                    if (uri == null) return;
                    final ok = await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法打开详情链接')),
                      );
                    }
                  },
                ),
              if (canGrab)
                ListTile(
                  leading: const Icon(Icons.rss_feed),
                  title: Text('投给订阅「${s.grabTarget!.$2}」'),
                  subtitle: grabState == TorrentSubmitState.idle
                      ? null
                      : Text(grabState.grabLabel),
                  enabled: grabState != TorrentSubmitState.submitting &&
                      grabState != TorrentSubmitState.done &&
                      grabState != TorrentSubmitState.exists,
                  onTap: () => unawaited(notifier.grabForSubscription(hit)),
                ),
              if (canDownload)
                ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(downloadState.downloadLabel),
                  enabled: downloadState != TorrentSubmitState.submitting &&
                      downloadState != TorrentSubmitState.done &&
                      downloadState != TorrentSubmitState.exists,
                  onTap: () => notifier.startDownload(hit),
                ),
              if (!canDownload && !canGrab)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('当前账号没有下载权限',
                      style: TextStyle(color: Colors.white54)),
                ),
            ],
          ),
        ),
      );
    }
    final flow = s.download;
    final request = flow.request;
    if (request == null) return const SizedBox.shrink();
    if (flow.confirmOnly && flow.remembered != null) {
      final remembered = flow.remembered!;
      final label = switch (remembered.kind) {
        'smart' => '智能入库（自动识别条目并入库）',
        'dir' => '保存到 ${remembered.savePath ?? ''}',
        _ => '下载器默认目录',
      };
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                request.identityTitle ?? request.hint ?? '下载这条种子',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('上次的保存位置：$label',
                  style: const TextStyle(color: Colors.white70)),
              if (remembered.downloaderName != null &&
                  remembered.downloaderName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('下载器：${remembered.downloaderName}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: notifier.confirmRemembered,
                child: const Text('确认下载'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => notifier.reopenTargetDialog(),
                      child: const Text('更改'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          unawaited(notifier.forgetRemembered()),
                      child: const Text('不再记住'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final options = computeTargetOptions(
      isAdmin: s.isAdmin ?? false,
      target: flow.target,
      showOther: flow.showOther,
      downloader: flow.downloaders
          .where((d) => d.id == flow.downloaderId)
          .firstOrNull,
      memberLibraries: flow.memberLibraries,
      request: request,
    );
    return DownloadTargetSheet(
      flow: flow,
      options: options,
      isAdmin: s.isAdmin ?? false,
      onSelectOption: notifier.selectOption,
      onToggleRemember: notifier.setRemember,
      onShowOther: notifier.showOtherTargets,
      onSelectDownloader: notifier.setDownloader,
      onHintChanged: notifier.setHintDraft,
      onSearchHint: notifier.searchHint,
      onSelectCandidate: notifier.selectCandidate,
      onConfirm: notifier.submitSelected,
    );
  }
}

/// 空态：历史记录（本机 SharedPreferences，最近 20 条，可单删/清空）。
class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchProvider.select((s) => s.history));
    if (history.isEmpty) {
      return const Center(
        child: Text('还没有搜索记录', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            const Icon(McIcons.history1, size: 16, color: Colors.white54),
            const SizedBox(width: 6),
            const Text('搜索历史', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(searchProvider.notifier).clearHistory(),
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in history)
              InputChip(
                label: Text(q),
                onPressed: () => onPick(q),
                onDeleted: () =>
                    ref.read(searchProvider.notifier).removeHistory(q),
              ),
          ],
        ),
      ],
    );
  }
}

/// 结果区：联想 → 无结果（含建议词）→ 命中（人物行 + 条目平铺）。
class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);

    if (s.searching && s.hits.isEmpty && s.people.isEmpty) {
      return const McLoadingView();
    }
    if (s.error != null) {
      return McErrorView(
        text: s.error!,
        onRetry: () => ref.read(searchProvider.notifier).search(
              s.submittedQuery.isEmpty ? s.query : s.submittedQuery,
            ),
      );
    }

    final hasResults = s.hits.isNotEmpty || s.people.isNotEmpty;
    if (!hasResults) {
      return _NoResults(s: s, onPick: onPick);
    }

    // 人物行最多展示 8 个（对齐 Kotlin）。
    final people = s.people.take(8).toList();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 游标分页：快到底且还有 next_cursor 时追加一页。
        if (n.metrics.extentAfter < 600 &&
            s.nextCursor != null &&
            !s.searching) {
          ref.read(searchProvider.notifier).search(
                s.submittedQuery.isEmpty ? s.query : s.submittedQuery,
                cursor: s.nextCursor,
              );
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (s.selectedPerson != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActionChip(
                avatar: const Icon(McIcons.close2, size: 16),
                label: Text('只看「${s.selectedPerson!.name}」的作品'),
                onPressed: () =>
                    ref.read(searchProvider.notifier).clearPerson(),
              ),
            ),
          if (!s.indexPending && s.suggestions.isNotEmpty) ...[
            _SuggestionRow(suggestions: s.suggestions, onPick: onPick),
            const SizedBox(height: 12),
          ],
          if (people.isNotEmpty && s.selectedPerson == null) ...[
            const Text('相关影人', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: people.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _PersonCell(person: people[i]),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (s.selectedPerson != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                s.selectedPerson!.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 4),
          // 相关度平铺：服务端顺序即展示顺序，不做本地重排/分组。
          for (final hit in s.hits) ...[
            _HitTile(hit: hit),
            const SizedBox(height: 8),
          ],
          if (s.searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (s.nextCursor == null && s.hits.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('已加载全部结果', style: TextStyle(color: Colors.white54)),
              ),
            ),
          if (s.indexPending)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('部分内容仍在建立索引，结果可能不全',
                  style: TextStyle(color: Colors.white54)),
            ),
        ],
      ),
    );
  }
}

class _NoResults extends ConsumerWidget {
  const _NoResults({required this.s, required this.onPick});

  final SearchState s;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 40, color: Colors.white38),
          const SizedBox(height: 12),
          Text('没有找到「${s.submittedQuery}」相关的内容'),
          if (s.suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final sug in s.suggestions)
                  ActionChip(
                    label: Text(sug.label ?? sug.text),
                    onPressed: () => onPick(sug.text),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 输入联想行（候选词，点按直接搜索）。
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestions, required this.onPick});

  final List<SearchSuggestion> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sug = suggestions[i];
          return ActionChip(
            label: Text(sug.label ?? sug.text,
                style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            onPressed: () => onPick(sug.text),
          );
        },
      ),
    );
  }
}

/// 人物格：头像 + 名字（点击下钻该人物的库内作品）。
class _PersonCell extends ConsumerWidget {
  const _PersonCell({required this.person});

  final LibrarySearchPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TV 形态包焦点环；非 TV 原样返回 child，零开销。
    return McFocusRing(
      borderRadius: 12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ref.read(searchProvider.notifier).selectPerson(person),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              ClipOval(
                child: person.avatarUrl != null && person.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl:
                            McImageUrls.resolve(person.avatarUrl, widthPx: 160),
                        httpHeaders: mcImageHeaders(),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
              const SizedBox(height: 6),
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        width: 64,
        height: 64,
        color: McColors.surfaceDark,
        child: const Icon(McIcons.user, color: Colors.white38),
      );
}

/// 命中条目行：海报 + 标题/年份 + 命中原因（match.label）+ 所在库数。
class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final LibrarySearchHit hit;

  @override
  Widget build(BuildContext context) {
    // TV 形态包焦点环；非 TV 原样返回 child，零开销。
    return McFocusRing(
      borderRadius: 14,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // 库内条目 → 全局详情路由（播放一律交播放器域）。
            if (hit.libraryIds.isEmpty) return;
            context.push('/detail/${hit.libraryIds.first}/${hit.itemId}');
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hit.posterUrl != null && hit.posterUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl:
                              McImageUrls.resolve(hit.posterUrl, widthPx: 360),
                          httpHeaders: mcImageHeaders(),
                          width: 52,
                          height: 78,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _posterFallback(),
                        )
                      : _posterFallback(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (hit.year != null) hit.year.toString(),
                          if (hit.matchLabel.isNotEmpty) hit.matchLabel,
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54),
                      ),
                      if (hit.libraryIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            hit.libraryIds.length > 1
                                ? '在 ${hit.libraryIds.length} 个媒体库中'
                                : '在库',
                            style: const TextStyle(
                                fontSize: 12, color: McColors.accent),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(McIcons.arrowRight, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _posterFallback() => Container(
        width: 52,
        height: 78,
        color: McColors.surfaceDark,
        child: const Icon(McIcons.movie, color: Colors.white24, size: 20),
      );
}
