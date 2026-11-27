import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/gallery_wall_view.dart';
import '../widgets/library_shared.dart';
import '../widgets/library_widgets.dart';

class _FavSortOption {
  const _FavSortOption({
    required this.value,
    required this.label,
    required this.naturalAsc,
    required this.ascLabel,
    required this.descLabel,
  });

  final String value;
  final String label;
  final bool naturalAsc;
  final String ascLabel;
  final String descLabel;

  String? orderParam(bool reversed) =>
      reversed ? (naturalAsc ? 'desc' : 'asc') : null;

  String directionLabel(bool reversed) {
    final asc = reversed ? !naturalAsc : naturalAsc;
    return asc ? ascLabel : descLabel;
  }
}

/// 「我的收藏」全部（对齐 iOS `FavoritesView`）：
/// - 4 档排序（未看优先 / 最近收藏 / 评分 / 名称）+ 升降序切换并本机持久化；
/// - 海报墙 / 图床瀑布流（`LibraryGalleryWall`）双模式切换；
/// - 「回到上次位置」（`LibraryWallRecall` + `WallRecallPill`）。
class LibraryFavoritesPage extends ConsumerStatefulWidget {
  const LibraryFavoritesPage({super.key});

  @override
  ConsumerState<LibraryFavoritesPage> createState() =>
      _LibraryFavoritesPageState();
}

class _LibraryFavoritesPageState extends ConsumerState<LibraryFavoritesPage> {
  static const _pageSize = 60;
  static const _sortPrefKey = 'movieclaw.favorites.wall-sort';
  static const _recallScope = 'library:favorites';

  static const _sortOptions = <_FavSortOption>[
    _FavSortOption(
      value: 'unwatched_first',
      label: '未看优先',
      naturalAsc: false,
      ascLabel: '已看优先',
      descLabel: '未看优先',
    ),
    _FavSortOption(
      value: 'favorited_at',
      label: '最近收藏',
      naturalAsc: false,
      ascLabel: '最早收藏',
      descLabel: '最近收藏',
    ),
    _FavSortOption(
      value: 'rating',
      label: '评分',
      naturalAsc: false,
      ascLabel: '从低到高',
      descLabel: '从高到低',
    ),
    _FavSortOption(
      value: 'title',
      label: '名称',
      naturalAsc: true,
      ascLabel: 'A → Z',
      descLabel: 'Z → A',
    ),
  ];

  final _scrollCtrl = ScrollController();
  final _items = <LibraryItemView>[];
  int _total = 0;
  int _startOffset = 0;
  int _galleryStart = 0;
  bool _loading = false;
  bool _failed = false;
  bool _done = false;
  String _sort = 'favorited_at';
  bool _reversed = false;
  int? _recallOffset;
  bool _offeredRecall = false;
  int _lastRecordedOffset = -1;

  _FavSortOption get _currentSort => _sortOptions.firstWhere(
        (o) => o.value == _sort,
        orElse: () => _sortOptions[1],
      );

