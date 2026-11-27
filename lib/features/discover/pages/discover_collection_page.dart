import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/permissions.dart';
import '../routes.dart' as feat_discover;
import '../state/discover_controller.dart';

/// 榜单全列表页（1:1 对齐 iOS `DiscoverCollectionView.swift`）：
/// - TMDB 片单每页 20 条，滚到底自动续页（过滤期间暂停自动续页，失败给「重试下一页」）；
/// - 豆瓣片单一次拉完（`limit=500`）；
/// - 支持实时片名搜索 + 类型二级胶囊筛选（纯本地过滤已加载条目）。
class DiscoverCollectionPage extends ConsumerStatefulWidget {
  const DiscoverCollectionPage({
    super.key,
    required this.collectionRef,
    this.initialTitle,
    this.initialSource,
  });

  final String collectionRef;
  final String? initialTitle;
  final String? initialSource;

  @override
  ConsumerState<DiscoverCollectionPage> createState() =>
      _DiscoverCollectionPageState();
}

class _DiscoverCollectionPageState
    extends ConsumerState<DiscoverCollectionPage> {
  late final McClient _mc = McClient(session: ref.read(sessionStoreProvider));
  final TextEditingController _searchCtrl = TextEditingController();

  List<DiscTitle>? _items;
  late String _title = (widget.initialTitle?.isNotEmpty == true)
      ? widget.initialTitle!
      : '片单列表';
  int _nextPage = 2;
  int _totalResults = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _error;
  String _query = '';
  final List<String> _selectedGenres = [];
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  String get _provider {
    final parts = widget.collectionRef.split(':');
    if (parts.isNotEmpty && (parts.first == 'tmdb' || parts.first == 'douban')) {
      return parts.first;
    }
    return (widget.initialSource ?? 'tmdb').toLowerCase();
  }

  bool get _isTmdb => _provider == 'tmdb';

  bool get _filteringLoaded =>
      _query.trim().isNotEmpty || _selectedGenres.isNotEmpty;

  List<({String name, int count})> get _genres {
    final counts = <String, int>{};
    for (final item in _items ?? const <DiscTitle>[]) {
      for (final g in item.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final list = [
      for (final e in counts.entries) (name: e.key, count: e.value),
    ];
    list.sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return list;
  }

  List<DiscTitle> get _filtered {
    final kw = _query.trim().toLowerCase();
    return (_items ?? const <DiscTitle>[]).where((item) {
      final genreOk = _selectedGenres.isEmpty ||
          _selectedGenres.any((g) => item.genres.contains(g));
      final kwOk = kw.isEmpty ||
          item.title.toLowerCase().contains(kw) ||
          item.originalTitle.toLowerCase().contains(kw);
      return genreOk && kwOk;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFirstPage);
  }

  @override
  void dispose() {
    _scrollOffset.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() => _error = null);
    try {
      final body = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/collections/${Uri.encodeComponent(widget.collectionRef)}/titles',
        query: {'limit': _isTmdb ? 20 : 500, 'page': 1},
      );
      final parsed = <DiscTitle>[];
      for (final el in (body['titles'] as List<dynamic>? ?? const [])) {
        if (el is Map) {
          final t = DiscTitle.fromJson(Map<String, dynamic>.from(el));
          if (t != null) parsed.add(t);
        }
      }
      final col = body['collection'];
      final colName = col is Map ? (col['name'] ?? '').toString() : '';
      final page = (body['page'] as num?)?.toInt() ?? 1;
      final totalResults =
          (body['total_results'] as num?)?.toInt() ?? parsed.length;
      final hasMore = _isTmdb && body['has_more'] == true;
      if (!mounted) return;
      setState(() {
        _items = parsed;
        if (colName.isNotEmpty) _title = colName;
        _totalResults = totalResults;
        _hasMore = hasMore;
        _nextPage = page + 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendlyMessage);
    } catch (_) {
      if (mounted) setState(() => _error = '片单加载失败，请稍后重试');
    }
  }

  Future<void> _loadNextPage() async {
    if (!_isTmdb || !_hasMore || _loadingMore || _items == null) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final body = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/collections/${Uri.encodeComponent(widget.collectionRef)}/titles',
        query: {'limit': 20, 'page': _nextPage},
      );
      final existing = {for (final t in _items!) t.ref};
      final added = <DiscTitle>[];
      for (final el in (body['titles'] as List<dynamic>? ?? const [])) {
        if (el is Map) {
          final t = DiscTitle.fromJson(Map<String, dynamic>.from(el));
          if (t != null && existing.add(t.ref)) added.add(t);
        }
      }
      final page = (body['page'] as num?)?.toInt() ?? _nextPage;
      final totalResults =
          (body['total_results'] as num?)?.toInt() ?? _totalResults;
      final hasMore = body['has_more'] == true && added.isNotEmpty;
      if (!mounted) return;
      setState(() {
        _items = [..._items!, ...added];
        _totalResults = totalResults;
        _hasMore = hasMore;
        _nextPage = page + 1;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.friendlyMessage;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '加载下一页失败';
          _loadingMore = false;
        });
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home?tab=discover');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final form = McFormWatch.of(context);
    final pad = form == McDeviceForm.phone
        ? McTokens.pagePadding
        : McTokens.pagePaddingWide;
    final subs = ref.watch(discoverSubscriptionIndexProvider);
    final perms = ref.watch(permissionsProvider);
    final filtered = _filtered;
    final genres = _genres;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.depth == 0) {
                _scrollOffset.value = n.metrics.pixels;
                if (n.metrics.extentAfter < 500 && !_filteringLoaded) {
                  _loadNextPage();
                }
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cols = mcGridCrossAxisCount(
                  form,
                  constraints,
                  cellExtent: 126,
                );
                final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.515,
                );
                return RefreshIndicator(
                  edgeOffset: topPad + 56,
                  color: McTokens.accentStrong,
                  backgroundColor: McTokens.surfaceSolid,
                  onRefresh: _loadFirstPage,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            pad,
                            topPad + 60,
                            pad,
                            14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_provider.toUpperCase()} COLLECTION',
                                style: McText.micro.copyWith(
                                  color: McTokens.accent2,
                                  letterSpacing: 1.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(_title, style: McText.display),
                              const SizedBox(height: 4),
                              Text(
                                _items == null
                                    ? '正在加载片单…'
                                    : (_isTmdb
                                        ? '已加载 ${_items!.length} / $_totalResults 部'
                                        : '共 ${_items!.length} 部作品'),
                                style: McText.sub.tabular,
                              ),
                              const SizedBox(height: 12),
                              // 实时关键词筛选输入框
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: McTokens.surfaceInset,
                                  borderRadius: BorderRadius.circular(
                                    McTokens.pillRadius,
                                  ),
                                  border: Border.all(
                                    color: McTokens.lineStrong,
                                    width: 1,
                                  ),
                                ),
                                padding: EdgeInsets.only(
                                  left: 14,
                                  right: _query.isNotEmpty ? 0 : 14,
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
                                        controller: _searchCtrl,
                                        style: McText.sub.copyWith(
                                          color: McTokens.text,
                                        ),
                                        onChanged: (v) =>
                                            setState(() => _query = v),
                                        decoration: InputDecoration(
                                          isCollapsed: true,
                                          filled: false,
                                          hintText: _isTmdb
                                              ? '筛选已加载的影片…'
                                              : '在片单中搜索片名…',
                                          hintStyle: McText.sub.copyWith(
                                            color: McTokens.textFaint,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    if (_query.isNotEmpty)
                                      Tooltip(
                                        message: '清空筛选',
                                        child: Semantics(
                                          button: true,
                                          label: '清空筛选',
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              _searchCtrl.clear();
                                              setState(() => _query = '');
                                            },
                                            child: const SizedBox(
                                              width: 40,
                                              height: 40,
                                              child: Center(
                                                child: Icon(
                                                  McIcons.close,
                                                  size: 15,
                                                  color: McTokens.textMuted,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 类型二级胶囊筛选条
                      if (genres.isNotEmpty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: pad),
                              children: [
                                McChip(
                                  label: '全部',
                                  compact: true,
                                  selected: _selectedGenres.isEmpty,
                                  onTap: () => setState(
                                    () => _selectedGenres.clear(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                for (final g in genres) ...[
                                  McChip(
                                    label: '${g.name} ${g.count}',
                                    compact: true,
                                    selected: _selectedGenres.contains(g.name),
                                    onTap: () => setState(() {
                                      if (_selectedGenres.contains(g.name)) {
                                        _selectedGenres.remove(g.name);
                                      } else {
                                        _selectedGenres.add(g.name);
                                      }
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (_selectedGenres.isNotEmpty)
                                  TextButton(
                                    onPressed: () => setState(
                                      () => _selectedGenres.clear(),
                                    ),
                                    child: Text('清空 ${_selectedGenres.length}'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 14)),
                      if (_items == null && _error != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: McErrorView(
                              text: _error!,
                              onRetry: _loadFirstPage,
                            ),
                          ),
                        )
                      else if (_items == null)
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: pad),
                          sliver: SliverGrid(
                            gridDelegate: gridDelegate,
                            delegate: SliverChildBuilderDelegate(
                              (_, __) => const McShimmerBox(
                                height: 210,
                                radius: McTokens.posterRadius,
                              ),
                              childCount: cols * 4,
                            ),
                          ),
                        )
                      else if (filtered.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 56),
                            child: McEmptyView(
                              title: '没有匹配的作品',
                              text: _filteringLoaded
                                  ? '试试更换搜索词或放宽类型筛选'
                                  : '当前片单暂无条目',
                              actionLabel: _filteringLoaded ? '清空筛选' : null,
                              onRetry: _filteringLoaded
                                  ? () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _query = '';
                                        _selectedGenres.clear();
                                      });
                                    }
                                  : null,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: pad),
                          sliver: SliverGrid(
                            gridDelegate: gridDelegate,
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final t = filtered[i];
                                final sub = subs.findByTitle(t);
                                final badge = t.owned
                                    ? '已入库'
                                    : (sub != null ? '已订阅' : null);
                                final badgeColor = t.owned
                                    ? McTokens.ok
                                    : (sub != null ? McTokens.info : null);
                                return McFocusRing(
                                  borderRadius: McTokens.posterRadius,
                                  child: McPosterCard(
                                    title: t.title,
                                    posterUrl: t.posterUrl,
                                    width: null,
                                    subtitle: [
                                      if (t.year != null) '${t.year}',
                                      if (t.extentLabel.isNotEmpty)
                                        t.extentLabel
                                      else if (t.genres.isNotEmpty)
                                        t.genres.first,
                                    ].join(' · '),
                                    rating: (t.rating ?? 0) > 0
                                        ? t.rating
                                        : null,
                                    badge: badge,
                                    badgeDotColor: badgeColor,
                                    onTap: () => feat_discover.pushTitle(
                                      context,
                                      t.ref,
                                      seed: t,
                                    ),
                                    contextActions: [
                                      McPosterMenuAction(
                                        icon: McIcons.film,
                                        label: '查看详情',
                                        onTap: () => feat_discover.pushTitle(
                                          context,
                                          t.ref,
                                          seed: t,
                                        ),
                                      ),
                                      if (t.owned &&
                                          t.libraryId != null &&
                                          t.mediaItemId != null)
                                        McPosterMenuAction(
                                          icon: McIcons.play2Fill,
                                          label: '前往媒体库观看',
                                          onTap: () => context.push(
                                            '/detail/${t.libraryId}/${t.mediaItemId}',
                                          ),
                                        ),
                                      if (perms.canSubscribe)
                                        McPosterMenuAction(
                                          icon: McIcons.bookmarkFill,
                                          label: sub != null ? '管理订阅' : '订阅影片',
                                          onTap: () async {
                                            final out =
                                                await showSubscribeSheet(
                                              context,
                                              ref,
                                              titleRef: t.ref,
                                            );
                                            if (!mounted || out == null) return;
                                            ref
                                                .read(
                                                  discoverSubscriptionIndexProvider
                                                      .notifier,
                                                )
                                                .refresh();
                                            if (out ==
                                                SubscribeSheetOutcome.created) {
                                              McToast.success('已加入追更订阅');
                                            } else if (out ==
                                                SubscribeSheetOutcome.managed) {
                                              this.context.push(
                                                    '/subscriptions',
                                                  );
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                      if (_loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_error != null && _items != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: McTokens.surfaceRaised,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: McTokens.line),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: McText.caption.muted,
                                    ),
                                  ),
                                  if (_hasMore)
                                    McGlassButton(
                                      onTap: _loadNextPage,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        '重试下一页',
                                        style: McText.caption.semibold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (!_hasMore &&
                          filtered.isNotEmpty &&
                          !_filteringLoaded &&
                          _items != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            child: Center(
                              child: Text(
                                '已加载全部 ${_items!.length} 部作品',
                                style: McText.caption.faint,
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: 40 + bottomPad),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (_, offset, __) => McFloatingDetailBar(
                onBack: _back,
                title: _title,
                titleVisible: offset > 56,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
