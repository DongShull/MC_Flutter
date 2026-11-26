import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/library_shared.dart';

/// 「我的收藏」全部（首页收藏行「查看全部 N 部」的去处）：
/// 收藏时间序海报网格，滚到底按 60 条翻页；角标标出收藏层级（某季 / 某集）。
class LibraryFavoritesPage extends ConsumerStatefulWidget {
  const LibraryFavoritesPage({super.key});

  @override
  ConsumerState<LibraryFavoritesPage> createState() =>
      _LibraryFavoritesPageState();
}

class _LibraryFavoritesPageState extends ConsumerState<LibraryFavoritesPage> {
  static const _pageSize = 60;

  final _items = <LibraryItemView>[];
  int _total = 0;
  bool _loading = false;
  bool _failed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading || (_done && !reset)) return;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _items.clear();
        _done = false;
      }
    });
    try {
      final page = await ref.read(libraryApiProvider).favorites(
            limit: _pageSize,
            offset: _items.length,
            sort: 'favorited_at',
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _done = page.items.length < _pageSize || _items.length >= page.total;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: _total > 0 ? '我的收藏 · $_total 部' : '我的收藏',
            titleVisible: true,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadMore(reset: true),
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: McTokens.textMuted),
            )
          else if (_failed)
            Center(
              child: Column(
                children: [
                  Text('收藏加载失败', style: McText.sub.muted),
                  const SizedBox(height: 12),
                  LibraryGlassTextButton(
                    label: '重试',
                    onTap: () => _loadMore(reset: true),
                  ),
                ],
              ),
            )
          else
            const LibraryEmptyState(
              icon: McIcons.heart2,
              title: '还没有收藏',
              message: '在作品详情页点「收藏」，喜欢的作品会集中在这里。',
            ),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) _loadMore();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 124).floor().clamp(3, 8);
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              8,
              McTokens.pagePadding,
              32,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: McTokens.posterAspect * 0.78,
            ),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final item = _items[i];
              return GestureDetector(
                onTap: () {
                  final lid = item.libraryId;
                  if (lid != null) {
                    context.push('/detail/$lid/${item.mediaItemId}');
                  }
                },
                child: LibraryPosterCell(
                  title: item.title,
                  year: item.year,
                  url: McImageUrls.resolve(item.posterUrl, widthPx: 480),
                  imageAspect: item.primaryAspect,
                  cornerLabel: favoriteLevelLabel(
                    item.kind,
                    item.favoriteSeasonNumber,
                    item.favoriteEpisodeNumber,
                  ),
                  placeholderIcon:
                      item.kind == 'tv' ? McIcons.tv : McIcons.movie,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