  String get _recallView =>
      'favorites:$_sort${_reversed ? ':rev' : ''}';

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sortPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final rev = raw.endsWith(':rev');
        final base = rev ? raw.substring(0, raw.length - 4) : raw;
        if (_sortOptions.any((o) => o.value == base)) {
          _sort = base;
          _reversed = rev;
        }
      }
    } catch (_) {}
    await _loadMore(reset: true);
  }

  Future<void> _saveSortPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sortPrefKey,
        _reversed ? '$_sort:rev' : _sort,
      );
    } catch (_) {}
  }

  Future<void> _loadMore({bool reset = false, int startAt = 0}) async {
    if (_loading || (_done && !reset)) return;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _items.clear();
        _startOffset = startAt;
        _done = false;
      }
    });
    try {
      final isUnwatchedFirst = _sort == 'unwatched_first';
      final page = await ref.read(libraryApiProvider).favorites(
            limit: _pageSize,
            offset: _startOffset + _items.length,
            unwatchedFirst: isUnwatchedFirst,
            sort: isUnwatchedFirst ? 'favorited_at' : _sort,
            order: _currentSort.orderParam(_reversed),
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _done = page.items.length < _pageSize ||
            (_startOffset + _items.length) >= page.total;
      });
      if (reset && !_offeredRecall) {
        _offeredRecall = true;
        final saved = await LibraryWallRecall.read(
          scope: _recallScope,
          view: _recallView,
        );
        if (mounted && saved != null && saved < page.total) {
          setState(() => _recallOffset = saved);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPrevious() async {
    if (_startOffset <= 0 || _loading) return;
    final prevOffset = (_startOffset - _pageSize).clamp(0, _startOffset);
    setState(() => _loading = true);
    try {
      final isUnwatchedFirst = _sort == 'unwatched_first';
      final page = await ref.read(libraryApiProvider).favorites(
            limit: _startOffset - prevOffset,
            offset: prevOffset,
            unwatchedFirst: isUnwatchedFirst,
            sort: isUnwatchedFirst ? 'favorited_at' : _sort,
            order: _currentSort.orderParam(_reversed),
          );
      if (!mounted) return;
      setState(() {
        _startOffset = prevOffset;
        _items.insertAll(0, page.items);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recordOffset(int offset) {
    if (_recallOffset != null && (offset - _startOffset).abs() >= 12) {
      setState(() => _recallOffset = null);
    }
    if (offset != _lastRecordedOffset && _recallOffset == null) {
      _lastRecordedOffset = offset;
      LibraryWallRecall.write(
        scope: _recallScope,
        view: _recallView,
        offset: offset,
      );
    }
  }

  void _openSortSheet() {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '收藏排序',
          margin: EdgeInsets.zero,
          children: [
            for (final opt in _sortOptions)
              McInsetRow(
                title: opt.label,
                subtitle: _sort == opt.value
                    ? opt.directionLabel(_reversed)
                    : null,
                trailing: _sort == opt.value
                    ? const Icon(
                        McIcons.check,
                        size: 18,
                        color: McTokens.accentStrong,
                      )
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _sort = opt.value;
                    _reversed = false;
                    _galleryStart = 0;
                    _recallOffset = null;
                    _offeredRecall = false;
                  });
                  _saveSortPref();
                  _loadMore(reset: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GalleryPrefs.instance,
      builder: (context, _) {
        final galleryOn =
            GalleryPrefs.instance.galleryModeFor() && _items.isNotEmpty;
        final form = McFormWatch.of(context);
        final sortOpt = _currentSort;

        return Scaffold(
          backgroundColor: McTokens.bg,
          body: Stack(
            children: [
              Column(
                children: [
                  McFloatingDetailBar(
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    title: _total > 0 ? '我的收藏 · $_total 部' : '我的收藏',
                    titleVisible: true,
                    trailing: [
                      if (_items.isNotEmpty) ...[
                        McGlassIconButton(
                          icon: galleryOn ? McIcons.gallery1 : McIcons.imageAdd,
                          tooltip: galleryOn ? '回到海报墙' : '图床浏览',
                          onTap: () =>
                              GalleryPrefs.instance.setGalleryMode(!galleryOn),
                        ),
                        if (galleryOn) ...[
                          const SizedBox(width: 6),
                          McGlassIconButton(
                            icon: McIcons.listSettings2,
                            tooltip: '图床显示设置',
                            onTap: () => showGalleryPrefsSheet(context),
                          ),
                        ],
                      ],
                    ],
                  ),
                  if (_items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        McTokens.pagePadding,
                        4,
                        McTokens.pagePadding,
                        8,
                      ),
                      child: Row(
                        children: [
                          McChip(
                            label: sortOpt.label,
                            icon: McIcons.sort,
                            compact: true,
                            onTap: _openSortSheet,
                          ),
                          const SizedBox(width: 8),
                          McChip(
                            label: sortOpt.directionLabel(_reversed),
                            icon: _reversed
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            compact: true,
                            selected: _reversed,
                            onTap: () {
                              setState(() {
                                _reversed = !_reversed;
                                _galleryStart = 0;
                                _recallOffset = null;
                              });
                              _saveSortPref();
                              _loadMore(reset: true);
                            },
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _loadMore(reset: true),
                      child: galleryOn
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                8,
                                McTokens.pagePadding,
                                40,
                              ),
                              child: LibraryGalleryWall(
                                reloadKey: '$_sort|$_reversed',
                                startOffset: _galleryStart,
                                fetch: (offset, limit) {
                                  final api = ref.read(libraryApiProvider);
                                  return api.favoritesGallery(
                                    limit: limit,
                                    offset: offset,
                                    sort: _sort == 'unwatched_first'
                                        ? 'favorited_at'
                                        : _sort,
                                    order: sortOpt.orderParam(_reversed),
                                  );
                                },
                                onFirstVisible: _recordOffset,
                              ),
                            )
                          : _buildPosterBody(form),
                    ),
                  ),
                ],
              ),
              if (_recallOffset != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.paddingOf(context).bottom + 20,
                  child: Center(
                    child: WallRecallPill(
                      onJump: () {
                        final target = _recallOffset!;
                        setState(() => _recallOffset = null);
                        if (galleryOn) {
                          setState(() => _galleryStart = target);
                        } else {
                          _loadMore(reset: true, startAt: target);
                        }
                      },
                      onDismiss: () => setState(() => _recallOffset = null),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPosterBody(McDeviceForm form) {
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          if (_loading)
            const McLoadingView()
          else if (_failed)
            McErrorView(
              text: '收藏加载失败，请重试',
              onRetry: () => _loadMore(reset: true),
            )
          else
            const McEmptyView(
              icon: McIcons.heart2,
              title: '还没有收藏',
              text: '在作品详情页点「收藏」，喜欢的作品会集中在这里。',
            ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
          _loadMore();
        }
        if (n is ScrollEndNotification && _items.isNotEmpty) {
          final cols = form == McDeviceForm.phone ? 3 : 5;
          final approxRow = (n.metrics.pixels / 210).floor().clamp(0, 99999);
          _recordOffset(_startOffset + approxRow * cols);
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_startOffset > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Center(
                  child: McActionPill(
                    label: _loading ? '加载中…' : '加载前面已跳过的作品',
                    icon: Icons.arrow_upward_rounded,
                    onTap: _loading ? null : _loadPrevious,
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              8,
              McTokens.pagePadding,
              40,
            ),
            sliver: SliverGrid(
              gridDelegate: form == McDeviceForm.phone
                  ? const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.515,
                    )
                  : SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: mcGridCrossAxisCount(
                        form,
                        BoxConstraints.tightFor(
                          width: MediaQuery.widthOf(context) - 32,
                        ),
                        cellExtent: 130,
                      ),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.515,
                    ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => mcItemCard(
                  context,
                  _items[i],
                  width: null,
                  showRating: _sort == 'rating',
                ),
                childCount: _items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
