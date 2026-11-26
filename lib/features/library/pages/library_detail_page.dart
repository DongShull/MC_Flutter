import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../routes.dart';
import '../state/library_detail_controller.dart';
import '../state/models.dart';
import '../widgets/library_widgets.dart';

/// 单库页（全功能升级版）：
/// - `影片 | 合集` 分段视图无缝切换；
/// - 完整十维筛选抽屉（类型 / 地区 / 年代 / 观看状态 / 评分 / 片长 / 语言 / 分辨率 / HDR / 库存）+ 一键「存为智能合集」；
/// - 排序字段 + 升序/倒序双向切换；
/// - 按名称排序时右侧浮出银玻璃 A–Z 字母快速定位条（支持点击与垂直滑擦跳定位）。
class LibraryDetailPage extends ConsumerStatefulWidget {
  const LibraryDetailPage({
    super.key,
    required this.libraryId,
    this.query = const {},
  });

  final int libraryId;
  final Map<String, String> query;

  @override
  ConsumerState<LibraryDetailPage> createState() => _LibraryDetailPageState();
}

class _LibraryDetailPageState extends ConsumerState<LibraryDetailPage> {
  final ScrollController _scroll = ScrollController();
  String? _activeInitial;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(libraryDetailProvider(_arg).notifier);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  LibraryDetailArg get _arg =>
      LibraryDetailArg(libraryId: widget.libraryId, initialQuery: widget.query);

