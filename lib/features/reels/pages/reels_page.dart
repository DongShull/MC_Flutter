import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/player/player_page_args.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../state/reel_inline_player.dart';
import '../state/reels_api.dart';
import '../widgets/reel_filter_sheet.dart';
import '../widgets/reel_page.dart';

/// 刷片页（竖屏沉浸真视频片段流）：
/// - 当前卡片真内联视频自动循环播放 `[startMs, endMs]` + 预热下一条 `standby` 实例瞬切；
/// - 完整标准事件埋点：`impression` / `first_frame(wait_ms)` / `leave(position_ms, watched_ms)` /
///   `complete` / `fullscreen` / `detail` / `fail`，切后台与退出立即刷盘上报；
/// - 「全屏观看」向 `/player` 传 `PlaybackClip(clipStartMs, clipEndMs)`，不污染主观看记录；
/// - 分享调用真实访客分享链接创建接口 `POST /api/v1/libraries/{libraryId}/items/{id}/share`。
class ReelsPage extends ConsumerStatefulWidget {
  const ReelsPage({super.key});

  @override
  ConsumerState<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends ConsumerState<ReelsPage> {
  final PageController _pageController = PageController();
  AppLifecycleListener? _lifecycle;

  int _currentIndex = 0;
  ReelInlineSession? _activeSession;
  ReelInlineSession? _standbySession;
  Timer? _standbyTimer;
  String? _notice;
  Timer? _noticeTimer;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _activeSession?.pause();
        ref.read(reelsControllerProvider.notifier).flushEvents();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctrl = ref.read(reelsControllerProvider.notifier);
      final s = ref.read(reelsControllerProvider);
      if (s.items.isEmpty && !s.loading) {
        await ctrl.loadFirstPage();
      }
      if (mounted) _activateCurrent(0);
    });
  }

  @override
  void dispose() {
    _standbyTimer?.cancel();
    _noticeTimer?.cancel();
    _lifecycle?.dispose();
    WakelockPlus.disable();
    _teardownPlayers(recordLeave: true);
    ref.read(reelsControllerProvider.notifier).flushEvents();
    _pageController.dispose();
    super.dispose();
  }

  void _flashNotice(String msg) {
    if (!mounted) return;
    _noticeTimer?.cancel();
    setState(() => _notice = msg);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _teardownPlayers({required bool recordLeave}) {
    _standbyTimer?.cancel();
    _standbyTimer = null;

    final active = _activeSession;
    _activeSession = null;
    if (active != null) {
      if (recordLeave && !_handedOff) {
        ref.read(reelsControllerProvider.notifier).event(
              active.item,
              'leave',
              positionMs: active.currentFilePosMs,
              watchedMs: active.watchedMs,
            );
      }
      unawaited(active.dispose());
    }
    _handedOff = false;

    final standby = _standbySession;
    _standbySession = null;
    if (standby != null) {
      unawaited(standby.dispose());
    }
  }

  ReelInlineSession _createSession(ReelItemView item, {required int? quality}) {
    final ctrl = ref.read(reelsControllerProvider.notifier);
    return ReelInlineSession(
      item: item,
      maxHeight: quality,
      mcClient: ref.read(mcClientProvider),
      reelsApi: ref.read(reelsApiProvider),
      onFirstFrame: (waitMs) {
        ctrl.event(
          item,
          'first_frame',
          waitMs: waitMs,
          positionMs: item.segment.startMs,
        );
        _scheduleStandbyPrewarm();
      },
      onComplete: () => ctrl.event(
        item,
        'complete',
        positionMs: item.segment.endMs,
      ),
      onFail: (reason) => ctrl.event(
        item,
        'fail',
        detail: {'reason': reason},
      ),
      onNotice: _flashNotice,
    );
  }

  void _activateCurrent(int index, {int? fromFileMs}) {
    final state = ref.read(reelsControllerProvider);
    if (index < 0 || index >= state.items.length) return;
    final item = state.items[index];

    if (_activeSession?.item.id == item.id && fromFileMs == null) return;

    final prevActive = _activeSession;
    if (prevActive != null) {
      if (!_handedOff) {
        ref.read(reelsControllerProvider.notifier).event(
              prevActive.item,
              'leave',
              positionMs: prevActive.currentFilePosMs,
              watchedMs: prevActive.watchedMs,
            );
      }
      unawaited(prevActive.dispose());
      _activeSession = null;
    }
    _handedOff = false;
    _standbyTimer?.cancel();

    ref.read(reelsControllerProvider.notifier).event(
          item,
          'impression',
          positionMs: fromFileMs ?? item.segment.startMs,
        );

    // 若 standby 已预热当前这条，直接转正秒播！
    if (_standbySession != null &&
        _standbySession!.item.id == item.id &&
        _standbySession!.error.value == null &&
        fromFileMs == null) {
      final ready = _standbySession!;
      _standbySession = null;
      _activeSession = ready;
      if (mounted) setState(() {});
      unawaited(ready.promoteFromStandby());
      return;
    }

    // 否则丢弃旧 standby 并现建当前播放器
    final staleStandby = _standbySession;
    _standbySession = null;
    if (staleStandby != null) unawaited(staleStandby.dispose());

    final nextSession = _createSession(item, quality: state.qualityMaxHeight);
    _activeSession = nextSession;
    if (mounted) setState(() {});
    unawaited(nextSession.start(autoplay: true, fromFileMs: fromFileMs));
  }

  /// 当前这条出首帧后延迟 1 秒预热下一条 standby 实例，实现滑屏零等待。
  void _scheduleStandbyPrewarm() {
    _standbyTimer?.cancel();
    _standbyTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      final state = ref.read(reelsControllerProvider);
      final nextIndex = _currentIndex + 1;
      if (nextIndex >= state.items.length) return;
      final nextItem = state.items[nextIndex];
      if (_standbySession?.item.id == nextItem.id) return;
      final old = _standbySession;
      _standbySession = null;
      if (old != null) unawaited(old.dispose());

      final pre = _createSession(nextItem, quality: state.qualityMaxHeight);
      _standbySession = pre;
      unawaited(pre.start(autoplay: false));
    });
  }

  Future<void> _changeQuality(int? maxHeight) async {
    final state = ref.read(reelsControllerProvider);
    final prevPos = _activeSession?.currentFilePosMs;
    await ref.read(reelsControllerProvider.notifier).selectQuality(maxHeight);
    if (!mounted) return;
    if (state.qualityMaxHeight == maxHeight) return;
    _handedOff = true;
    _teardownPlayers(recordLeave: false);
    _activateCurrent(_currentIndex, fromFileMs: prevPos);
    _flashNotice(
      '画质已切换为 ${maxHeight == null ? '原画' : '${maxHeight}p'}',
    );
  }

  void _back() {
    _teardownPlayers(recordLeave: true);
    ref.read(reelsControllerProvider.notifier).flushEvents();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _openDetail(ReelItemView item) async {
    final pos = _activeSession?.item.id == item.id
        ? _activeSession!.currentFilePosMs
        : item.segment.startMs;
    final watched = _activeSession?.item.id == item.id
        ? _activeSession!.watchedMs
        : 0;
    ref.read(reelsControllerProvider.notifier).event(
          item,
          'detail',
          positionMs: pos,
          watchedMs: watched,
        );
    _handedOff = true;
    _teardownPlayers(recordLeave: false);
    await context.push('/detail/${item.title.libraryId}/${item.title.mediaItemId}');
    if (mounted) _activateCurrent(_currentIndex, fromFileMs: pos);
  }

  Future<void> _openPerson(int tmdbPersonId, String name) async {
    final pos = _activeSession?.currentFilePosMs;
    _handedOff = true;
    _teardownPlayers(recordLeave: false);
    await context.push(
      '/library/person/$tmdbPersonId?name=${Uri.encodeComponent(name)}',
    );
    if (mounted) _activateCurrent(_currentIndex, fromFileMs: pos);
  }

  Future<void> _openFullscreen(ReelItemView item) async {
    final posMs = _activeSession?.item.id == item.id
        ? _activeSession!.currentFilePosMs
        : item.segment.startMs;
    final watched = _activeSession?.item.id == item.id
        ? _activeSession!.watchedMs
        : 0;
    final quality = ref.read(reelsControllerProvider).qualityMaxHeight;

    ref.read(reelsControllerProvider.notifier).event(
          item,
          'fullscreen',
          positionMs: posMs,
          watchedMs: watched,
        );
    _handedOff = true;
    _teardownPlayers(recordLeave: false);

    final ep = item.title.episode;
    await context.push(
      '/player',
      extra: PlayerPageArgs(
        mediaItemId: item.title.mediaItemId,
        fileId: item.segment.fileId > 0 ? item.segment.fileId : null,
        seasonNumber: ep?.season,
        episodeNumber: ep?.episode,
        title: item.title.name,
        seriesTitle: item.title.name,
        episodeSubtitle: ep != null
            ? 'S${ep.season.toString().padLeft(2, '0')}E${ep.episode.toString().padLeft(2, '0')}${ep.name != null ? ' · ${ep.name}' : ''}'
            : null,
        artworkUrl: item.title.backdropUrl ?? item.coverUrl ?? item.title.posterUrl,
        isEpisode: ep != null,
        startPosition: posMs > 0 ? Duration(milliseconds: posMs) : null,
        // 传入 PlaybackClip 边界，全屏观看绝不污染主观看记录
        clipStartMs: item.segment.startMs,
        clipEndMs: item.segment.endMs > item.segment.startMs
            ? item.segment.endMs
            : item.segment.startMs + 45000,
        initialMaxHeight: quality,
      ),
    );
    if (mounted) {
      await ref.read(reelsControllerProvider.notifier).loadQuality();
      if (mounted) _activateCurrent(_currentIndex, fromFileMs: posMs);
    }
  }

  Future<void> _share(ReelItemView item) async {
    _activeSession?.pause();
    final t = item.title;
    final share = await ref
        .read(reelsControllerProvider.notifier)
        .createGuestShareLink(item);
    if (!mounted) return;
    if (share != null && share.url.isNotEmpty) {
      final origin = ServerRoutes.instance.currentOrigin(
        ref.read(sessionStoreProvider).baseUrl ?? '',
      );
      final fullUrl = share.url.startsWith('http')
          ? share.url
          : (origin.isNotEmpty ? '$origin${share.url}' : share.url);
      final pwd = share.password != null && share.password!.isNotEmpty
          ? '\n访问密码：${share.password}'
          : '';
      await Share.share('MovieClaw · 《${t.name}》\n$fullUrl$pwd');
    } else {
      final yearStr = t.year != null ? '（${t.year}）' : '';
      await Share.share('MovieClaw · 《${t.name}》$yearStr');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reelsControllerProvider);
    final controller = ref.read(reelsControllerProvider.notifier);

    ref.listen<ReelsState>(reelsControllerProvider, (prev, next) {
      if ((prev?.items.isEmpty ?? true) && next.items.isNotEmpty) {
        _currentIndex = 0;
        _activateCurrent(0);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
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
              text: state.filter.isActive
                  ? '换个筛选条件试试'
                  : '媒体库完成刮削与切片后将在此展示',
              actionLabel: state.filter.isActive ? '查看全部' : null,
              onRetry: state.filter.isActive ? controller.clearFilter : null,
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: state.items.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _activateCurrent(index);
                controller.loadMoreIfNeeded(index);
              },
              itemBuilder: (context, index) {
                final item = state.items[index];
                final isCurrent = index == _currentIndex;
                final session = _activeSession?.item.id == item.id
                    ? _activeSession
                    : (_standbySession?.item.id == item.id
                        ? _standbySession
                        : null);
                return ReelPage(
                  item: item,
                  active: isCurrent,
                  session: session,
                  qualityMaxHeight: state.qualityMaxHeight,
                  favorite: controller.isFavorite(item),
                  played: controller.isPlayed(item),
                  onToggleFavorite: () => controller.toggleFavorite(item),
                  onTogglePlayed: () => controller.togglePlayed(item),
                  onOpenDetail: () => _openDetail(item),
                  onShare: () => _share(item),
                  onFullscreen: () => _openFullscreen(item),
                  onPickQuality: _changeQuality,
                  onOpenPerson: _openPerson,
                );
              },
            ),

          if (_notice != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 62,
              left: 0,
              right: 0,
              child: Center(
                child: IgnorePointer(
                  child: McLiquidGlass(
                    radius: McTokens.pillRadius,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Text(
                      _notice!,
                      style: McText.caption.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

          // 顶栏：液态玻璃返回圆钮 / 片名胶囊 / 多选筛选胶囊
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
            : () => _openDetail(state.items[_currentIndex]),
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
    return Tooltip(
      message: '筛选片段',
      child: Semantics(
        button: true,
        label: '筛选片段',
        child: McFocusRing(
          borderRadius: 22,
          child: McPressable(
            haptic: true,
            onTap: () async {
              final session = _activeSession;
              final wasPlaying = session != null &&
                  !session.paused.value &&
                  session.service.playing.value;
              if (wasPlaying) {
                unawaited(session.pause());
              }
              final filter = await showReelFilterSheet(context, state);
              if (!mounted) return;
              if (filter != null && filter != state.filter) {
                _teardownPlayers(recordLeave: true);
                controller.applyFilter(filter);
              } else if (wasPlaying && _activeSession == session) {
                unawaited(session.resume());
              }
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
        ),
      ),
    );
  }
}
