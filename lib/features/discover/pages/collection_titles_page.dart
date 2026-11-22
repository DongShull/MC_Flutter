// 发现榜单完整列表页：海报网格 + 翻页；点海报进条目详情。
// 榜单（isRanked）按服务端顺序显示名次（1 起，跨页累加）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../routes.dart' as feat_discover;
import '../state/collection_titles_controller.dart';

class CollectionTitlesPage extends ConsumerWidget {
  const CollectionTitlesPage({
    super.key,
    required this.collectionRef,
    required this.title,
  });

  final String collectionRef;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionTitlesProvider(collectionRef));
    final notifier =
        ref.read(collectionTitlesProvider(collectionRef).notifier);
    final ranked = state.collection?.isRanked ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: state.loading && state.titles.isEmpty
          ? const McLoadingView()
          : state.error != null && state.titles.isEmpty
              ? McErrorView(text: state.error!, onRetry: notifier.load)
              : state.titles.isEmpty
                  ? const Center(child: Text('这个榜单是空的'))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.extentAfter < 600 &&
                            !state.loadingMore) {
                          notifier.loadMore();
                        }
                        return false;
                      },
                      child: CustomScrollView(
                        slivers: [
                          if (state.collection?.description.isNotEmpty ??
                              false)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  4,
                                ),
                                child: Text(
                                  state.collection!.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.all(12),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 8,
                                // 海报 2:3 + 标题 + 副标题：0.55 才放得下两行文字
                                //（0.62 会在宽屏溢出约 10px，见 McPosterCard 版式）。
                                childAspectRatio: 0.55,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  if (i >= state.titles.length) {
                                    return const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                  final t = state.titles[i];
                                  return McPosterCard(
                                    title: t.title,
                                    posterUrl: t.posterUrl,
                                    subtitle: [
                                      if (ranked) '第 ${i + 1} 名',
                                      if (t.releaseYear != null)
                                        t.releaseYear.toString(),
                                      if (t.genres.isNotEmpty) t.genres.first,
                                    ].join(' · '),
                                    rating: t.providerRating > 0
                                        ? t.providerRating
                                        : null,
                                    badge: (t.libraryStatus?.fileCount ??
                                                0) >
                                            0
                                        ? '在库'
                                        : null,
                                    onTap: () => feat_discover.pushTitle(
                                      context,
                                      t.titleRef,
                                    ),
                                  );
                                },
                                childCount: state.titles.length +
                                    (state.hasMore ? 1 : 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
