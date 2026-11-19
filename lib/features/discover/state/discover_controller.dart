// IMPLEMENTED — 1:1 重写自 MovieClaw feature/discover/DiscoverScreen.kt（DiscoverViewModel）。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/notify/debounce_guard.dart';
import '../widgets/discovery_filter.dart';

/// 发现页板块里的一条（服务端编排的分区，presentation == 'hero' 的是英雄轮播）。
class DiscoverRowData {
  const DiscoverRowData({
    required this.collectionRef,
    required this.title,
    this.presentation = '',
    this.previewLimit = 12,
    required this.titles,
  });

  final String collectionRef;
  final String title;
  final String presentation;
  final int previewLimit;
  final List<DiscTitle> titles;
}

/// 筛选网格里的一格（TMDB discover 的返回切片，对齐 DiscTitle）。
class DiscTitle {
  const DiscTitle({
    required this.ref,
    required this.title,
    this.year,
    this.rating,
    this.posterUrl,
    this.genres = const [],
    this.owned = false,
  });

  final String ref;
  final String title;
  final int? year;
  final double? rating;
  final String? posterUrl;
  final List<String> genres;
  final bool owned;

  static DiscTitle? fromJson(Map<String, dynamic> o) {
    final ref = o['title_ref']?.toString();
    if (ref == null || ref.isEmpty) return null;
    final lib = o['library_status'];
    return DiscTitle(
      ref: ref,
      title: o['title']?.toString() ?? '',
      year: (o['release_year'] as num?)?.toInt(),
      rating: (o['provider_rating'] as num?)?.toDouble(),
      posterUrl: o['poster_url']?.toString(),
      genres: [
        for (final g in (o['genres'] as List<dynamic>? ?? const [])) g.toString(),
      ],
      // library_status 是对象（MediaLibraryStatus），不是字符串（原 Kotlin 踩过的坑）。
      owned: lib is Map && ((lib['file_count'] as num? ?? 0).toInt() > 0),
    );
  }
}

/// 发现页状态（对齐 DiscoverViewModel.UiState）。
class DiscoverState {
  const DiscoverState({
    this.loading = true,
    this.refreshing = false,
    this.error,
    this.mediaType = 'movie',
    this.source = 'tmdb',
    this.rows = const [],
    this.filters = const DiscoveryFilter(),
    this.filtered = const [],
    this.filteredLoading = false,
    this.filteredError,
    this.filteredPage = 1,
    this.filteredTotalPages = 1,
    this.filteredTotal = 0,
  });

  final bool loading;
  final bool refreshing;
  final String? error;
  final String mediaType;
  final String source;
  final List<DiscoverRowData> rows;
  final DiscoveryFilter filters;
  final List<DiscTitle> filtered;
  final bool filteredLoading;
  final String? filteredError;
  final int filteredPage;
  final int filteredTotalPages;
  final int filteredTotal;

  /// 条件是否生效：只有 TMDB 源有筛选（豆瓣源的按钮不出现），且至少一项条件。
  bool get filtering => source.toLowerCase() == 'tmdb' && filters.activeCount > 0;

  DiscoverState copyWith({
    bool? loading,
    bool? refreshing,
    Object? error = _sentinel,
    String? mediaType,
    String? source,
    List<DiscoverRowData>? rows,
    DiscoveryFilter? filters,
    List<DiscTitle>? filtered,
    bool? filteredLoading,
    Object? filteredError = _sentinel,
    int? filteredPage,
    int? filteredTotalPages,
    int? filteredTotal,
  }) =>
      DiscoverState(
        loading: loading ?? this.loading,
        refreshing: refreshing ?? this.refreshing,
        error: identical(error, _sentinel) ? this.error : error as String?,
        mediaType: mediaType ?? this.mediaType,
        source: source ?? this.source,
        rows: rows ?? this.rows,
        filters: filters ?? this.filters,
        filtered: filtered ?? this.filtered,
        filteredLoading: filteredLoading ?? this.filteredLoading,
        filteredError:
            identical(filteredError, _sentinel) ? this.filteredError : filteredError as String?,
        filteredPage: filteredPage ?? this.filteredPage,
        filteredTotalPages: filteredTotalPages ?? this.filteredTotalPages,
        filteredTotal: filteredTotal ?? this.filteredTotal,
      );

  static const _sentinel = Object();
}

class DiscoverController extends Notifier<DiscoverState> {
  final _debounce = Debouncer(const Duration(milliseconds: 300));
  final _filteredSeqGuard = SeqGuard();
  McClient? _client;

