import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/notify/debounce_guard.dart';
import '../../../core/session/permissions.dart';
import '../../../core/storage/page_snapshots.dart';
import '../widgets/discovery_filter.dart';

/// 院线地区列表（对齐 iOS `DiscoverRegions.all`）。
const discoverRegions = <MapEntry<String, String>>[
  MapEntry('CN', '中国大陆'),
  MapEntry('HK', '中国香港'),
  MapEntry('TW', '中国台湾'),
  MapEntry('US', '美国'),
  MapEntry('JP', '日本'),
  MapEntry('KR', '韩国'),
  MapEntry('GB', '英国'),
];

String discoverRegionName(String code) => discoverRegions
    .firstWhere((e) => e.key == code, orElse: () => MapEntry(code, code))
    .value;

/// 将 TMDB w1280 剧照升级为 original 高清原图（经代理按需缩放，对齐 iOS `DiscoverHeroImage.fullResolution`）。
String? upgradeTmdbBackdropUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return raw.replaceFirst(
    'image.tmdb.org/t/p/w1280/',
    'image.tmdb.org/t/p/original/',
  );
}

/// 解析 title_ref（`tmdb:movie:550` / `douban:1292052` / `douban:tv:123`）。
({String source, String? mediaType, String externalId}) parseTitleRef(
  String raw,
) {
  final parts = raw.split(':');
  if (parts.isNotEmpty && parts.first == 'douban') {
    return (
      source: 'douban',
      mediaType: parts.length >= 3 ? parts[1] : null,
      externalId: parts.isNotEmpty ? parts.last : '',
    );
  }
  return (
    source: parts.isNotEmpty ? parts.first : 'tmdb',
    mediaType: parts.length >= 3 ? parts[1] : null,
    externalId: parts.isNotEmpty ? parts.last : '',
  );
}

/// 发现页错误态模型（对齐 iOS `DiscoverFeed.Failure`）。
class DiscoverFailure {
  const DiscoverFailure({
    required this.message,
    this.unreachable = false,
    this.hint,
  });

  final String message;
  final bool unreachable;
  final String? hint;

  DiscoverFailure copyWith({String? message, bool? unreachable, String? hint}) =>
      DiscoverFailure(
        message: message ?? this.message,
        unreachable: unreachable ?? this.unreachable,
        hint: hint ?? this.hint,
      );
}

/// 发现页板块里的一条（服务端编排的分区，presentation == 'hero' 的是英雄轮播）。
class DiscoverRowData {
  const DiscoverRowData({
    required this.collectionRef,
    required this.title,
    this.presentation = '',
    this.previewLimit = 12,
    this.supportsFullListing = true,
    required this.titles,
  });

  final String collectionRef;
  final String title;
  final String presentation;
  final int previewLimit;
  final bool supportsFullListing;
  final List<DiscTitle> titles;

  Map<String, dynamic> toJson() => {
        'collection_ref': collectionRef,
        'title': title,
        'presentation': presentation,
        'preview_limit': previewLimit,
        'supports_full_listing': supportsFullListing,
        'titles': [for (final t in titles) t.toJson()],
      };

  static DiscoverRowData? fromJson(Map<String, dynamic> o) {
    final ref = (o['collection_ref'] ?? '').toString();
    if (ref.isEmpty) return null;
    final titles = <DiscTitle>[];
    for (final el in (o['titles'] as List<dynamic>? ?? const [])) {
      if (el is Map) {
        final t = DiscTitle.fromJson(Map<String, dynamic>.from(el));
        if (t != null) titles.add(t);
      }
    }
    if (titles.isEmpty) return null;
    return DiscoverRowData(
      collectionRef: ref,
      title: (o['title'] ?? '').toString(),
      presentation: (o['presentation'] ?? '').toString(),
      previewLimit: (o['preview_limit'] as num?)?.toInt() ?? 12,
      supportsFullListing: o['supports_full_listing'] != false,
      titles: titles,
    );
  }
}

/// 发现模块影视条目卡片模型（对齐 iOS `DiscoverPosterItem` + `DiscoveredTitleView`）。
class DiscTitle {
  const DiscTitle({
    required this.ref,
    required this.title,
    this.originalTitle = '',
    this.provider = 'tmdb',
    this.externalId = '',
    this.mediaType,
    this.year,
    this.rating,
    this.posterUrl,
    this.backdropUrl,
    this.extentLabel = '',
    this.overview = '',
    this.genres = const [],
    this.owned = false,
    this.libraryId,
    this.mediaItemId,
  });

