import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import '../state/models.dart';
import '../state/collection_detail_controller.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../widgets/library_widgets.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 合集详情页（对齐 Kotlin LibraryCollectionScreen.kt）：封面拼贴头 + 条目墙 + 本地排序。
class CollectionDetailPage extends ConsumerStatefulWidget {
  const CollectionDetailPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  ConsumerState<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends ConsumerState<CollectionDetailPage> {
  CollectionDetailArg get _arg => CollectionDetailArg(collectionId: widget.collectionId);

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
      appBar: AppBar(
        title: Text(c?.name ?? '合集'),
        actions: [
          IconButton(
            icon: const Icon(McIcons.sort),
            onPressed: () => _openSortSheet(context, state),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(collectionDetailProvider(_arg).notifier).reload(),
        child: state.loading && state.items.isEmpty
            ? const McLoadingView()
            : state.error != null && state.items.isEmpty
                ? McErrorView(
                    text: state.error!,
                    onRetry: () => ref.read(collectionDetailProvider(_arg).notifier).reload())
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
                        ref.read(collectionDetailProvider(_arg).notifier).loadMore();
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (c != null)
                          SliverToBoxAdapter(child: _header(context, c, state)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          sliver: state.items.isEmpty
                              ? const SliverToBoxAdapter(
                                  child: McEmptyView(text: '合集还没有条目'))
                              : SliverGrid(
                                  // 平板/TV 自适应列数；手机保持现有密度不变。
                                  gridDelegate: form == McDeviceForm.phone
                                      ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 130,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 0.55,
                                        )
                                      : SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: mcGridCrossAxisCount(
                                              form,
                                              BoxConstraints.tightFor(
                                                  width:
                                                      MediaQuery.widthOf(context) - 32),
                                          cellExtent: 130),
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

  Widget _header(BuildContext context, CollectionView c, CollectionDetailState state) {
    final covers = c.covers.map((e) => e.url).where((u) => u.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (covers.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final url in covers)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 180, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '${c.itemCount} 部 · ${_sortLabel(state.sort)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
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
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in options)
              ListTile(
                title: Text(label),
                trailing: state.sort == value ? const Icon(McIcons.check, size: 18) : null,
                onTap: () {
                  ref.read(collectionDetailProvider(_arg).notifier).setSort(value);
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
  ConsumerState<LibraryCollectionsPage> createState() => _LibraryCollectionsPageState();
}

class _LibraryCollectionsPageState extends ConsumerState<LibraryCollectionsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(collectionsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('合集')),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(collectionsProvider.notifier).load(),
        child: state.loading && state.collections.isEmpty
            ? const McLoadingView()
            : state.collections.isEmpty
                ? const McEmptyView(text: '还没有合集')
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: state.collections.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = state.collections[i];
                      return ListTile(
                        leading: _coverThumb(c),
                        title: Text(c.name),
                        subtitle: Text('${c.itemCount} 部'),
                        onTap: () => context.push(routeLibraryCollection(c.id)),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _coverThumb(CollectionView c) {
    final url = c.covers.isEmpty ? null : c.covers.first.url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44,
        height: 60,
        child: url == null || url.isEmpty
            ? Container(color: const Color(0xFF141A21))
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}
