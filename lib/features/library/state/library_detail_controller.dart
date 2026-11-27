import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_api.dart';
import 'models.dart';

/// 单库海报墙的筛选条件（完整对齐 iOS `LibraryFilter`）：与服务端 /items /facets /relax /collections 一一对应。
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
    this.seriesKeys = const {},
    this.actor,
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
  final Set<String> seriesKeys;
  final String? actor;
  final String sort;
  final String? order;

  bool get hasActor => actor != null && actor!.trim().isNotEmpty;

  int get activeCount =>
      genres.length +
      countries.length +
      decades.length +
      watch.length +
      runtimes.length +
      languages.length +
      resolutions.length +
      stock.length +
      seriesKeys.length +
      (ratingGte != null ? 1 : 0) +
      (hdr != null ? 1 : 0) +
      (hasActor ? 1 : 0);

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
    Set<String>? seriesKeys,
    String? actor,
    bool clearActor = false,
    String? sort,
    String? order,
    bool clearOrder = false,
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
        seriesKeys: seriesKeys ?? this.seriesKeys,
        actor: clearActor ? null : (actor ?? this.actor),
        sort: sort ?? this.sort,
        order: clearOrder ? null : (order ?? this.order),
      );

  /// 转成 /items、/facets、/relax、/item-index 共用的查询参数。
  Map<String, String?> toQuery() => {
        if (genres.isNotEmpty) 'g': genres.join(','),
        if (countries.isNotEmpty) 'c': countries.join(','),
        if (decades.isNotEmpty) 'd': decades.join(','),
        if (watch.isNotEmpty) 'w': watch.join(','),
        if (ratingGte != null) 'rating_gte': ratingGte.toString(),
        if (runtimes.isNotEmpty) 'rt': runtimes.join(','),
        if (languages.isNotEmpty) 'lang': languages.join(','),
        if (resolutions.isNotEmpty) 'res': resolutions.join(','),
        if (hdr != null) 'hdr': hdr! ? '1' : '0',
        if (stock.isNotEmpty) 'stock': stock.join(','),
        if (seriesKeys.isNotEmpty) 'series_keys': seriesKeys.join(','),
        if (hasActor) 'actor': actor!.trim(),
        'sort': sort,
        if (order != null) 'order': order,
      };

  /// 转成合集创建接口 `POST /collections` 标准的 rules 列表。
  List<Map<String, dynamic>> toRules() => [
        if (genres.isNotEmpty)
          {
            'field': 'genres',
            'op': 'any_of',
            'values': genres.map(int.tryParse).whereType<int>().toList(),
          },
        if (countries.isNotEmpty)
          {
            'field': 'origin_countries',
            'op': 'any_of',
            'values': countries.toList(),
          },
        if (decades.isNotEmpty)
          {
            'field': 'decades',
            'op': 'any_of',
            'values': decades.toList(),
          },
        if (watch.isNotEmpty)
          {
            'field': 'watch',
            'op': 'any_of',
            'values': watch.toList(),
          },
        if (ratingGte != null)
          {
            'field': 'rating_gte',
            'op': 'any_of',
            'values': [ratingGte],
          },
        if (runtimes.isNotEmpty)
          {
            'field': 'runtimes',
            'op': 'any_of',
            'values': runtimes.toList(),
          },
        if (languages.isNotEmpty)
          {
            'field': 'languages',
            'op': 'any_of',
            'values': languages.toList(),
          },
        if (resolutions.isNotEmpty)
          {
            'field': 'resolutions',
            'op': 'any_of',
            'values': resolutions.toList(),
          },
        if (hdr != null)
          {
            'field': 'hdr',
            'op': 'any_of',
            'values': [hdr!],
          },
        if (stock.isNotEmpty)
          {
            'field': 'stock',
            'op': 'any_of',
            'values': stock.toList(),
          },
        if (seriesKeys.isNotEmpty)
          {
            'field': 'series_key',
            'op': 'any_of',
            'values': seriesKeys.toList(),
          },
      ];

  /// 根据 `/relax` 建议一键去掉某条条件。
  LibraryFilter withoutRelax(RelaxSuggestionView s) {
    final dim = s.dim;
    final val = s.value;
    switch (dim) {
      case 'g':
      case 'genres':
        return copyWith(genres: genres.where((e) => e != val).toSet());
      case 'c':
      case 'countries':
      case 'origin_countries':
        return copyWith(countries: countries.where((e) => e != val).toSet());
      case 'd':
      case 'decades':
        return copyWith(decades: decades.where((e) => e != val).toSet());
      case 'w':
      case 'watch':
        return copyWith(watch: watch.where((e) => e != val).toSet());
      case 'rating_gte':
      case 'rating':
        return copyWith(clearRating: true);
      case 'rt':
      case 'runtimes':
        return copyWith(runtimes: runtimes.where((e) => e != val).toSet());
      case 'lang':
      case 'languages':
        return copyWith(languages: languages.where((e) => e != val).toSet());
      case 'res':
      case 'resolutions':
        return copyWith(
          resolutions: resolutions.where((e) => e != val).toSet(),
        );
      case 'hdr':
        return copyWith(clearHdr: true);
      case 'stock':
        return copyWith(stock: stock.where((e) => e != val).toSet());
      case 'actor':
        return copyWith(clearActor: true);
      default:
        return cleared;
    }
  }

  /// 用于 WallRecall / 图床重载的稳定键。
  String get filterKey {
    final entries = toQuery().entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value ?? ''}').join('&');
  }

  factory LibraryFilter.fromQuery(Map<String, String> q) => LibraryFilter(
        genres: _set(q['g']),
        countries: _set(q['c']),
        decades: _set(q['d']),
        watch: _set(q['w']),
        ratingGte:
            q['rating_gte'] == null ? null : double.tryParse(q['rating_gte']!),
        runtimes: _set(q['rt']),
        languages: _set(q['lang']),
        resolutions: _set(q['res']),
        hdr: q['hdr'] == null
            ? null
            : (q['hdr'] == 'true' || q['hdr'] == '1'),
        stock: _set(q['stock']),
        seriesKeys: _set(q['series_keys']),
        actor: q['actor'],
        sort: q['sort'] ?? 'title',
        order: q['order'],
      );

  static Set<String> _set(String? v) =>
      v == null || v.isEmpty ? const {} : v.split(',').toSet();
}