  final String ref;
  final String title;
  final String originalTitle;
  final String provider;
  final String externalId;
  final String? mediaType;
  final int? year;
  final double? rating;
  final String? posterUrl;
  final String? backdropUrl;
  final String extentLabel;
  final String overview;
  final List<String> genres;
  final bool owned;
  final int? libraryId;
  final int? mediaItemId;

  /// Hero 横图地址：优先 `backdropUrl` 并升级 TMDB `w1280` -> `original`；无剧照（如豆瓣）才回退 `posterUrl`。
  String? get heroImageUrl {
    final bd = backdropUrl;
    if (bd != null && bd.isNotEmpty) {
      return upgradeTmdbBackdropUrl(bd);
    }
    return (posterUrl != null && posterUrl!.isNotEmpty) ? posterUrl : null;
  }

  Map<String, dynamic> toJson() => {
        'title_ref': ref,
        'title': title,
        'original_title': originalTitle,
        'provider': provider,
        'external_id': externalId,
        if (mediaType != null) 'media_type': mediaType,
        if (year != null) 'release_year': year,
        if (rating != null) 'provider_rating': rating,
        if (posterUrl != null) 'poster_url': posterUrl,
        if (backdropUrl != null) 'backdrop_url': backdropUrl,
        'extent_label': extentLabel,
        'overview': overview,
        'genres': genres,
        if (owned)
          'library_status': {
            'file_count': 1,
            if (libraryId != null) 'library_id': libraryId,
            if (mediaItemId != null) 'media_item_id': mediaItemId,
          },
      };

  static DiscTitle? fromJson(Map<String, dynamic> o) {
    var ref = (o['title_ref'] ?? o['ref'] ?? '').toString();
    final prov = (o['provider'] ?? o['source'] ?? '').toString();
    final extId = (o['external_id'] ?? '').toString();
    final mType = (o['media_type'] ?? o['kind'])?.toString();
    if (ref.isEmpty && extId.isNotEmpty) {
      final p = prov.isNotEmpty ? prov : 'tmdb';
      ref = p == 'douban'
          ? 'douban:$extId'
          : '$p:${mType ?? 'movie'}:$extId';
    }
    if (ref.isEmpty) return null;
    final parsedRef = parseTitleRef(ref);
    final lib = o['library_status'];
    final libMap = lib is Map ? Map<String, dynamic>.from(lib) : null;
    final backdropRaw = o['backdrop_url']?.toString();
    final posterRaw = o['poster_url']?.toString();
    return DiscTitle(
      ref: ref,
      title: (o['title'] ?? '').toString(),
      originalTitle: (o['original_title'] ?? '').toString(),
      provider: prov.isNotEmpty ? prov : parsedRef.source,
      externalId: extId.isNotEmpty ? extId : parsedRef.externalId,
      mediaType: (mType != null && mType.isNotEmpty)
          ? mType
          : parsedRef.mediaType,
      year: (o['release_year'] as num?)?.toInt() ?? (o['year'] as num?)?.toInt(),
      rating: (o['provider_rating'] as num?)?.toDouble() ??
          (o['rating'] as num?)?.toDouble(),
      posterUrl: (posterRaw != null && posterRaw.isNotEmpty) ? posterRaw : null,
      backdropUrl:
          (backdropRaw != null && backdropRaw.isNotEmpty) ? backdropRaw : null,
      extentLabel: (o['extent_label'] ?? '').toString(),
      overview: (o['overview'] ?? '').toString(),
      genres: [
        for (final g in (o['genres'] as List<dynamic>? ?? const [])) g.toString(),
      ],
      owned: libMap != null &&
          (((libMap['file_count'] as num? ?? 0).toInt() > 0) ||
              (libMap['library_count'] as num? ?? 0).toInt() > 0),
      libraryId: (libMap?['library_id'] as num?)?.toInt(),
      mediaItemId: (libMap?['media_item_id'] as num?)?.toInt() ??
          (libMap?['item_id'] as num?)?.toInt(),
    );
  }
}

