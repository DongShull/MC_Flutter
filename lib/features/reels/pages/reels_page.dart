import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/player/player_page_args.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/effects/mc_stretch.dart';

import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/reel_page.dart';
import '../widgets/reel_filter_sheet.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 刷片页（对应 Android ReelsScreen.kt 竖屏主界面）：
/// 上下整页滑动，每页一条片段。播放引擎由 player 域负责，本页只做
/// 封面 + 播放意图（TODO(reels-playback)），并上报浏览事件。
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
    // 离开页面把攒着的事件冲掉（同 Android onDispose）
    ref.read(reelsControllerProvider.notifier).flushEvents();
    _pageController.dispose();
    super.dispose();
  }

  void _back() {
    ref.read(reelsControllerProvider.notifier).flushEvents();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reelsControllerProvider);
    final controller = ref.read(reelsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 信息流 ──
          if (state.loading && state.items.isEmpty)
            const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0x99FFFFFF),
                ),
              ),
            )
          else if (state.serverOutdated)
            _CenterNote(
              title: '服务器版本较旧',
              message: '刷片需要升级服务器后使用',
              actionText: '重试',
              onAction: controller.loadFirstPage,
            )
          else if (state.error != null)
            _CenterNote(
              title: '加载失败',
              message: state.error,
              actionText: '重试',
              onAction: controller.loadFirstPage,
            )
          else if (state.items.isEmpty)
            _CenterNote(
              title: '没有可刷的片段',
              message: state.filter.isActive ? '换个筛选条件试试' : null,
              actionText: state.filter.isActive ? '看全部' : null,
              onAction: state.filter.isActive ? controller.clearFilter : null,
            )
          else
            // 果冻拉伸：上下滑越界时整页呈冻拉伸并回弹（对应飞牛 stretch_effect）。
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
                  favorite: controller.isFavorite(item),
                  played: controller.isPlayed(item),
                  onToggleFavorite: () => controller.toggleFavorite(item),
                  onTogglePlayed: () => controller.togglePlayed(item),
                  onOpenDetail: () => _openDetail(item),
                  onShare: () => _share(item),
                  onPlay: () => _play(item),
                );
              },
            ),
            ),

          // ── 顶栏：返回键 / 片名胶囊 / 筛选胶囊 ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _GlassIconButton(icon: McIcons.arrowLeft, onTap: _back),
                  const SizedBox(width: 8),
                  Expanded(child: Center(child: _titleCapsule(state))),
                  const SizedBox(width: 8),
                  _filterCapsule(state, controller),
                ],
              ),
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
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      // TV：片名胶囊可聚焦。
      child: McFocusRing(
        borderRadius: 22,
        child: InkWell(
          onTap: current == null
              ? null
              : () {
                  final item = state.items[_currentIndex];
                  ref
                      .read(reelsControllerProvider.notifier)
                      .event(item, 'detail');
                  _openDetail(item);
                },
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current?.name ?? '片段',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (current?.year != null)
                Text(
                  current!.year.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _filterCapsule(ReelsState state, ReelsController controller) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      // TV：筛选胶囊可聚焦。
      child: McFocusRing(
        borderRadius: 22,
        child: InkWell(
          onTap: () async {
            final filter = await showReelFilterSheet(context, state);
            if (filter != null) controller.applyFilter(filter);
          },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filterLabel(state.filter, state.facets),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.unfold_more,
              size: 16,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }

  int get _currentIndex => _pageController.hasClients
      ? _pageController.page?.round() ?? 0
      : 0;

  void _openDetail(ReelItemView item) {
    // 详情深链（同 Android onOpenItem）：libraryId + mediaItemId
    context.push('/detail/${item.title.libraryId.toString()}/${item.title.mediaItemId.toString()}');
  }

  void _play(ReelItemView item) {
    // 片段起播：PlayerPageArgs.startPosition = 片段起点（segment.startMs），
    // 从片段处接着看（同 Android「看全片」）；无片段信息则从 0 开始。
    ref.read(reelsControllerProvider.notifier).event(item, 'open');
    final ep = item.title.episode;
    context.push('/player', extra: PlayerPageArgs(
      mediaItemId: item.title.mediaItemId,
      fileId: item.segment.fileId > 0 ? item.segment.fileId : null,
      seasonNumber: ep?.season,
      episodeNumber: ep?.episode,
      title: item.title.name,
      isEpisode: ep != null,
      startPosition: item.segment.startMs > 0
          ? Duration(milliseconds: item.segment.startMs)
          : null,
    ));
  }

  /// 系统分享：媒体详情页链接（对齐 detail 分享的服务端链接语义）。
  void _share(ReelItemView item) {
    final t = item.title;
    Share.share('MovieClaw · ${t.name} /detail/${t.libraryId}/${t.mediaItemId}');
  }
}

/// 空态 / 提示：主行 15、副行 12，可带一颗玻璃按钮（同 Android CenterNote）
class _CenterNote extends StatelessWidget {
  const _CenterNote({
    required this.title,
    this.message,
    this.actionText,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.36),
                ),
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: InkWell(
                  onTap: onAction,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      actionText!,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 左上玻璃返回键（同 Android McNavButton）
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      // TV：返回键 D-pad 聚焦环（非 TV 原样透传）。
      child: McFocusRing(
        borderRadius: 22,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
