import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../../../core/player/player_page_args.dart';
import '../state/models.dart';
import '../state/offline_state.dart';
import '../state/server_reachability.dart';
import '../widgets/downloading_row.dart';

/// 离线模式顶部提示条（对齐 iOS OfflineBanner）：
/// 说明当前正在浏览本机已下载内容，并提供一键「重新连接」探测服务器。
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, this.onReconnected});

  final VoidCallback? onReconnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reach = ref.watch(serverReachabilityProvider);
    if (!reach.isOffline && reach.isReachable) {
      return const SizedBox.shrink();
    }
    final itemsCount = ref.watch(offlineProvider).downloadedItems.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: McTokens.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(McIcons.wifiOff, size: 18, color: McTokens.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('离线媒体库', style: McText.sub.semibold),
                const SizedBox(height: 2),
                Text(
                  '正在显示本机已下载的 $itemsCount 部作品 · 零网络播放',
                  style: McText.micro.muted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          McChip(
            label: reach.probing ? '连接中…' : '重新连接',
            compact: true,
            selected: true,
            onTap: reach.probing
                ? null
                : () async {
                    final ok = await ref
                        .read(serverReachabilityProvider.notifier)
                        .reconnect();
                    if (ok) {
                      ref.read(offlineProvider.notifier).flushViewings();
                      McToast.success('已连上服务器');
                      onReconnected?.call();
                    } else {
                      McToast.info('暂时还连不上服务器，继续离线浏览');
                    }
                  },
          ),
        ],
      ),
    );
  }
}

/// 离线媒体库专页（`/offline/library`，对齐 iOS OfflineLibraryHomeView + OfflineMinimalDetail）：
/// - 离线提示条 + 重连按钮；
/// - 「接着看」横滚卡（读取本机 `progress.json` 续播点）；
/// - 按媒体库分组的 2:3 本地海报网格（全部使用 `OfflineImages` 本地缓存图片）；
/// - 支持按最近下载 / 片名排序，点击进入离线详情直接本机起播。
class OfflineLibraryPage extends ConsumerStatefulWidget {
  const OfflineLibraryPage({super.key});

  @override
  ConsumerState<OfflineLibraryPage> createState() => _OfflineLibraryPageState();
}

