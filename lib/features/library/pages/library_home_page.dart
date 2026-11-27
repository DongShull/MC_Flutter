import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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
import '../../offline/embed.dart';
import '../routes.dart';
import '../state/home_rows.dart';
import '../state/library_home_controller.dart';
import '../state/models.dart';
import '../widgets/library_shared.dart';
import '../widgets/library_widgets.dart';

/// 媒体库首页（默认 Tab 1，1:1 对齐 upstream iOS `LibraryHomeView.swift`）：
/// - 顶栏：左上 `30sp Bold`「媒体库」+ 右侧液态玻璃 `⋯` 菜单钮、片段钮与搜索圆钮；
/// - 下拉二楼：继续下拉展开 35mm 胶片齿孔预览条（`ReelsFilmStrip`），松手伴随触感震动进入竖屏「片段（Reels）」（蜂窝网络先弹确认）；
/// - 内容行流：`16:9` 接下来继续横卡 → 我的收藏 → 我的媒体库（真实库 + 置顶合集虚拟库卡）→ 按类型找电影/剧集渐变剧照卡 → 各库/跨库类型/合集 `2:3` 海报架 → 页脚库存统计；
/// - 离线兜底：网络不可达时展示警告横幅，并给出「查看本机 N 部离线内容」入口。
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
  int _lastFilmStep = 0;
  final int _floorShuffle = math.Random().nextInt(1 << 30);

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
    if (mounted) await _controller.reloadWithPrefs();
  }

  void _openItem(int libraryId, int itemId) {
    if (libraryId > 0) {
      context.push('/detail/$libraryId/$itemId');
    }
  }

  Future<bool> _isOnCellular() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return false;
    try {
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      if (ifaces.isEmpty) return false;
      var hasWifi = false;
      var hasCell = false;
      for (final iface in ifaces) {
        final name = iface.name.toLowerCase();
        if (name.startsWith('en') ||
            name.startsWith('wlan') ||
            name.startsWith('eth') ||
            name.startsWith('wifi')) {
          hasWifi = true;
        } else if (name.startsWith('pdp_ip') ||
            name.startsWith('rmnet') ||
            name.startsWith('ccmni') ||
            name.startsWith('wwan')) {
          hasCell = true;
        }
      }
      return hasCell && !hasWifi;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openReels() async {
    final cellular = await _isOnCellular();
    if (!mounted) return;
    if (!cellular) {
      context.push('/reels');
      return;
    }
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('当前正在使用移动数据', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '「片段」会自动连续预载高清视频片段，在蜂窝网络下可能消耗较多流量，确认进入吗？',
              style: McText.sub.muted,
            ),
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
                    label: '继续进入',
                    primary: true,
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
    if (ok == true && mounted) {
      context.push('/reels');
    }
  }

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
      final step = ((-px) * 2.4 / 96).floor();
      if (step != _lastFilmStep && !armed && -px > 36) {
        _lastFilmStep = step;
        HapticFeedback.selectionClick();
      }
      if (armed != _armedReels) {
        if (armed) HapticFeedback.heavyImpact();
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
      _openReels();
    }
    return false;
  }

  List<String> _floorStills(LibraryHomeState state) {
    final seen = <String>{};
    final out = <String>[];
    for (final u in state.upNext) {
      final p = u.backdropUrl ?? u.episodeStillUrl;
      if (p != null && p.isNotEmpty && seen.add(p)) out.add(p);
    }
    for (final list in state.itemsByKey.values) {
      for (final item in list) {
        final p = item.backdropUrl;
        if (p != null && p.isNotEmpty && seen.add(p)) out.add(p);
      }
    }
    out.sort((a, b) => (a.hashCode ^ _floorShuffle)
        .compareTo(b.hashCode ^ _floorShuffle));
    return out
        .take(8)
        .map((p) => McImageUrls.resolve(p, widthPx: 360))
        .where((u) => u.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryHomeProvider);
    final offline = ref.watch(offlineProvider);
    final offlineCount = offline.doneUnits.length;
    final pullDepth = math.max(0.0, -_overscroll);
    final reveal = ((pullDepth - 28) / 64).clamp(0.0, 1.0);

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
                  ..._content(state, offlineCount),
                  if (state.libraries != null && state.libraries!.isNotEmpty)
                    SliverToBoxAdapter(child: _statsFooter(state)),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: McTokens.bottomBarClearance),
                  ),
                ],
              ),
            ),
          ),
          // 下拉二楼 35mm 胶片走片预览条（ReelsFloor）
          if (reveal > 0.02)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: reveal,
                  child: _ReelsFilmStrip(
                    pull: pullDepth,
                    armed: _armedReels,
                    stills: _floorStills(state),
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
          onTap: _openReels,
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: '更多操作',
          onSelected: (v) {
            if (v == 'customize') _openCustomize();
            if (v == 'collections') context.push(routeLibraryCollections);
            if (v == 'manage') {
              context.push(routeLibraryManage).then((_) {
                if (mounted) _controller.reload();
              });
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'customize',
              child: _MenuRow(icon: McIcons.setting1, label: '自定义首页'),
            ),
            PopupMenuItem(
              value: 'collections',
              child: _MenuRow(icon: McIcons.mediaLibraryFill, label: '全部合集'),
            ),
            PopupMenuItem(
              value: 'manage',
              child: _MenuRow(
                icon: McIcons.folderSettings,
                label: '管理媒体库与异常',
              ),
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

  List<Widget> _content(LibraryHomeState state, int offlineCount) {
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
            child: Column(
              children: [
                McErrorView(
                  title: '媒体库暂时无法加载',
                  text: '请检查服务器连接后重试。',
                  onRetry: _controller.reload,
                ),
                if (offlineCount > 0) ...[
                  const SizedBox(height: 16),
                  McActionPill(
                    label: '进入离线媒体库（本机已下载 $offlineCount 项）',
                    icon: McIcons.downloadCheck,
                    primary: false,
                    onTap: () => context.push('/offline/library'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ];
    }
    final rows = state.rows;
    return [
      if (state.failed)
        SliverToBoxAdapter(
          child: _FailedBanner(
            offlineCount: offlineCount,
            onOpenOffline: () => context.push('/offline/library'),
          ),
        ),
      if (state.libraries!.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 56),
            child: LibraryEmptyState(
              title: state.isAdmin ? '为收藏准备一个家' : '还没有可浏览的媒体库',
              message: state.isAdmin
                  ? '创建电影库或剧集库，选好根目录后，订阅完成的内容会自动整理到这里。'
                  : '当前账号暂时没有可浏览的媒体库，请联系管理员分配媒体库权限。',
              actionTitle: state.isAdmin ? '创建第一个媒体库' : null,
              onAction: state.isAdmin
                  ? () => context.push(routeLibraryManage).then((_) {
                        if (mounted) _controller.reload();
                      })
                  : null,
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
        showRating: k.sort == 'rating',
        onOpen: _openItem,
      );
    }
    if (k is LibrariesRowKind) return _librariesRow(state, row);
    if (k is GenresRowKind) return _genresRow(state, row, k);
    if (k is LibraryRowKind) {
      final order = HomeRows.orderParam(k.sort, k.reversed);
      final q = <String, String>{
        'sort': k.sort,
        if (order != null) 'order': order,
        if (row.watch != null) 'w': row.watch!,
      };
      return _PosterRow(
        title: row.title(),
        moreTitle: '查看全部',
        onMore: () => context.push(routeLibraryDetail(k.library.id, query: q)),
        items: state.itemsByKey[LibraryHomeController.fetchKey(row)] ?? const [],
        fallbackLibraryId: k.library.id,
        showRating: k.sort == 'rating',
        onOpen: _openItem,
      );
    }
    if (k is MediaKindRowKind) {
      return _PosterRow(
        title: row.title(),
        moreTitle: '查看全部',
        onMore: () => context.push(
          routeLibraryKind(
            k.kind,
            watch: row.watch,
            sort: k.sort,
            order: HomeRows.orderParam(k.sort, k.reversed),
          ),
        ),
        items: state.itemsByKey[LibraryHomeController.fetchKey(row)] ?? const [],
        fallbackLibraryId: 0,
        showRating: k.sort == 'rating',
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
        showRating: k.sort == 'rating',
        onOpen: _openItem,
      );
    }
    return const SizedBox.shrink();
  }

  // ── 按类型找电影 / 剧集（渐变剧照色块行） ──

  Widget _genresRow(
    LibraryHomeState state,
    HomeRow row,
    GenresRowKind kindRow,
  ) {
    final genres = state.genresByKind[kindRow.kind] ?? const [];
    if (genres.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(
            title: row.title(),
            trailingText: '全部${HomeRows.mediaKindLabel(kindRow.kind)}',
            onTap: () => context.push(routeLibraryKind(kindRow.kind)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 186 * 150 / 236 + 4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              itemCount: genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final g = genres[i];
                return GenreCardFace(
                  label: g.label,
                  count: g.count,
                  mediaKind: kindRow.kind,
                  coverUrl: g.coverUrl,
                  width: 186,
                  onTap: () => context.push(
                    routeLibraryKind(kindRow.kind, genre: g.value),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 接下来继续：16:9 沉浸横卡横滑 ──

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
                  contextActions: [
                    McPosterMenuAction(
                      icon: McIcons.play2Fill,
                      label: '立即续播',
                      onTap: () => _play(it),
                    ),
                    McPosterMenuAction(
                      icon: McIcons.film,
                      label: '查看详情',
                      onTap: () => _openItem(it.libraryId, it.mediaItemId),
                    ),
                    McPosterMenuAction(
                      icon: McIcons.checkCircleFill,
                      label: '标为已看完',
                      onTap: () async {
                        await _controller.toggleItemMark(
                          it.mediaItemId,
                          played: true,
                        );
                        if (mounted) McToast.success('已标为看完');
                      },
                    ),
                  ],
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

  // ── 我的媒体库：真实库 + 置顶合集虚拟库横滑卡 ──

  Widget _librariesRow(LibraryHomeState state, HomeRow row) {
    final libs = state.visibleLibraries;
    final pinnedCols = state.homeCollections;
    if (libs.isEmpty && pinnedCols.isEmpty) return const SizedBox.shrink();
    final totalCards = libs.length + pinnedCols.length;
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
              itemCount: totalCards,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                if (i < libs.length) {
                  final lib = libs[i];
                  final hasPosters = (state.itemsByKey[
                              LibraryHomeController.coverKey(lib.id)] ??
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
                }
                final col = pinnedCols[i - libs.length];
                return McPressable(
                  onTap: () => context.push(routeLibraryCollection(col.id)),
                  child: SizedBox(
                    width: 228,
                    child: _PinnedCollectionCard(collection: col),
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

/// 35mm 胶片齿孔走片预览条（对齐 iOS `ReelsFilmStrip`）。
class _ReelsFilmStrip extends StatelessWidget {
  const _ReelsFilmStrip({
    required this.pull,
    required this.armed,
    required this.stills,
  });

  final double pull;
  final bool armed;
  final List<String> stills;

  @override
  Widget build(BuildContext context) {
    final shift = (pull * 1.8) % 92;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        McLiquidGlass(
          radius: McTokens.pillRadius,
          tone: armed ? McGlassTone.strong : McGlassTone.regular,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                McIcons.play2Fill,
                size: 13,
                color: armed ? McTokens.accentStrong : McTokens.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                armed ? '松手进入「片段」' : '继续下拉进入「片段」',
                style: McText.caption.copyWith(
                  color: armed ? McTokens.text : McTokens.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 76,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xEB0E1015),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: armed
                    ? const Color(0x99CCE0FF)
                    : const Color(0x2EFFFFFF),
                width: armed ? 1.4 : 0.8,
              ),
              boxShadow: armed
                  ? const [
                      BoxShadow(
                        color: Color(0x55A7C6FF),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                _sprocketStrip(),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final count = (constraints.maxWidth / 92).ceil() + 2;
                          return OverflowBox(
                            maxWidth: double.infinity,
                            alignment: Alignment.centerLeft,
                            child: Transform.translate(
                              offset: Offset(-shift, 0),
                              child: Row(
                                children: [
                                  for (var i = 0; i < count; i++)
                                    _filmFrame(
                                      stills.isEmpty
                                          ? null
                                          : stills[i % stills.length],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // 中央片门高光框
                      Container(
                        width: 96,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: armed
                                ? const Color(0xE6DDEAFF)
                                : const Color(0x66FFFFFF),
                            width: armed ? 2 : 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _sprocketStrip(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sprocketStrip() => SizedBox(
        height: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 18; i++)
              Container(
                width: 7,
                height: 4,
                decoration: BoxDecoration(
                  color: armed
                      ? const Color(0x99CCE0FF)
                      : const Color(0x40FFFFFF),
                  borderRadius: BorderRadius.circular(1.2),
                ),
              ),
          ],
        ),
      );

  Widget _filmFrame(String? url) => Container(
        width: 84,
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E28),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0x26FFFFFF), width: 0.6),
        ),
        child: url == null
            ? const Icon(McIcons.film, size: 18, color: Color(0x33FFFFFF))
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: mcImageHeaders(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  McIcons.film,
                  size: 18,
                  color: Color(0x33FFFFFF),
                ),
              ),
      );
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

/// 置顶到首页的合集虚拟库卡片（与真实库同宽 228、同 2.05 宽屏比例）。
class _PinnedCollectionCard extends StatelessWidget {
  const _PinnedCollectionCard({required this.collection});

  final CollectionView collection;

  @override
  Widget build(BuildContext context) {
    final covers =
        collection.covers.where((c) => c.url.isNotEmpty).take(3).toList();
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
                colors: [Color(0xFF1D2230), Color(0xFF0E1016)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (covers.isEmpty)
                  const Icon(
                    McIcons.stack,
                    size: 36,
                    color: Color(0x24FFFFFF),
                  )
                else
                  Row(
                    children: [
                      for (final c in covers)
                        Expanded(
                          child: LibraryNetImage(
                            url: McImageUrls.resolve(c.url, widthPx: 360),
                            blurDataUri: c.blur,
                            placeholderIcon: McIcons.stack,
                          ),
                        ),
                    ],
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x14000000), Color(0x8C000000)],
                    ),
                  ),
                ),
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
                      border: Border.all(color: const Color(0x26FFFFFF)),
                    ),
                    child: Text(
                      '合集 · ${collection.itemCount} 部',
                      style: McText.micro
                          .copyWith(color: const Color(0xEBFFFFFF))
                          .tabular,
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
              const Icon(McIcons.stack, size: 14, color: McTokens.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.ui.semibold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

/// 横滚海报行（收藏行 / 库行 / 跨库类型行 / 合集行统一形态）。
class _PosterRow extends ConsumerWidget {
  const _PosterRow({
    required this.title,
    required this.moreTitle,
    required this.onMore,
    required this.items,
    required this.onOpen,
    this.fallbackLibraryId = 0,
    this.favorite = false,
    this.showRating = false,
  });

  final String title;
  final String moreTitle;
  final VoidCallback onMore;
  final List<LibraryItemView> items;
  final void Function(int libraryId, int itemId) onOpen;
  final int fallbackLibraryId;
  final bool favorite;
  final bool showRating;

  static const _cellWidth = 122.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            height: _cellWidth / McTokens.posterAspect + 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                final isFav = favorite || item.isFavorite;
                final recentBadge = !favorite && item.recentAddition != null
                    ? formatRecentAddition(item.recentAddition!)
                    : null;
                final favCorner = favorite
                    ? favoriteLevelLabel(
                        item.kind,
                        item.favoriteSeasonNumber,
                        item.favoriteEpisodeNumber,
                      )
                    : null;
                return mcItemCard(
                  context,
                  item.copyWith(isFavorite: isFav),
                  width: _cellWidth,
                  fallbackLibraryId: fallbackLibraryId,
                  showRating: showRating,
                  cornerLabel: favCorner ?? recentBadge,
                  extraActions: [
                    McPosterMenuAction(
                      icon: isFav ? McIcons.unheart2 : McIcons.heart2,
                      label: isFav ? '取消收藏' : '加入收藏',
                      onTap: () async {
                        await ref
                            .read(libraryHomeProvider.notifier)
                            .toggleItemMark(
                              item.mediaItemId,
                              favorite: !isFav,
                            );
                        if (context.mounted) {
                          McToast.success(isFav ? '已取消收藏' : '已加入收藏');
                        }
                      },
                    ),
                    McPosterMenuAction(
                      icon: McIcons.checkCircle,
                      label: '标为已看',
                      onTap: () async {
                        await ref
                            .read(libraryHomeProvider.notifier)
                            .toggleItemMark(item.mediaItemId, played: true);
                        if (context.mounted) McToast.success('已标为看完');
                      },
                    ),
                  ],
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
  const _FailedBanner({
    required this.offlineCount,
    required this.onOpenOffline,
  });

  final int offlineCount;
  final VoidCallback onOpenOffline;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            if (offlineCount > 0) ...[
              const SizedBox(height: 8),
              McChip(
                icon: McIcons.downloadCheck,
                label: '查看本机离线下载 ($offlineCount 项)',
                compact: true,
                onTap: onOpenOffline,
              ),
            ],
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
