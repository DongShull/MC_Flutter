import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_api.dart';
import 'models.dart';

/// 单库海报墙的筛选条件（对齐 Kotlin LibraryFilter）：与服务端 /items 查询参数一一对应。
class LibraryFilter {
  const LibraryFilter({
    this.genres = const {},
    this.countries = const {},
    this.decades = const {},
    this.watch = const {},
    this.ratingGte,
    this.runtimes = const {},
    this.languages = const {},
    this.resolutions = const {},
    this.hdr,
    this.stock = const {},
    this.sort = 'title',
    this.order,
  });

  final Set<String> genres;
  final Set<String> countries;
  final Set<String> decades;
  final Set<String> watch;
  final double? ratingGte;
  final Set<String> runtimes;
  final Set<String> languages;
  final Set<String> resolutions;

  /// null = 不限；true = 只看 HDR；false = 只看 SDR。
  final bool? hdr;
  final Set<String> stock;
  final String sort;
  final String? order;

  int get activeCount =>
      genres.length +
      countries.length +
      decades.length +
      watch.length +
      runtimes.length +
      languages.length +
      resolutions.length +
      stock.length +
      (ratingGte != null ? 1 : 0) +
      (hdr != null ? 1 : 0);

  bool get isEmpty => activeCount == 0;

  LibraryFilter get cleared => LibraryFilter(sort: sort, order: order);

  LibraryFilter copyWith({
    Set<String>? genres,
    Set<String>? countries,
    Set<String>? decades,
    Set<String>? watch,
    double? ratingGte,
    bool clearRating = false,
    Set<String>? runtimes,
    Set<String>? languages,
    Set<String>? resolutions,
    bool? hdr,
    bool clearHdr = false,
    Set<String>? stock,
    String? sort,
    String? order,
  }) =>
      LibraryFilter(
        genres: genres ?? this.genres,
        countries: countries ?? this.countries,
        decades: decades ?? this.decades,
        watch: watch ?? this.watch,
        ratingGte: clearRating ? null : (ratingGte ?? this.ratingGte),
        runtimes: runtimes ?? this.runtimes,
        languages: languages ?? this.languages,
        resolutions: resolutions ?? this.resolutions,
        hdr: clearHdr ? null : (hdr ?? this.hdr),
        stock: stock ?? this.stock,
        sort: sort ?? this.sort,
        order: order ?? this.order,
      );

  /// 转成 /items、/facets、/item-index 共用的查询参数。
  Map<String, String?> toQuery() => {
        if (genres.isNotEmpty) 'g': genres.join(','),
        if (countries.isNotEmpty) 'c': countries.join(','),
        if (decades.isNotEmpty) 'd': decades.join(','),
        if (watch.isNotEmpty) 'w': watch.join(','),
        if (ratingGte != null) 'rating_gte': ratingGte.toString(),
        if (runtimes.isNotEmpty) 'rt': runtimes.join(','),
        if (languages.isNotEmpty) 'lang': languages.join(','),
        if (resolutions.isNotEmpty) 'res': resolutions.join(','),
        if (hdr != null) 'hdr': hdr.toString(),
        if (stock.isNotEmpty) 'stock': stock.join(','),
        'sort': sort,
        if (order != null) 'order': order,
      };

  /// 从 URL 查询串还原（URL 即状态的唯一事实源）。
  factory LibraryFilter.fromQuery(Map<String, String> q) => LibraryFilter(
        genres: _set(q['g']),
        countries: _set(q['c']),
        decades: _set(q['d']),
        watch: _set(q['w']),
        ratingGte: q['rating_gte'] == null ? null : double.tryParse(q['rating_gte']!),
        runtimes: _set(q['rt']),
        languages: _set(q['lang']),
        resolutions: _set(q['res']),
        hdr: q['hdr'] == null ? null : q['hdr'] == 'true',
        stock: _set(q['stock']),
        sort: q['sort'] ?? 'title',
        order: q['order'],
      );

  static Set<String> _set(String? v) =>
      v == null || v.isEmpty ? const {} : v.split(',').toSet();
}

