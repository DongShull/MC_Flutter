import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/notify/debounce_guard.dart';
import 'search_mode_memory.dart';

/// 规范化搜索分区模式：`library`（本地媒体库）| `media`（TMDB/豆瓣影视）| `torrent`（PT 种子资源）。
String normalizeSearchMode(String? raw) => switch (raw?.trim().toLowerCase()) {
      'media' || 'titles' || 'discover' => 'media',
      'torrent' || 'torrents' || 'pt' || 'resource' => 'torrent',
      _ => 'library',
    };

/// 库内搜索一条命中：条目 + 它在哪些库 + 为什么命中（LibrarySearchHit）。
class LibrarySearchHit {
  const LibrarySearchHit({
    required this.itemId,
    required this.itemName,
    this.posterUrl,
    this.year,
    this.libraryIds = const [],
    this.matchLabel = '',
  });

  final int itemId;
  final String itemName;
  final String? posterUrl;
  final int? year;
  final List<int> libraryIds;
  final String matchLabel;

  static LibrarySearchHit fromJson(Map<String, dynamic> o) {
    final item = o['item'];
    final itemMap =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final match = o['match'];
    final matchMap =
        match is Map ? Map<String, dynamic>.from(match) : <String, dynamic>{};
    return LibrarySearchHit(
      itemId: (itemMap['id'] as num? ?? itemMap['media_item_id'] as num? ?? 0)
          .toInt(),
      itemName: (itemMap['name'] ?? itemMap['title'] ?? '').toString(),
      posterUrl: itemMap['poster_url']?.toString(),
      year: (itemMap['year'] as num?)?.toInt() ??
          (itemMap['release_year'] as num?)?.toInt(),
      libraryIds: [
        for (final id in (o['library_ids'] as List<dynamic>? ?? const []))
          if (id is num) id.toInt(),
      ],
      matchLabel: (matchMap['label'] ?? '').toString(),
    );
  }
}

/// 人物行的一格（LibrarySearchPerson）。
class LibrarySearchPerson {
  const LibrarySearchPerson({
    required this.id,
    this.tmdbPersonId,
    required this.name,
    this.avatarUrl,
    this.itemCount = 0,
  });

  final int id;
  final int? tmdbPersonId;
  final String name;
  final String? avatarUrl;
  final int itemCount;

  static LibrarySearchPerson fromJson(Map<String, dynamic> o) =>
      LibrarySearchPerson(
        id: (o['id'] as num? ?? 0).toInt(),
        tmdbPersonId: (o['tmdb_person_id'] as num?)?.toInt(),
        name: (o['name'] ?? '').toString(),
        avatarUrl: o['avatar_url']?.toString() ?? o['profile_path']?.toString(),
        itemCount: (o['item_count'] as num? ?? 0).toInt(),
      );
}

/// 输入即联想的一条候选（LibrarySearchSuggestion）。
class SearchSuggestion {
  const SearchSuggestion({required this.text, this.label, this.personId});

  final String text;
  final String? label;
  final int? personId;

  static SearchSuggestion fromJson(Map<String, dynamic> o) => SearchSuggestion(
        text: (o['text'] ?? '').toString(),
        label: o['label']?.toString(),
        personId: (o['person_id'] as num?)?.toInt(),
      );
}

/// 影视发现搜索命中（POST /api/v1/search/titles）。
class MediaSearchHit {
  const MediaSearchHit({
    required this.titleRef,
    required this.title,
    required this.mediaType,
    this.year,
    this.rating,
    this.posterUrl,
    this.overview,
    this.genres = const [],
    this.inLibrary = false,
    this.libraryId,
    this.mediaItemId,
  });

  final String titleRef;
  final String title;
  final String mediaType;
  final int? year;
  final double? rating;
  final String? posterUrl;
  final String? overview;
  final List<String> genres;
  final bool inLibrary;
  final int? libraryId;
  final int? mediaItemId;

