import '../../../core/image/image_urls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/image/cover_preloader.dart';
import '../../../core/models/format.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../routes.dart';
import '../state/home_rows.dart';
import '../state/library_home_controller.dart';
import '../state/models.dart';
import '../widgets/library_widgets.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 媒体库首页（对齐 Kotlin LibraryScreen.kt）：
/// 顶部计数/容量一行 + 有序行清单（up-next / favorites / libraries / genres / lib / collection）。
/// 行顺序与显示内容由 ui/preferences 驱动（HomeRows 合并规则），右上「⋯」进自定义首页。
class LibraryHomePage extends ConsumerStatefulWidget {
  const LibraryHomePage({super.key});

  @override
  ConsumerState<LibraryHomePage> createState() => _LibraryHomePageState();
}

class _LibraryHomePageState extends ConsumerState<LibraryHomePage> {
  bool _coversPreloaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(libraryHomeProvider.notifier).load());
  }

  /// 从首页状态收集全部可预取的封面 URL。
  List<String> _collectCoverUrls(LibraryHomeState state) {
    final urls = <String>[
      for (final e in state.upNext) if (e.episodeStillUrl != null) McImageUrls.resolve(e.episodeStillUrl),
    ];
    for (final row in state.rows) {
      final genres = state.kindGenres[row.id] ?? const <Map<String, dynamic>>[];
      for (final g in genres) {
        final url = McImageUrls.resolve((g['backdrop_url'] ?? g['poster_url'] ?? g['cover_url'] ?? '') as String);
        if (url.isNotEmpty) urls.add(url);
      }
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryHomeProvider);
    final (count, bytes) = state.storageStats;
    // 封面预加载（docs/design/09 §3.3，对齐飞牛 preloadArtwork）：
    // 首屏行渲染完成后，把首页全部封面喂进预取队列（并发 4、去重）。
    if (!_coversPreloaded && state.rows.isNotEmpty) {
      _coversPreloaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CoverPreloader.preload(context, _collectCoverUrls(state));
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          IconButton(
            icon: const Icon(McIcons.filterS),
            tooltip: '自定义首页',
            onPressed: () => context.push(routeLibraryCustomize),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(libraryHomeProvider.notifier).load();
        },
        child: state.loading && state.rows.isEmpty
            ? const McLoadingView()
            : state.error != null && state.rows.isEmpty
                ? McErrorView(text: state.error!, onRetry: () => ref.read(libraryHomeProvider.notifier).load())
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (count > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            '$count 部媒体 · 共 ${mcFormatBytes(bytes)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      for (final row in state.visibleRows) _buildRow(context, row),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, HomeRow row) {
    final state = ref.watch(libraryHomeProvider);
    final k = row.kind;

    // 「我的媒体库」行：库网格（名称 + 部数），点进单库页。
    if (k is LibrariesRowKind) {
      return const _LibraryGridRow();
    }

    // 「按类型找电影/剧集」行：类型色块，点进类型墙。
    if (k is GenresRowKind) {
      final genres = state.kindGenres[row.id] ?? const <Map<String, dynamic>>[];
      return McHomeRowSection(
        title: row.title(),
        meta: state.kindSummaries[row.id] == null
            ? null
            : '${state.kindSummaries[row.id]!.itemCount} 部',
        onMore: () => context.push(routeLibraryKind(k.kind)),
        children: [
          for (final g in genres.take(20))
            _GenreBlock(
              name: (g['name'] ?? g['label'] ?? '').toString(),
              url: (g['backdrop_url'] ?? g['poster_url'] ?? g['cover_url'] ?? '') as String,
              onTap: () => context.push(routeLibraryKind(k.kind)),
            ),
        ],
      );
    }

    // 通用横滑海报行。
    List<Widget> cards;
    String? meta;
    if (k is UpNextRowKind) {
      cards = [
        for (final e in state.upNext)
          McFocusRing(
            borderRadius: 12,
            child: McPosterCard(
              title: e.title,
              posterUrl: e.episodeStillUrl,
              aspect: 16 / 9,
              subtitle: 'S${e.seasonNumber} E${e.episodeNumber} · ${e.episodeTitle ?? ''}',
              progress: e.progressPercent / 100,
              width: 160,
              onTap: () => context.push('/detail/${e.libraryId}/${e.mediaItemId}'),
            ),
          ),
      ];
    } else if (k is FavoritesRowKind) {
      meta = '${state.favorites.length} 部';
      cards = [
        for (final item in state.favorites) mcItemCard(context, item),
      ];
    } else if (k is LibraryRowKind) {
      final items = state.rowItems[row.id] ?? const <LibraryItemView>[];
      meta = '${items.length} 部';
      cards = [for (final item in items) mcItemCard(context, item)];
      return McHomeRowSection(
        title: row.title(),
        meta: meta,
        onMore: () => _openLibrary(context, k.library.id),
        children: cards,
      );
    } else if (k is CollectionRowKind) {
      final items = state.rowItems[row.id] ?? const <LibraryItemView>[];
      meta = '${items.length} 部';
      cards = [for (final item in items) mcItemCard(context, item)];
      return McHomeRowSection(
        title: row.title(),
        meta: meta,
        onMore: () => context.push(routeLibraryCollection(k.collection.id)),
        children: cards,
      );
    } else {
      cards = const [];
    }
    return McHomeRowSection(title: row.title(), meta: meta, children: cards);
  }

  void _openLibrary(BuildContext context, int libraryId) =>
      context.push(routeLibraryDetail(libraryId));
}

/// 库网格行（简单 2 列卡片；库名 + 部数 + 容量）。
class _LibraryGridRow extends StatelessWidget {
  const _LibraryGridRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我的媒体库',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          _LibraryGrid(),
        ],
      ),
    );
  }
}

class _LibraryGrid extends ConsumerWidget {
  const _LibraryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryHomeProvider);
    final libs = [
      for (final r in state.rows)
        if (r.kind is LibraryRowKind) (r.kind as LibraryRowKind).library,
    ];
    if (libs.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      // 平板/TV 自适应列数；手机保持 2 列不变。
      final form = McFormWatch.of(context);
      final columns = form == McDeviceForm.phone
          ? 2
          : mcGridCrossAxisCount(form, constraints,
              cellExtent: 320, min: 2, max: 6);
      return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        for (final lib in libs)
          McFocusRing(
            borderRadius: 10,
            child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.push(routeLibraryDetail(lib.id)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: McColors.surfaceDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(lib.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${lib.stats.itemCount} 部 · ${mcFormatBytes(lib.stats.totalSizeBytes)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ),
      ],
      );
    });
  }
}

/// 类型色块（TMDB 类型 + 封面）。
class _GenreBlock extends StatelessWidget {
  const _GenreBlock({required this.name, required this.url, required this.onTap});

  final String name;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return McFocusRing(
      borderRadius: 8,
      child: GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 110,
          height: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isEmpty)
                Container(color: McColors.surfaceDark)
              else
                CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.35)),
              Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
