import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/library_detail_controller.dart';
import '../state/models.dart';
import '../widgets/library_widgets.dart';

/// 单库页（对齐 Kotlin LibraryDetailScreen.kt）：
/// 筛选墙 + 排序抽屉 + 滚动分页 + URL 即状态。
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final arg = LibraryDetailArg(
        libraryId: widget.libraryId,
        initialQuery: widget.query,
      );
      ref.read(libraryDetailProvider(arg).notifier);
    });
  }

  LibraryDetailArg get _arg =>
      LibraryDetailArg(libraryId: widget.libraryId, initialQuery: widget.query);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryDetailProvider(_arg));
    final library = state.library;
    final form = McFormWatch.of(context);
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
              McGlassIconButton(
                icon: McIcons.filterS,
                tooltip: '筛选',
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
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(libraryDetailProvider(_arg).notifier).reload(),
              child: state.loading && state.items.isEmpty
                  ? const McLoadingView()
                  : state.error != null && state.items.isEmpty
                      ? McErrorView(
                          text: state.error!,
                          onRetry: () => ref
                              .read(libraryDetailProvider(_arg).notifier)
                              .reload(),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels >
                                n.metrics.maxScrollExtent - 400) {
                              ref
                                  .read(libraryDetailProvider(_arg).notifier)
                                  .loadMore();
                            }
                            return false;
                          },
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: _filterBar(context, state),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  McTokens.pagePadding,
                                  8,
                                  McTokens.pagePadding,
                                  32,
                                ),
                                sliver: state.items.isEmpty
                                    ? const SliverToBoxAdapter(
                                        child: McEmptyView(
                                          text: '没有符合条件的媒体',
                                        ),
                                      )
                                    : SliverGrid(
                                        gridDelegate: form == McDeviceForm.phone
                                            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 130,
                                                mainAxisSpacing: 14,
                                                crossAxisSpacing: 12,
                                                childAspectRatio: 0.55,
                                              )
                                            : SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount:
                                                    mcGridCrossAxisCount(
                                                  form,
                                                  BoxConstraints.tightFor(
                                                    width: MediaQuery.widthOf(
                                                          context,
                                                        ) -
                                                        32,
                                                  ),
                                                  cellExtent: 130,
                                                ),
                                                mainAxisSpacing: 14,
                                                crossAxisSpacing: 12,
                                                childAspectRatio: 0.55,
                                              ),
                                        delegate: SliverChildBuilderDelegate(
                                          (context, i) => mcItemCard(
                                            context,
                                            state.items[i],
                                          ),
                                          childCount: state.items.length,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
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
          w == 'unwatched' ? '未看' : w,
          () => _remove((s) => s.copyWith(watch: {...s.watch}..remove(w))),
        ),
      if (f.ratingGte != null)
        _chip(
          '评分 ≥ ${f.ratingGte}',
          () => _remove((s) => s.copyWith(clearRating: true)),
        ),
      for (final r in f.resolutions)
        _chip(
          r,
          () => _remove(
            (s) => s.copyWith(resolutions: {...s.resolutions}..remove(r)),
          ),
        ),
      if (f.hdr != null)
        _chip('HDR', () => _remove((s) => s.copyWith(clearHdr: true))),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
        children: [
          ...chips,
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
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          final live = sheetRef.watch(libraryDetailProvider(_arg));
          final facets = live.facets;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              shrinkWrap: true,
              children: [
                const Text('筛选', style: McText.titleSm),
                const SizedBox(height: 12),
                if (facets == null)
                  Text('筛选维度加载中…', style: McText.sub.muted)
                else
                  _facetGroup(
                    '类型',
                    facets.genres,
                    live.filter.genres,
                    (v, on) {
                      final cur = notifier.currentFilter;
                      final next = {...cur.genres};
                      on ? next.add(v.value) : next.remove(v.value);
                      notifier.applyFilter(cur.copyWith(genres: next));
                    },
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: McActionPill(
                        label: '清空全部',
                        primary: false,
                        expanded: true,
                        onTap: () {
                          notifier.clearFilter();
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: McActionPill(
                        label: '完成',
                        primary: true,
                        expanded: true,
                        onTap: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                  ],
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
      ('title', '按名称'),
      ('added_at', '按添加时间'),
      ('release_date', '按上映日期'),
      ('rating', '按评分'),
      ('random', '随机'),
    ];
    showMcSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '排序方式',
          margin: EdgeInsets.zero,
          children: [
            for (final (value, label) in sorts)
              McInsetRow(
                title: label,
                trailing: state.filter.sort == value
                    ? const Icon(
                        McIcons.check,
                        size: 18,
                        color: McTokens.accentStrong,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(libraryDetailProvider(_arg).notifier)
                      .setSort(value, null);
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
  String title,
  List<FacetValue> facets,
  Set<String> selected,
  _FacetTap onTap,
) =>
    Column(
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
    );