/// 单个视角（movie/tv × tmdb/douban）的缓存数据。
class _DiscoverViewCache {
  _DiscoverViewCache({
    this.rows = const [],
    this.loadedFromNetwork = false,
    this.failure,
  });

  List<DiscoverRowData> rows;
  bool loadedFromNetwork;
  DiscoverFailure? failure;
}

/// 院线地区设置视图（`GET/PUT /api/v1/discover/region`）。
class DiscoverRegionState {
  const DiscoverRegionState({
    this.region,
    this.canEdit = false,
    this.saving = false,
    this.justSaved = false,
  });

  final String? region;
  final bool canEdit;
  final bool saving;
  final bool justSaved;

  DiscoverRegionState copyWith({
    String? region,
    bool? canEdit,
    bool? saving,
    bool? justSaved,
  }) =>
      DiscoverRegionState(
        region: region ?? this.region,
        canEdit: canEdit ?? this.canEdit,
        saving: saving ?? this.saving,
        justSaved: justSaved ?? this.justSaved,
      );
}

/// 发现页状态。
class DiscoverState {
  const DiscoverState({
    this.loading = true,
    this.refreshing = false,
    this.failure,
    this.mediaType = 'movie',
    this.source = 'tmdb',
    this.rows = const [],
    this.genres = const [],
    this.filters = const DiscoveryFilter(),
    this.filtered = const [],
    this.filteredLoading = false,
    this.filteredError,
    this.filteredPage = 1,
    this.filteredTotalPages = 1,
    this.filteredTotal = 0,
    this.region = const DiscoverRegionState(),
  });

  final bool loading;
  final bool refreshing;
  final DiscoverFailure? failure;
  final String mediaType;
  final String source;
  final List<DiscoverRowData> rows;
  final List<DiscoveryGenre> genres;
  final DiscoveryFilter filters;
  final List<DiscTitle> filtered;
  final bool filteredLoading;
  final String? filteredError;
  final int filteredPage;
  final int filteredTotalPages;
  final int filteredTotal;
  final DiscoverRegionState region;

  String? get error => failure?.message;

  /// 条件是否生效：只有 TMDB 源有筛选，且至少启用一个维度。
  bool get filtering => source.toLowerCase() == 'tmdb' && filters.activeCount > 0;

  Map<int, String> get genreNameMap => {
        for (final g in genres) g.id: g.name,
      };

  DiscoverState copyWith({
    bool? loading,
    bool? refreshing,
    Object? failure = _sentinel,
    String? mediaType,
    String? source,
    List<DiscoverRowData>? rows,
    List<DiscoveryGenre>? genres,
    DiscoveryFilter? filters,
    List<DiscTitle>? filtered,
    bool? filteredLoading,
    Object? filteredError = _sentinel,
    int? filteredPage,
    int? filteredTotalPages,
    int? filteredTotal,
    DiscoverRegionState? region,
  }) =>
      DiscoverState(
        loading: loading ?? this.loading,
        refreshing: refreshing ?? this.refreshing,
        failure: identical(failure, _sentinel)
            ? this.failure
            : failure as DiscoverFailure?,
        mediaType: mediaType ?? this.mediaType,
        source: source ?? this.source,
        rows: rows ?? this.rows,
        genres: genres ?? this.genres,
        filters: filters ?? this.filters,
        filtered: filtered ?? this.filtered,
        filteredLoading: filteredLoading ?? this.filteredLoading,
        filteredError: identical(filteredError, _sentinel)
            ? this.filteredError
            : filteredError as String?,
        filteredPage: filteredPage ?? this.filteredPage,
        filteredTotalPages: filteredTotalPages ?? this.filteredTotalPages,
        filteredTotal: filteredTotal ?? this.filteredTotal,
        region: region ?? this.region,
      );

  static const _sentinel = Object();
}

class DiscoverController extends Notifier<DiscoverState> {
  final _debounce = Debouncer(const Duration(milliseconds: 300));
  final _filteredSeqGuard = SeqGuard();
  final Map<String, _DiscoverViewCache> _cache = {};
  final Set<String> _snapshotHydrated = {};
  bool _regionLoaded = false;
  McClient? _client;

  McClient get _mc => _client ??= McClient(session: ref.read(sessionStoreProvider));

