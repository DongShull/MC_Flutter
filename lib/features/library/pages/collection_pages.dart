import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
import '../state/collection_detail_controller.dart';
import '../state/models.dart';
import '../widgets/library_widgets.dart';

/// 合集详情页（对齐 Kotlin LibraryCollectionScreen.kt）：封面拼贴头 + 条目墙 + 本地排序。
class CollectionDetailPage extends ConsumerStatefulWidget {
  const CollectionDetailPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  ConsumerState<CollectionDetailPage> createState() =>
      _CollectionDetailPageState();
}

class _CollectionDetailPageState extends ConsumerState<CollectionDetailPage> {
  CollectionDetailArg get _arg =>
      CollectionDetailArg(collectionId: widget.collectionId);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(collectionDetailProvider(_arg).notifier));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionDetailProvider(_arg));
    final c = state.collection;
    final form = McFormWatch.of(context);
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: c?.name ?? '合集',
            titleVisible: true,
            trailing: [
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
                  ref.read(collectionDetailProvider(_arg).notifier).reload(),
              child: state.loading && state.items.isEmpty
                  ? const McLoadingView()
                  : state.error != null && state.items.isEmpty
                      ? McErrorView(
                          text: state.error!,
                          onRetry: () => ref
                              .read(collectionDetailProvider(_arg).notifier)
                              .reload(),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels >
                                n.metrics.maxScrollExtent - 400) {
                              ref
                                  .read(collectionDetailProvider(_arg).notifier)
                                  .loadMore();
                            }
                            return false;
                          },
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (c != null)
                                SliverToBoxAdapter(
                                  child: _header(context, c, state),
                                ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  McTokens.pagePadding,
                                  12,
                                  McTokens.pagePadding,
                                  32,
                                ),
                                sliver: state.items.isEmpty
                                    ? const SliverToBoxAdapter(
                                        child: McEmptyView(text: '合集还没有条目'),
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

  Widget _header(
    BuildContext context,
    CollectionView c,
    CollectionDetailState state,
  ) {
    final covers =
        c.covers.map((e) => e.url).where((u) => u.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (covers.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              children: [
                for (final url in covers)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(McTokens.radiusSm),
                      child: CachedNetworkImage(
                        imageUrl: McImageUrls.resolve(url, widthPx: 480),
                        httpHeaders: mcImageHeaders(),
                        width: 180,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: McTokens.posterPlaceholder,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            McTokens.pagePadding,
            12,
            McTokens.pagePadding,
            0,
          ),
          child: Text(
            '${c.itemCount} 部 · ${_sortLabel(state.sort)}',
            style: McText.caption.muted,
          ),
        ),
      ],
    );
  }

  String _sortLabel(String sort) => switch (sort) {
        'title' => '按名称',
        'release_date' => '按上映日期',
        'rating' => '按评分',
        'random' => '随机',
        _ => '按添加时间',
      };

  void _openSortSheet(BuildContext context, CollectionDetailState state) {
    const options = <(String, String)>[
      ('added_at', '按添加时间'),
      ('title', '按名称'),
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
            for (final (value, label) in options)
              McInsetRow(
                title: label,
                trailing: state.sort == value
                    ? const Icon(
                        McIcons.check,
                        size: 18,
                        color: McTokens.accentStrong,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(collectionDetailProvider(_arg).notifier)
                      .setSort(value);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 「合集」入口页：合集清单，点进合集详情。
class LibraryCollectionsPage extends ConsumerStatefulWidget {
  const LibraryCollectionsPage({super.key});

  @override
  ConsumerState<LibraryCollectionsPage> createState() =>
      _LibraryCollectionsPageState();
}

class _LibraryCollectionsPageState
    extends ConsumerState<LibraryCollectionsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(collectionsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionsProvider);
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '合集',
            titleVisible: true,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(collectionsProvider.notifier).load(),
              child: state.loading && state.collections.isEmpty
                  ? const McLoadingView()
                  : state.collections.isEmpty
                      ? const McEmptyView(text: '还没有合集')
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8, bottom: 32),
                          children: [
                            McInsetGroup(
                              dividerIndent: 72,
                              children: [
                                for (final c in state.collections)
                                  McInsetRow(
                                    leading: _coverThumb(c),
                                    title: c.name,
                                    subtitle: '${c.itemCount} 部',
                                    onTap: () => context.push(
                                      routeLibraryCollection(c.id),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverThumb(CollectionView c) {
    final url = c.covers.isEmpty ? null : c.covers.first.url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(McTokens.radiusSm),
      child: SizedBox(
        width: 44,
        height: 60,
        child: url == null || url.isEmpty
            ? const ColoredBox(color: McTokens.posterPlaceholder)
            : CachedNetworkImage(
                imageUrl: McImageUrls.resolve(url, widthPx: 480),
                httpHeaders: mcImageHeaders(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: McTokens.posterPlaceholder),
              ),
      ),
    );
  }
}