/// 单库页完整状态。
class LibraryDetailState {
  const LibraryDetailState({
    this.loading = false,
    this.loadingMore = false,
    this.loadingPrevious = false,
    this.error,
    this.library,
    this.isAdmin = false,
    this.items = const [],
    this.provisionalItems = const [],
    this.collections = const [],
    this.showHiddenCollections = false,
    this.facets,
    this.relax,
    this.index = const [],
    this.metadataRefresh,
    this.filter = const LibraryFilter(),
    this.total = 0,
    this.baseOffset = 0,
    this.viewMode = 'items',
    this.endReached = false,
    this.photoRefreshToken = 0,
  });

  final bool loading;
  final bool loadingMore;
  final bool loadingPrevious;
  final String? error;
  final LibraryView? library;
  final bool isAdmin;
  final List<LibraryItemView> items;
  final List<LibraryItemView> provisionalItems;
  final List<CollectionView> collections;
  final bool showHiddenCollections;
  final LibraryFacets? facets;
  final LibraryRelaxView? relax;
  final List<LibraryIndexEntry> index;
  final MetadataRefresh? metadataRefresh;
  final LibraryFilter filter;
  final int total;
  final int baseOffset;
  final String viewMode; // items | collections
  final bool endReached;
  final int photoRefreshToken;

  int get pendingIssuesCount {
    final l = library;
    if (l == null) return 0;
    return l.missingCount + l.unidentifiedCount + l.reviewCount;
  }

