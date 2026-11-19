import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/person_kind_controllers.dart';
import '../../../core/designsystem/state_views.dart';
import '../widgets/library_widgets.dart';

/// 人物下钻页（对齐 Kotlin LibraryPersonScreen.kt）：
/// GET /search/library?person_id 游标分页的网格；待建索引时显示提示；滚动加载。
class LibraryPersonPage extends ConsumerStatefulWidget {
  const LibraryPersonPage({super.key, required this.personId, this.personName});

  final int personId;
  final String? personName;

  @override
  ConsumerState<LibraryPersonPage> createState() => _LibraryPersonPageState();
}

class _LibraryPersonPageState extends ConsumerState<LibraryPersonPage> {
  PersonArg get _arg =>
      PersonArg(personId: widget.personId, personName: widget.personName);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(personProvider(_arg).notifier));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personProvider(_arg));
    return Scaffold(
      appBar: AppBar(title: Text(widget.personName ?? '相关作品')),
      body: state.loading && state.items.isEmpty
          ? const McLoadingView()
          : state.error != null && state.items.isEmpty
              ? McErrorView(text: state.error!, onRetry: () => ref.read(personProvider(_arg).notifier).load())
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
                      ref.read(personProvider(_arg).notifier).loadMore();
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (state.indexPending)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('正在为相关内容建索引，结果可能不完整',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: state.items.isEmpty
                            ? const SliverToBoxAdapter(
                                child: McEmptyView(text: '没有找到相关作品'))
                            : SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 130,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.55,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) {
                                    final hit = state.items[i];
                                    return mcItemCard(context, hit.item);
                                  },
                                  childCount: state.items.length,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// 类型墙页（对齐 Kotlin KindWallScreen.kt）：跨库 kind + 类型/观看筛选 + 排序。
class KindWallPage extends ConsumerStatefulWidget {
  const KindWallPage({super.key, required this.kind});

  /// movie / tv
  final String kind;

  @override
  ConsumerState<KindWallPage> createState() => _KindWallPageState();
}

class _KindWallPageState extends ConsumerState<KindWallPage> {
  KindWallArg get _arg => KindWallArg(kind: widget.kind);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(kindWallProvider(_arg).notifier));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kindWallProvider(_arg));
    final total = state.summary?.itemCount ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.kind == 'movie' ? '电影' : '剧集'} · $total 部'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '观看过滤',
            onSelected: (v) => ref
                .read(kindWallProvider(_arg).notifier)
                .setWatch(v == 'all' ? null : v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('全部')),
              PopupMenuItem(value: 'unwatched', child: Text('未看')),
            ],
            child: const Icon(Icons.remove_red_eye_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: '排序',
            onSelected: (v) =>
                ref.read(kindWallProvider(_arg).notifier).setSort(v, null),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'added_at', child: Text('按添加时间')),
              PopupMenuItem(value: 'title', child: Text('按名称')),
              PopupMenuItem(value: 'release_date', child: Text('按上映日期')),
              PopupMenuItem(value: 'rating', child: Text('按评分')),
              PopupMenuItem(value: 'random', child: Text('随机')),
            ],
            child: const Icon(Icons.sort),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(kindWallProvider(_arg).notifier).reload(),
        child: Column(
          children: [
            if (state.genres.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    for (final g in state.genres)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text((g['name'] ?? g['label'] ?? '').toString()),
                          selected: state.genre == (g['id'] ?? g['value'] ?? '').toString(),
                          onSelected: (on) => ref
                              .read(kindWallProvider(_arg).notifier)
                              .setGenre(on ? (g['id'] ?? g['value']).toString() : null),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: state.loading && state.items.isEmpty
                  ? const McLoadingView()
                  : state.error != null && state.items.isEmpty
                      ? McErrorView(
                          text: state.error!,
                          onRetry: () =>
                              ref.read(kindWallProvider(_arg).notifier).reload())
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
                              ref.read(kindWallProvider(_arg).notifier).loadMore();
                            }
                            return false;
                          },
                          child: state.items.isEmpty
                              ? const McEmptyView(text: '没有符合条件的媒体')
                              : GridView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 130,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.55,
                                  ),
                                  itemCount: state.items.length,
                                  itemBuilder: (context, i) =>
                                      mcItemCard(context, state.items[i]),
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
