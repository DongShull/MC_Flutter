// 收藏夹独立页（PARITY.md 第 14 行：薄 → 有）。
// 海报列表 + 分页加载；点条目进详情。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/state_views.dart';
import '../../../core/image/image_urls.dart';
import '../state/favorites_controller.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesProvider);
    final notifier = ref.read(favoritesProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('收藏夹')),
      body: state.loading && state.items.isEmpty
          ? const McLoadingView()
          : state.error != null && state.items.isEmpty
              ? McErrorView(text: state.error!, onRetry: notifier.load)
              : state.items.isEmpty
                  ? const Center(child: Text('还没有收藏'))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.extentAfter < 600 &&
                            !state.loadingMore) {
                          notifier.loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: state.items.length +
                            (state.hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final item = state.items[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => context.push(
                                  '/detail/${item.libraryId}/${item.mediaItemId}',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: item.posterUrl != null &&
                                                item.posterUrl!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: McImageUrls.resolve(
                                                  item.posterUrl,
                                                  widthPx: 360,
                                                ),
                                                httpHeaders:
                                                    mcImageHeaders(),
                                                width: 52,
                                                height: 78,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _posterFallback(context),
                                              )
                                            : _posterFallback(context),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                if (item.year != null)
                                                  item.year.toString(),
                                                if (item.rating != null)
                                                  '★ ${item.rating!.toStringAsFixed(1)}',
                                              ].join(' · '),
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
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _posterFallback(BuildContext context) => Container(
        width: 52,
        height: 78,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.movie, size: 20),
      );
}