  LibraryDetailState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? loadingPrevious,
    String? error,
    bool clearError = false,
    LibraryView? library,
    bool? isAdmin,
    List<LibraryItemView>? items,
    List<LibraryItemView>? provisionalItems,
    List<CollectionView>? collections,
    bool? showHiddenCollections,
    LibraryFacets? facets,
    LibraryRelaxView? relax,
    bool clearRelax = false,
    List<LibraryIndexEntry>? index,
    MetadataRefresh? metadataRefresh,
    bool clearMetadataRefresh = false,
    LibraryFilter? filter,
    int? total,
    int? baseOffset,
    String? viewMode,
    bool? endReached,
    int? photoRefreshToken,
  }) =>
      LibraryDetailState(
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        loadingPrevious: loadingPrevious ?? this.loadingPrevious,
        error: clearError ? null : (error ?? this.error),
        library: library ?? this.library,
        isAdmin: isAdmin ?? this.isAdmin,
        items: items ?? this.items,
        provisionalItems: provisionalItems ?? this.provisionalItems,
        collections: collections ?? this.collections,
        showHiddenCollections:
            showHiddenCollections ?? this.showHiddenCollections,
        facets: facets ?? this.facets,
        relax: clearRelax ? null : (relax ?? this.relax),
        index: index ?? this.index,
        metadataRefresh: clearMetadataRefresh
            ? null
            : (metadataRefresh ?? this.metadataRefresh),
        filter: filter ?? this.filter,
        total: total ?? this.total,
        baseOffset: baseOffset ?? this.baseOffset,
        viewMode: viewMode ?? this.viewMode,
        endReached: endReached ?? this.endReached,
        photoRefreshToken: photoRefreshToken ?? this.photoRefreshToken,
      );
}

class LibraryDetailArg {
  const LibraryDetailArg({
    required this.libraryId,
    this.initialQuery = const {},
  });