class _OfflineLibraryPageState extends ConsumerState<OfflineLibraryPage> {
  bool _sortByTitle = false;

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider);
    final rawItems = offline.downloadedItems;
    final items = _sortByTitle
        ? ([...rawItems]..sort((a, b) => a.title.compareTo(b.title)))
        : rawItems;

    // 汇总本机有续播点的条目（positionMs > 0 且存在可播本地文件）
    final resumeEntries = <({
      OfflineItemSummary item,
      DownloadUnit unit,
      OfflineProgress progress,
    })>[];
    for (final entry in offline.progressByItem.entries) {
      final summary = offline.items[entry.key];
      if (summary == null) continue;
      for (final p in entry.value.entries) {
        if (p.value.positionMs <= 0) continue;
        final parts = p.key.split('-');
        if (parts.length != 2) continue;
        final season = int.tryParse(parts[0]);
        final episode = int.tryParse(parts[1]);
        if (season == null || episode == null) continue;
        final unit = offline.unitForEpisode(
          mediaItemId: entry.key,
          season: season,
          episode: episode,
        );
        if (unit != null && unit.playable) {
          resumeEntries.add((item: summary, unit: unit, progress: p.value));
        }
      }
    }
    resumeEntries.sort((a, b) => b.progress.updatedAt.compareTo(a.progress.updatedAt));

    // 按媒体库分组
    final groups = <({int libraryId, String name, List<OfflineItemSummary> items})>[];
    final byLib = <int, List<OfflineItemSummary>>{};
    final libNames = <int, String>{};
    for (final item in items) {
      byLib.putIfAbsent(item.libraryId, () => []).add(item);
      libNames[item.libraryId] = item.libraryName;
    }
    for (final e in byLib.entries) {
      groups.add((
        libraryId: e.key,
        name: libNames[e.key] ?? '媒体库',
        items: e.value,
      ));
    }

    final form = McFormWatch.of(context);
    final windowClass = mcWindowClassOf(form);

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/offline'),
            title: '离线媒体库',
            titleVisible: true,
            trailing: [
              McGlassIconButton(
                icon: McIcons.filterS,
                tooltip: _sortByTitle ? '当前按片名排序' : '当前按最近下载排序',
                onTap: () => setState(() => _sortByTitle = !_sortByTitle),
              ),
              const SizedBox(width: 6),
              McGlassIconButton(
                icon: McIcons.fileDownload,
                tooltip: '下载管理',
                onTap: () => context.go('/offline'),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: windowClass == McWindowClass.expanded
                      ? 960
                      : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    8,
                    McTokens.pagePadding,
                    36,
                  ),
                  children: [
                    const OfflineBanner(),
                    if (items.isEmpty) ...[
                      const SizedBox(height: 60),
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              McIcons.fileDownload,
                              size: 40,
                              color: McTokens.textFaint,
                            ),
                            const SizedBox(height: 12),
                            const Text('本机还没有已下载的影片', style: McText.titleSm),
                            const SizedBox(height: 6),
                            Text(
                              '在影片详情页点击「下载」，无网时即可在这里完整浏览和播放。',
                              style: McText.sub.muted,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (resumeEntries.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('接着看', style: McText.titleSm),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 186,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: resumeEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final entry = resumeEntries[index];
                              return _OfflineResumeCard(
                                item: entry.item,
                                unit: entry.unit,
                                progress: entry.progress,
                              );
                            },
                          ),
                        ),
                      ],
                      for (final group in groups) ...[
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(group.name, style: McText.titleSm),
                            ),
                            Text(
                              '${group.items.length} 部 · ${_sortByTitle ? '按片名' : '最近下载'}',
                              style: McText.caption.faint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 150,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.54,
                          ),
                          itemCount: group.items.length,
                          itemBuilder: (context, index) {
                            final item = group.items[index];
                            final playableCount = offline.doneUnits
                                .where(
                                  (u) =>
                                      u.mediaItemId == item.mediaItemId &&
                                      u.playable,
                                )
                                .length;
                            return _OfflinePosterCard(
                              item: item,
                              playableCount: playableCount,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => OfflineMinimalDetailPage(
                                    mediaItemId: item.mediaItemId,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineResumeCard extends ConsumerWidget {
  const _OfflineResumeCard({
    required this.item,
    required this.unit,
    required this.progress,
  });

  final OfflineItemSummary item;
  final DownloadUnit unit;
  final OfflineProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = (progress.durationMs != null && progress.durationMs! > 0)
        ? (progress.positionMs / progress.durationMs!).clamp(0.0, 1.0)
        : 0.0;
    final clock = mcFormatClock(progress.positionMs ~/ 1000);
    final sub = unit.isMovie
        ? '看到 $clock'
        : '${unit.displaySeasonEpisode ?? ''} · 看到 $clock';

    return McPressable(
      onTap: () {
        final uri = ref.read(offlineProvider.notifier).localPlayUri(unit);
        if (uri == null) {
          McToast.error('本地离线文件不存在');
          return;
        }
        context.push(
          '/player',
          extra: PlayerPageArgs(
            url: uri,
            mediaItemId: item.mediaItemId,
            fileId: unit.fileId,
            title: item.title,
            subtitle: unit.displaySeasonEpisode ?? '本机离线播放',
            startPosition: Duration(milliseconds: progress.positionMs),
            seasonNumber: unit.isMovie ? null : unit.seasonNumber,
            episodeNumber: unit.isMovie ? null : unit.episodeNumber,
            isEpisode: !unit.isMovie,
            isOffline: true,
            offlineItemId: item.mediaItemId.toString(),
            offlineFileId: unit.fileId,
            artworkUrl: item.posterUrl ?? item.backdropUrl,
          ),
        );
      },
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OfflineArtworkImage(
                      rawUrl: item.backdropUrl ?? item.posterUrl,
                      widthPx: 480,
                      placeholderIcon:
                          item.kind == 'tv' ? McIcons.tv : McIcons.movie,
                    ),
                    if (ratio > 0)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 3,
                            color: Colors.white.withValues(alpha: 0.9),
                            backgroundColor: Colors.black.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.sub.semibold,
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.faint.tabular,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflinePosterCard extends StatelessWidget {
  const _OfflinePosterCard({
    required this.item,
    required this.playableCount,
    required this.onTap,
  });

  final OfflineItemSummary item;
  final int playableCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return McPressable(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(McTokens.posterRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OfflineArtworkImage(
                      rawUrl: item.posterUrl,
                      widthPx: 360,
                      placeholderIcon:
                          item.kind == 'tv' ? McIcons.tv : McIcons.movie,
                    ),
                    if (item.kind == 'tv' && playableCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$playableCount 集',
                            style: McText.micro.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.sub.semibold,
          ),
          if (item.year != null)
            Text('${item.year}', style: McText.micro.faint),
        ],
      ),
    );
  }
}

/// 离线极简详情页（对齐 iOS OfflineMinimalDetail）：
/// 完全依赖本机 `summary.json` / `item.json` / `season-XX.json` / `playback.json`，无网也可看简介、选季、直接播放或删除。
class OfflineMinimalDetailPage extends ConsumerStatefulWidget {
  const OfflineMinimalDetailPage({super.key, required this.mediaItemId});

  final int mediaItemId;

  @override
  ConsumerState<OfflineMinimalDetailPage> createState() =>
      _OfflineMinimalDetailPageState();
}

class _OfflineMinimalDetailPageState
    extends ConsumerState<OfflineMinimalDetailPage> {
  String? _plot;
  int? _selectedSeason;
  Map<int, String> _episodeNames = const {};
  Map<int, String> _episodeStills = const {};

  @override
  void initState() {
    super.initState();
    _loadLocalMetadata();
  }

  Future<void> _loadLocalMetadata() async {
    final ctrl = ref.read(offlineProvider.notifier);
    final detail = await ctrl.loadItemDetailJson(widget.mediaItemId);
    if (!mounted) return;
    final meta = detail?['local_meta'] ?? detail?['localMeta'];
    final plot = meta is Map ? meta['plot']?.toString() : null;
    setState(() => _plot = plot);

    final units = ref
        .read(offlineProvider)
        .doneUnits
        .where((u) => u.mediaItemId == widget.mediaItemId && u.playable)
        .toList();
    final seasons = {
      for (final u in units)
        if (!u.isMovie) u.seasonNumber,
    }.toList()
      ..sort();
    if (seasons.isNotEmpty) {
      await _selectSeason(seasons.first);
    }
  }

  Future<void> _selectSeason(int season) async {
    setState(() => _selectedSeason = season);
    final data = await ref
        .read(offlineProvider.notifier)
        .loadSeasonJson(widget.mediaItemId, season);
    if (!mounted) return;
    final names = <int, String>{};
    final stills = <int, String>{};
    final eps = (data?['episodes'] as List?) ?? const [];
    for (final raw in eps.whereType<Map>()) {
      final numEp =
          ((raw['episode_number'] ?? raw['episodeNumber']) as num?)?.toInt();
      if (numEp == null) continue;
      final name = raw['name']?.toString();
      if (name != null && name.isNotEmpty) names[numEp] = name;
      final still = (raw['still_url'] ?? raw['stillUrl'])?.toString();
      if (still != null && still.isNotEmpty) stills[numEp] = still;
    }
    setState(() {
      _episodeNames = names;
      _episodeStills = stills;
    });
  }

  void _confirmDelete(DownloadUnit unit, int totalUnitsCount) {
    final label = unit.displaySeasonEpisode != null
        ? '${unit.title} · ${unit.displaySeasonEpisode}'
        : unit.title;
    final sizeHint = unit.receivedBytes > 0
        ? '立即释放 ${mcFormatBytes(unit.receivedBytes)}，只删本机视频文件，观看进度会保留。'
        : '只删本机视频文件，观看进度会保留。';
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('删除「$label」的离线副本？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(sizeHint, style: McText.sub.muted),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '删除副本',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await ref
                          .read(offlineProvider.notifier)
                          .deleteDownloaded(unit);
                      if (mounted && totalUnitsCount <= 1) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _playUnit(DownloadUnit unit) {
    final ctrl = ref.read(offlineProvider.notifier);
    final uri = ctrl.localPlayUri(unit);
    if (uri == null) {
      McToast.error('本地离线文件不存在');
      return;
    }
    final localProg = ref.read(offlineProvider).localProgress(
          widget.mediaItemId,
          unit.seasonNumber,
          unit.episodeNumber,
        );
    context.push(
      '/player',
      extra: PlayerPageArgs(
        url: uri,
        mediaItemId: unit.mediaItemId,
        fileId: unit.fileId,
        title: unit.title,
        subtitle: unit.displaySeasonEpisode ?? '本机离线播放',
        startPosition: localProg != null && localProg.positionMs > 0
            ? Duration(milliseconds: localProg.positionMs)
            : null,
        seasonNumber: unit.isMovie ? null : unit.seasonNumber,
        episodeNumber: unit.isMovie ? null : unit.episodeNumber,
        isEpisode: !unit.isMovie,
        isOffline: true,
        offlineItemId: (unit.mediaItemId ?? widget.mediaItemId).toString(),
        offlineFileId: unit.fileId,
        artworkUrl: unit.posterUrl ?? unit.backdropUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider);
    final summary = offline.items[widget.mediaItemId] ??
        offline.downloadedItems
            .where((i) => i.mediaItemId == widget.mediaItemId)
            .firstOrNull;
    final units = offline.doneUnits
        .where((u) => u.mediaItemId == widget.mediaItemId && u.playable)
        .toList()
      ..sort((a, b) {
        final s = a.seasonNumber.compareTo(b.seasonNumber);
        return s != 0 ? s : a.episodeNumber.compareTo(b.episodeNumber);
      });

    final isTv = summary?.kind == 'tv' || units.any((u) => !u.isMovie);
    final seasons = {
      for (final u in units)
        if (!u.isMovie) u.seasonNumber,
    }.toList()
      ..sort();
    final activeSeason = _selectedSeason ?? seasons.firstOrNull;
    final visibleUnits = isTv && activeSeason != null
        ? units.where((u) => u.seasonNumber == activeSeason).toList()
        : units;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () => Navigator.of(context).pop(),
            title: summary?.title ?? '本机副本',
            titleVisible: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                McTokens.pagePadding,
                10,
                McTokens.pagePadding,
                36,
              ),
              children: [
                if (summary != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 90,
                          height: 135,
                          child: OfflineArtworkImage(
                            rawUrl: summary.posterUrl,
                            widthPx: 240,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(summary.title, style: McText.titleLg),
                            if (summary.year != null) ...[
                              const SizedBox(height: 4),
                              Text('${summary.year}', style: McText.sub.muted),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              '本机离线副本 · ${units.length} 个文件',
                              style: McText.caption.faint,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_plot != null && _plot!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_plot!, style: McText.sub.muted),
                ],
                if (isTv && seasons.length > 1) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final s in seasons)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: McChip(
                              label: s == 0 ? '特别篇' : '第 $s 季',
                              selected: s == activeSeason,
                              onTap: () => _selectSeason(s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (visibleUnits.isEmpty)
                  Text('本机已无可播副本', style: McText.sub.muted)
                else
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      for (final unit in visibleUnits)
                        McInsetRow(
                          leading: unit.isMovie
                              ? const Icon(
                                  McIcons.play2Fill,
                                  color: McTokens.accentStrong,
                                  size: 20,
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 64,
                                    height: 36,
                                    child: OfflineArtworkImage(
                                      rawUrl: _episodeStills[
                                              unit.episodeNumber] ??
                                          unit.stillUrl ??
                                          summary?.backdropUrl,
                                      widthPx: 240,
                                      placeholderIcon: McIcons.play2Fill,
                                    ),
                                  ),
                                ),
                          title: unit.isMovie
                              ? '播放正片'
                              : [
                                  unit.displaySeasonEpisode ??
                                      '第 ${unit.episodeNumber} 集',
                                  if (_episodeNames[unit.episodeNumber] != null)
                                    _episodeNames[unit.episodeNumber]!,
                                ].join(' · '),
                          subtitle: [
                            unit.profileLabel,
                            if (unit.receivedBytes > 0)
                              mcFormatBytes(unit.receivedBytes),
                            if (unit.watched) '已看完',
                          ].join(' · '),
                          trailing: IconButton(
                            tooltip: '删除副本',
                            icon: const Icon(
                              McIcons.trash2,
                              size: 17,
                              color: McTokens.danger,
                            ),
                            onPressed: () =>
                                _confirmDelete(unit, units.length),
                          ),
                          onTap: () => _playUnit(unit),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
