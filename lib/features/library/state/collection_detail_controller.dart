import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_rows.dart';
import 'mc_api.dart';
import 'models.dart';

/// 排序字段自然方向表（与单库 / 收藏 / 合集共用）。
class WallSortMeta {
  const WallSortMeta({
    required this.value,
    required this.label,
    required this.naturalAsc,
    required this.ascLabel,
    required this.descLabel,
  });

  final String value;
  final String label;
  final bool naturalAsc;
  final String ascLabel;
  final String descLabel;

  String? orderParam({required bool reversed}) {
    if (!reversed) return null;
    return naturalAsc ? 'desc' : 'asc';
  }

  String directionLabel({required bool reversed}) {
    final isAsc = reversed ? !naturalAsc : naturalAsc;
    return isAsc ? ascLabel : descLabel;
  }
}

const List<WallSortMeta> collectionSortMetas = [
  WallSortMeta(
    value: 'title',
    label: '名称',
    naturalAsc: true,
    ascLabel: 'A → Z',
    descLabel: 'Z → A',
  ),
  WallSortMeta(
    value: 'added_at',
    label: '最近添加',
    naturalAsc: false,
    ascLabel: '最早添加',
    descLabel: '最新添加',
  ),
  WallSortMeta(
    value: 'release_date',
    label: '上映日期',
    naturalAsc: false,
    ascLabel: '最早',
    descLabel: '最新',
  ),
  WallSortMeta(
    value: 'rating',
    label: '评分',
    naturalAsc: false,
    ascLabel: '从低到高',
    descLabel: '从高到低',
  ),
  WallSortMeta(
    value: 'runtime',
    label: '时长',
    naturalAsc: false,
    ascLabel: '从短到长',
    descLabel: '从长到短',
  ),
  WallSortMeta(
    value: 'size',
    label: '体积',
    naturalAsc: false,
    ascLabel: '从小到大',
    descLabel: '从大到小',
  ),
  WallSortMeta(
    value: 'last_played',
    label: '最近观看',
    naturalAsc: false,
    ascLabel: '最早观看',
    descLabel: '最近观看',
  ),
];

WallSortMeta wallSortMetaOf(String key) => collectionSortMetas.firstWhere(
      (e) => e.value == key,
      orElse: () => collectionSortMetas.first,
    );

/// 合集详情状态（完整对齐 iOS `CollectionDetailView`）。
class CollectionDetailState {
  const CollectionDetailState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.collection,
    this.series,
    this.facets,
    this.items = const [],
    this.sort = 'default',
    this.reversed = false,
    this.endReached = false,
    this.onHome = false,
    this.isAdmin = false,
    this.membersEpoch = 0,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;
  final CollectionView? collection;
  final CollectionSeriesView? series;
  final LibraryFacets? facets;
  final List<LibraryItemView> items;
  final String sort;
  final bool reversed;
  final bool endReached;
  final bool onHome;
  final bool isAdmin;
  final int membersEpoch;

  WallSortMeta get defaultSortMeta {
    final c = collection;
    if (c == null || !c.ruleDriven) {
      return const WallSortMeta(
        value: 'default',
        label: '自定顺序',
        naturalAsc: true,
        ascLabel: '正序',
        descLabel: '倒序',
      );
    }
    if (c.kind == 'series' || c.sort == 'release_date_asc') {
      return const WallSortMeta(
        value: 'default',
        label: '上映顺序',
        naturalAsc: true,
        ascLabel: '最早优先',
        descLabel: '最新优先',
      );
    }
    final m = wallSortMetaOf(c.sort);
    return WallSortMeta(
      value: 'default',
      label: m.label,
      naturalAsc: m.naturalAsc,
      ascLabel: m.ascLabel,
      descLabel: m.descLabel,
    );
  }

  ({String? sort, String? order}) get sortParams {
    if (sort == 'default') {
      return (
        sort: null,
        order: defaultSortMeta.orderParam(reversed: reversed),
      );
    }
    final meta = wallSortMetaOf(sort);
    return (sort: sort, order: meta.orderParam(reversed: reversed));
  }

  String get sortKey =>
      '${sort == 'default' ? '' : sort}${reversed ? ':rev' : ''}';

