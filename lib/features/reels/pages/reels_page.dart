import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/effects/mc_stretch.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/player/player_page_args.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/reel_filter_sheet.dart';
import '../widgets/reel_page.dart';

/// 刷片页（竖屏沉浸片段流 + 液态玻璃顶栏胶囊）。
class ReelsPage extends ConsumerStatefulWidget {
  const ReelsPage({super.key});

  @override
  ConsumerState<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends ConsumerState<ReelsPage> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(reelsControllerProvider);
      if (s.items.isEmpty && !s.loading) {
        ref.read(reelsControllerProvider.notifier).loadFirstPage();
      }
    });
  }

  @override
  void dispose() {
    ref.read(reelsControllerProvider.notifier).flushEvents();
    _pageController.dispose();
    super.dispose();
  }

  void _back() {
    ref.read(reelsControllerProvider.notifier).flushEvents();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reelsControllerProvider);
    final controller = ref.read(reelsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (state.loading && state.items.isEmpty)
            const McLoadingView()
          else if (state.serverOutdated)
            McEmptyView(
              icon: McIcons.film,
              title: '服务器版本较旧',
              text: '刷片片段功能需要升级服务器后使用',
              actionLabel: '重试',
              onRetry: controller.loadFirstPage,
            )
          else if (state.error != null)
            McErrorView(
              text: state.error!,
              onRetry: controller.loadFirstPage,
            )
          else if (state.items.isEmpty)
            McEmptyView(
              icon: McIcons.film,
              title: '没有可刷的片段',
              text: state.filter.isActive ? '换个筛选条件试试' : '媒体库完成刮削与切片后将在此展示',
              actionLabel: state.filter.isActive ? '查看全部' : null,
              onRetry: state.filter.isActive ? controller.clearFilter : null,
            )
          else
            McStretchContainer(
              axis: Axis.vertical,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: state.items.length,
                onPageChanged: (index) {
                  setState(() {});
                  controller.loadMoreIfNeeded(index);
                },
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return ReelPage(
                    item: item,
                    active: index == _currentIndex,
                    favorite: controller.isFavorite(item),
                    played: controller.isPlayed(item),
                    onToggleFavorite: () => controller.toggleFavorite(item),
                    onTogglePlayed: () => controller.togglePlayed(item),
                    onOpenDetail: () => _openDetail(item),
                    onShare: () => _share(item),
                    onPlay: () => _play(item, fullMovie: false),
                    onWatchFull: () => _play(item, fullMovie: true),
                  );
                },
              ),
            ),

          // 顶栏：液态玻璃返回圆钮 / 片名胶囊 / 筛选胶囊
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              children: [
                McPageFog(height: MediaQuery.paddingOf(context).top + 68),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        McFocusRing(
                          borderRadius: 22,
                          child: McGlassIconButton(
                            icon: McIcons.arrowLeftS,
                            size: 38,
                            iconSize: 22,
                            tooltip: '返回',
                            onTap: _back,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Center(child: _titleCapsule(state))),
                        const SizedBox(width: 10),
                        _filterCapsule(state, controller),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleCapsule(ReelsState state) {
    final current = _currentIndex < state.items.length
        ? state.items[_currentIndex].title
        : null;
    return McFocusRing(
      borderRadius: 22,
      child: McPressable(
        onTap: current == null
            ? null
            : () {
                final item = state.items[_currentIndex];
                ref.read(reelsControllerProvider.notifier).event(item, 'detail');
                _openDetail(item);
              },
        child: McLiquidGlass(
          radius: McTokens.pillRadius,
          withShadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current?.name ?? '片段',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.sub.copyWith(
                  color: McTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (current?.year != null)
                Text(
                  current!.year.toString(),
                  style: McText.micro
                      .copyWith(
                        fontWeight: FontWeight.w500,
                        color: McTokens.textMuted,
                      )
                      .tabular,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterCapsule(ReelsState state, ReelsController controller) {
    return McFocusRing(
      borderRadius: 22,
      child: McPressable(
        haptic: true,
        onTap: () async {
          final filter = await showReelFilterSheet(context, state);
          if (filter != null) controller.applyFilter(filter);
        },
        child: McLiquidGlass(
          tone: state.filter.isActive
              ? McGlassTone.strong
              : McGlassTone.regular,
          radius: McTokens.pillRadius,
          withShadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filterLabel(state.filter, state.facets),
                style: McText.caption.copyWith(
                  color: McTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                McIcons.filterS,
                size: 14,
                color: McTokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _currentIndex =>
      _pageController.hasClients ? _pageController.page?.round() ?? 0 : 0;

  void _openDetail(ReelItemView item) {
    context.push('/detail/${item.title.libraryId}/${item.title.mediaItemId}');
  }

  void _play(ReelItemView item, {required bool fullMovie}) {
    ref
        .read(reelsControllerProvider.notifier)
        .event(item, fullMovie ? 'fullscreen' : 'open');
    final ep = item.title.episode;
    context.push(
      '/player',
      extra: PlayerPageArgs(
        mediaItemId: item.title.mediaItemId,
        fileId: item.segment.fileId > 0 ? item.segment.fileId : null,
        seasonNumber: ep?.season,
        episodeNumber: ep?.episode,
        title: item.title.name,
        isEpisode: ep != null,
        startPosition: !fullMovie && item.segment.startMs > 0
            ? Duration(milliseconds: item.segment.startMs)
            : null,
      ),
    );
  }

  void _share(ReelItemView item) {
    final t = item.title;
    final origin = ServerRoutes.instance.currentOrigin(
      ref.read(sessionStoreProvider).baseUrl ?? '',
    );
    final link = origin.isNotEmpty
        ? '$origin/detail/${t.libraryId}/${t.mediaItemId}'
        : '/detail/${t.libraryId}/${t.mediaItemId}';
    Share.share('MovieClaw · 《${t.name}》 $link');
  }
}