  McClient get _mc => _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  DiscoverState build() {
    ref.onDispose(_debounce.dispose);
    Future.microtask(load);
    return const DiscoverState();
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

  /// 首页数据：服务端编排的发现页板块 + 各板块并行拉前 N 条。
  Future<void> load() async {
    if (state.filtering) return; // 筛选态下正文是结果网格，不必白拉一趟
    final session = ref.read(sessionStoreProvider);
    if (!session.isReady) {
      state = state.copyWith(loading: false, error: '尚未连接服务器');
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/ui/discovery/${state.mediaType}',
        query: {'provider': state.source},
      );
      final sections = (page['sections'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      final rows = <DiscoverRowData>[];
      for (final s in sections) {
        final ref0 = (s['collection_ref'] ?? s['collectionRef'] ?? '').toString();
        if (ref0.isEmpty) continue;
        final limit =
            ((s['preview_limit'] ?? s['previewLimit'] ?? 12) as num).toInt().clamp(6, 30);
        List<DiscTitle> titles = const [];
        try {
          final body = await _mc.unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/discover/collections/${Uri.encodeComponent(ref0)}/titles',
            query: {'limit': limit},
          );
          titles = _parseTitles(body);
        } catch (_) {
          titles = const []; // 单板块失败不打断整页（原 Kotlin getOrDefault(emptyList())）
        }
        if (titles.isEmpty) continue;
        rows.add(DiscoverRowData(
          collectionRef: ref0,
          title: (s['label'] ?? s['title'] ?? '').toString(),
          presentation: (s['presentation'] ?? '').toString(),
          previewLimit: limit,
          titles: titles,
        ));
      }
      state = state.copyWith(loading: false, rows: rows);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(loading: false, error: '网络错误，请稍后重试');
    }
  }

  /// 下拉刷新：首页板块或筛选网格各自重拉一份。
  Future<void> pullRefresh() async {
    if (state.refreshing) return;
    state = state.copyWith(refreshing: true);
    try {
      if (state.filtering) {
        await loadFiltered();
        await Future<void>.delayed(const Duration(milliseconds: 450));
      } else {
        await load();
      }
    } finally {
      state = state.copyWith(refreshing: false);
    }
  }

  /// 切类型清空筛选条件；切源清空筛选条件（原 Kotlin switchSource/switchMediaType 同语义）。
  Future<void> switchMediaType(String mediaType) async {
    if (state.mediaType == mediaType) return;
    state = state.copyWith(
      mediaType: mediaType,
      filters: const DiscoveryFilter(),
      rows: const [],
      filtered: const [],
    );
    await refresh();
  }

  Future<void> switchSource(String source) async {
    if (state.source == source) return;
    state = state.copyWith(source: source, filters: const DiscoveryFilter(), rows: const []);
    await refresh();
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
      await load();
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
        completer.complete();
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
          if (f.sort != null) 'sort': f.sort,
          'page': page,
        },
      );
      if (!_filteredSeqGuard.isCurrent(seq)) return; // 只允许最后一次请求写回
      final titles = _parseTitles(body)
          .fold<List<DiscTitle>>([], (acc, t) => acc.any((e) => e.ref == t.ref) ? acc : [...acc, t]);
      state = state.copyWith(
        filteredLoading: false,
        filtered: titles,
        filteredPage: page,
        filteredTotalPages: ((body['total_pages'] as num?) ?? 1).toInt(),
        filteredTotal: ((body['total_results'] as num?) ?? 0).toInt(),
      );
    } on ApiException catch (e) {
      if (!_filteredSeqGuard.isCurrent(seq)) return;
      state = state.copyWith(filteredLoading: false, filteredError: e.friendlyMessage);
    } catch (_) {
      if (!_filteredSeqGuard.isCurrent(seq)) return;
      state = state.copyWith(filteredLoading: false, filteredError: '网络错误，请稍后重试');
    }
  }

  /// 滚到底自动翻页（旧条件在飞页回来作废：靠 SeqGuard 守卫）。
  Future<void> loadMoreFiltered() async {
    final s = state;
    if (s.filteredLoading || s.filteredPage >= s.filteredTotalPages || !s.filtering) return;
    await _loadFilteredPage(s.filteredPage + 1);
  }
}

final discoverProvider =
    NotifierProvider<DiscoverController, DiscoverState>(DiscoverController.new);
