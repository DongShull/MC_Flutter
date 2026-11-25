import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/player/player_page_args.dart';
import '../routes.dart';
import '../state/home_rows.dart';
import '../state/library_home_controller.dart';
import '../state/models.dart';
import '../widgets/hero_banner.dart';
import '../widgets/library_shared.dart';

/// 媒体库首页（1:1 对齐鸿蒙 LibraryNavHost + LibraryHomeView）：
/// 标题栏「媒体库」+ ⋯ · 搜索 · 片段；统计行；按偏好合并出的行清单——
/// 接下来继续（大图轮播）/ 我的收藏 / 我的媒体库（库卡片 + 扫描进度环）/ 每库一行 / 合集行。
/// 只负责「看」，排序与行的增删改收进自定义页。
class LibraryHomePage extends ConsumerStatefulWidget {
  const LibraryHomePage({super.key});

  @override
  ConsumerState<LibraryHomePage> createState() => _LibraryHomePageState();
}

class _LibraryHomePageState extends ConsumerState<LibraryHomePage> {
  late final LibraryHomeController _controller = ref.read(libraryHomeProvider.notifier);

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

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2500)));
  }

  Future<void> _openCustomize() async {
    await context.push(routeLibraryCustomize);
    if (mounted) await _controller.reload();
  }

  void _openItem(int libraryId, int itemId) => context.push('/detail/$libraryId/$itemId');

  void _play(UpNextItem item) {
    context.push(
      '/player',
      extra: PlayerPageArgs(
        mediaItemId: item.mediaItemId,
        seasonNumber: item.isEpisode ? item.seasonNumber : null,
        episodeNumber: item.isEpisode ? item.episodeNumber : null,
        title: item.title,
        subtitle: item.isEpisode ? episodeCode(item.seasonNumber, item.episodeNumber) : null,
        startPosition: item.positionMs > 0 ? Duration(milliseconds: item.positionMs) : null,
        isEpisode: item.isEpisode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryHomeProvider);
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: RefreshIndicator(
        onRefresh: _controller.reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _titleBar(context),
            SliverToBoxAdapter(child: _statsHeader(state)),
            ..._content(state),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── 标题栏：媒体库 + ⋯ · 搜索 · 片段（顺序同 iOS 工具栏） ──

  Widget _titleBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: McTokens.bg,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 56,
      titleSpacing: 16,
      title: const Text('媒体库',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: McTokens.text)),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: McTokens.textMuted),
          onSelected: (v) {
            if (v == 'customize') _openCustomize();
            if (v == 'collections') context.push(routeLibraryCollections);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'customize',
              child: _MenuRow(icon: Icons.tune, label: '自定义首页'),
            ),
            PopupMenuItem(
              value: 'collections',
              child: _MenuRow(icon: Icons.layers_outlined, label: '全部合集'),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.search, color: McTokens.textMuted),
          onPressed: () => context.push('/search'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 12),
          child: McGlassButton(
            onTap: () => context.push('/reels'),
            radius: 17,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            foregroundColor: McTokens.textMuted,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_outline, size: 16),
                SizedBox(width: 4),
                Text('片段', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statsHeader(LibraryHomeState state) {
    final text = state.failed && state.libraries == null
        ? '暂时无法获取媒体库统计，正在自动重试'
        : libraryStatsSummary(state.libraries == null ? null : state.visibleLibraries);
    return Padding(
      padding: const EdgeInsets.fromLTRB(McTokens.pagePadding, 4, McTokens.pagePadding, 0),
      child: Text(text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, color: McTokens.textMuted)),
    );
  }

  // ── 内容：加载 / 失败 / 空库 / 全隐藏 / 行清单 ──

  List<Widget> _content(LibraryHomeState state) {
    if (state.libraries == null && !state.failed) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 64),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: McTokens.textMuted),
                ),
                SizedBox(width: 10),
                Text('正在加载媒体库…', style: TextStyle(fontSize: 15, color: McTokens.textMuted)),
              ],
            ),
          ),
        ),
      ];
    }
    if (state.libraries == null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 64),
            child: Column(
              children: [
                const Text('媒体库加载失败',
                    style: TextStyle(fontSize: 15, color: McTokens.textMuted)),
                const SizedBox(height: 12),
                LibraryGlassTextButton(label: '重试', onTap: _controller.reload),
              ],
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
            padding: const EdgeInsets.only(top: 40),
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
        moreTitle: '查看全部 ${state.favorites.total} 部',
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

  // ── 接下来继续：大图轮播 + ⋯ 清空观看记录 ──

  Widget _upNextRow(LibraryHomeState state, HomeRow row) {
    if (state.upNext.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LibrarySectionHeader(
            title: row.title(),
            trailing: SizedBox(
              width: 30,
              height: 30,
              child: PopupMenuButton<int>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz, size: 20, color: McTokens.textMuted),
                onSelected: (v) => v == 3 ? _openLibraryPicker(state) : _confirmClearHistory(v),
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
          LibraryHeroBanner(
            items: state.upNext,
            onOpen: (it) => _openItem(it.libraryId, it.mediaItemId),
            onPlay: _play,
          ),
        ],
      ),
    );
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
      description = '所有作品的续播进度、已看标记和播放次数都会清除，无法恢复。只影响你自己的记录；应用更新前的自动备份仍包含历史记录。';
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('清空$label？'),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: McTokens.accent2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空', style: TextStyle(color: McTokens.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final deleted = await _controller.clearHistory(since: since);
      if (!mounted) return;
      _toast(since != null
          ? (deleted > 0 ? '已清空$label' : '$label里没有可清除的记录')
          : '已清空全部观看记录');
    } catch (_) {
      if (mounted) _toast('清空观看记录失败，请稍后重试');
    }
  }

  /// 「清空某个媒体库的观看记录」选择框（同 Web ClearLibraryHistoryDialog）。
  Future<void> _openLibraryPicker(LibraryHomeState state) async {
    final libs = state.visibleLibraries;
    int? picked = libs.isNotEmpty ? libs.first.id : null;
    var busy = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: McTokens.bg,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final name = libs.where((l) => l.id == picked).map((l) => l.name).firstOrNull;
          final enabled = picked != null && !busy;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('清空某个媒体库的观看记录',
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: McTokens.text)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Text('取消',
                              style: TextStyle(fontSize: 15, color: McTokens.textMuted)),
                        ),
                      ],
                    ),
                  ),
                  if (libs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text('没有可浏览的媒体库',
                          style: TextStyle(fontSize: 15, color: McTokens.textMuted)),
                    ),
                  for (final lib in libs)
                    InkWell(
                      onTap: () => setSheet(() => picked = lib.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(lib.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, color: McTokens.text)),
                            ),
                            if (picked == lib.id)
                              const Icon(Icons.check, size: 18, color: McTokens.accentStrong),
                          ],
                        ),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text('选中库里所有作品的续播进度、已看标记和播放次数都会清除，无法恢复。只影响你自己的记录。',
                        style: TextStyle(fontSize: 12, color: McTokens.textMuted)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Opacity(
                      opacity: enabled ? 1 : 0.4,
                      child: SizedBox(
                        width: double.infinity,
                        child: McGlassButton(
                          onTap: !enabled
                              ? null
                              : () async {
                                  setSheet(() => busy = true);
                                  try {
                                    await _controller.clearHistory(libraryId: picked);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) _toast('已清空该库的观看记录');
                                  } catch (_) {
                                    if (mounted) _toast('清空观看记录失败，请稍后重试');
                                    if (ctx.mounted) setSheet(() => busy = false);
                                  }
                                },
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: McTokens.danger,
                          child: Center(
                            child: Text(
                              busy ? '清空中…' : (name == null ? '清空' : '清空「$name」'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
          LibrarySectionHeader(
            title: row.title(),
            trailingText: state.collections.isNotEmpty ? '全部合集 ›' : null,
            onTrailing: () => context.push(routeLibraryCollections),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230 / 2.1 + 10 + 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
              itemCount: libs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final lib = libs[i];
                final hasPosters = (state.itemsByKey[LibraryHomeController.coverKey(lib.id)] ??
                        const [])
                    .isNotEmpty;
                return GestureDetector(
                  onTap: () => context.push(routeLibraryDetail(lib.id)),
                  child: SizedBox(
                    width: 230,
                    child: _LibraryCard(library: lib, showCover: hasPosters || lib.customCover),
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
      );
}

/// 库卡片：服务端拼贴封面 + 库名 +「默认」；扫描/整理/刷元数据时封面归进度环。
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.library, required this.showCover});

  final LibraryView library;
  final bool showCover;

  bool get _busy =>
      library.scanning || library.organizing || (library.metadataRefresh?.refreshing ?? false);

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
          aspectRatio: 2.1,
          child: Container(
            clipBehavior: Clip.antiAlias,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(McTokens.cardRadius),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(McTokens.cardRadius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1C212E), Color(0xFF0F121C)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Icon(icon, size: 40, color: const Color(0x21FFFFFF)),
                if (showCover)
                  LibraryNetImage(
                    url: McImageUrls.resolve('/libraries/${library.id}/cover', widthPx: 720),
                    placeholderIcon: icon,
                  ),
                if (_busy)
                  ColoredBox(
                    color: const Color(0x8C000000),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LibraryProgressRing(
                          processed: _progress.processed,
                          total: _progress.total,
                          size: 62,
                        ),
                        const SizedBox(height: 4),
                        Text(_progress.label,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xD9FFFFFF))),
                        if (library.metadataRefresh?.refreshing == true &&
                            library.metadataRefresh?.activeLine != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(library.metadataRefresh!.activeLine!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0x99FFFFFF))),
                          ),
                      ],
                    ),
                  )
                else if (importing > 0)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x8C000000),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: const Color(0x597FB0FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: McTokens.info, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('$importing 个新文件入库中',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: McTokens.info)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(library.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              if (library.isDefault)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0x24FFFFFF)),
                  ),
                  child: const Text('默认',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xCCFFFFFF))),
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

  static const _cellWidth = 124.0;

  Future<void> _showInfo(BuildContext context, Offset at, List<String> lines) async {
    if (lines.isEmpty) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
          at.dx, at.dy, overlay.size.width - at.dx, overlay.size.height - at.dy),
      items: [for (final l in lines) PopupMenuItem<void>(enabled: false, child: Text(l))],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LibrarySectionHeader(title: title, trailingText: moreTitle, onTrailing: onMore),
          const SizedBox(height: 12),
          SizedBox(
            height: _cellWidth / McTokens.posterAspect + 8 + 22 + 18,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                return GestureDetector(
                  onTap: () => onOpen(item.libraryId ?? fallbackLibraryId, item.mediaItemId),
                  onLongPressStart: (d) => _showInfo(
                      context, d.globalPosition, posterInfoLines(item, favorite: favorite)),
                  child: SizedBox(
                    width: _cellWidth,
                    child: LibraryPosterCell(
                      title: item.title,
                      year: item.year,
                      url: McImageUrls.resolve(item.posterUrl, widthPx: 480),
                      imageAspect: item.primaryAspect,
                      placeholderIcon: item.kind == 'tv' ? Icons.tv_outlined : Icons.movie_outlined,
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

/// 瞬时失败提示条：已有数据继续显示，自动重试。
class _FailedBanner extends StatelessWidget {
  const _FailedBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(McTokens.pagePadding, 16, McTokens.pagePadding, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x1AFBBF24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x40FBBF24)),
        ),
        child: const Text('与后端通信失败，正在自动重试；下方显示的是最近一次成功加载的数据',
            style: TextStyle(fontSize: 13, color: Color(0xFFFCE68A))),
      ),
    );
  }
}

/// 所有行都被隐藏了。
class _AllHiddenBox extends StatelessWidget {
  const _AllHiddenBox({required this.onCustomize});

  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(McTokens.pagePadding, 64, McTokens.pagePadding, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: McTokens.lineStrong),
        ),
        child: Column(
          children: [
            const Text('首页空空如也',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: McTokens.text)),
            const SizedBox(height: 6),
            const Text('所有行都被隐藏了。到「自定义首页」挑几行回来，或恢复默认。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: McTokens.textMuted)),
            const SizedBox(height: 16),
            LibraryGlassTextButton(label: '自定义首页', onTap: onCustomize),
          ],
        ),
      ),
    );
  }
}
