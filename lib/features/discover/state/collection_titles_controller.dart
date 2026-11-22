// 发现榜单完整列表（对照 PARITY.md 第 8 行：薄 → 有；
// 安卓 DiscoverScreen 行右侧「查看完整榜单」，web 榜单统一走稳定
// collectionRef 路由，如 douban/movie_top250）。
//
// `GET /discover/collections/{collectionRef}/titles`（typed McApi，
// limit 24 + page 翻页）；isRanked 的榜单按服务端顺序显示名次。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/models.dart';

class CollectionTitlesState {
  const CollectionTitlesState({
    this.loading = true,
    this.error,
    this.collection,
    this.titles = const [],
    this.page = 1,
    this.totalPages = 1,
    this.totalResults = 0,
    this.loadingMore = false,
  });

  final bool loading;
  final String? error;
  final DiscoveryCollectionInfo? collection;
  final List<DiscoveredTitle> titles;
  final int page;
  final int totalPages;
  final int totalResults;
  final bool loadingMore;

  bool get hasMore => page < totalPages;

  CollectionTitlesState copyWith({
    bool? loading,
    Object? error = _sentinel,
    DiscoveryCollectionInfo? collection,
    List<DiscoveredTitle>? titles,
    int? page,
    int? totalPages,
    int? totalResults,
    bool? loadingMore,
  }) =>
      CollectionTitlesState(
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        collection: collection ?? this.collection,
        titles: titles ?? this.titles,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        totalResults: totalResults ?? this.totalResults,
        loadingMore: loadingMore ?? this.loadingMore,
      );

  static const _sentinel = Object();
}

class CollectionTitlesController
    extends FamilyNotifier<CollectionTitlesState, String> {
  McApi get _api => ref.read(mcApiProvider);

  @override
  CollectionTitlesState build(String collectionRef) {
    Future.microtask(load);
    return const CollectionTitlesState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _api.collectionTitles(
        collectionRef: arg,
        limit: 24,
        page: 1,
      );
      state = state.copyWith(
        loading: false,
        collection: result.collection,
        titles: result.titles,
        page: result.page,
        totalPages: result.totalPages,
        totalResults: result.totalResults,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await _api.collectionTitles(
        collectionRef: arg,
        limit: 24,
        page: state.page + 1,
      );
      state = state.copyWith(
        loadingMore: false,
        titles: [...state.titles, ...result.titles],
        page: result.page,
        totalPages: result.totalPages,
        totalResults: result.totalResults,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: '加载失败：$e');
    }
  }
}

final collectionTitlesProvider = NotifierProvider.family<
    CollectionTitlesController, CollectionTitlesState, String>(
  CollectionTitlesController.new,
);
