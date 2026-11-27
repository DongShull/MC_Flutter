import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/cover_preloader.dart';
import '../../../core/session/permissions.dart';
import '../routes.dart' as feat_discover;
import '../state/discover_controller.dart';
import '../widgets/discovery_filter.dart';

class _DimSheetBody extends ConsumerWidget {
  const _DimSheetBody({
    required this.dimKey,
    required this.mediaType,
    required this.onApply,
  });

  final String dimKey;
  final String mediaType;
  final ValueChanged<DiscoveryFilter> onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverProvider);
    return DiscoveryFilterOptionsPanel(
      dimKey: dimKey,
      filter: state.filters,
      mediaType: mediaType,
      genres: state.genres,
      onApply: (f) {
        Navigator.of(context).pop();
        onApply(f);
      },
    );
  }
}

/// 组合筛选的结果网格：顶部动态条件胶囊条 + 自适应海报墙网格 + 滚到底自动翻页。
class DiscoverFilteredGrid extends ConsumerStatefulWidget {
  const DiscoverFilteredGrid({super.key});

  @override
  ConsumerState<DiscoverFilteredGrid> createState() =>
      _DiscoverFilteredGridState();
}

class _DiscoverFilteredGridState extends ConsumerState<DiscoverFilteredGrid> {
  int? _preloadedSig;

  void _openDim(String key) {
    final state = ref.read(discoverProvider);
    showMcSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: _DimSheetBody(
          dimKey: key,
          mediaType: state.mediaType,
          onApply: (f) => ref.read(discoverProvider.notifier).applyFilters(f),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);
    final subs = ref.watch(discoverSubscriptionIndexProvider);
    final perms = ref.watch(permissionsProvider);
    final sig = state.filtered.length;
    if (sig > 0 && sig != _preloadedSig) {
      _preloadedSig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          CoverPreloader.preload(
            context,
            state.filtered.map((t) => t.posterUrl),
          );
        }
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) {
          ref.read(discoverProvider.notifier).loadMoreFiltered();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final form = McFormWatch.of(context);
          final pad = form == McDeviceForm.phone
              ? McTokens.pagePadding
              : McTokens.pagePaddingWide;
          final cols = mcGridCrossAxisCount(form, constraints, cellExtent: 122);
          final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 20,
            crossAxisSpacing: 12,
            childAspectRatio: 0.515,
          );

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(state, ref, pad)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DiscoverFilterChipsRow(
                    filters: state.filters,
                    mediaType: state.mediaType,
                    genreNames: state.genreNameMap,
                    onOpenDim: _openDim,
                  ),
                ),
              ),
              if (state.filteredLoading && state.filtered.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: SliverGrid(
                    gridDelegate: gridDelegate,
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const McShimmerBox(
                        height: 210,
                        radius: McTokens.posterRadius,
                      ),
                      childCount: cols * 3,
                    ),
                  ),
                )
              else if (state.filteredError != null && state.filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: McErrorView(
                      text: state.filteredError!,
                      onRetry: () => ref
                          .read(discoverProvider.notifier)
                          .loadFiltered(skipDebounce: true),
                    ),
                  ),
                )
              else if (state.filtered.isEmpty && !state.filteredLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 64),
                    child: McEmptyView(
                      title: '没有符合条件的影片',
                      text: '试试放宽筛选条件，或一键清空恢复默认片单。',
                      actionLabel: '清空条件',
                      onRetry: () => ref
                          .read(discoverProvider.notifier)
                          .applyFilters(const DiscoveryFilter()),
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
                        final t = state.filtered[i];
                        final sub = subs.findByTitle(t);
                        final badge =
                            t.owned ? '已入库' : (sub != null ? '已订阅' : null);
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
                              if (t.year != null) t.year.toString(),
                              if (t.extentLabel.isNotEmpty)
                                t.extentLabel
                              else if (t.genres.isNotEmpty)
                                t.genres.first,
                            ].join(' · '),
                            rating: (t.rating ?? 0) > 0 ? t.rating : null,
                            badge: badge,
                            badgeDotColor: badgeColor,
                            onTap: () => feat_discover.pushTitle(
                              context,
                              t.ref,
                              seed: t,
                            ),
                            onQuickPlay: t.owned &&
                                    t.libraryId != null &&
                                    t.mediaItemId != null
                                ? () => context.push(
                                      '/detail/${t.libraryId}/${t.mediaItemId}',
                                    )
                                : null,
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
                                    final out = await showSubscribeSheet(
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
                                    if (out == SubscribeSheetOutcome.created) {
                                      McToast.success('已加入追更订阅');
                                    } else if (out ==
                                        SubscribeSheetOutcome.managed) {
                                      this.context.push('/subscriptions');
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                      childCount: state.filtered.length,
                    ),
                  ),
                ),
              if (state.filteredLoading && state.filtered.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              if (state.filteredPage >= state.filteredTotalPages &&
                  state.filtered.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        '已加载全部 ${state.filtered.length} 部作品',
                        style: McText.caption.faint,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: McTokens.bottomBarClearance +
                      MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(DiscoverState state, WidgetRef ref, double pad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 6, pad, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state.filteredTotal > 0
                  ? '共找到 ${state.filteredTotal} 部作品（已加载 ${state.filtered.length}）'
                  : '已启用 ${state.filters.activeCount} 项筛选',
              style: McText.sub.tabular,
            ),
          ),
          McGlassButton(
            onTap: () => ref
                .read(discoverProvider.notifier)
                .applyFilters(const DiscoveryFilter()),
            tone: McGlassTone.secondary,
            radius: McTokens.pillRadius,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '清空条件',
              style: McText.caption.copyWith(
                color: McTokens.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
