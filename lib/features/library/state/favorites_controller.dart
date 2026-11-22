// 收藏夹（对照 PARITY.md 第 14 行：此前无独立路由，仅模型/页面内提及）。
//
// 独立入口：`GET /playback/favorites`（typed McApi，分 offset 分页），
// 点条目进详情（`/detail/{libraryId}/{mediaItemId}`）。
// 收藏/取消收藏的操作仍在详情页（PlaybackMarks），本页只做独立浏览入口。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/models.dart';

class FavoritesState {
  const FavoritesState({
    this.loading = true,
    this.error,
    this.items = const [],
    this.total = 0,
    this.loadingMore = false,
  });

  final bool loading;
  final String? error;
  final List<FavoriteItemView> items;
  final int total;
  final bool loadingMore;

  bool get hasMore => items.length < total;

  FavoritesState copyWith({
    bool? loading,
    Object? error = _sentinel,
    List<FavoriteItemView>? items,
    int? total,
    bool? loadingMore,
  }) =>
      FavoritesState(
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        items: items ?? this.items,
        total: total ?? this.total,
        loadingMore: loadingMore ?? this.loadingMore,
      );

  static const _sentinel = Object();
}

class FavoritesController extends Notifier<FavoritesState> {
  static const _pageSize = 24;

  McApi get _api => ref.read(mcApiProvider);

  @override
  FavoritesState build() {
    Future.microtask(load);
    return const FavoritesState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _api.favorites(limit: _pageSize, offset: 0);
      state = state.copyWith(
        loading: false,
        items: page.items,
        total: page.total,
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
      final page = await _api.favorites(
        limit: _pageSize,
        offset: state.items.length,
      );
      state = state.copyWith(
        loadingMore: false,
        items: [...state.items, ...page.items],
        total: page.total,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: '加载失败：$e');
    }
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, FavoritesState>(
  FavoritesController.new,
);