  static String _viewKey(String mediaType, String source) =>
      '$mediaType:$source';

  static String _snapshotName(String mediaType, String source) =>
      'discover-$mediaType-$source';

  @override
  DiscoverState build() {
    ref.watch(sessionGenerationProvider);
    _cache.clear();
    _snapshotHydrated.clear();
    _regionLoaded = false;
    ref.onDispose(_debounce.dispose);
    Future.microtask(() async {
      await _hydrateSnapshotAndLoad('movie', 'tmdb');
      _loadGenres('movie');
      _loadRegionIfNeeded();
    });
    return DiscoverState(
      genres: DiscoverGenreCatalog.cached('movie'),
    );
  }

  List<DiscTitle> _parseTitles(Map<String, dynamic> raw) {
    final out = <DiscTitle>[];
    for (final el in (raw['titles'] as List<dynamic>? ?? const [])) {
      if (el is! Map) continue;
      final t = DiscTitle.fromJson(Map<String, dynamic>.from(el));
      if (t != null) out.add(t);
    }
    return out;
  }

  Future<void> _hydrateSnapshotAndLoad(
    String mediaType,
    String source, {
    bool forceReload = false,
  }) async {
    final key = _viewKey(mediaType, source);
    final mem = _cache[key];

    if (!forceReload && mem != null && mem.rows.isNotEmpty) {
      if (state.mediaType == mediaType && state.source == source) {
        state = state.copyWith(
          loading: !mem.loadedFromNetwork,
          rows: mem.rows,
          failure: mem.failure,
        );
      }
      if (mem.loadedFromNetwork) return;
    }

    // 尝试冷启动磁盘快照（PageSnapshots），先原样渲染再静默刷新
    if (!_snapshotHydrated.contains(key)) {
      _snapshotHydrated.add(key);
      final session = ref.read(sessionStoreProvider);
      if (session.isReady) {
        final snap = await PageSnapshots.readMap(
          _snapshotName(mediaType, source),
          origin: session.baseUrl ?? '',
          username: session.username,
        );
        if (snap != null) {
          final parsedRows = <DiscoverRowData>[];
          for (final el in (snap['rows'] as List<dynamic>? ?? const [])) {
            if (el is Map) {
              final r = DiscoverRowData.fromJson(Map<String, dynamic>.from(el));
              if (r != null) parsedRows.add(r);
            }
          }
          if (parsedRows.isNotEmpty) {
            final entry = _cache.putIfAbsent(key, _DiscoverViewCache.new);
            if (entry.rows.isEmpty) {
              entry.rows = parsedRows;
              if (state.mediaType == mediaType && state.source == source) {
                state = state.copyWith(
                  loading: false,
                  rows: parsedRows,
                  failure: null,
                );
              }
            }
          }
        }
      }
    }

    await load(force: forceReload);
  }