  static MediaSearchHit? fromJson(
    Map<String, dynamic> o, {
    String fallbackMediaType = 'movie',
  }) {
    var ref = (o['title_ref'] ?? o['ref'] ?? '').toString();
    final mType =
        (o['media_type'] ?? o['kind'] ?? fallbackMediaType).toString();
    if (ref.isEmpty) {
      final tmdb = o['tmdb_id'] ?? o['id'];
      if (tmdb != null) {
        ref = 'tmdb:${mType == 'tv' ? 'tv' : 'movie'}:$tmdb';
      }
    }
    if (ref.isEmpty) return null;
    final lib = o['library_status'];
    final libMap = lib is Map ? Map<String, dynamic>.from(lib) : null;
    final owned = libMap != null &&
        (((libMap['file_count'] as num? ?? 0).toInt() > 0) ||
            libMap['owned'] == true ||
            libMap['in_library'] == true);
    return MediaSearchHit(
      titleRef: ref,
      title: (o['title'] ?? o['name'] ?? '').toString(),
      mediaType: mType,
      year: (o['release_year'] as num?)?.toInt() ??
          (o['year'] as num?)?.toInt(),
      rating: (o['provider_rating'] as num?)?.toDouble() ??
          (o['rating'] as num?)?.toDouble(),
      posterUrl: o['poster_url']?.toString(),
      overview: o['overview']?.toString(),
      genres: [
        for (final g in (o['genres'] as List<dynamic>? ?? const []))
          g.toString(),
      ],
      inLibrary: owned,
      libraryId: (libMap?['library_id'] as num?)?.toInt(),
      mediaItemId: (libMap?['media_item_id'] as num?)?.toInt() ??
          (libMap?['item_id'] as num?)?.toInt(),
    );
  }
}

/// PT 种子搜索命中（GET /api/v1/search/torrents）。
class TorrentSearchHit {
  const TorrentSearchHit({
    required this.key,
    required this.siteId,
    required this.siteName,
    required this.torrentId,
    required this.title,
    this.subtitle = '',
    this.category = '',
    this.sizeBytes = 0,
    this.seeders = 0,
    this.leechers = 0,
    this.downloadUrl = '',
    this.pageUrl = '',
    this.isFree = false,
    this.freeLabel = '',
    this.hitAndRun = false,
    this.publishTime = '',
    this.raw = const {},
  });

  final String key;
  final String siteId;
  final String siteName;
  final String torrentId;
  final String title;
  final String subtitle;
  final String category;
  final int sizeBytes;
  final int seeders;
  final int leechers;
  final String downloadUrl;
  final String pageUrl;
  final bool isFree;
  final String freeLabel;
  final bool hitAndRun;
  final String publishTime;
  final Map<String, dynamic> raw;

  List<String> get techBadges {
    final upper = '$title $subtitle'.toUpperCase();
    final out = <String>[];
    if (upper.contains('2160P') || upper.contains('4K')) {
      out.add('4K');
    } else if (upper.contains('1080P')) {
      out.add('1080P');
    } else if (upper.contains('720P')) {
      out.add('720P');
    }
    if (upper.contains('REMUX')) out.add('REMUX');
    if (upper.contains('BLURAY') || upper.contains('BLU-RAY')) {
      out.add('BluRay');
    } else if (upper.contains('WEB-DL') || upper.contains('WEBDL')) {
      out.add('WEB-DL');
    }
    if (upper.contains('DV') || upper.contains('DOLBY VISION')) {
      out.add('杜比视界');
    } else if (upper.contains('HDR')) {
      out.add('HDR');
    }
    if (upper.contains('ATMOS')) out.add('Atmos');
    return out.take(4).toList();
  }

