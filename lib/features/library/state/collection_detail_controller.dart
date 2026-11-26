import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_api.dart';
import 'models.dart';

/// 合集详情状态（支持排序、重命名、可见性切换、移除条目与删除合集）。
class CollectionDetailState {
  const CollectionDetailState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.collection,
    this.items = const [],
    this.sort = 'added_at',
    this.order,
    this.endReached = false,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;
  final CollectionView? collection;
  final List<LibraryItemView> items;
  final String sort;
  final String? order;
  final bool endReached;

  CollectionDetailState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    CollectionView? collection,
    List<LibraryItemView>? items,
    String? sort,
    String? order,
    bool clearOrder = false,
    bool? endReached,
  }) =>
      CollectionDetailState(
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
        collection: collection ?? this.collection,
        items: items ?? this.items,
        sort: sort ?? this.sort,
        order: clearOrder ? null : (order ?? this.order),
        endReached: endReached ?? this.endReached,
      );
}

class CollectionDetailArg {
  const CollectionDetailArg({required this.collectionId});

  final int collectionId;

  @override
  bool operator ==(Object other) =>
      other is CollectionDetailArg && other.collectionId == collectionId;

  @override
  int get hashCode => collectionId;
}

class CollectionDetailController extends AutoDisposeFamilyNotifier<
    CollectionDetailState, CollectionDetailArg> {
  @override
  CollectionDetailState build(CollectionDetailArg arg) {
    Future.microtask(() => load());
    return const CollectionDetailState();
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final collection = await _api.collection(arg.collectionId);
      final sort = state.sort == 'added_at' ? collection.sort : state.sort;
      state = state.copyWith(
        loading: false,
        collection: collection,
        sort: sort,
      );
      await reload();
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, endReached: false);
    try {
      final items = await _api.collectionItems(
        arg.collectionId,
        sort: state.sort,
        order: state.order,
      );
      state = state.copyWith(
        loading: false,
        items: items,
        endReached: items.length < 60,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || state.endReached) return;
    state = state.copyWith(loadingMore: true);
    try {
      final more = await _api.collectionItems(
        arg.collectionId,
        offset: state.items.length,
        sort: state.sort,
        order: state.order,
      );
      state = state.copyWith(
        loadingMore: false,
        items: [...state.items, ...more],
        endReached: more.length < 60,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  void setSort(String sort) {
    state = state.copyWith(sort: sort, clearOrder: true);
    reload();
  }

  Future<void> rename(String newName) async {
    final updated = await _api.updateCollection(
      arg.collectionId,
      name: newName,
    );
    state = state.copyWith(collection: updated);
  }

  Future<void> toggleVisibility() async {
    final cur = state.collection?.visibility ?? 'household';
    final next = cur == 'private' ? 'household' : 'private';
    final updated = await _api.updateCollection(
      arg.collectionId,
      visibility: next,
    );
    state = state.copyWith(collection: updated);
  }

  Future<void> removeItem(int mediaItemId) async {
    await _api.removeCollectionItem(arg.collectionId, mediaItemId);
    state = state.copyWith(
      items: state.items.where((i) => i.mediaItemId != mediaItemId).toList(),
    );
  }

  Future<void> deleteSelf() => _api.deleteCollection(arg.collectionId);
}

final collectionDetailProvider = NotifierProvider.autoDispose.family<
    CollectionDetailController,
    CollectionDetailState,
    CollectionDetailArg>(CollectionDetailController.new);

/// 「合集」入口页状态：合集清单 + 新建 / 重命名 / 删除。
class CollectionsState {
  const CollectionsState({
    this.loading = false,
    this.collections = const [],
    this.error,
  });

  final bool loading;
  final List<CollectionView> collections;
  final String? error;

  CollectionsState copyWith({
    bool? loading,
    List<CollectionView>? collections,
    String? error,
  }) =>
      CollectionsState(
        loading: loading ?? this.loading,
        collections: collections ?? this.collections,
        error: error,
      );
}

class CollectionsController extends Notifier<CollectionsState> {
  @override
  CollectionsState build() => const CollectionsState();

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final collections = await _api.collections(includeEmpty: true);
      state = state.copyWith(loading: false, collections: collections);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  Future<CollectionView> create({
    required String name,
    String visibility = 'household',
  }) async {
    final c = await _api.createCollection(name: name, visibility: visibility);
    await load();
    return c;
  }

  Future<void> delete(int id) async {
    await _api.deleteCollection(id);
    await load();
  }
}

final collectionsProvider =
    NotifierProvider<CollectionsController, CollectionsState>(
      CollectionsController.new,
    );