  final int libraryId;
  final Map<String, String> initialQuery;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryDetailArg &&
          other.libraryId == libraryId &&
          const MapEquality().equals(other.initialQuery, initialQuery));

  @override
  int get hashCode => Object.hash(
        libraryId,
        Object.hashAllUnordered(
          initialQuery.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

class MapEquality {
  const MapEquality();

  bool equals(Map<String, String> a, Map<String, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

class LibraryDetailController
    extends AutoDisposeFamilyNotifier<LibraryDetailState, LibraryDetailArg> {
  Timer? _refreshPoll;
  Timer? _libraryPoll;

  @override
  LibraryDetailState build(LibraryDetailArg arg) {
    final initView =
        arg.initialQuery['view'] == 'collections' ? 'collections' : 'items';
    final filter = LibraryFilter.fromQuery(arg.initialQuery);
    ref.onDispose(() {
      _refreshPoll?.cancel();
      _libraryPoll?.cancel();
    });
    Future.microtask(() => _start(arg.libraryId, filter));
    return LibraryDetailState(filter: filter, viewMode: initView);
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  LibraryFilter get currentFilter => state.filter;

  Future<void> _start(int libraryId, LibraryFilter filter) async {
    state = state.copyWith(loading: true, clearError: true, filter: filter);
    try {
      final results = await Future.wait([
        _api.libraryGet(libraryId).catchError((_) async {
          final libs = await _api.libraries(scope: 'all');
          return libs.firstWhere((l) => l.id == libraryId);
        }),
        _api.currentRole().catchError((_) => ''),
      ]);
      final library = results[0] as LibraryView;
      final role = results[1] as String;
      // 照片库默认按拍摄日期（release_date）排，避免标题排序破坏按月相册体验
      var effectiveFilter = filter;
      if (!library.capabilities.playable &&
          arg.initialQuery['sort'] == null &&
          filter.sort == 'title') {
        effectiveFilter = filter.copyWith(sort: 'release_date');
      }
      state = state.copyWith(
        loading: false,
        library: library,
        isAdmin: role == 'admin',
        filter: effectiveFilter,
        metadataRefresh: library.metadataRefresh,
      );
      _ensurePolls();
      if (library.viewerAccess) {
        await Future.wait([
          reload(),
          _probeRefreshProgress(),
        ]);
      }
    } catch (_) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  void _ensurePolls() {
    _libraryPoll?.cancel();
    _libraryPoll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final lib = state.library;
      if (lib == null) return;
      if (lib.scanning || lib.organizing || lib.activeJobsCount > 0) {
        await refreshLibraryMeta();
      }
    });
  }

  Future<void> _probeRefreshProgress() async {
    try {
      final progress = await _api.metadataRefreshProgress(arg.libraryId);
      state = state.copyWith(
        metadataRefresh: progress.refreshing ? progress : null,
        clearMetadataRefresh: !progress.refreshing,
      );
      if (progress.refreshing) {
        _startRefreshPolling();
      } else {
        _refreshPoll?.cancel();
      }
    } catch (_) {}
  }

  void _startRefreshPolling() {
    _refreshPoll?.cancel();
    _refreshPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final p = await _api.metadataRefreshProgress(arg.libraryId);
        if (!p.refreshing) {
          _refreshPoll?.cancel();
          state = state.copyWith(clearMetadataRefresh: true);
          await refreshLibraryMeta();
          await reload();
        } else {
          state = state.copyWith(metadataRefresh: p);
        }
      } catch (_) {}
    });
  }

  /// 仅刷新库头元数据（扫描/整理进度、缺失/待识别/复核计数等）。
  Future<void> refreshLibraryMeta() async {
    try {
      final lib = await _api.libraryGet(arg.libraryId);
      final wasBusy =
          state.library?.scanning == true || state.library?.organizing == true;
      state = state.copyWith(
        library: lib,
        photoRefreshToken: state.photoRefreshToken + 1,
      );
      if (wasBusy && !lib.scanning && !lib.organizing) {
        await reload();
      }
    } catch (_) {}
  }

  /// 重新拉墙 + 合集 + facets + 索引 + 临时身份 + 0结果放宽建议。
  Future<void> reload() async {
    final id = arg.libraryId;
    final q = state.filter.toQuery();
    final isPhoto = state.library != null && !state.library!.capabilities.playable;

    state = state.copyWith(
      loading: true,
      endReached: false,
      baseOffset: 0,
      clearError: true,
      clearRelax: true,
      photoRefreshToken: state.photoRefreshToken + 1,
    );

    if (!isPhoto) {
      try {
        final items = await _api.libraryItems(id, filterQuery: q);
        state = state.copyWith(
          loading: false,
          items: items,
          total: items.length,
          endReached: items.length < 60,
        );
      } catch (_) {
        state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
        return;
      }
    } else {
      state = state.copyWith(loading: false);
    }

    // 并行拉取合集、分面、索引、临时身份、放宽建议
    await Future.wait<void>([
      _api
          .collections(
            libraryId: id,
            includeHidden: state.showHiddenCollections,
          )
          .then<void>((cols) {
            state = state.copyWith(collections: cols);
          })
          .catchError((_) {}),
      _api
          .libraryFacets(id, allTiers: true, filterQuery: q)
          .then<void>((facets) {
            state = state.copyWith(
              facets: facets,
              total: facets.total > 0 ? facets.total : state.items.length,
            );
          })
          .catchError((_) {}),
      if (state.filter.sort == 'title')
        _api
            .libraryItemIndex(id, filterQuery: q)
            .then<void>((idx) {
              state = state.copyWith(index: idx);
            })
            .catchError((_) {})
      else
        Future<void>.sync(() {
          state = state.copyWith(index: const []);
        }),
      if (state.filter.isEmpty && !isPhoto)
        _api
            .libraryItemsProvisional(id)
            .then<void>((p) {
              state = state.copyWith(provisionalItems: p);
            })
            .catchError((_) {})
      else
        Future<void>.sync(() {
          state = state.copyWith(provisionalItems: const []);
        }),
      if (!isPhoto && state.items.isEmpty && !state.filter.isEmpty)
        _api
            .libraryRelax(id, q)
            .then<void>((r) {
              state = state.copyWith(relax: r);
            })
            .catchError((_) {}),
    ]);
  }

  /// 滚动加载下一页。
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || state.endReached) return;
    state = state.copyWith(loadingMore: true);
    try {
      final more = await _api.libraryItems(
        arg.libraryId,
        offset: state.baseOffset + state.items.length,
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

  /// A–Z 跳转或「回到上次位置」之后向上补加载前一页。
  Future<void> loadPrevious() async {
    if (state.baseOffset <= 0 || state.loadingPrevious || state.loading) return;
    state = state.copyWith(loadingPrevious: true);
    final prevOffset = (state.baseOffset - 60).clamp(0, state.baseOffset);
    final count = state.baseOffset - prevOffset;
    try {
      final prev = await _api.libraryItems(
        arg.libraryId,
        offset: prevOffset,
        limit: count,
        filterQuery: state.filter.toQuery(),
      );
      state = state.copyWith(
        loadingPrevious: false,
        baseOffset: prevOffset,
        items: [...prev, ...state.items],
      );
    } catch (_) {
      state = state.copyWith(loadingPrevious: false);
    }
  }

  /// A–Z 索引跳转或「回到上次位置」跳转。
  Future<int?> jumpToIndexOffset(int offset) async {
    final loadedEnd = state.baseOffset + state.items.length;
    if (offset >= state.baseOffset && offset < loadedEnd) {
      return offset - state.baseOffset;
    }
    state = state.copyWith(loading: true, endReached: false);
    try {
      final window = await _api.libraryItems(
        arg.libraryId,
        offset: offset,
        limit: 90,
        filterQuery: state.filter.toQuery(),
      );
      state = state.copyWith(
        loading: false,
        baseOffset: offset,
        items: window,
        endReached: window.length < 90,
      );
      return 0;
    } catch (_) {
      state = state.copyWith(loading: false);
      return null;
    }
  }

  /// 保存当前筛选为动态规则合集或定格快照合集（`snapshot: true`）。
  Future<CollectionView> saveAsCollection({
    required String name,
    required bool snapshot,
    required String visibility,
  }) async {
    final created = await _api.createCollection(
      name: name,
      libraryId: arg.libraryId,
      rules: state.filter.toRules(),
      sort: state.filter.sort,
      visibility: visibility,
      snapshot: snapshot,
    );
    final cols = await _api.collections(
      libraryId: arg.libraryId,
      includeHidden: state.showHiddenCollections,
    );
    state = state.copyWith(collections: cols);
    return created;
  }

  /// 管理动作
  Future<void> startScan() async {
    await _api.scanLibrary(arg.libraryId);
    await refreshLibraryMeta();
  }

  Future<void> stopScan() async {
    await _api.stopLibraryScan(arg.libraryId);
    await refreshLibraryMeta();
  }

  Future<void> startMetadataRefresh(String mode) async {
    await _api.libraryMetadataRefresh(arg.libraryId, mode: mode);
    await _probeRefreshProgress();
  }

  Future<void> stopMetadataRefresh() async {
    await _api.metadataRefreshStop(arg.libraryId);
    await _probeRefreshProgress();
  }

  Future<void> generateChapters({bool force = false}) async {
    await _api.generateChapterImages(arg.libraryId, force: force);
    await refreshLibraryMeta();
  }

  Future<void> toggleShowHiddenCollections() async {
    final next = !state.showHiddenCollections;
    state = state.copyWith(showHiddenCollections: next);
    try {
      final cols = await _api.collections(
        libraryId: arg.libraryId,
        includeHidden: next,
      );
      state = state.copyWith(collections: cols);
    } catch (_) {}
  }

  void applyFilter(LibraryFilter filter) {
    state = state.copyWith(filter: filter);
    reload();
  }

  void clearFilter() => applyFilter(state.filter.cleared);

  void applyRelax(RelaxSuggestionView s) =>
      applyFilter(state.filter.withoutRelax(s));

  void setSort(String sort, String? order) => applyFilter(
        state.filter.copyWith(
          sort: sort,
          order: order,
          clearOrder: order == null,
        ),
      );

  void setViewMode(String mode) => state = state.copyWith(viewMode: mode);
}

final libraryDetailProvider = NotifierProvider.autoDispose
    .family<LibraryDetailController, LibraryDetailState, LibraryDetailArg>(
  LibraryDetailController.new,
);