  static TorrentSearchHit fromJson(Map<String, dynamic> o, int idx) {
    final siteId = (o['site_id'] ?? o['site'] ?? '').toString();
    final siteName =
        (o['site_name'] ?? o['indexer_name'] ?? siteId).toString();
    final tid = (o['torrent_id'] ?? o['id'] ?? '$idx').toString();
    final dlUrl = (o['download_url'] ?? o['enclosure'] ?? '').toString();
    final freeRaw = (o['discount'] ?? o['promotion'] ?? o['free_type'] ?? '')
        .toString()
        .toUpperCase();
    final isFree = o['is_free'] == true ||
        o['free'] == true ||
        freeRaw.contains('FREE') ||
        freeRaw.contains('2X');
    return TorrentSearchHit(
      key: '$siteId:$tid:${dlUrl.hashCode}:$idx',
      siteId: siteId,
      siteName: siteName.isEmpty ? 'PT 站点' : siteName,
      torrentId: tid,
      title: (o['title'] ?? o['name'] ?? '').toString(),
      subtitle: (o['subtitle'] ?? o['description'] ?? '').toString(),
      category: (o['category'] ?? '').toString(),
      sizeBytes: (o['size_bytes'] as num?)?.toInt() ??
          (o['size'] as num?)?.toInt() ??
          0,
      seeders: (o['seeders'] as num?)?.toInt() ?? 0,
      leechers: (o['leechers'] as num?)?.toInt() ??
          (o['peers'] as num?)?.toInt() ??
          0,
      downloadUrl: dlUrl,
      pageUrl: (o['page_url'] ?? o['details_url'] ?? '').toString(),
      isFree: isFree,
      freeLabel: freeRaw.isNotEmpty ? freeRaw : (isFree ? 'FREE' : ''),
      hitAndRun: o['hit_and_run'] == true || o['hr'] == true,
      publishTime:
          (o['publish_time'] ?? o['published_at'] ?? o['pub_date'] ?? '')
              .toString(),
      raw: o,
    );
  }
}

/// 三合一全局搜索状态（`本地媒体库 | 影视发现 | 种子资源 PT`）。
class SearchState {
  const SearchState({
    this.mode = 'library',
    this.mediaProvider = 'tmdb',
    this.mediaType = 'all',
    this.query = '',
    this.searching = false,
    this.error,
    this.submittedQuery = '',
    this.hits = const [],
    this.people = const [],
    this.suggestions = const [],
    this.mediaHits = const [],
    this.torrentHits = const [],
    this.busyTorrentKeys = const {},
    this.downloadedTorrentKeys = const {},
    this.nextCursor,
    this.indexPending = false,
    this.selectedPerson,
    this.history = const [],
  });

  final String mode;
  final String mediaProvider;
  final String mediaType;
  final String query;
  final bool searching;
  final String? error;
  final String submittedQuery;
  final List<LibrarySearchHit> hits;
  final List<LibrarySearchPerson> people;
  final List<SearchSuggestion> suggestions;
  final List<MediaSearchHit> mediaHits;
  final List<TorrentSearchHit> torrentHits;
  final Set<String> busyTorrentKeys;
  final Set<String> downloadedTorrentKeys;
  final String? nextCursor;
  final bool indexPending;
  final LibrarySearchPerson? selectedPerson;
  final List<String> history;

  SearchState copyWith({
    String? mode,
    String? mediaProvider,
    String? mediaType,
    String? query,
    bool? searching,
    Object? error = _sentinel,
    String? submittedQuery,
    List<LibrarySearchHit>? hits,
    List<LibrarySearchPerson>? people,
    List<SearchSuggestion>? suggestions,
    List<MediaSearchHit>? mediaHits,
    List<TorrentSearchHit>? torrentHits,
    Set<String>? busyTorrentKeys,
    Set<String>? downloadedTorrentKeys,
    Object? nextCursor = _sentinel,
    bool? indexPending,
    Object? selectedPerson = _sentinel,
    List<String>? history,
  }) =>
      SearchState(
        mode: mode ?? this.mode,
        mediaProvider: mediaProvider ?? this.mediaProvider,
        mediaType: mediaType ?? this.mediaType,
        query: query ?? this.query,
        searching: searching ?? this.searching,
        error: identical(error, _sentinel) ? this.error : error as String?,
        submittedQuery: submittedQuery ?? this.submittedQuery,
        hits: hits ?? this.hits,
        people: people ?? this.people,
        suggestions: suggestions ?? this.suggestions,
        mediaHits: mediaHits ?? this.mediaHits,
        torrentHits: torrentHits ?? this.torrentHits,
        busyTorrentKeys: busyTorrentKeys ?? this.busyTorrentKeys,
        downloadedTorrentKeys:
            downloadedTorrentKeys ?? this.downloadedTorrentKeys,
        nextCursor: identical(nextCursor, _sentinel)
            ? this.nextCursor
            : nextCursor as String?,
        indexPending: indexPending ?? this.indexPending,
        selectedPerson: identical(selectedPerson, _sentinel)
            ? this.selectedPerson
            : selectedPerson as LibrarySearchPerson?,
        history: history ?? this.history,
      );

