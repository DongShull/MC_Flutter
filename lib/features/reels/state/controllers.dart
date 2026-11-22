import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'reels_api.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_error.dart';

/// 刷片页状态（对应 Android ReelsViewModel.UiState 的 Flutter 侧裁剪：
/// 播放引擎部分由 player 域负责，这里只管信息流 / 标记 / 事件）。
class ReelsState {
  const ReelsState({
    this.loading = false,
    this.items = const [],
    this.favorites = const {},
    this.playeds = const {},
    this.facets,
    this.filter = const ReelFilter(),
    this.error,
    this.serverOutdated = false,
  });

  final bool loading;
  final List<ReelItemView> items;

  /// 片段 id -> 本人是否收藏 / 已看（乐观更新，失败回滚）
  final Map<String, bool> favorites;
  final Map<String, bool> playeds;
  final ReelFacetsView? facets;
  final ReelFilter filter;
  final String? error;

  /// 服务器版本比 App 旧（/reels 404）：提示升级服务器，不报「加载失败」
  final bool serverOutdated;

  ReelsState copyWith({
    bool? loading,
    List<ReelItemView>? items,
    Map<String, bool>? favorites,
    Map<String, bool>? playeds,
    ReelFacetsView? facets,
    bool clearFacets = false,
    ReelFilter? filter,
    String? error,
    bool clearError = false,
    bool? serverOutdated,
  }) {
    return ReelsState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      favorites: favorites ?? this.favorites,
      playeds: playeds ?? this.playeds,
      facets: clearFacets ? null : (facets ?? this.facets),
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
      serverOutdated: serverOutdated ?? this.serverOutdated,
    );
  }
}

/// 刷片信息流控制器：
/// - 首页 limit=5、翻页 limit=10（Android 首页 5 同款）；
/// - 同一种子顺序固定、服务端无状态：滑到末尾前 3 条时预取下一页；
/// - 事件攒批，满 10 条 flush（失败即丢）；
/// - 收藏 / 已看走 playback/marks，乐观更新失败回滚。
class ReelsController extends Notifier<ReelsState> {
  static const _firstPageSize = 5;
  static const _pageSize = 10;

  int? _seed;
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  final List<ReelEventView> _pendingEvents = [];

  @override
  ReelsState build() {
    ref.onDispose(flushEvents);
    return const ReelsState();
  }

  ReelsApi get _api => ref.read(reelsApiProvider);

  /* ---------------- 信息流 ---------------- */

