import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../../../core/player/player_page_args.dart';
import '../routes.dart';
import '../state/home_rows.dart';
import '../state/library_home_controller.dart';
import '../state/models.dart';
import '../widgets/library_shared.dart';

/// 媒体库首页（默认 Tab 1，1:1 对齐 iOS `LibraryHomeView.swift` & Web 银玻璃媒体库页）：
/// - 顶栏：左上 `30sp Bold`「媒体库」+ 右侧液态玻璃 `⋯` 菜单钮、片段钮与搜索圆钮；
/// - 下拉二楼：继续下拉超过 `-96dp` 展开胶片齿孔预览条，松手伴随触感震动直接进入竖屏「片段（Reels）」；
/// - 内容行流：`16:9` 接下来继续横卡（`McUpNextCard`）→ 我的媒体库圆角横卡 → 各库/收藏/合集 `2:3` 海报架 → 页脚库存统计。
class LibraryHomePage extends ConsumerStatefulWidget {
  const LibraryHomePage({super.key});

  @override
  ConsumerState<LibraryHomePage> createState() => _LibraryHomePageState();
}

class _LibraryHomePageState extends ConsumerState<LibraryHomePage> {
  static const _reelsTriggerOffset = -112.0;

  late final LibraryHomeController _controller =
      ref.read(libraryHomeProvider.notifier);