  /// 上游不可达时补取错误体里的 `details[0].hint`（对齐 iOS `discoverUnreachableHint`）。
  Future<String?> _fetchUnreachableHint(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _mc.get(Channel.general, path, query: query);
      final data = res.data;
      if (data == null) return null;
      final details = data['details'];
      if (details is List && details.isNotEmpty) {
        final first = details.first;
        if (first is Map) {
          final hint = (first['hint'] ?? first['message'] ?? '').toString().trim();
          if (hint.isNotEmpty) return hint;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 首页数据：服务端编排的发现页板块 + 各板块并发拉取。
  Future<void> load({bool force = false}) async {
    if (state.filtering) return;
    final mediaType = state.mediaType;
    final source = state.source;
    final key = _viewKey(mediaType, source);
    final session = ref.read(sessionStoreProvider);
    if (!session.isReady) {
      state = state.copyWith(
        loading: false,
        failure: const DiscoverFailure(message: '尚未连接服务器'),
      );
      return;
    }

    final existingRows = _cache[key]?.rows ?? state.rows;
    state = state.copyWith(
      loading: existingRows.isEmpty,
      failure: null,
    );

    try {
      final page = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/ui/discovery/$mediaType',
        query: {'provider': source},
      );
      final sections = (page['sections'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();

      ApiException? firstSectionError;
      String? firstErrorRef;
      int? firstErrorLimit;

      // 并发拉取全部片单分区
      final results = await Future.wait(
        sections.map((s) async {
          final ref0 =
              (s['collection_ref'] ?? s['collectionRef'] ?? '').toString();
          if (ref0.isEmpty) return null;
          final limit =
              ((s['preview_limit'] ?? s['previewLimit'] ?? 12) as num)
                  .toInt()
                  .clamp(6, 30);
          final title = (s['title'] ?? s['label'] ?? '').toString();
          final presentation = (s['presentation'] ?? '').toString();
          final supportsFull = (s['supports_full_listing'] ??
                  s['supportsFullListing']) !=
              false;
          try {
            final body = await _mc.unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/discover/collections/${Uri.encodeComponent(ref0)}/titles',
              query: {'limit': limit},
            );
            final titles = _parseTitles(body);
            if (titles.isEmpty) return null;
            return DiscoverRowData(
              collectionRef: ref0,
              title: title,
              presentation: presentation,
              previewLimit: limit,
              supportsFullListing: supportsFull,
              titles: titles,
            );
          } on ApiException catch (e) {
            if (firstSectionError == null && presentation != 'hero') {
              firstSectionError = e;
              firstErrorRef = ref0;
              firstErrorLimit = limit;
            }
            return null;
          } catch (_) {
            return null;
          }
        }),
      );

      final rows = results.whereType<DiscoverRowData>().toList();

      if (rows.isEmpty && firstSectionError != null) {
        final err = firstSectionError!;
        final unreachable = err.code == 'UPSTREAM_UNREACHABLE';
        var failure = DiscoverFailure(
          message: err.friendlyMessage,
          unreachable: unreachable,
        );
        if (unreachable && firstErrorRef != null) {
          final hint = await _fetchUnreachableHint(
            '/api/v1/discover/collections/${Uri.encodeComponent(firstErrorRef!)}/titles',
            query: firstErrorLimit != null ? {'limit': firstErrorLimit} : null,
          );
          if (hint != null) failure = failure.copyWith(hint: hint);
        }
        _cache[key] = _DiscoverViewCache(
          rows: existingRows,
          loadedFromNetwork: false,
          failure: failure,
        );
        if (state.mediaType == mediaType && state.source == source) {
          state = state.copyWith(
            loading: false,
            rows: existingRows,
            failure: existingRows.isEmpty ? failure : null,
          );
        }
        return;
      }

      _cache[key] = _DiscoverViewCache(
        rows: rows,
        loadedFromNetwork: true,
        failure: null,
      );

      // 落盘快照（按服务器 + 账号隔离）
      if (rows.isNotEmpty) {
        unawaited(
          PageSnapshots.write(
            _snapshotName(mediaType, source),
            {'rows': [for (final r in rows) r.toJson()]},
            origin: session.baseUrl ?? '',
            username: session.username,
          ),
        );
      }

      if (state.mediaType == mediaType && state.source == source) {
        state = state.copyWith(loading: false, rows: rows, failure: null);
      }
    } on ApiException catch (e) {
      final unreachable = e.code == 'UPSTREAM_UNREACHABLE';
      var failure = DiscoverFailure(
        message: e.friendlyMessage,
        unreachable: unreachable,
      );
      if (unreachable) {
        final hint = await _fetchUnreachableHint(
          '/api/v1/ui/discovery/$mediaType',
          query: {'provider': source},
        );
        if (hint != null) failure = failure.copyWith(hint: hint);
      }
      _cache[key] = _DiscoverViewCache(
        rows: existingRows,
        loadedFromNetwork: false,
        failure: failure,
      );
      if (state.mediaType == mediaType && state.source == source) {
        state = state.copyWith(
          loading: false,
          rows: existingRows,
          failure: existingRows.isEmpty ? failure : null,
        );
      }
    } catch (_) {
      const failure = DiscoverFailure(message: '网络错误，请稍后重试');
      if (state.mediaType == mediaType && state.source == source) {
        state = state.copyWith(
          loading: false,
          rows: existingRows,
          failure: existingRows.isEmpty ? failure : null,
        );
      }
    }
  }

  Future<void> _loadGenres(String mediaType) async {
    final list = await DiscoverGenreCatalog.load(_mc, mediaType);
    if (state.mediaType == mediaType && list.isNotEmpty) {
      state = state.copyWith(genres: list);
    }
  }

  /// 读取院线地区（电影 × TMDB 页脚，对齐 iOS `DiscoverRegionFooter`）。
  Future<void> _loadRegionIfNeeded() async {
    if (_regionLoaded) return;
    final session = ref.read(sessionStoreProvider);
    if (!session.isReady) return;
    _regionLoaded = true;
    try {
      final body = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/region',
      );
      _applyRegionBody(body);
    } on ApiException catch (e) {
      if (e.httpStatus == 404) {
        try {
          final body = await _mc.unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/settings/discover-region',
          );
          _applyRegionBody(body);
          return;
        } catch (_) {}
      }
      _regionLoaded = false;
    } catch (_) {
      _regionLoaded = false;
    }
  }

  void _applyRegionBody(Map<String, dynamic> body) {
    final code = (body['region'] ?? '').toString().trim();
    final canEdit =
        body['can_edit'] == true || ref.read(permissionsProvider).isAdmin;
    if (code.isNotEmpty) {
      state = state.copyWith(
        region: state.region.copyWith(region: code, canEdit: canEdit),
      );
    }
  }

  /// 管理员切换院线地区：乐观更新 → PUT 保存 → 清空全部 4 视角缓存并重拉当前视角。
  Future<String?> setRegion(String code) async {
    if (code == state.region.region) return null;
    final prev = state.region.region;
    state = state.copyWith(
      region: state.region.copyWith(
        region: code,
        saving: true,
        justSaved: false,
      ),
    );
    try {
      Map<String, dynamic> body;
      try {
        body = await _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'PUT',
          '/api/v1/discover/region',
          body: {'region': code},
        );
      } on ApiException catch (e) {
        if (e.httpStatus == 404) {
          body = await _mc.unwrap<Map<String, dynamic>>(
            Channel.general,
            'PUT',
            '/api/v1/settings/discover-region',
            body: {'region': code},
          );
        } else {
          rethrow;
        }
      }
      final updated = (body['region'] ?? code).toString();
      state = state.copyWith(
        region: state.region.copyWith(
          region: updated,
          saving: false,
          justSaved: true,
        ),
      );
      // 院线地区变更：清掉全部 4 视角缓存并重拉当前页
      for (final entry in _cache.values) {
        entry.loadedFromNetwork = false;
      }
      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        if (state.region.justSaved) {
          state = state.copyWith(
            region: state.region.copyWith(justSaved: false),
          );
        }
      });
      await load(force: true);
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(
        region: state.region.copyWith(region: prev, saving: false),
      );
      return e.friendlyMessage;
    } catch (_) {
      state = state.copyWith(
        region: state.region.copyWith(region: prev, saving: false),
      );
      return '切换院线地区失败，请重试';
    }
  }

  /// 下拉刷新：首页板块或筛选网格各自重拉一份。
  Future<void> pullRefresh() async {
    if (state.refreshing) return;
    state = state.copyWith(refreshing: true);
    try {
      if (state.filtering) {
        await loadFiltered(skipDebounce: true);
      } else {
        await load(force: true);
      }
    } finally {
      state = state.copyWith(refreshing: false);
    }
  }

  /// 切类型清空筛选条件，直接秒切 4 视角内存/快照缓存。
  Future<void> switchMediaType(String mediaType) async {
    if (state.mediaType == mediaType) return;
    final key = _viewKey(mediaType, state.source);
    final cached = _cache[key];
    state = state.copyWith(
      mediaType: mediaType,
      filters: const DiscoveryFilter(),
      genres: DiscoverGenreCatalog.cached(mediaType),
      rows: cached?.rows ?? const [],
      loading: cached == null || cached.rows.isEmpty,
      failure: cached?.failure,
      filtered: const [],
      filteredError: null,
    );
    unawaited(_loadGenres(mediaType));
    if (mediaType == 'movie' && state.source == 'tmdb') {
      unawaited(_loadRegionIfNeeded());
    }
    await _hydrateSnapshotAndLoad(mediaType, state.source);
  }

  /// 切数据源清空筛选条件，直接秒切 4 视角内存/快照缓存。
  Future<void> switchSource(String source) async {
    if (state.source == source) return;
    final key = _viewKey(state.mediaType, source);
    final cached = _cache[key];
    state = state.copyWith(
      source: source,
      filters: const DiscoveryFilter(),
      rows: cached?.rows ?? const [],
      loading: cached == null || cached.rows.isEmpty,
      failure: cached?.failure,
      filtered: const [],
      filteredError: null,
    );
    if (state.mediaType == 'movie' && source == 'tmdb') {
      unawaited(_loadRegionIfNeeded());
    }
    await _hydrateSnapshotAndLoad(state.mediaType, source);
  }

  /// 选一项筛选条件即生效：条件生效时正文换成结果网格；清空则回到常规板块。
  Future<void> applyFilters(DiscoveryFilter filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> refresh() async {
    if (state.filtering) {
      await loadFiltered(skipDebounce: state.filtered.isEmpty);
    } else {
      state = state.copyWith(filtered: const [], filteredError: null);
      await _hydrateSnapshotAndLoad(state.mediaType, state.source);
    }
  }

  /// 结果网格重查：条件变了先等 300ms 防抖，首次进入不必等。
  Future<void> loadFiltered({bool skipDebounce = false}) async {
    if (skipDebounce) {
      await _loadFilteredPage(1);
      return;
    }
    final completer = Completer<void>();
    _debounce(() async {
      try {
        await _loadFilteredPage(1);
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  Future<void> _loadFilteredPage(int page) async {
    final seq = _filteredSeqGuard.next;
    final s = state;
    final session = ref.read(sessionStoreProvider);
    if (!session.isReady) {
      state = state.copyWith(filteredLoading: false, filteredError: '尚未连接服务器');
      return;
    }
    state = state.copyWith(
      filteredLoading: true,
      filteredError: null,
      filtered: page == 1 ? const [] : s.filtered,
      filteredPage: page,
    );
    final f = s.filters;
    try {
      final body = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/titles',
        query: {
          'media_type': s.mediaType,
          if (f.genreIds.isNotEmpty) 'genre_ids': f.genreIds,
          if (f.originCountry != null) 'origin_country': f.originCountry,
          if (f.year != null) 'year': f.year,
          if (f.ratingGte != null) 'rating_gte': f.ratingGte,
          if (f.runtimeLte != null) 'runtime_lte': f.runtimeLte,
          if (f.sort != DiscoveryFilter.defaultSort) 'sort': f.sort,
          'page': page,
        },
      );
      if (!_filteredSeqGuard.isCurrent(seq)) return;
      final titles = _parseTitles(body).fold<List<DiscTitle>>(
        [],
        (acc, t) => acc.any((e) => e.ref == t.ref) ? acc : [...acc, t],
      );
      final merged = page == 1
          ? titles
          : [
              ...s.filtered,
              for (final t in titles)
                if (!s.filtered.any((e) => e.ref == t.ref)) t,
            ];
      state = state.copyWith(
        filteredLoading: false,
        filtered: merged,
        filteredPage: page,
        filteredTotalPages: ((body['total_pages'] as num?) ?? 1).toInt(),
        filteredTotal: ((body['total_results'] as num?) ?? 0).toInt(),
      );
    } on ApiException catch (e) {
      if (!_filteredSeqGuard.isCurrent(seq)) return;
      state = state.copyWith(
        filteredLoading: false,
        filteredError: e.friendlyMessage,
      );
    } catch (_) {
      if (!_filteredSeqGuard.isCurrent(seq)) return;
      state = state.copyWith(
        filteredLoading: false,
        filteredError: '网络错误，请稍后重试',
      );
    }
  }

  /// 滚到底自动翻页（旧条件在飞页回来作废：靠 SeqGuard 守卫）。
  Future<void> loadMoreFiltered() async {
    final s = state;
    if (s.filteredLoading || s.filteredPage >= s.filteredTotalPages || !s.filtering) {
      return;
    }
    await _loadFilteredPage(s.filteredPage + 1);
  }
}

final discoverProvider =
    NotifierProvider<DiscoverController, DiscoverState>(DiscoverController.new);

// ── 发现侧订阅索引（供海报卡/Hero/详情页展示「已订阅」角标与订阅状态，零跨 feature 导入） ──

class DiscoverSubEntry {
  const DiscoverSubEntry({
    required this.id,
    required this.status,
    required this.kind,
    this.tmdbId,
    this.doubanId,
    this.progressNote = '',
  });

  final int id;
  final String status;
  final String kind;
  final int? tmdbId;
  final String? doubanId;
  final String progressNote;

  String get statusLabel => switch (status.toLowerCase()) {
        'active' || 'watching' => '追更中',
        'paused' => '已暂停',
        'completed' || 'done' => '已完成',
        'searching' => '检索中',
        'downloading' => '下载中',
        _ => status.isEmpty ? '已订阅' : status,
      };
}

class DiscoverSubscriptionIndex {
  const DiscoverSubscriptionIndex({
    this.byTmdb = const {},
    this.byDouban = const {},
  });

  final Map<String, DiscoverSubEntry> byTmdb;
  final Map<String, DiscoverSubEntry> byDouban;

  DiscoverSubEntry? find({
    required String source,
    required String externalId,
    String? mediaType,
  }) {
    if (externalId.isEmpty) return null;
    if (source == 'douban') {
      return byDouban[externalId];
    }
    if (mediaType != null && mediaType.isNotEmpty) {
      final exact = byTmdb['$mediaType:$externalId'];
      if (exact != null) return exact;
    }
    return byTmdb['movie:$externalId'] ?? byTmdb['tv:$externalId'];
  }

  DiscoverSubEntry? findByTitle(DiscTitle item) => find(
        source: item.provider,
        externalId: item.externalId,
        mediaType: item.mediaType,
      );

  DiscoverSubEntry? findByRef(String titleRef) {
    final p = parseTitleRef(titleRef);
    return find(
      source: p.source,
      externalId: p.externalId,
      mediaType: p.mediaType,
    );
  }
}

class DiscoverSubscriptionIndexController
    extends Notifier<DiscoverSubscriptionIndex> {
  McClient? _client;
  McClient get _mc => _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  DiscoverSubscriptionIndex build() {
    ref.watch(sessionGenerationProvider);
    final perms = ref.watch(permissionsProvider);
    if (perms.canSubscribe) {
      Future.microtask(refresh);
    }
    return const DiscoverSubscriptionIndex();
  }

  Future<void> refresh() async {
    final session = ref.read(sessionStoreProvider);
    if (!session.isReady) return;
    if (!ref.read(permissionsProvider).canSubscribe) return;
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/subscriptions',
      );
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['subscriptions'] ?? raw['items'] ?? const [])
                  as List<dynamic>
              : const <dynamic>[]);
      final byTmdb = <String, DiscoverSubEntry>{};
      final byDouban = <String, DiscoverSubEntry>{};
      for (final el in list) {
        if (el is! Map) continue;
        final m = Map<String, dynamic>.from(el);
        final media = m['media'] is Map
            ? Map<String, dynamic>.from(m['media'] as Map)
            : const <String, dynamic>{};
        final id = (m['id'] as num?)?.toInt() ?? 0;
        if (id <= 0) continue;
        final status = (m['status'] ?? 'active').toString();
        final kind = (media['kind'] ?? m['media_kind'] ?? m['kind'] ?? 'movie')
            .toString();
        final tmdbId = (media['tmdb_id'] ?? m['tmdb_id']) as num?;
        final doubanId =
            (media['douban_id'] ?? m['douban_id'])?.toString().trim();
        final owned = (m['owned_count'] ?? m['completed_units'] ?? 0) as num;
        final total = (m['total_units'] ?? m['wanted_count'] ?? 0) as num;
        final note = total > 0 ? '已入库 $owned/$total' : '';
        final entry = DiscoverSubEntry(
          id: id,
          status: status,
          kind: kind,
          tmdbId: tmdbId?.toInt(),
          doubanId: (doubanId != null && doubanId.isNotEmpty) ? doubanId : null,
          progressNote: note,
        );
        if (entry.tmdbId != null && entry.tmdbId! > 0) {
          byTmdb['$kind:${entry.tmdbId}'] = entry;
        }
        if (entry.doubanId != null) {
          byDouban[entry.doubanId!] = entry;
        }
      }
      state = DiscoverSubscriptionIndex(byTmdb: byTmdb, byDouban: byDouban);
    } catch (_) {}
  }
}

final discoverSubscriptionIndexProvider = NotifierProvider<
    DiscoverSubscriptionIndexController,
    DiscoverSubscriptionIndex>(DiscoverSubscriptionIndexController.new);