  Future<void> _jumpToEntry(LibraryIndexEntry entry, int cols) async {
    setState(() => _activeInitial = entry.initial);
    HapticFeedback.selectionClick();
    final localIdx = await ref
        .read(libraryDetailProvider(_arg).notifier)
        .jumpToIndexOffset(entry.offset);
    if (!mounted || localIdx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final row = localIdx ~/ cols;
      const estimatedRowHeight = 236.0;
      final target = (row * estimatedRowHeight).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(target);
    });
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted && _activeInitial == entry.initial) {
        setState(() => _activeInitial = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryDetailProvider(_arg));
    final library = state.library;
    final form = McFormWatch.of(context);
    final showIndex = state.viewMode == 'items' &&
        state.filter.sort == 'title' &&
        state.index.length > 1;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: library?.name ?? '媒体库',
            titleVisible: true,
            trailing: [
              if (state.viewMode == 'items') ...[
                McGlassIconButton(
                  icon: McIcons.filterS,
                  tooltip: '十维筛选',
                  badgeColor: state.filter.activeCount > 0
                      ? McTokens.accentStrong
                      : null,
                  onTap: () => _openFilterSheet(context, state),
                ),
                const SizedBox(width: 6),
                McGlassIconButton(
                  icon: McIcons.sort,
                  tooltip: '排序',
                  onTap: () => _openSortSheet(context, state),
                ),
              ],
            ],
          ),
          // 影片 / 合集 视图切换栏 + 总数计数
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              2,
              McTokens.pagePadding,
              6,
            ),
            child: Row(
              children: [
                McChip(
                  label: '影片',
                  icon: McIcons.film,
                  compact: true,
                  selected: state.viewMode == 'items',
                  onTap: () => ref
                      .read(libraryDetailProvider(_arg).notifier)
                      .setViewMode('items'),
                ),
                const SizedBox(width: 8),
                McChip(
                  label: state.collections.isNotEmpty
                      ? '合集 (${state.collections.length})'
                      : '合集',
                  icon: McIcons.stack,
                  compact: true,
                  selected: state.viewMode == 'collections',
                  onTap: () => ref
                      .read(libraryDetailProvider(_arg).notifier)
                      .setViewMode('collections'),
                ),
                const Spacer(),
                if (state.viewMode == 'items' && state.total > 0)
                  Text(
                    '共 ${state.total} 部',
                    style: McText.caption.faint.tabular,
                  ),
              ],
            ),
          ),
          Expanded(
            child: state.viewMode == 'collections'
                ? _buildCollectionsView(context, state)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = form == McDeviceForm.phone
                          ? ((constraints.maxWidth - 32) / 130)
                              .floor()
                              .clamp(3, 6)
                          : mcGridCrossAxisCount(
                              form,
                              BoxConstraints.tightFor(
                                width: constraints.maxWidth - 32,
                              ),
                              cellExtent: 130,
                            );
                      return Stack(
                        children: [
                          RefreshIndicator(
                            onRefresh: () async => ref
                                .read(libraryDetailProvider(_arg).notifier)
                                .reload(),
                            child: state.loading && state.items.isEmpty
                                ? const McLoadingView()
                                : state.error != null && state.items.isEmpty
                                    ? McErrorView(
                                        text: state.error!,
                                        onRetry: () => ref
                                            .read(
                                              libraryDetailProvider(
                                                _arg,
                                              ).notifier,
                                            )
                                            .reload(),
                                      )
                                    : NotificationListener<ScrollNotification>(
                                        onNotification: (n) {
                                          if (n.metrics.pixels >
                                              n.metrics.maxScrollExtent - 400) {
                                            ref
                                                .read(
                                                  libraryDetailProvider(
                                                    _arg,
                                                  ).notifier,
                                                )
                                                .loadMore();
                                          }
                                          return false;
                                        },
                                        child: CustomScrollView(
                                          controller: _scroll,
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          slivers: [
                                            SliverToBoxAdapter(
                                              child: _filterBar(context, state),
                                            ),
                                            SliverPadding(
                                              padding: EdgeInsets.fromLTRB(
                                                McTokens.pagePadding,
                                                8,
                                                showIndex
                                                    ? McTokens.pagePadding + 22
                                                    : McTokens.pagePadding,
                                                32,
                                              ),
                                              sliver: state.items.isEmpty
                                                  ? const SliverToBoxAdapter(
                                                      child: McEmptyView(
                                                        text: '没有符合条件的媒体',
                                                      ),
                                                    )
                                                  : SliverGrid(
                                                      gridDelegate:
                                                          SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount: cols,
                                                        mainAxisSpacing: 14,
                                                        crossAxisSpacing: 12,
                                                        childAspectRatio: 0.55,
                                                      ),
                                                      delegate:
                                                          SliverChildBuilderDelegate(
                                                        (context, i) =>
                                                            mcItemCard(
                                                          context,
                                                          state.items[i],
                                                          width: null,
                                                          fallbackLibraryId:
                                                              widget.libraryId,
                                                        ),
                                                        childCount:
                                                            state.items.length,
                                                      ),
                                                    ),
                                            ),
                                            if (state.loadingMore)
                                              const SliverToBoxAdapter(
                                                child: Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: Center(
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                          ),
                          if (showIndex)
                            Positioned(
                              right: 4,
                              top: 12,
                              bottom: 24,
                              child: Center(
                                child: _AlphabetIndexBar(
                                  entries: state.index,
                                  activeInitial: _activeInitial,
                                  onSelect: (e) => _jumpToEntry(e, cols),
                                ),
                              ),
                            ),
                          if (_activeInitial != null)
                            Center(
                              child: IgnorePointer(
                                child: McLiquidGlass(
                                  radius: 20,
                                  tone: McGlassTone.strong,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    _activeInitial!,
                                    style: McText.display,
                                  ),
                                ),
                              ),
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

  Widget _buildCollectionsView(BuildContext context, LibraryDetailState state) {
    if (state.collections.isEmpty) {
      return McEmptyView(
        icon: McIcons.stack,
        title: '该媒体库暂无合集',
        text: '在影片视图开启任意筛选条件后，可一键保存为智能合集。',
        actionLabel: '前往合集管理',
        onRetry: () => context.push(routeLibraryCollections),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        McInsetGroup(
          dividerIndent: 72,
          children: [
            for (final c in state.collections)
              McInsetRow(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(McTokens.radiusSm),
                  child: SizedBox(
                    width: 44,
                    height: 60,
                    child: c.covers.isEmpty || c.covers.first.url.isEmpty
                        ? const ColoredBox(color: McTokens.posterPlaceholder)
                        : CachedNetworkImage(
                            imageUrl: McImageUrls.resolve(
                              c.covers.first.url,
                              widthPx: 320,
                            ),
                            httpHeaders: mcImageHeaders(),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: McTokens.posterPlaceholder,
                            ),
                          ),
                  ),
                ),
                title: c.name,
                subtitle:
                    '${c.itemCount} 部${c.ruleDriven ? ' · 智能规则' : ''}',
                onTap: () => context.push(routeLibraryCollection(c.id)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _filterBar(BuildContext context, LibraryDetailState state) {
    final f = state.filter;
    final chips = <Widget>[
      for (final g in f.genres)
        _chip(
          '类型: $g',
          () => _remove((s) => s.copyWith(genres: {...s.genres}..remove(g))),
        ),
      for (final c in f.countries)
        _chip(
          '地区: $c',
          () => _remove(
            (s) => s.copyWith(countries: {...s.countries}..remove(c)),
          ),
        ),
      for (final d in f.decades)
        _chip(
          '年代: $d',
          () => _remove((s) => s.copyWith(decades: {...s.decades}..remove(d))),
        ),
      for (final w in f.watch)
        _chip(
          w == 'unwatched' ? '未看' : (w == 'seen' ? '已看' : w),
          () => _remove((s) => s.copyWith(watch: {...s.watch}..remove(w))),
        ),
      if (f.ratingGte != null)
        _chip(
          '评分 ≥ ${f.ratingGte}',
          () => _remove((s) => s.copyWith(clearRating: true)),
        ),
      for (final rt in f.runtimes)
        _chip(
          '片长: $rt',
          () => _remove(
            (s) => s.copyWith(runtimes: {...s.runtimes}..remove(rt)),
          ),
        ),
      for (final lang in f.languages)
        _chip(
          '语言: $lang',
          () => _remove(
            (s) => s.copyWith(languages: {...s.languages}..remove(lang)),
          ),
        ),
      for (final r in f.resolutions)
        _chip(
          r,
          () => _remove(
            (s) => s.copyWith(resolutions: {...s.resolutions}..remove(r)),
          ),
        ),
      if (f.hdr != null)
        _chip(
          f.hdr! ? '仅 HDR' : '仅 SDR',
          () => _remove((s) => s.copyWith(clearHdr: true)),
        ),
      for (final st in f.stock)
        _chip(
          '库存: $st',
          () => _remove((s) => s.copyWith(stock: {...s.stock}..remove(st))),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
        children: [
          ...chips,
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: McChip(
              icon: McIcons.folderSmart,
              label: '存为智能合集',
              compact: true,
              onTap: () => _promptSaveSmartCollection(context),
            ),
          ),
          McChip(
            label: '清空',
            compact: true,
            onTap: () =>
                ref.read(libraryDetailProvider(_arg).notifier).clearFilter(),
          ),
        ],
      ),
    );
  }

  Future<void> _promptSaveSmartCollection(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final name = await showMcSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('保存为智能合集', style: McText.titleSm),
            const SizedBox(height: 6),
            Text(
              '新入库的影片只要满足当前筛选条件，会自动归入该合集。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: McText.body,
              decoration: const InputDecoration(hintText: '输入合集名称，例如「高分 4K 科幻」'),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 18),
            McActionPill(
              label: '创建智能合集',
              icon: McIcons.folderSmart,
              primary: true,
              expanded: true,
              onTap: () => Navigator.of(ctx).pop(nameCtrl.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await ref
          .read(libraryDetailProvider(_arg).notifier)
          .saveAsSmartCollection(name);
      if (mounted) McToast.success('已创建智能合集「$name」');
    } catch (e) {
      if (mounted) McToast.error('创建失败：$e');
    }
  }

  Widget _chip(String label, VoidCallback onRemove) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: McChip(
          label: '$label ×',
          selected: true,
          compact: true,
          onTap: onRemove,
        ),
      );

  void _remove(LibraryFilter Function(LibraryFilter) edit) {
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    notifier.applyFilter(edit(notifier.currentFilter));
  }

  void _openFilterSheet(BuildContext context, LibraryDetailState state) {
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    showMcSheet<void>(
      context: context,
      maxWidth: 620,
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          final live = sheetRef.watch(libraryDetailProvider(_arg));
          final facets = live.facets;
          final f = live.filter;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('全维度筛选', style: McText.titleSm),
                      ),
                      if (f.activeCount > 0)
                        McChip(
                          label: '已选 ${f.activeCount} 项 · 清空',
                          compact: true,
                          onTap: notifier.clearFilter,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: McTokens.line),
                Flexible(
                  child: facets == null
                      ? const SizedBox(
                          height: 180,
                          child: McLoadingView(label: '加载十维筛选指标…'),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                          shrinkWrap: true,
                          children: [
                            if (facets.watch.isNotEmpty)
                              _facetGroup('观看状态', facets.watch, f.watch, (v, on) {
                                final cur = notifier.currentFilter;
                                final next = {...cur.watch};
                                on ? next.add(v.value) : next.remove(v.value);
                                notifier.applyFilter(cur.copyWith(watch: next));
                              }),
                            if (facets.genres.isNotEmpty)
                              _facetGroup('类型', facets.genres, f.genres, (v, on) {
                                final cur = notifier.currentFilter;
                                final next = {...cur.genres};
                                on ? next.add(v.value) : next.remove(v.value);
                                notifier.applyFilter(cur.copyWith(genres: next));
                              }),
                            if (facets.countries.isNotEmpty)
                              _facetGroup(
                                '地区',
                                facets.countries,
                                f.countries,
                                (v, on) {
                                  final cur = notifier.currentFilter;
                                  final next = {...cur.countries};
                                  on ? next.add(v.value) : next.remove(v.value);
                                  notifier.applyFilter(
                                    cur.copyWith(countries: next),
                                  );
                                },
                              ),
                            if (facets.decades.isNotEmpty)
                              _facetGroup(
                                '年代',
                                facets.decades,
                                f.decades,
                                (v, on) {
                                  final cur = notifier.currentFilter;
                                  final next = {...cur.decades};
                                  on ? next.add(v.value) : next.remove(v.value);
                                  notifier.applyFilter(
                                    cur.copyWith(decades: next),
                                  );
                                },
                              ),
                            // 评分门槛（支持 facets.ratings 或固定档位）
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('最低评分', style: McText.sub.semibold),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final r in const [
                                        9.0,
                                        8.0,
                                        7.0,
                                        6.0,
                                      ])
                                        McChip(
                                          label: '≥ ${r.toStringAsFixed(0)} 分',
                                          selected: f.ratingGte == r,
                                          compact: true,
                                          onTap: () {
                                            final cur = notifier.currentFilter;
                                            notifier.applyFilter(
                                              cur.ratingGte == r
                                                  ? cur.copyWith(
                                                      clearRating: true,
                                                    )
                                                  : cur.copyWith(ratingGte: r),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (facets.resolutions.isNotEmpty)
                              _facetGroup(
                                '分辨率',
                                facets.resolutions,
                                f.resolutions,
                                (v, on) {
                                  final cur = notifier.currentFilter;
                                  final next = {...cur.resolutions};
                                  on ? next.add(v.value) : next.remove(v.value);
                                  notifier.applyFilter(
                                    cur.copyWith(resolutions: next),
                                  );
                                },
                              ),
                            // 动态范围 HDR / SDR
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('动态范围', style: McText.sub.semibold),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      McChip(
                                        label: '不限',
                                        selected: f.hdr == null,
                                        compact: true,
                                        onTap: () => notifier.applyFilter(
                                          notifier.currentFilter.copyWith(
                                            clearHdr: true,
                                          ),
                                        ),
                                      ),
                                      McChip(
                                        label: 'HDR / 杜比视界',
                                        selected: f.hdr == true,
                                        compact: true,
                                        onTap: () => notifier.applyFilter(
                                          notifier.currentFilter.copyWith(
                                            hdr: true,
                                          ),
                                        ),
                                      ),
                                      McChip(
                                        label: '仅 SDR',
                                        selected: f.hdr == false,
                                        compact: true,
                                        onTap: () => notifier.applyFilter(
                                          notifier.currentFilter.copyWith(
                                            hdr: false,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (facets.runtimes.isNotEmpty)
                              _facetGroup(
                                '片长',
                                facets.runtimes,
                                f.runtimes,
                                (v, on) {
                                  final cur = notifier.currentFilter;
                                  final next = {...cur.runtimes};
                                  on ? next.add(v.value) : next.remove(v.value);
                                  notifier.applyFilter(
                                    cur.copyWith(runtimes: next),
                                  );
                                },
                              ),
                            if (facets.languages.isNotEmpty)
                              _facetGroup(
                                '语言',
                                facets.languages,
                                f.languages,
                                (v, on) {
                                  final cur = notifier.currentFilter;
                                  final next = {...cur.languages};
                                  on ? next.add(v.value) : next.remove(v.value);
                                  notifier.applyFilter(
                                    cur.copyWith(languages: next),
                                  );
                                },
                              ),
                            if (facets.stock.isNotEmpty)
                              _facetGroup(
                                '库存状态',
                                facets.stock,
                                f.stock,
                                (v, on) {
                                  final cur = notifier.currentFilter;
                                  final next = {...cur.stock};
                                  on ? next.add(v.value) : next.remove(v.value);
                                  notifier.applyFilter(
                                    cur.copyWith(stock: next),
                                  );
                                },
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      if (f.activeCount > 0) ...[
                        Expanded(
                          child: McActionPill(
                            label: '存为智能合集',
                            icon: McIcons.folderSmart,
                            primary: false,
                            expanded: true,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _promptSaveSmartCollection(this.context);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: McActionPill(
                          label: '查看结果 (${live.total})',
                          primary: true,
                          expanded: true,
                          onTap: () => Navigator.of(sheetContext).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openSortSheet(BuildContext context, LibraryDetailState state) {
    const sorts = <(String, String)>[
      ('title', '按名称 (A–Z 索引)'),
      ('added_at', '按添加时间'),
      ('release_date', '按上映日期'),
      ('rating', '按评分'),
      ('random', '随机洗牌'),
    ];
    showMcSheet<void>(
      context: context,
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          final live = sheetRef.watch(libraryDetailProvider(_arg));
          final curOrder = live.filter.order;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                McInsetGroup(
                  header: '排序字段',
                  margin: EdgeInsets.zero,
                  children: [
                    for (final (value, label) in sorts)
                      McInsetRow(
                        title: label,
                        trailing: live.filter.sort == value
                            ? const Icon(
                                McIcons.check,
                                size: 18,
                                color: McTokens.accentStrong,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(libraryDetailProvider(_arg).notifier)
                              .setSort(value, curOrder);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                  ],
                ),
                if (live.filter.sort != 'random') ...[
                  const SizedBox(height: 12),
                  McInsetGroup(
                    header: '排序方向',
                    margin: EdgeInsets.zero,
                    children: [
                      McInsetRow(
                        icon: McIcons.sortAsc1,
                        title: '正序 (A → Z / 旧 → 新)',
                        trailing: curOrder == 'asc'
                            ? const Icon(
                                McIcons.check,
                                size: 18,
                                color: McTokens.accentStrong,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(libraryDetailProvider(_arg).notifier)
                              .setSort(live.filter.sort, 'asc');
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                      McInsetRow(
                        icon: McIcons.sortDesc1,
                        title: '倒序 (Z → A / 新 → 旧)',
                        trailing: curOrder == 'desc'
                            ? const Icon(
                                McIcons.check,
                                size: 18,
                                color: McTokens.accentStrong,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(libraryDetailProvider(_arg).notifier)
                              .setSort(live.filter.sort, 'desc');
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AlphabetIndexBar extends StatelessWidget {
  const _AlphabetIndexBar({
    required this.entries,
    required this.activeInitial,
    required this.onSelect,
  });

  final List<LibraryIndexEntry> entries;
  final String? activeInitial;
  final ValueChanged<LibraryIndexEntry> onSelect;

  void _pickAt(BuildContext context, Offset localPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || entries.isEmpty) return;
    final idx = ((localPos.dy / box.size.height) * entries.length)
        .floor()
        .clamp(0, entries.length - 1);
    onSelect(entries[idx]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (d) => _pickAt(context, d.localPosition),
      onVerticalDragUpdate: (d) => _pickAt(context, d.localPosition),
      onTapDown: (d) => _pickAt(context, d.localPosition),
      child: Container(
        width: 22,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x80151821),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: McTokens.line, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.2),
                child: Text(
                  e.initial,
                  style: McText.micro.copyWith(
                    fontSize: 10,
                    color: activeInitial == e.initial
                        ? McTokens.accentStrong
                        : McTokens.textMuted,
                    fontWeight: activeInitial == e.initial
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

typedef _FacetTap = void Function(FacetValue value, bool on);

Widget _facetGroup(
  String title,
  List<FacetValue> facets,
  Set<String> selected,
  _FacetTap onTap,
) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: McText.sub.semibold),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in facets)
                McChip(
                  label: '${f.label} (${f.count})',
                  selected: selected.contains(f.value),
                  compact: true,
                  onTap: () => onTap(f, !selected.contains(f.value)),
                ),
            ],
          ),
        ],
      ),
    );