  double _overscroll = 0;
  bool _armedReels = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_controller.reload);
  }

  @override
  void dispose() {
    _controller.stopPolling();
    super.dispose();
  }

  Future<void> _openCustomize() async {
    await context.push(routeLibraryCustomize);
    if (mounted) await _controller.reload();
  }

  void _openItem(int libraryId, int itemId) =>
      context.push('/detail/$libraryId/$itemId');

  void _play(UpNextItem item) {
    context.push(
      '/player',
      extra: PlayerPageArgs(
        mediaItemId: item.mediaItemId,
        seasonNumber: item.isEpisode ? item.seasonNumber : null,
        episodeNumber: item.isEpisode ? item.episodeNumber : null,
        title: item.title,
        subtitle: item.isEpisode
            ? episodeCode(item.seasonNumber, item.episodeNumber)
            : null,
        startPosition:
            item.positionMs > 0 ? Duration(milliseconds: item.positionMs) : null,
        isEpisode: item.isEpisode,
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final px = n.metrics.pixels;
    if (px < 0) {
      final armed = px <= _reelsTriggerOffset;
      if (armed != _armedReels) {
        if (armed) HapticFeedback.mediumImpact();
        setState(() {
          _armedReels = armed;
          _overscroll = px;
        });
      } else if ((_overscroll - px).abs() > 2) {
        setState(() => _overscroll = px);
      }
    } else if (_overscroll != 0 || _armedReels) {
      setState(() {
        _overscroll = 0;
        _armedReels = false;
      });
    }

    if (n is ScrollEndNotification && _armedReels) {
      setState(() {
        _overscroll = 0;
        _armedReels = false;
      });
      context.push('/reels');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryHomeProvider);
    final pullDepth = math.max(0.0, -_overscroll);

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: RefreshIndicator(
              edgeOffset: MediaQuery.paddingOf(context).top + 56,
              color: McTokens.accentStrong,
              backgroundColor: McTokens.surfaceSolid,
              onRefresh: _controller.reload,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  _buildTopBar(context),
                  ..._content(state),
                  if (state.libraries != null && state.libraries!.isNotEmpty)
                    SliverToBoxAdapter(child: _statsFooter(state)),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: McTokens.bottomBarClearance),
                  ),
                ],
              ),
            ),
          ),
          // 下拉二楼胶片条（Reels 入口提示）
          if (pullDepth > 28)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Opacity(
                  opacity: ((pullDepth - 28) / 56).clamp(0.0, 1.0),
                  child: Center(
                    child: _ReelsPullPill(armed: _armedReels),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return McSliverTopBar(
      title: '媒体库',
      onSearch: () => context.push('/search'),
      actions: [
        McGlassIconButton(
          icon: McIcons.play2,
          tooltip: '片段 Reels',
          onTap: () => context.push('/reels'),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: '更多操作',
          onSelected: (v) {
            if (v == 'customize') _openCustomize();
            if (v == 'collections') context.push(routeLibraryCollections);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'customize',
              child: _MenuRow(icon: McIcons.setting1, label: '自定义首页'),
            ),
            const PopupMenuItem(
              value: 'collections',
              child: _MenuRow(icon: McIcons.mediaLibraryFill, label: '全部合集'),
            ),
          ],
          child: const IgnorePointer(
            child: McGlassIconButton(
              icon: McIcons.more,
              onTap: null,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _statsFooter(LibraryHomeState state) {
    final text = libraryStatsSummary(state.visibleLibraries);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        36,
        McTokens.pagePadding,
        8,
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: McText.caption.faint,
        ),
      ),
    );
  }

  List<Widget> _content(LibraryHomeState state) {
    if (state.libraries == null && !state.failed) {
      return const [
        SliverToBoxAdapter(
          child: McFeedSkeleton(showHero: false),
        ),
      ];
    }
    if (state.libraries == null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 72),
            child: McErrorView(
              title: '媒体库暂时无法加载',
              text: '请检查服务器连接后重试。',
              onRetry: _controller.reload,
            ),
          ),
        ),
      ];
    }
    final rows = state.rows;
    return [
      if (state.failed) const SliverToBoxAdapter(child: _FailedBanner()),
      if (state.libraries!.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 56),
            child: LibraryEmptyState(
              title: state.isAdmin ? '为收藏准备一个家' : '还没有可浏览的媒体库',
              message: state.isAdmin
                  ? '创建电影库或剧集库，选好根目录后，订阅完成的内容会自动整理到这里。'
                  : '当前账号暂时没有可浏览的媒体库，请联系管理员分配媒体库权限。',
            ),
          ),
        )
      else if (rows.isEmpty)
        SliverToBoxAdapter(child: _AllHiddenBox(onCustomize: _openCustomize))
      else
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) => _rowView(state, rows[i]),
        ),
    ];
  }

  Widget _rowView(LibraryHomeState state, HomeRow row) {
    final k = row.kind;
    if (k is UpNextRowKind) return _upNextRow(state, row);
    if (k is FavoritesRowKind) {
      if (state.favorites.items.isEmpty) return const SizedBox.shrink();
      return _PosterRow(
        title: row.title(),
        moreTitle: '${state.favorites.total} 部',
        onMore: () => context.push(routeLibraryFavorites),
        items: state.favorites.items,
        favorite: true,
        onOpen: _openItem,
      );
    }
    if (k is LibrariesRowKind) return _librariesRow(state, row);
    if (k is LibraryRowKind) {
      return _PosterRow(
        title: row.title(),
        moreTitle: '查看全部',
        onMore: () => context.push(routeLibraryDetail(k.library.id)),
        items: state.itemsByKey[LibraryHomeController.fetchKey(row)] ?? const [],
        fallbackLibraryId: k.library.id,
        onOpen: _openItem,
      );
    }
    if (k is CollectionRowKind) {
      return _PosterRow(
        title: row.title(),
        moreTitle: '查看全部',
        onMore: () => context.push(routeLibraryCollection(k.collection.id)),
        items: state.itemsByKey[LibraryHomeController.fetchKey(row)] ?? const [],
        fallbackLibraryId: k.collection.libraryId ?? 0,
        onOpen: _openItem,
      );
    }
    return const SizedBox.shrink();
  }

  // ── 接下来继续：16:9 沉浸横卡横滑（对齐 iOS & Web UpNextRow） ──

  Widget _upNextRow(LibraryHomeState state, HomeRow row) {
    if (state.upNext.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(
            title: row.title(),
            trailing: SizedBox(
              width: 30,
              height: 30,
              child: PopupMenuButton<int>(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  McIcons.more,
                  size: 19,
                  color: McTokens.textMuted,
                ),
                onSelected: (v) => v == 3
                    ? _openLibraryPicker(state)
                    : _confirmClearHistory(v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 0, child: Text('清空今天的观看记录…')),
                  PopupMenuItem(value: 1, child: Text('清空最近一周的观看记录…')),
                  PopupMenuItem(value: 2, child: Text('清空全部观看记录…')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 3, child: Text('清空某个媒体库的观看记录…')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 204,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              itemCount: state.upNext.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final it = state.upNext[i];
                final art = it.isEpisode
                    ? (it.episodeStillUrl ??
                        it.episodeStillOriginalUrl ??
                        it.backdropUrl ??
                        it.posterUrl)
                    : (it.backdropUrl ?? it.posterUrl);
                final frac = (it.progressPercent != null && it.positionMs > 0)
                    ? (it.progressPercent! / 100.0).clamp(0.02, 1.0)
                    : null;
                final subParts = <String>[
                  if (it.isEpisode)
                    episodeCode(it.seasonNumber, it.episodeNumber),
                  if (it.isEpisode &&
                      it.episodeTitle != null &&
                      it.episodeTitle!.isNotEmpty)
                    it.episodeTitle!
                  else if (it.year != null)
                    '${it.year}',
                  if (it.unwatchedAheadCount > 0)
                    '还有 ${it.unwatchedAheadCount} 集',
                ];
                final ago = it.lastPlayedAt != null && it.lastPlayedAt!.isNotEmpty
                    ? '${mcFromNowIso(it.lastPlayedAt)}看过'
                    : null;

                return McUpNextCard(
                  width: 238,
                  title: it.title,
                  backdropUrl: art,
                  subtitle: subParts.join(' · '),
                  footnote: ago,
                  timeLabel: _formatProgressTime(it.positionMs, it.durationMs),
                  progress: frac,
                  onPlay: () => _play(it),
                  onTap: () => _openItem(it.libraryId, it.mediaItemId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _formatProgressTime(int posMs, int? durMs) {
    if (posMs <= 0 && (durMs == null || durMs <= 0)) return null;
    String fmt(int ms) {
      final totalSec = ms ~/ 1000;
      final h = totalSec ~/ 3600;
      final m = (totalSec % 3600) ~/ 60;
      final s = totalSec % 60;
      if (h > 0) return '$h:${mcPad2(m)}:${mcPad2(s)}';
      return '${mcPad2(m)}:${mcPad2(s)}';
    }

    if (posMs > 0 && durMs != null && durMs > 0) {
      return '${fmt(posMs)} / ${fmt(durMs)}';
    }
    if (durMs != null && durMs > 0) return fmt(durMs);
    return fmt(posMs);
  }

  Future<void> _confirmClearHistory(int which) async {
    final now = DateTime.now();
    late final String label;
    late final String description;
    DateTime? since;
    if (which == 0) {
      label = '今天的观看记录';
      since = DateTime(now.year, now.month, now.day);
      description = '今天播放过的作品，续播进度、已看标记和播放次数都会清除，无法恢复。只影响你自己的记录。';
    } else if (which == 1) {
      label = '最近一周的观看记录';
      since = now.subtract(const Duration(days: 7));
      description = '最近 7 天播放过的作品，续播进度、已看标记和播放次数都会清除，无法恢复。只影响你自己的记录。';
    } else {
      label = '全部观看记录';
      description = '所有作品的续播进度、已看标记和播放次数都会清除，无法恢复。只影响你自己的记录。';
    }
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('清空$label？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(description, style: McText.sub.muted),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '清空',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final deleted = await _controller.clearHistory(since: since);
      if (!mounted) return;
      McToast.success(
        since != null
            ? (deleted > 0 ? '已清空$label' : '$label里没有可清除的记录')
            : '已清空全部观看记录',
      );
    } catch (_) {
      if (mounted) McToast.error('清空观看记录失败，请稍后重试');
    }
  }

  Future<void> _openLibraryPicker(LibraryHomeState state) async {
    final libs = state.visibleLibraries;
    int? picked = libs.isNotEmpty ? libs.first.id : null;
    var busy = false;
    await showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final name =
              libs.where((l) => l.id == picked).map((l) => l.name).firstOrNull;
          final enabled = picked != null && !busy;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('清空某个媒体库的观看记录', style: McText.titleSm),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (libs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('没有可浏览的媒体库', style: McText.sub),
                  )
                else
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      for (final lib in libs)
                        McInsetRow(
                          title: lib.name,
                          onTap: () => setSheet(() => picked = lib.id),
                          trailing: picked == lib.id
                              ? const Icon(
                                  McIcons.check,
                                  size: 18,
                                  color: McTokens.accentStrong,
                                )
                              : null,
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  '选中库里所有作品的续播进度、已看标记和播放次数都会清除，无法恢复。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 14),
                McActionPill(
                  label: busy
                      ? '清空中…'
                      : (name == null ? '清空' : '清空「$name」'),
                  primary: false,
                  tone: McGlassTone.danger,
                  expanded: true,
                  busy: busy,
                  onTap: !enabled
                      ? null
                      : () async {
                          setSheet(() => busy = true);
                          try {
                            await _controller.clearHistory(libraryId: picked);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) McToast.success('已清空该库的观看记录');
                          } catch (_) {
                            if (mounted) McToast.error('清空观看记录失败，请稍后重试');
                            if (ctx.mounted) setSheet(() => busy = false);
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 我的媒体库：横滑库卡片 ──

  Widget _librariesRow(LibraryHomeState state, HomeRow row) {
    final libs = state.visibleLibraries;
    if (libs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(
            title: row.title(),
            trailingText: state.collections.isNotEmpty ? '全部合集' : null,
            onTap: state.collections.isNotEmpty
                ? () => context.push(routeLibraryCollections)
                : null,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 228 / 2.05 + 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              itemCount: libs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final lib = libs[i];
                final hasPosters =
                    (state.itemsByKey[LibraryHomeController.coverKey(lib.id)] ??
                            const [])
                        .isNotEmpty;
                return McPressable(
                  onTap: () => context.push(routeLibraryDetail(lib.id)),
                  child: SizedBox(
                    width: 228,
                    child: _LibraryCard(
                      library: lib,
                      showCover: hasPosters || lib.customCover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelsPullPill extends StatelessWidget {
  const _ReelsPullPill({required this.armed});

  final bool armed;

  @override
  Widget build(BuildContext context) {
    return McLiquidGlass(
      radius: McTokens.pillRadius,
      tone: armed ? McGlassTone.strong : McGlassTone.regular,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            McIcons.play2Fill,
            size: 14,
            color: armed ? McTokens.accentStrong : McTokens.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            armed ? '松手进入「片段」' : '继续下拉进入「片段」',
            style: McText.caption.copyWith(
              color: armed ? McTokens.text : McTokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 17, color: McTokens.textMuted),
          const SizedBox(width: 10),
          Text(label),
        ],
      );
}

/// 库卡片：服务端拼贴封面 + 库名 +「默认」；扫描/整理/刷元数据时展示银白进度环。
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.library, required this.showCover});

  final LibraryView library;
  final bool showCover;

  bool get _busy =>
      library.scanning ||
      library.organizing ||
      (library.metadataRefresh?.refreshing ?? false);

  ({int? processed, int? total, String label}) get _progress {
    if (library.scanning) {
      return (
        processed: library.scanProgress?.processed,
        total: library.scanProgress?.total,
        label: scanPhaseLabel(library.scanProgress?.phase),
      );
    }
    if (library.organizing) {
      return (
        processed: library.organizeProgress?.processed,
        total: library.organizeProgress?.total,
        label: '整理中',
      );
    }
    return (
      processed: library.metadataRefresh?.processed,
      total: library.metadataRefresh?.total,
      label: '刷新元数据',
    );
  }

  @override
  Widget build(BuildContext context) {
    final importing = _busy ? 0 : library.lastScanDeferred;
    final icon = libraryKindIcon(library.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2.05,
          child: Container(
            clipBehavior: Clip.antiAlias,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(McTokens.cardRadius),
              border: Border.all(color: McTokens.line),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(McTokens.cardRadius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1D26), Color(0xFF0E1016)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Icon(icon, size: 38, color: const Color(0x21FFFFFF)),
                if (showCover)
                  LibraryNetImage(
                    url: McImageUrls.resolve(
                      '/libraries/${library.id}/cover',
                      widthPx: 720,
                    ),
                    placeholderIcon: icon,
                  ),
                if (_busy)
                  ColoredBox(
                    color: const Color(0x94000000),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LibraryProgressRing(
                          processed: _progress.processed,
                          total: _progress.total,
                          size: 56,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _progress.label,
                          style: McText.caption.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (library.metadataRefresh?.refreshing == true &&
                            library.metadataRefresh?.activeLine != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              library.metadataRefresh!.activeLine!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.micro.muted,
                            ),
                          ),
                      ],
                    ),
                  )
                else if (importing > 0)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(McTokens.pillRadius),
                        border: Border.all(color: const Color(0x597FB0FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: McTokens.info,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$importing 个新文件入库中',
                            style: McText.micro.copyWith(color: McTokens.info),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  library.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.ui.semibold,
                ),
              ),
              if (library.isDefault)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: McTokens.surfaceInset,
                    borderRadius: BorderRadius.circular(McTokens.pillRadius),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Text('默认', style: McText.micro.muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 横滚海报行（收藏行 / 库行 / 合集行统一形态）；长按海报弹出入库/收藏信息。
class _PosterRow extends StatelessWidget {
  const _PosterRow({
    required this.title,
    required this.moreTitle,
    required this.onMore,
    required this.items,
    required this.onOpen,
    this.fallbackLibraryId = 0,
    this.favorite = false,
  });

  final String title;
  final String moreTitle;
  final VoidCallback onMore;
  final List<LibraryItemView> items;
  final void Function(int libraryId, int itemId) onOpen;
  final int fallbackLibraryId;
  final bool favorite;

  static const _cellWidth = 122.0;

  Future<void> _showInfo(
    BuildContext context,
    Offset at,
    List<String> lines,
  ) async {
    if (lines.isEmpty) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        at.dx,
        at.dy,
        overlay.size.width - at.dx,
        overlay.size.height - at.dy,
      ),
      items: [
        for (final l in lines)
          PopupMenuItem<void>(enabled: false, child: Text(l)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(
            title: title,
            trailingText: moreTitle,
            onTap: onMore,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _cellWidth / McTokens.posterAspect + 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                final recentBadge = !favorite && item.recentAddition != null
                    ? formatRecentAddition(item.recentAddition!)
                    : null;
                return GestureDetector(
                  onLongPressStart: (d) => _showInfo(
                    context,
                    d.globalPosition,
                    posterInfoLines(item, favorite: favorite),
                  ),
                  child: McPosterCard(
                    width: _cellWidth,
                    title: item.title,
                    posterUrl: item.posterUrl,
                    imageAspect: item.primaryAspect,
                    subtitle: [
                      if (item.year != null) '${item.year}',
                      if ((item.rating ?? 0) > 0)
                        '★ ${item.rating!.toStringAsFixed(1)}',
                    ].join(' · '),
                    badge: recentBadge,
                    favorite: favorite || item.isFavorite,
                    onTap: () => onOpen(
                      item.libraryId ?? fallbackLibraryId,
                      item.mediaItemId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedBanner extends StatelessWidget {
  const _FailedBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        12,
        McTokens.pagePadding,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x1FF5C451),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x4DF5C451)),
        ),
        child: Row(
          children: [
            const Icon(McIcons.alert1, size: 16, color: McTokens.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '与服务器通信暂时中断，正在自动重试；当前展示上次缓存。',
                style: McText.caption.copyWith(color: McTokens.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllHiddenBox extends StatelessWidget {
  const _AllHiddenBox({required this.onCustomize});

  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: McEmptyView(
        icon: McIcons.setting1,
        title: '首页空空如也',
        text: '所有栏目都被隐藏了。到「自定义首页」挑几行回来，或恢复默认。',
        actionLabel: '自定义首页',
        onRetry: onCustomize,
      ),
    );
  }
}