  static const _sentinel = Object();
}

class SearchController extends Notifier<SearchState> {
  final _debounce = Debouncer(const Duration(milliseconds: 350));
  final _seq = SeqGuard();
  McClient? _client;
  McClient get _mc =>
      _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  SearchState build() {
    ref.onDispose(_debounce.dispose);
    Future.microtask(() async {
      await SearchModeMemory.instance.load();
      if (SearchModeMemory.instance.mode != null && state.query.isEmpty) {
        state = state.copyWith(
          mode: normalizeSearchMode(SearchModeMemory.instance.mode),
        );
      }
      await _loadHistory();
    });
    return const SearchState();
  }

  /// 页面带 URL 参数（`?q=...&tab=...`）进入时同步模式并立即检索。
  Future<void> applyRouteArgs({String? query, String? mode}) async {
    final nextMode = mode != null && mode.isNotEmpty
        ? normalizeSearchMode(mode)
        : state.mode;
    if (nextMode != state.mode) {
      state = state.copyWith(mode: nextMode);
    }
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      state = state.copyWith(query: q);
      await search(q);
    }
  }

  Future<void> switchMode(String rawMode) async {
    final next = normalizeSearchMode(rawMode);
    if (next == state.mode) return;
    rememberMode(next);
    final q = (state.query.trim().isNotEmpty
            ? state.query
            : state.submittedQuery)
        .trim();
    if (q.isNotEmpty) {
      await search(q);
    }
  }

  Future<void> setMediaFilter({String? provider, String? mediaType}) async {
    state = state.copyWith(
      mediaProvider: provider ?? state.mediaProvider,
      mediaType: mediaType ?? state.mediaType,
    );
    final q = (state.query.trim().isNotEmpty
            ? state.query
            : state.submittedQuery)
        .trim();
    if (q.isNotEmpty && state.mode == 'media') {
      await search(q);
    }
  }

  void onQuery(String value) {
    state = state.copyWith(query: value);
    final q = value.trim();
    if (q.isEmpty) {
      state = state.copyWith(
        searching: false,
        error: null,
        hits: const [],
        people: const [],
        suggestions: const [],
        mediaHits: const [],
        torrentHits: const [],
        nextCursor: null,
        selectedPerson: null,
      );
      return;
    }
    _debounce(() => search(q));
  }

  /// 立即搜索（提交/点历史词/切分区）。写历史记录。
  Future<void> search(String q, {String? cursor}) async {
    final query = q.trim();
    if (query.isEmpty) return;
    if (state.mode == 'media') {
      await _searchMedia(query);
    } else if (state.mode == 'torrent') {
      await _searchTorrents(query);
    } else {
      await _searchLibrary(query, cursor: cursor, fresh: cursor == null);
    }
    if (cursor == null) await _rememberHistory(query);
  }

  Future<void> _searchLibrary(
    String query, {
    String? cursor,
    required bool fresh,
  }) async {
    final seq = _seq.next;
    state = state.copyWith(
      searching: true,
      error: null,
      submittedQuery: query,
      suggestions: const [],
      hits: fresh ? const [] : state.hits,
      people: fresh ? const [] : state.people,
      nextCursor: fresh ? null : state.nextCursor,
    );
    final person = state.selectedPerson;
    try {
      final body = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/search/library',
        query: {
          'q': query,
          'limit': 24,
          if (person != null) 'person_id': person.id,
          if (cursor != null) 'cursor': cursor,
        },
      );
      if (!_seq.isCurrent(seq)) return;
      state = state.copyWith(
        searching: false,
        hits: [
          ...state.hits,
          for (final el in (body['items'] as List<dynamic>? ?? const []))
            if (el is Map)
              LibrarySearchHit.fromJson(Map<String, dynamic>.from(el)),
        ],
        people: [
          for (final el in (body['people'] as List<dynamic>? ?? const []))
            if (el is Map)
              LibrarySearchPerson.fromJson(Map<String, dynamic>.from(el)),
        ],
        suggestions: [
          for (final el in (body['suggestions'] as List<dynamic>? ?? const []))
            if (el is Map)
              SearchSuggestion.fromJson(Map<String, dynamic>.from(el)),
        ],
        nextCursor: body['next_cursor']?.toString(),
        indexPending: body['index_pending'] == true,
      );
    } on ApiException catch (e) {
      if (!_seq.isCurrent(seq)) return;
      if (cursor != null && e.httpStatus == 400) {
        await _searchLibrary(query, fresh: true);
        return;
      }
      state = state.copyWith(searching: false, error: e.friendlyMessage);
    } catch (_) {
      if (!_seq.isCurrent(seq)) return;
      state = state.copyWith(searching: false, error: '网络错误，请稍后重试');
    }
  }

  Future<List<MediaSearchHit>> _fetchMediaKind(
    String query,
    String mediaType,
  ) async {
    final raw = await _mc.unwrap<dynamic>(
      Channel.general,
      'POST',
      '/api/v1/search/titles',
      body: {
        'query': query,
        'provider': state.mediaProvider,
        'media_type': mediaType,
        'page': 1,
      },
    );
    final list = raw is List
        ? raw
        : (raw is Map
            ? (raw['titles'] ?? raw['items'] ?? raw['results'] ?? const [])
                as List<dynamic>
            : const <dynamic>[]);
    final out = <MediaSearchHit>[];
    for (final el in list) {
      if (el is Map) {
        final hit = MediaSearchHit.fromJson(
          Map<String, dynamic>.from(el),
          fallbackMediaType: mediaType,
        );
        if (hit != null && !out.any((e) => e.titleRef == hit.titleRef)) {
          out.add(hit);
        }
      }
    }
    return out;
  }

  Future<void> _searchMedia(String query) async {
    final seq = _seq.next;
    state = state.copyWith(
      searching: true,
      error: null,
      submittedQuery: query,
      mediaHits: const [],
    );
    try {
      List<MediaSearchHit> merged;
      if (state.mediaType == 'all') {
        final results = await Future.wait([
          _fetchMediaKind(query, 'movie'),
          _fetchMediaKind(query, 'tv').catchError((_) => <MediaSearchHit>[]),
        ]);
        final movies = results[0];
        final shows = results[1];
        merged = <MediaSearchHit>[];
        final maxLen =
            movies.length > shows.length ? movies.length : shows.length;
        for (var i = 0; i < maxLen; i++) {
          if (i < movies.length) merged.add(movies[i]);
          if (i < shows.length &&
              !merged.any((e) => e.titleRef == shows[i].titleRef)) {
            merged.add(shows[i]);
          }
        }
      } else {
        merged = await _fetchMediaKind(query, state.mediaType);
      }
      if (!_seq.isCurrent(seq)) return;
      state = state.copyWith(searching: false, mediaHits: merged);
    } on ApiException catch (e) {
      if (!_seq.isCurrent(seq)) return;
      state = state.copyWith(searching: false, error: e.friendlyMessage);
    } catch (_) {
      if (!_seq.isCurrent(seq)) return;
      state = state.copyWith(searching: false, error: '影视检索失败，请检查网络连接');
    }
  }

  Future<void> _searchTorrents(String query) async {
    final seq = _seq.next;
    state = state.copyWith(
      searching: true,
      error: null,
      submittedQuery: query,
      torrentHits: const [],
    );
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/search/torrents',
        query: {'keyword': query, 'q': query, 'page': 1},
      );
      if (!_seq.isCurrent(seq)) return;
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['items'] ?? raw['torrents'] ?? raw['results'] ?? const [])
                  as List<dynamic>
              : const <dynamic>[]);
      final hits = <TorrentSearchHit>[];
      var i = 0;
      for (final el in list) {
        if (el is Map) {
          hits.add(TorrentSearchHit.fromJson(Map<String, dynamic>.from(el), i));
          i++;
        }
      }
      state = state.copyWith(searching: false, torrentHits: hits);
    } on ApiException catch (e) {
      if (!_seq.isCurrent(seq)) return;
      state = state.copyWith(searching: false, error: e.friendlyMessage);
    } catch (_) {
      if (!_seq.isCurrent(seq)) return;
      state = state.copyWith(searching: false, error: '种子检索失败，请确认已配置可用 PT 站点');
    }
  }

  /// 一键直推下载器（POST /api/v1/downloaders/submit）。成功返回 null。
  Future<String?> directDownloadTorrent(TorrentSearchHit hit) async {
    state = state.copyWith(
      busyTorrentKeys: {...state.busyTorrentKeys, hit.key},
    );
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/downloaders/submit',
        body: {
          ...hit.raw,
          'site_id': hit.siteId,
          'torrent_id': hit.torrentId,
          'title': hit.title,
          'download_url': hit.downloadUrl,
          'size_bytes': hit.sizeBytes,
        },
      );
      state = state.copyWith(
        busyTorrentKeys: {...state.busyTorrentKeys}..remove(hit.key),
        downloadedTorrentKeys: {...state.downloadedTorrentKeys, hit.key},
      );
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(
        busyTorrentKeys: {...state.busyTorrentKeys}..remove(hit.key),
      );
      return e.friendlyMessage;
    } catch (e) {
      state = state.copyWith(
        busyTorrentKeys: {...state.busyTorrentKeys}..remove(hit.key),
      );
      return '推送下载失败：$e';
    }
  }

  /// 为指定订阅手动选种抓源入库（POST /api/v1/subscriptions/{id}/selected-torrent-downloads）。
  Future<String?> grabForSubscription(
    int subscriptionId,
    TorrentSearchHit hit,
  ) async {
    state = state.copyWith(
      busyTorrentKeys: {...state.busyTorrentKeys, hit.key},
    );
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/subscriptions/$subscriptionId/selected-torrent-downloads',
        body: {
          ...hit.raw,
          'site_id': hit.siteId,
          'torrent_id': hit.torrentId,
          'title': hit.title,
          'download_url': hit.downloadUrl,
          'size_bytes': hit.sizeBytes,
        },
      );
      state = state.copyWith(
        busyTorrentKeys: {...state.busyTorrentKeys}..remove(hit.key),
        downloadedTorrentKeys: {...state.downloadedTorrentKeys, hit.key},
      );
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(
        busyTorrentKeys: {...state.busyTorrentKeys}..remove(hit.key),
      );
      return e.friendlyMessage;
    } catch (e) {
      state = state.copyWith(
        busyTorrentKeys: {...state.busyTorrentKeys}..remove(hit.key),
      );
      return '手动抓源失败：$e';
    }
  }

  /// 人物行点击 → 下钻这个人的库内作品。
  Future<void> selectPerson(LibrarySearchPerson p) async {
    state = state.copyWith(selectedPerson: p);
    await _searchLibrary(
      state.submittedQuery.isEmpty ? state.query : state.submittedQuery,
      fresh: true,
    );
  }

  Future<void> clearPerson() async {
    state = state.copyWith(selectedPerson: null);
    await _searchLibrary(
      state.submittedQuery.isEmpty ? state.query : state.submittedQuery,
      fresh: true,
    );
  }

  void rememberMode(String mode) {
    final normalized = normalizeSearchMode(mode);
    state = state.copyWith(mode: normalized);
    SearchModeMemory.instance.remember(normalized);
  }

  /* ── 历史记录（本机 SharedPreferences，最多 20 条） ── */

  Future<void> _loadHistory() async {
    final list = await SearchModeMemory.instance.readHistory();
    state = state.copyWith(history: list);
  }

  Future<void> _rememberHistory(String query) async {
    final list = await SearchModeMemory.instance.appendHistory(query);
    state = state.copyWith(history: list);
  }

  Future<void> removeHistory(String query) async {
    final list = await SearchModeMemory.instance.removeHistory(query);
    state = state.copyWith(history: list);
  }

  Future<void> clearHistory() async {
    final list = await SearchModeMemory.instance.clearHistory();
    state = state.copyWith(history: list);
  }
}

final searchProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
