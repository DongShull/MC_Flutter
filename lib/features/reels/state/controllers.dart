import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import 'models.dart';
import 'network_tier.dart';
import 'reels_api.dart';

/// 刷片页状态（信息流、收藏/已看、筛选、四象限画质、事件攒批）。
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
    this.qualityMaxHeight,
    this.qualityLoaded = false,
  });

  final bool loading;
  final List<ReelItemView> items;
  final Map<String, bool> favorites;
  final Map<String, bool> playeds;
  final ReelFacetsView? facets;
  final ReelFilter filter;
  final String? error;
  final bool serverOutdated;

  /// 当前网络象限生效的画质上限（`null` = 原画，1080/720/480 = 转码上限）。
  final int? qualityMaxHeight;
  final bool qualityLoaded;

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
    int? qualityMaxHeight,
    bool setQualityOriginal = false,
    bool? qualityLoaded,
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
      qualityMaxHeight: setQualityOriginal
          ? null
          : (qualityMaxHeight ?? this.qualityMaxHeight),
      qualityLoaded: qualityLoaded ?? this.qualityLoaded,
    );
  }
}

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
    unawaited(loadQuality());
    return const ReelsState();
  }

  ReelsApi get _api => ref.read(reelsApiProvider);

  Future<void> loadQuality() async {
    final q = await ReelsQuality.current();
    state = state.copyWith(
      qualityMaxHeight: q,
      setQualityOriginal: q == null,
      qualityLoaded: true,
    );
  }

  Future<void> selectQuality(int? maxHeight) async {
    await ReelsQuality.remember(maxHeight);
    state = state.copyWith(
      qualityMaxHeight: maxHeight,
      setQualityOriginal: maxHeight == null,
      qualityLoaded: true,
    );
  }

  /* ---------------- 信息流 ---------------- */

  Future<void> loadFirstPage() async {
    if (!state.qualityLoaded) {
      await loadQuality();
    }
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
    unawaited(loadFacets());
  }

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
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  String _messageOf(Object e) =>
      e is ApiException ? e.friendlyMessage : e.toString();

  bool _isNotFound(Object e) {
    if (e is ApiException) return e.httpStatus == 404;
    final m = e.toString();
    return m.contains('404') ||
        m.toLowerCase().contains('not found') ||
        m.contains('找不到');
  }

  Future<void> loadFacets() async {
    try {
      final facets = await _api.facets(filter: state.filter);
      state = state.copyWith(facets: facets);
    } catch (_) {}
  }

  void applyFilter(ReelFilter filter) {
    state = state.copyWith(filter: filter, items: const [], loading: true);
    loadFirstPage();
  }

  void clearFilter() => applyFilter(const ReelFilter());

  /* ---------------- 真实访客分享链接 ---------------- */

  Future<ReelShareResult?> createGuestShareLink(ReelItemView item) async {
    final t = item.title;
    if (t.libraryId <= 0 || t.mediaItemId <= 0) return null;
    try {
      return await _api.createShareLink(
        libraryId: t.libraryId,
        mediaItemId: t.mediaItemId,
      );
    } catch (_) {
      return null;
    }
  }

  /* ---------------- 事件 ---------------- */

  void event(
    ReelItemView item,
    String kind, {
    int? positionMs,
    int? watchedMs,
    int? waitMs,
    Map<String, dynamic>? detail,
  }) {
    _pendingEvents.add(
      ReelEventView(
        reelId: item.id,
        kind: kind,
        mode: item.play.mode,
        mediaItemId: item.title.mediaItemId > 0 ? item.title.mediaItemId : null,
        fileId: item.segment.fileId > 0 ? item.segment.fileId : null,
        positionMs: positionMs,
        watchedMs: watchedMs,
        waitMs: waitMs,
        detail: detail,
      ),
    );
    if (_pendingEvents.length >= 10) {
      unawaited(flushEvents());
    }
  }

  Future<void> flushEvents() async {
    if (_pendingEvents.isEmpty) return;
    final batch = List<ReelEventView>.of(_pendingEvents);
    _pendingEvents.clear();
    try {
      await _api.reportEvents(batch);
    } catch (_) {}
  }

  /* ---------------- 收藏 / 已看 ---------------- */

  bool isFavorite(ReelItemView item) =>
      state.favorites[item.id] ?? item.title.favorite;

  bool isPlayed(ReelItemView item) =>
      state.playeds[item.id] ?? item.title.played;

  Future<void> toggleFavorite(ReelItemView item) async {
    final t = item.title;
    final next = !(state.favorites[item.id] ?? t.favorite);
    state = state.copyWith(favorites: {...state.favorites, item.id: next});
    try {
      await _api.setMarks(mediaItemId: t.mediaItemId, favorite: next);
    } catch (_) {
      state = state.copyWith(favorites: {...state.favorites, item.id: !next});
    }
  }

  Future<void> togglePlayed(ReelItemView item) async {
    final t = item.title;
    final next = !(state.playeds[item.id] ?? t.played);
    state = state.copyWith(playeds: {...state.playeds, item.id: next});
    final season = t.episode?.season;
    final episode = t.episode?.episode;
    try {
      await _api.setMarks(
        mediaItemId: t.mediaItemId,
        seasonNumber: (season == null || season <= 0) ? null : season,
        episodeNumber: (episode == null || episode <= 0) ? null : episode,
        played: next,
      );
    } catch (_) {
      state = state.copyWith(playeds: {...state.playeds, item.id: !next});
    }
  }
}

/// 顶栏筛选键摘要：没条件「全部」、单维写值（多选用「剧情等 2 个」）、多维写「已筛选 N 项」。
String filterLabel(ReelFilter filter, ReelFacetsView? facets) {
  if (filter.activeCount == 0) return '全部';

  String pickLabel(List<FacetValue> list, String value) {
    for (final e in list) {
      if (e.value == value) return e.label;
    }
    return value;
  }

  String summarizeSet(Set<String> values, List<FacetValue> list) {
    final sorted = values.toList()..sort();
    final first = pickLabel(list, sorted.first);
    return sorted.length == 1 ? first : '$first等 ${sorted.length} 项';
  }

  final labels = <String>[
    if (filter.kind != null)
      pickLabel(facets?.kinds ?? const [], filter.kind!),
    if (filter.watch != null) '没看过',
    if (filter.genres.isNotEmpty)
      summarizeSet(filter.genres, facets?.genres ?? const []),
    if (filter.countries.isNotEmpty)
      summarizeSet(filter.countries, facets?.countries ?? const []),
    if (filter.decades.isNotEmpty)
      summarizeSet(filter.decades, facets?.decades ?? const []),
    if (filter.ratingGte != null) '${filter.ratingGte} 分以上',
    if (filter.runtimes.isNotEmpty)
      summarizeSet(filter.runtimes, facets?.runtimes ?? const []),
  ];
  if (labels.length == 1) return labels.first;
  return '已筛选 ${labels.length} 项';
}

final reelsControllerProvider =
    NotifierProvider<ReelsController, ReelsState>(ReelsController.new);