  CollectionDetailState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    CollectionView? collection,
    CollectionSeriesView? series,
    LibraryFacets? facets,
    List<LibraryItemView>? items,
    String? sort,
    bool? reversed,
    bool? endReached,
    bool? onHome,
    bool? isAdmin,
    int? membersEpoch,
  }) =>
      CollectionDetailState(
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        collection: collection ?? this.collection,
        series: series ?? this.series,
        facets: facets ?? this.facets,
        items: items ?? this.items,
        sort: sort ?? this.sort,
        reversed: reversed ?? this.reversed,
        endReached: endReached ?? this.endReached,
        onHome: onHome ?? this.onHome,
        isAdmin: isAdmin ?? this.isAdmin,
        membersEpoch: membersEpoch ?? this.membersEpoch,
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
  String get _sortStorageKey =>
      'movieclaw.collection.wall-sort:${arg.collectionId}';

  @override
  CollectionDetailState build(CollectionDetailArg arg) {
    Future.microtask(load);
    return const CollectionDetailState(loading: true);
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> _hydrateSavedSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sortStorageKey);
      if (raw == null || raw.isEmpty) return;
      final rev = raw.endsWith(':rev');
      final base = rev ? raw.substring(0, raw.length - 4) : raw;
      final allowed = {'default', ...collectionSortMetas.map((e) => e.value)};
      if (allowed.contains(base)) {
        state = state.copyWith(sort: base, reversed: rev);
      }
    } catch (_) {}
  }

  Future<void> _persistSort(String sort, bool reversed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sortStorageKey,
        reversed ? '$sort:rev' : sort,
      );
    } catch (_) {}
  }

  List<HomeRowPref> _parseSavedRows(Map<String, dynamic> prefsMap) {
    final home = prefsMap['home'];
    final rawRows =
        home is Map ? (home['rows'] as List<dynamic>? ?? const []) : const [];
    return rawRows
        .whereType<Map>()
        .map((m) => HomeRowPref.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    await _hydrateSavedSort();
    try {
      final results = await Future.wait([
        _api.collection(arg.collectionId),
        _api.currentRole().catchError((_) => ''),
        _api.uiPreferences().catchError((_) => <String, dynamic>{}),
      ]);
      final collection = results[0] as CollectionView;
      final role = results[1] as String;
      final prefsMap = results[2] as Map<String, dynamic>;
      final savedRows = _parseSavedRows(prefsMap);
      final homeRow = savedRows
          .where((r) => r.collectionId == arg.collectionId)
          .firstOrNull;
      final onHome = homeRow != null
          ? homeRow.hidden != true
          : collection.showOnHome;

      state = state.copyWith(
        collection: collection,
        isAdmin: role == 'admin',
        onHome: onHome,
      );

      // 并行拉取系列完整档（如为 series）、整库分面（用于规则展示/编辑）和首批条目
      final futures = <Future<void>>[reload()];
      if (collection.kind == 'series') {
        futures.add(
          _api.collectionSeries(arg.collectionId).then((s) {
            state = state.copyWith(series: s);
          }).catchError((_) {}),
        );
      }
      if (collection.libraryId != null &&
          (collection.ruleDriven || collection.rules.isNotEmpty)) {
        futures.add(
          _api.libraryFacets(collection.libraryId!, allTiers: true).then((f) {
            state = state.copyWith(facets: f);
          }).catchError((_) {}),
        );
      }
      await Future.wait(futures);
    } catch (_) {
      state = state.copyWith(loading: false, error: '合集不可用或加载失败，请下拉重试');
    }
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, endReached: false, clearError: true);
    try {
      final params = state.sortParams;
      final items = await _api.collectionItems(
        arg.collectionId,
        limit: 60,
        offset: 0,
        sort: params.sort,
        order: params.order,
      );
      state = state.copyWith(
        loading: false,
        items: items,
        endReached: items.length < 60,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || state.endReached) return;
    state = state.copyWith(loadingMore: true);
    try {
      final params = state.sortParams;
      final more = await _api.collectionItems(
        arg.collectionId,
        limit: 60,
        offset: state.items.length,
        sort: params.sort,
        order: params.order,
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

  Future<void> setSort(String sort, {bool? reversed}) async {
    final nextRev = reversed ?? false;
    state = state.copyWith(sort: sort, reversed: nextRev);
    await _persistSort(sort, nextRev);
    await reload();
  }

  Future<void> toggleDirection() async {
    final nextRev = !state.reversed;
    state = state.copyWith(reversed: nextRev);
    await _persistSort(state.sort, nextRev);
    await reload();
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

  Future<void> setHidden(bool hidden) async {
    final updated = await _api.updateCollection(
      arg.collectionId,
      hidden: hidden,
    );
    state = state.copyWith(collection: updated);
  }

  Future<void> toggleOnHome() async {
    final c = state.collection;
    if (c == null) return;
    final wasOnHome = state.onHome;
    final prefsMap = await _api.uiPreferences();
    final saved = _parseSavedRows(prefsMap);
    final existingIdx = saved.indexWhere((r) => r.collectionId == c.id);
    List<HomeRowPref> next;
    if (existingIdx >= 0) {
      next = [
        for (var i = 0; i < saved.length; i++)
          i == existingIdx
              ? saved[i].copyWith(
                  hidden: wasOnHome ? true : null,
                  clearHidden: !wasOnHome,
                )
              : saved[i],
      ];
    } else {
      final libs = await _api.libraries(scope: 'all');
      final cols = await _api.collections(includeEmpty: true);
      final built = HomeRows.build(saved, libs, cols);
      next = HomeRows.toPrefs([...built, HomeRows.newCollectionRow(c)]);
    }
    await _api.updateUiPreferences({
      'home': {'rows': next.map((e) => e.toJson()).toList()},
    });
    state = state.copyWith(onHome: !wasOnHome);
  }

  Future<void> updateRules(List<Map<String, dynamic>> rules) async {
    final updated = await _api.updateCollectionRules(
      arg.collectionId,
      {'rules': rules},
    );
    state = state.copyWith(
      collection: updated,
      membersEpoch: state.membersEpoch + 1,
    );
    await reload();
  }

  Future<List<LibraryItemView>> fetchOrderingList() async {
    if (state.sort == 'default' && !state.reversed && state.items.isNotEmpty) {
      return state.items;
    }
    return _api.collectionItems(arg.collectionId, limit: 200, offset: 0);
  }

  Future<void> reorderItems(List<int> mediaItemIds) async {
    final updated = await _api.updateCollectionOrder(
      arg.collectionId,
      mediaItemIds,
    );
    state = state.copyWith(
      collection: updated,
      membersEpoch: state.membersEpoch + 1,
    );
    await reload();
  }

  Future<void> removeItem(int mediaItemId) async {
    await _api.removeCollectionItem(arg.collectionId, mediaItemId);
    final nextItems =
        state.items.where((i) => i.mediaItemId != mediaItemId).toList();
    state = state.copyWith(
      items: nextItems,
      membersEpoch: state.membersEpoch + 1,
    );
    try {
      final refreshed = await _api.collection(arg.collectionId);
      state = state.copyWith(collection: refreshed);
    } catch (_) {}
  }

  Future<void> deleteSelf() => _api.deleteCollection(arg.collectionId);
}

final collectionDetailProvider = NotifierProvider.autoDispose.family<
    CollectionDetailController,
    CollectionDetailState,
    CollectionDetailArg>(CollectionDetailController.new);

/* ────────────────────── 全部合集入口页状态 ────────────────────── */

/// 全部合集筛选与列表状态（支持类型 series/rule/manual、按库筛选、显示已隐藏合集）。
class CollectionsState {
  const CollectionsState({
    this.loading = false,
    this.collections = const [],
    this.libraries = const [],
    this.typeFilter = 'all', // all | series | rule | manual
    this.libraryFilter, // null=全部, -1=跨库, >0=指定库ID
    this.includeHidden = false,
    this.error,
  });

  final bool loading;
  final List<CollectionView> collections;
  final List<LibraryView> libraries;
  final String typeFilter;
  final int? libraryFilter;
  final bool includeHidden;
  final String? error;

  static bool matchesType(CollectionView c, String type) => switch (type) {
        'series' => c.kind == 'series',
        'rule' => c.kind != 'series' && c.ruleDriven,
        'manual' => c.kind != 'series' && !c.ruleDriven,
        _ => true,
      };

  static bool matchesLibrary(CollectionView c, int? libFilter) {
    if (libFilter == null) return true;
    if (libFilter == -1) return c.libraryId == null;
    return c.libraryId == libFilter;
  }

  List<CollectionView> get filtered => collections
      .where(
        (c) =>
            matchesType(c, typeFilter) && matchesLibrary(c, libraryFilter),
      )
      .toList();

  int countForType(String type) => collections
      .where((c) => matchesLibrary(c, libraryFilter) && matchesType(c, type))
      .length;

  int countForLibrary(int? libFilter) => collections
      .where((c) => matchesType(c, typeFilter) && matchesLibrary(c, libFilter))
      .length;

  CollectionsState copyWith({
    bool? loading,
    List<CollectionView>? collections,
    List<LibraryView>? libraries,
    String? typeFilter,
    int? libraryFilter,
    bool clearLibraryFilter = false,
    bool? includeHidden,
    String? error,
    bool clearError = false,
  }) =>
      CollectionsState(
        loading: loading ?? this.loading,
        collections: collections ?? this.collections,
        libraries: libraries ?? this.libraries,
        typeFilter: typeFilter ?? this.typeFilter,
        libraryFilter:
            clearLibraryFilter ? null : (libraryFilter ?? this.libraryFilter),
        includeHidden: includeHidden ?? this.includeHidden,
        error: clearError ? null : (error ?? this.error),
      );
}

class CollectionsController extends Notifier<CollectionsState> {
  @override
  CollectionsState build() => const CollectionsState();

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _api.collections(
          includeEmpty: true,
          includeHidden: state.includeHidden,
        ),
        _api.libraries(scope: 'all').catchError((_) => <LibraryView>[]),
      ]);
      state = state.copyWith(
        loading: false,
        collections: results[0] as List<CollectionView>,
        libraries: results[1] as List<LibraryView>,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  void setTypeFilter(String type) => state = state.copyWith(typeFilter: type);

  void setLibraryFilter(int? libId) => state = state.copyWith(
        libraryFilter: libId,
        clearLibraryFilter: libId == null,
      );

  Future<void> toggleIncludeHidden() async {
    state = state.copyWith(includeHidden: !state.includeHidden);
    await load();
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