  Future<void> loadFirstPage() async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      serverOutdated: false,
    );
    _seed = null;
    _nextOffset = 0;
    _hasMore = true;
    final f = state.filter;
    try {
      final page = await _api.feed(
        seed: null,
        offset: 0,
        limit: _firstPageSize,
        filter: f,
      );
      _seed = page.seed;
      _nextOffset = page.nextOffset;
      _hasMore = page.hasMore;
      state = state.copyWith(loading: false, items: page.items);
    } catch (e) {
      final outdated = _isNotFound(e);
      state = state.copyWith(
        loading: false,
        serverOutdated: outdated,
        error: outdated ? null : _messageOf(e),
      );
    }
    loadFacets();
  }

  /// 滑到末尾前几条时取下一页（同一种子顺序固定，服务端无状态）
  Future<void> loadMoreIfNeeded(int currentIndex) async {
    if (_loadingMore || !_hasMore || state.loading) return;
    if (currentIndex < state.items.length - 3) return;
    _loadingMore = true;
    try {
      final page = await _api.feed(
        seed: _seed,
        offset: _nextOffset,
        limit: _pageSize,
        filter: state.filter,
      );
      _nextOffset = page.nextOffset;
      _hasMore = page.hasMore;
      final known = state.items.map((e) => e.id).toSet();
      final merged = [
        ...state.items,
        ...page.items.where((e) => !known.contains(e.id)),
      ];
      state = state.copyWith(items: merged);
    } catch (e) {
      // 下一页拉不到就停在这儿；用户滑回来会再试（记日志，不静默）。
      McErrorLog.log(e, context: 'reels.loadMore');
    } finally {
      _loadingMore = false;
    }
  }

  String _messageOf(Object e) =>
      e is ApiException ? e.friendlyMessage : e.toString();

  bool _isNotFound(Object e) {
    if (e is ApiException) {
      return e.httpStatus == 404;
    }
    final m = e.toString();
    return m.contains('404') ||
        m.toLowerCase().contains('not found') ||
        m.contains('找不到');
  }

  Future<void> loadFacets() async {
    try {
      final facets = await _api.facets(filter: state.filter);
      state = state.copyWith(facets: facets);
    } catch (e) {
      // 候选值拉不到就沿用上一份（记日志，不静默）。
      McErrorLog.log(e, context: 'reels.facets');
    }
  }

  /// 换筛选：整个信息流重来（新种子、从头抽）
  void applyFilter(ReelFilter filter) {
    state = state.copyWith(filter: filter, items: const [], loading: true);
    loadFirstPage();
  }

  /// 清掉全部条件（空态里的「看全部」）
  void clearFilter() => applyFilter(const ReelFilter());

  /* ---------------- 事件 ---------------- */

  void event(
    ReelItemView item,
    String kind, {
    int? positionMs,
    int? watchedMs,
    int? waitMs,
    String? detail,
  }) {
    _pendingEvents.add(ReelEventView(
      reelId: item.id,
      kind: kind,
      mode: item.play.mode,
      mediaItemId: item.title.mediaItemId > 0 ? item.title.mediaItemId : null,
      fileId: item.segment.fileId > 0 ? item.segment.fileId : null,
      positionMs: positionMs,
      watchedMs: watchedMs,
      waitMs: waitMs,
      detail: detail,
    ));
    if (_pendingEvents.length >= 10) flushEvents();
  }

  Future<void> flushEvents() async {
    if (_pendingEvents.isEmpty) return;
    final batch = List<ReelEventView>.of(_pendingEvents);
    _pendingEvents.clear();
    try {
      await _api.reportEvents(batch);
    } catch (e) {
      // 失败即丢（同 Android），记日志不静默。
      McErrorLog.log(e, context: 'reels.reportEvents');
    }
  }

  /* ---------------- 收藏 / 已看（playback/marks，乐观更新失败回滚） ---------------- */

  bool isFavorite(ReelItemView item) =>
      state.favorites[item.id] ?? item.title.favorite;

  bool isPlayed(ReelItemView item) =>
      state.playeds[item.id] ?? item.title.played;

  Future<void> toggleFavorite(ReelItemView item) async {
    final t = item.title;
    final next = !(state.favorites[item.id] ?? t.favorite);
    state = state.copyWith(
      favorites: {...state.favorites, item.id: next},
    );
    try {
      // 收藏落在整部（电影 / 整剧）
      await _api.setMarks(mediaItemId: t.mediaItemId, favorite: next);
    } catch (_) {
      state = state.copyWith(
        favorites: {...state.favorites, item.id: !next}, // 失败改回去
      );
    }
  }

  Future<void> togglePlayed(ReelItemView item) async {
    final t = item.title;
    final next = !(state.playeds[item.id] ?? t.played);
    state = state.copyWith(
      playeds: {...state.playeds, item.id: next},
    );
    final season = t.episode?.season;
    final episode = t.episode?.episode;
    try {
      // 剧集记这一集，电影记整部
      await _api.setMarks(
        mediaItemId: t.mediaItemId,
        seasonNumber: (season == null || season <= 0) ? null : season,
        episodeNumber: (episode == null || episode <= 0) ? null : episode,
        played: next,
      );
    } catch (_) {
      state = state.copyWith(
        playeds: {...state.playeds, item.id: !next}, // 失败改回去
      );
    }
  }
}

/// 顶栏筛选键的文字：没条件「全部」、一个条件写它的值、多个写「已筛选 N 项」
String filterLabel(ReelFilter filter, ReelFacetsView? facets) {
  if (filter.activeCount == 0) return '全部';
  FacetValue pick(List<FacetValue> list, String value) =>
      list.firstWhere((e) => e.value == value,
          orElse: () => FacetValue(label: value));
  final labels = <String>[
    if (filter.kind != null) pick(facets?.kinds ?? const [], filter.kind!).label,
    if (filter.watch != null) '没看过',
    if (filter.genres != null)
      pick(facets?.genres ?? const [], filter.genres!).label,
    if (filter.countries != null)
      pick(facets?.countries ?? const [], filter.countries!).label,
    if (filter.decades != null) filter.decades!,
    if (filter.ratingGte != null) '${filter.ratingGte} 分以上',
    if (filter.runtimes != null)
      pick(facets?.runtimes ?? const [], filter.runtimes!).label,
  ];
  if (labels.length == 1) return labels.first;
  return '已筛选 ${labels.length} 项';
}

final reelsControllerProvider =
    NotifierProvider<ReelsController, ReelsState>(ReelsController.new);
