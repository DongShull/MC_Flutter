import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/library_detail_controller.dart';
import '../state/models.dart';
import '../../../core/designsystem/state_views.dart';
import '../widgets/library_widgets.dart';

/// 单库页（对齐 Kotlin LibraryDetailScreen.kt）：
/// 筛选墙。分段「影片/合集」；筛选条即时生效（铁律：点一下就变）；排序抽屉；
/// sort=='title' 时显示字母索引条；滚动分页；URL 即状态（查询串还原筛选）。
class LibraryDetailPage extends ConsumerStatefulWidget {
  const LibraryDetailPage({super.key, required this.libraryId, this.query = const {}});

  final int libraryId;
  final Map<String, String> query;

  @override
  ConsumerState<LibraryDetailPage> createState() => _LibraryDetailPageState();
}

class _LibraryDetailPageState extends ConsumerState<LibraryDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final arg = LibraryDetailArg(libraryId: widget.libraryId, initialQuery: widget.query);
      ref.read(libraryDetailProvider(arg).notifier);
    });
  }

  LibraryDetailArg get _arg =>
      LibraryDetailArg(libraryId: widget.libraryId, initialQuery: widget.query);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryDetailProvider(_arg));
    final library = state.library;
    return Scaffold(
      appBar: AppBar(
        title: Text(library?.name ?? '媒体库'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.filter.activeCount > 0,
              label: Text('${state.filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
            tooltip: '筛选',
            onPressed: () => _openFilterSheet(context, state),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onPressed: () => _openSortSheet(context, state),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(libraryDetailProvider(_arg).notifier).reload(),
        child: state.loading && state.items.isEmpty
            ? const McLoadingView()
            : state.error != null && state.items.isEmpty
                ? McErrorView(
                    text: state.error!,
                    onRetry: () => ref.read(libraryDetailProvider(_arg).notifier).reload())
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
                        ref.read(libraryDetailProvider(_arg).notifier).loadMore();
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _filterBar(context, state)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: state.items.isEmpty
                              ? const SliverToBoxAdapter(
                                  child: McEmptyView(text: '没有符合条件的媒体'))
                              : SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 130,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.55,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) => mcItemCard(context, state.items[i]),
                                    childCount: state.items.length,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  /// 顶部一行：当前生效的筛选 chip（可点 × 移除）+ 清空。
  Widget _filterBar(BuildContext context, LibraryDetailState state) {
    final f = state.filter;
    final chips = <Widget>[
      for (final g in f.genres) _chip('类型: $g', () => _remove((s) => s.copyWith(genres: {...s.genres}..remove(g)))),
      for (final c in f.countries) _chip('地区: $c', () => _remove((s) => s.copyWith(countries: {...s.countries}..remove(c)))),
      for (final d in f.decades) _chip('年代: $d', () => _remove((s) => s.copyWith(decades: {...s.decades}..remove(d)))),
      for (final w in f.watch) _chip(w == 'unwatched' ? '未看' : w, () => _remove((s) => s.copyWith(watch: {...s.watch}..remove(w)))),
      if (f.ratingGte != null)
        _chip('评分 ≥ ${f.ratingGte}', () => _remove((s) => s.copyWith(clearRating: true))),
      for (final r in f.resolutions) _chip(r, () => _remove((s) => s.copyWith(resolutions: {...s.resolutions}..remove(r)))),
      if (f.hdr != null) _chip('HDR', () => _remove((s) => s.copyWith(clearHdr: true))),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...chips,
          InputChip(
            label: const Text('清空'),
            onPressed: () => ref.read(libraryDetailProvider(_arg).notifier).clearFilter(),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          label: Text(label),
          onDeleted: onRemove,
          visualDensity: VisualDensity.compact,
        ),
      );

  void _remove(LibraryFilter Function(LibraryFilter) edit) {
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    notifier.applyFilter(edit(notifier.currentFilter));
  }

  void _openFilterSheet(BuildContext context, LibraryDetailState state) {
    final facets = state.facets;
    final notifier = ref.read(libraryDetailProvider(_arg).notifier);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('筛选', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (facets == null)
              const Text('筛选维度加载中…')
            else ...[
              _facetGroup(
                sheetContext,
                '类型',
                facets.genres,
                state.filter.genres,
                (v, on) {
                  final cur = notifier.currentFilter;
                  final next = {...cur.genres};
                  on ? next.add(v.value) : next.remove(v.value);
                  notifier.applyFilter(cur.copyWith(genres: next));
                },
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    notifier.clearFilter();
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('清空全部'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('完成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openSortSheet(BuildContext context, LibraryDetailState state) {
    const sorts = <(String, String)>[
      ('title', '按名称'),
      ('added_at', '按添加时间'),
      ('release_date', '按上映日期'),
      ('rating', '按评分'),
      ('random', '随机'),
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in sorts)
              ListTile(
                title: Text(label),
                trailing: state.filter.sort == value
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () {
                  ref.read(libraryDetailProvider(_arg).notifier).setSort(value, null);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

typedef _FacetTap = void Function(FacetValue value, bool on);

Widget _facetGroup(
  BuildContext context,
  String title,
  List<FacetValue> facets,
  Set<String> selected,
  _FacetTap onTap,
) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final f in facets)
              FilterChip(
                label: Text('${f.label} (${f.count})'),
                selected: selected.contains(f.value),
                onSelected: (on) => onTap(f, on),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