/// 单库页状态（对齐 Kotlin LibraryDetailScreen.kt 的 ViewModel）。
class LibraryDetailState {
  const LibraryDetailState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.library,
    this.items = const [],
    this.facets,
    this.index = const [],
    this.filter = const LibraryFilter(),
    this.total = 0,
    this.viewMode = 'items',
    this.endReached = false,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;
  final LibraryView? library;
  final List<LibraryItemView> items;
  final LibraryFacets? facets;
  final List<LibraryIndexEntry> index;
  final LibraryFilter filter;
  final int total;

  /// items / collections 分段开关（集合视图在本页「⋯」之外的分段里）。
  final String viewMode;
  final bool endReached;

  LibraryDetailState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    LibraryView? library,
    List<LibraryItemView>? items,
    LibraryFacets? facets,
    List<LibraryIndexEntry>? index,
    LibraryFilter? filter,
    int? total,
    String? viewMode,
    bool? endReached,
  }) =>
      LibraryDetailState(
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
        library: library ?? this.library,
        items: items ?? this.items,
        facets: facets ?? this.facets,
        index: index ?? this.index,
        filter: filter ?? this.filter,
        total: total ?? this.total,
        viewMode: viewMode ?? this.viewMode,
        endReached: endReached ?? this.endReached,
      );
}

/// family 参数：库 id + 初始筛选（从 URL 查询串还原）。
class LibraryDetailArg {
  const LibraryDetailArg({required this.libraryId, this.initialQuery = const {}});

  final int libraryId;
  final Map<String, String> initialQuery;

  @override
  bool operator ==(Object other) =>
      other is LibraryDetailArg &&
      other.libraryId == libraryId &&
      const MapEquality().equals(other.initialQuery, initialQuery);

  @override
  int get hashCode => Object.hash(libraryId, Object.hashAllUnordered(initialQuery.entries));
}

class MapEquality {
  const MapEquality();

  bool equals(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

class LibraryDetailController extends AutoDisposeFamilyNotifier<LibraryDetailState, LibraryDetailArg> {
  @override
  LibraryDetailState build(LibraryDetailArg arg) {
    final filter = LibraryFilter.fromQuery(arg.initialQuery);
    Future.microtask(() => _start(arg.libraryId, filter));
    return LibraryDetailState(filter: filter);
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  /// 页面读取当前筛选（避免直接碰受保护的 state）。
  LibraryFilter get currentFilter => state.filter;

  Future<void> _start(int libraryId, LibraryFilter filter) async {
    state = state.copyWith(loading: true, error: null, filter: filter);
    try {
      final libs = await _api.libraries();
      final library = libs.where((l) => l.id == libraryId).firstOrNull;
      state = state.copyWith(loading: false, library: library);
      await reload();
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  /// 重新拉墙 + facets + 索引（筛选 / 排序变化后）。
  Future<void> reload() async {
    final id = arg.libraryId;
    final q = state.filter.toQuery();
    state = state.copyWith(loading: true, endReached: false);
    try {
      final items = await _api.libraryItems(id, filterQuery: q);
      state = state.copyWith(
        loading: false,
        items: items,
        total: items.length,
        endReached: items.length < 60,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
      return;
    }
    // facets 与索引失败不影响主墙。
    try {
      state = state.copyWith(facets: await _api.libraryFacets(id, filterQuery: q));
    } catch (_) {}
    if (state.filter.sort == 'title') {
      try {
        state = state.copyWith(index: await _api.libraryItemIndex(id, filterQuery: q));
      } catch (_) {}
    } else {
      state = state.copyWith(index: const []);
    }
  }

  /// 滚动加载下一页（offset 分页）。
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || state.endReached) return;
    state = state.copyWith(loadingMore: true);
    try {
      final more = await _api.libraryItems(
        arg.libraryId,
        offset: state.items.length,
        filterQuery: state.filter.toQuery(),
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

  /// 筛选即时生效（铁律：点一下就变）。sort / order 持久化在本地偏好，筛选不落本地。
  void applyFilter(LibraryFilter filter) {
    state = state.copyWith(filter: filter);
    reload();
  }

  void clearFilter() => applyFilter(state.filter.cleared);

  void setSort(String sort, String? order) =>
      applyFilter(state.filter.copyWith(sort: sort, order: order));

  void setViewMode(String mode) => state = state.copyWith(viewMode: mode);
}

final libraryDetailProvider = NotifierProvider.autoDispose
    .family<LibraryDetailController, LibraryDetailState, LibraryDetailArg>(
        LibraryDetailController.new);
