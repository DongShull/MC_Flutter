import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/agent_sse_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/notify/debounce_guard.dart';
import '../../../core/session/permissions.dart';
import '../logic/torrent_search_logic.dart';
import '../models/search_models.dart';
import '../widgets/download_target_sheet.dart';
import 'search_mode_memory.dart';

/// 规范化搜索分区模式字符串（向后兼容旧路由调用）。
String normalizeSearchMode(String? raw) =>
    SearchVertical.fromRouteTab(raw, fallback: SearchVertical.library).name;

/// 全局搜索状态（整合搜索首页与三垂直结果页状态，支持 SSE 流式搜种、快照回放、12 维自排除筛选）。
class SearchState {
  const SearchState({
    this.access = const SearchAccess(),
    this.vertical = SearchVertical.library,
    this.query = '',
    this.submittedQuery = '',
    this.browsing = false,
    this.alsoKeywords = const [],
    this.scope = SearchScope.all,
    this.tabs = const [],
    this.tabsLoaded = false,
    // 服务端历史
    this.history = const [],
    this.historyLoading = false,
    // 媒体库垂直
    this.librarySearching = false,
    this.libraryLoadingMore = false,
    this.libraryError,
    this.libraryHits = const [],
    this.libraryPeople = const [],
    this.librarySuggestions = const [],
    this.libraryNextCursor,
    this.libraryIndexPending = false,
    // 影视垂直（双源叠排 + 快照回放）
    this.mediaSearching = false,
    this.mediaSnapshotAt,
    this.doubanHits,
    this.doubanError,
    this.tmdbHits,
    this.tmdbError,
    // 站点资源 PT 垂直（SSE 流式 + 12 维筛选 + 7 维排序 + 3 视图 + 分页 + 快照）
    this.torrentPhase = TorrentStreamPhase.idle,
    this.torrentFatalError,
    this.torrentItems = const [],
    this.torrentSites = const [],
    this.torrentTotalElapsedMs,
    this.torrentSnapshotAt,
    this.torrentAlsoSearched = const [],
    this.torrentPage = 1,
    this.torrentLoadingMore = false,
    this.torrentExhausted = false,
    this.torrentFilters = const TorrentFilters(),
    this.torrentSort = const TorrentSort(),
    this.torrentView = TorrentResultView.group,
    // 派生数据
    this.torrentFacets = const TorrentFacets(),
    this.torrentFiltered = const [],
    this.torrentSorted = const [],
    this.torrentEntities = const {},
    this.torrentSmartSortKeys = const [TorrentSortKey.free],
    // 下载 / 投给订阅逐行状态
    this.downloadStates = const {},
    this.grabStates = const {},
    this.grabTarget,
  });

  final SearchAccess access;
  final SearchVertical vertical;
  final String query;
  final String submittedQuery;
  final bool browsing;
  final List<String> alsoKeywords;
  final SearchScope scope;
  final List<SearchTab> tabs;
  final bool tabsLoaded;

  final List<SearchHistoryItem> history;
  final bool historyLoading;

  final bool librarySearching;
  final bool libraryLoadingMore;
  final String? libraryError;
  final List<LibrarySearchHit> libraryHits;
  final List<LibrarySearchPerson> libraryPeople;
  final List<SearchSuggestion> librarySuggestions;
  final String? libraryNextCursor;
  final bool libraryIndexPending;

  final bool mediaSearching;
  final String? mediaSnapshotAt;
  final List<MediaSearchHit>? doubanHits;
  final String? doubanError;
  final List<MediaSearchHit>? tmdbHits;
  final String? tmdbError;

  final TorrentStreamPhase torrentPhase;
  final String? torrentFatalError;
  final List<TorrentHit> torrentItems;
  final List<SiteProgress> torrentSites;
  final int? torrentTotalElapsedMs;
  final String? torrentSnapshotAt;
  final List<String> torrentAlsoSearched;
  final int torrentPage;
  final bool torrentLoadingMore;
  final bool torrentExhausted;
  final TorrentFilters torrentFilters;
  final TorrentSort torrentSort;
  final TorrentResultView torrentView;

  final TorrentFacets torrentFacets;
  final List<TorrentHit> torrentFiltered;
  final List<TorrentHit> torrentSorted;
  final Map<String, TorrentEntity> torrentEntities;
  final List<TorrentSortKey> torrentSmartSortKeys;

  final Map<String, TorrentSubmitState> downloadStates;
  final Map<String, TorrentSubmitState> grabStates;
  final ({int id, String title})? grabTarget;

  bool get torrentStreaming =>
      torrentPhase == TorrentStreamPhase.connecting ||
      torrentPhase == TorrentStreamPhase.streaming;

  int get torrentSettledCount =>
      torrentSites.where((s) => s.state != SiteProgressState.searching).length;

  int get torrentFailedCount =>
      torrentSites.where((s) => s.state == SiteProgressState.error).length;

  List<SiteProgress> get torrentOkSites =>
      torrentSites.where((s) => s.state == SiteProgressState.ok).toList();

  /// 是否处于结果展示态（媒体库输入即实时展示；影视/资源需提交或浏览/快照）。
  bool get showingResults {
    if (vertical == SearchVertical.library) return query.trim().isNotEmpty;
    if (vertical == SearchVertical.torrent) {
      return browsing ||
          submittedQuery.isNotEmpty ||
          torrentSnapshotAt != null ||
          torrentPhase != TorrentStreamPhase.idle;
    }
    return submittedQuery.isNotEmpty || mediaSnapshotAt != null;
  }

  /// 按当前垂直 + 关键词过滤后的分组历史（对齐 iOS `SearchHomeView.groups`）。
  List<HistoryGroup> get groupedHistory {
    final hv = vertical.historyVertical;
    if (hv == null) return const [];
    final visible = history.where((item) {
      if (item.vertical != hv) return false;
      return item.vertical == 'titles' ? access.canMedia : access.canTorrent;
    });
    final order = <String>[];
    final map = <String, List<SearchHistoryItem>>{};
    final display = <String, String>{};
    for (final item in visible) {
      final k = item.keyword.trim().toLowerCase();
      if (!map.containsKey(k)) {
        order.add(k);
        map[k] = <SearchHistoryItem>[];
        display[k] = item.keyword;
      }
      map[k]!.add(item);
    }
    final needle = query.trim().toLowerCase();
    return [
      for (final k in order)
        if (needle.isEmpty || k.contains(needle))
          HistoryGroup(key: k, keyword: display[k]!, items: map[k]!),
    ];
  }

  String siteNameOf(String siteId) {
    for (final s in torrentSites) {
      if (s.siteId == siteId) return s.siteName;
    }
    return siteId;
  }

  SearchState copyWith({
    SearchAccess? access,
    SearchVertical? vertical,
    String? query,
    String? submittedQuery,
    bool? browsing,
    List<String>? alsoKeywords,
    SearchScope? scope,
    List<SearchTab>? tabs,
    bool? tabsLoaded,
    List<SearchHistoryItem>? history,
    bool? historyLoading,
    bool? librarySearching,
    bool? libraryLoadingMore,
    Object? libraryError = _sentinel,
    List<LibrarySearchHit>? libraryHits,
    List<LibrarySearchPerson>? libraryPeople,
    List<SearchSuggestion>? librarySuggestions,
    Object? libraryNextCursor = _sentinel,
    bool? libraryIndexPending,
    bool? mediaSearching,
    Object? mediaSnapshotAt = _sentinel,
    Object? doubanHits = _sentinel,
    Object? doubanError = _sentinel,
    Object? tmdbHits = _sentinel,
    Object? tmdbError = _sentinel,
    TorrentStreamPhase? torrentPhase,
    Object? torrentFatalError = _sentinel,
    List<TorrentHit>? torrentItems,
    List<SiteProgress>? torrentSites,
    Object? torrentTotalElapsedMs = _sentinel,
    Object? torrentSnapshotAt = _sentinel,
    List<String>? torrentAlsoSearched,
    int? torrentPage,
    bool? torrentLoadingMore,
    bool? torrentExhausted,
    TorrentFilters? torrentFilters,
    TorrentSort? torrentSort,
    TorrentResultView? torrentView,
    TorrentFacets? torrentFacets,
    List<TorrentHit>? torrentFiltered,
    List<TorrentHit>? torrentSorted,
    Map<String, TorrentEntity>? torrentEntities,
    List<TorrentSortKey>? torrentSmartSortKeys,
    Map<String, TorrentSubmitState>? downloadStates,
    Map<String, TorrentSubmitState>? grabStates,
    Object? grabTarget = _sentinel,
  }) =>
      SearchState(
        access: access ?? this.access,
        vertical: vertical ?? this.vertical,
        query: query ?? this.query,
        submittedQuery: submittedQuery ?? this.submittedQuery,
        browsing: browsing ?? this.browsing,
        alsoKeywords: alsoKeywords ?? this.alsoKeywords,
        scope: scope ?? this.scope,
        tabs: tabs ?? this.tabs,
        tabsLoaded: tabsLoaded ?? this.tabsLoaded,
        history: history ?? this.history,
        historyLoading: historyLoading ?? this.historyLoading,
        librarySearching: librarySearching ?? this.librarySearching,
        libraryLoadingMore: libraryLoadingMore ?? this.libraryLoadingMore,
        libraryError: identical(libraryError, _sentinel)
            ? this.libraryError
            : libraryError as String?,
        libraryHits: libraryHits ?? this.libraryHits,
        libraryPeople: libraryPeople ?? this.libraryPeople,
        librarySuggestions: librarySuggestions ?? this.librarySuggestions,
        libraryNextCursor: identical(libraryNextCursor, _sentinel)
            ? this.libraryNextCursor
            : libraryNextCursor as String?,
        libraryIndexPending: libraryIndexPending ?? this.libraryIndexPending,
        mediaSearching: mediaSearching ?? this.mediaSearching,
        mediaSnapshotAt: identical(mediaSnapshotAt, _sentinel)
            ? this.mediaSnapshotAt
            : mediaSnapshotAt as String?,
        doubanHits: identical(doubanHits, _sentinel)
            ? this.doubanHits
            : doubanHits as List<MediaSearchHit>?,
        doubanError: identical(doubanError, _sentinel)
            ? this.doubanError
            : doubanError as String?,
        tmdbHits: identical(tmdbHits, _sentinel)
            ? this.tmdbHits
            : tmdbHits as List<MediaSearchHit>?,
        tmdbError: identical(tmdbError, _sentinel)
            ? this.tmdbError
            : tmdbError as String?,
        torrentPhase: torrentPhase ?? this.torrentPhase,
        torrentFatalError: identical(torrentFatalError, _sentinel)
            ? this.torrentFatalError
            : torrentFatalError as String?,
        torrentItems: torrentItems ?? this.torrentItems,
        torrentSites: torrentSites ?? this.torrentSites,
        torrentTotalElapsedMs: identical(torrentTotalElapsedMs, _sentinel)
            ? this.torrentTotalElapsedMs
            : torrentTotalElapsedMs as int?,
        torrentSnapshotAt: identical(torrentSnapshotAt, _sentinel)
            ? this.torrentSnapshotAt
            : torrentSnapshotAt as String?,
        torrentAlsoSearched: torrentAlsoSearched ?? this.torrentAlsoSearched,
        torrentPage: torrentPage ?? this.torrentPage,
        torrentLoadingMore: torrentLoadingMore ?? this.torrentLoadingMore,
        torrentExhausted: torrentExhausted ?? this.torrentExhausted,
        torrentFilters: torrentFilters ?? this.torrentFilters,
        torrentSort: torrentSort ?? this.torrentSort,
        torrentView: torrentView ?? this.torrentView,
        torrentFacets: torrentFacets ?? this.torrentFacets,
        torrentFiltered: torrentFiltered ?? this.torrentFiltered,
        torrentSorted: torrentSorted ?? this.torrentSorted,
        torrentEntities: torrentEntities ?? this.torrentEntities,
        torrentSmartSortKeys: torrentSmartSortKeys ?? this.torrentSmartSortKeys,
        downloadStates: downloadStates ?? this.downloadStates,
        grabStates: grabStates ?? this.grabStates,
        grabTarget: identical(grabTarget, _sentinel)
            ? this.grabTarget
            : grabTarget as ({int id, String title})?,
      );

  static const _sentinel = Object();
}

class SearchController extends Notifier<SearchState> {
  final _libraryDebounce = Debouncer(const Duration(milliseconds: 300));
  final _librarySeq = SeqGuard();
  final _mediaSeq = SeqGuard();
  final _historySeq = SeqGuard();
  final _grabTargetSeq = SeqGuard();
  int _torrentStreamSeq = 0;

  bool _routeArgsApplied = false;
  bool _userChangedVertical = false;
  Future<void>? _accessFuture;

  StreamSubscription<SseEvent>? _torrentSub;
  final List<StreamSubscription<SseEvent>> _auxSubs = [];
  final DownloadTargetPrefsStore prefsStore = DownloadTargetPrefsStore();

  McClient? _client;
  McClient get _mc => _client ??= McClient(session: ref.read(sessionStoreProvider));

  McSseClient get _sse => McSseClient(ref.read(sessionStoreProvider));

  @override
  SearchState build() {
    ref.watch(sessionGenerationProvider);
    _routeArgsApplied = false;
    _userChangedVertical = false;
    _accessFuture = null;
    ref.onDispose(() {
      _libraryDebounce.dispose();
      _cancelTorrentStreams();
    });
    Future.microtask(_bootstrap);
    return const SearchState();
  }

  void _cancelTorrentStreams() {
    _torrentSub?.cancel();
    _torrentSub = null;
    for (final s in _auxSubs) {
      s.cancel();
    }
    _auxSubs.clear();
  }

  Future<void> _bootstrap() async {
    await SearchModeMemory.instance.load();
    await _resolveAccess();
    if (!_routeArgsApplied && !_userChangedVertical) {
      final saved = SearchModeMemory.instance.mode;
      var nextVertical = saved != null
          ? SearchVertical.fromRouteTab(saved, fallback: state.vertical)
          : state.vertical;
      if (state.access.available.isNotEmpty &&
          !state.access.available.contains(nextVertical)) {
        nextVertical = state.access.available.first;
      }
      state = state.copyWith(vertical: nextVertical);
    }
    unawaited(_loadPresets());
    if (!_routeArgsApplied) {
      unawaited(loadHistory());
    }
    if (ref.read(permissionsProvider).isAdmin) {
      unawaited(prefsStore.refresh(_mc));
      unawaited(prefsStore.loadDirs(_mc));
    }
  }

  Future<void> _resolveAccess() {
    if (state.access.ready) return Future.value();
    return _accessFuture ??= _doResolveAccess().whenComplete(() {
      _accessFuture = null;
    });
  }

  Future<void> _doResolveAccess() async {
    final perms = ref.read(permissionsProvider);
    var canLib = perms.isAdmin;
    if (!canLib && ref.read(sessionStoreProvider).isReady) {
      try {
        final raw = await _mc.unwrap<dynamic>(
          Channel.general,
          'GET',
          '/api/v1/libraries',
          query: {'scope': 'all'},
        );
        final list = raw is List
            ? raw
            : (raw is Map
                ? (raw['libraries'] ?? raw['items'] ?? const [])
                    as List<dynamic>
                : const <dynamic>[]);
        canLib = list.isNotEmpty;
      } catch (_) {
        canLib = false;
      }
    }
    state = state.copyWith(
      access: SearchAccess(
        canMedia: perms.canSubscribe,
        canTorrent: perms.canSearch,
        canLibrary: canLib,
        ready: true,
      ),
    );
  }

  Future<void> _loadPresets() async {
    final perms = ref.read(permissionsProvider);
    if (!perms.isAdmin) {
      state = state.copyWith(
        tabs: SearchTab.defaults.where((t) => t.visible).toList(),
        tabsLoaded: true,
      );
      return;
    }
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/search/presets',
      );
      final list = <SearchTab>[];
      for (final el in (raw['presets'] as List<dynamic>? ?? const [])) {
        if (el is Map) {
          final tab = SearchTab.fromJson(Map<String, dynamic>.from(el));
          if (tab != null) list.add(tab);
        }
      }
      final effective = (list.isEmpty ? SearchTab.defaults : list)
          .where((t) => t.visible)
          .toList();
      state = state.copyWith(tabs: effective, tabsLoaded: true);
    } catch (_) {
      state = state.copyWith(
        tabs: SearchTab.defaults.where((t) => t.visible).toList(),
        tabsLoaded: true,
      );
    }
  }

  /// 清除从订阅手动选种进入的横幅上下文，防止泄漏到常规搜索。
  void clearGrabTarget() {
    _grabTargetSeq.next;
    if (state.grabTarget != null) {
      state = state.copyWith(grabTarget: null);
    }
  }

  /// 页面带 URL 参数进入（`?q=&tab=&scope=&also=&snapshot=&for_sub=&browse=1`）。
  Future<void> applyRouteArgs({
    String? query,
    String? tab,
    String? scopeEncoded,
    List<String> also = const [],
    int? snapshotId,
    int? forSubscriptionId,
    bool browse = false,
  }) async {
    _routeArgsApplied = true;
    if (!state.access.ready) {
      await _resolveAccess();
    }
    final perms = ref.read(permissionsProvider);
    final scope = SearchScope.decode(scopeEncoded);
    final q = (query ?? '').trim();

    // 手动选种目标订阅
    if (forSubscriptionId != null && perms.canGrabForSubscription) {
      unawaited(_loadGrabTarget(forSubscriptionId));
    } else if (forSubscriptionId == null) {
      clearGrabTarget();
    }

    var target = browse
        ? SearchVertical.torrent
        : (tab != null && tab.isNotEmpty
            ? SearchVertical.fromRouteTab(tab)
            : (forSubscriptionId != null
                ? SearchVertical.torrent
                : state.vertical));

    if (!browse &&
        state.access.available.isNotEmpty &&
        !state.access.available.contains(target)) {
      target = state.access.available.first;
    }

    state = state.copyWith(
      vertical: target,
      query: q,
      scope: scope,
      alsoKeywords: also,
      browsing: browse && target == SearchVertical.torrent,
      torrentView: scope.posterMode
          ? TorrentResultView.poster
          : TorrentResultView.group,
    );

    if (snapshotId != null) {
      if (target == SearchVertical.media) {
        await _loadMediaSnapshot(snapshotId, keyword: q);
      } else if (target == SearchVertical.torrent) {
        await _loadTorrentSnapshot(snapshotId, keyword: q);
      }
      return;
    }

    if (browse && target == SearchVertical.torrent) {
      await browseTorrents(scope: scope, keyword: q);
      return;
    }

    if (q.isNotEmpty) {
      await submitSearch(q, also: also, scope: scope);
    } else {
      await loadHistory();
    }
  }

  Future<void> _loadGrabTarget(int subscriptionId) async {
    final seq = _grabTargetSeq.next;
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/subscriptions/$subscriptionId',
      );
      if (!_grabTargetSeq.isCurrent(seq)) return;
      final media = raw['media'] is Map
          ? Map<String, dynamic>.from(raw['media'] as Map)
          : const <String, dynamic>{};
      final title = (media['title'] ?? raw['title'] ?? '订阅 #$subscriptionId')
          .toString();
      state = state.copyWith(grabTarget: (id: subscriptionId, title: title));
    } catch (_) {
      if (!_grabTargetSeq.isCurrent(seq)) return;
      state = state.copyWith(
        grabTarget: (id: subscriptionId, title: '订阅 #$subscriptionId'),
      );
    }
  }

  // ── 垂直 & 范围切换 ──

  Future<void> switchVertical(SearchVertical next) async {
    _userChangedVertical = true;
    if (next == state.vertical) return;
    if (!state.access.available.contains(next)) return;
    SearchModeMemory.instance.remember(next.name);

    final hadSnapshot =
        state.mediaSnapshotAt != null || state.torrentSnapshotAt != null;
    state = state.copyWith(
      vertical: next,
      browsing: next == SearchVertical.torrent ? state.browsing : false,
      mediaSnapshotAt: hadSnapshot ? null : state.mediaSnapshotAt,
      torrentSnapshotAt: hadSnapshot ? null : state.torrentSnapshotAt,
    );

    final q = (state.query.trim().isNotEmpty
            ? state.query
            : state.submittedQuery)
        .trim();
    if (q.isEmpty) {
      unawaited(loadHistory());
      return;
    }

    if (next == SearchVertical.library) {
      await _searchLibrary(q, fresh: true);
    } else if (next == SearchVertical.media &&
        (state.doubanHits == null || hadSnapshot || state.submittedQuery != q)) {
      await _searchMedia(q);
    } else if (next == SearchVertical.torrent &&
        (state.torrentPhase == TorrentStreamPhase.idle ||
            hadSnapshot ||
            state.submittedQuery != q)) {
      await _startTorrentStream(q, also: state.alsoKeywords, scope: state.scope);
    }
  }

  Future<void> switchScope(SearchScope next) async {
    if (next == state.scope && state.torrentSnapshotAt == null) return;
    state = state.copyWith(
      scope: next,
      torrentSnapshotAt: null,
      torrentView: next.posterMode
          ? TorrentResultView.poster
          : state.torrentView,
    );
    if (state.vertical == SearchVertical.torrent && state.showingResults) {
      final kw = state.browsing ? '' : state.submittedQuery;
      await _startTorrentStream(kw, also: state.alsoKeywords, scope: next);
    }
  }

  /// 输入框内容变动：媒体库实时防抖检索；影视/资源只更新输入并过滤历史列表。
  void onQueryChanged(String value) {
    state = state.copyWith(query: value);
    final q = value.trim();
    if (q.isEmpty) {
      _libraryDebounce.dispose();
      if (state.vertical == SearchVertical.library) {
        state = state.copyWith(
          librarySearching: false,
          libraryError: null,
          libraryHits: const [],
          libraryPeople: const [],
          librarySuggestions: const [],
          libraryNextCursor: null,
        );
      } else {
        // 回到搜索首页（历史 / 浏览最新资源）
        _cancelTorrentStreams();
        state = state.copyWith(
          submittedQuery: '',
          browsing: false,
          mediaSnapshotAt: null,
          torrentSnapshotAt: null,
          torrentPhase: TorrentStreamPhase.idle,
        );
        unawaited(loadHistory());
      }
      return;
    }
    if (state.vertical == SearchVertical.library && state.access.canLibrary) {
      _libraryDebounce(() => _searchLibrary(q, fresh: true));
    }
  }

  /// 提交搜索（PT 允许空关键词浏览最新资源；影视/媒体库空词不提交）。
  Future<void> submitSearch(
    String rawQuery, {
    List<String>? also,
    SearchScope? scope,
  }) async {
    final kw = rawQuery.trim();
    final effectiveScope = scope ?? state.scope;
    final effectiveAlso = also ?? state.alsoKeywords;

    if (state.vertical == SearchVertical.torrent) {
      if (!state.access.canTorrent) return;
      state = state.copyWith(
        query: kw,
        submittedQuery: kw,
        browsing: kw.isEmpty,
        scope: effectiveScope,
        alsoKeywords: effectiveAlso,
        torrentSnapshotAt: null,
        torrentView: effectiveScope.posterMode
            ? TorrentResultView.poster
            : TorrentResultView.group,
      );
      await _startTorrentStream(kw, also: effectiveAlso, scope: effectiveScope);
      return;
    }

    if (kw.isEmpty) return;
    state = state.copyWith(
      query: kw,
      submittedQuery: kw,
      browsing: false,
      mediaSnapshotAt: null,
    );
    if (state.vertical == SearchVertical.media) {
      if (!state.access.canMedia) return;
      await _searchMedia(kw);
    } else if (state.access.canLibrary) {
      await _searchLibrary(kw, fresh: true);
    }
  }

  /// 资源模式空关键词浏览分类/预设最新资源。
  Future<void> browseTorrents({
    required SearchScope scope,
    String keyword = '',
  }) async {
    if (!state.access.canTorrent) return;
    _userChangedVertical = true;
    final kw = keyword.trim();
    state = state.copyWith(
      vertical: SearchVertical.torrent,
      query: kw,
      submittedQuery: kw,
      browsing: kw.isEmpty,
      scope: scope,
      alsoKeywords: const [],
      torrentSnapshotAt: null,
      torrentView: scope.posterMode
          ? TorrentResultView.poster
          : TorrentResultView.group,
    );
    await _startTorrentStream(kw, also: const [], scope: scope);
  }

  // ── 服务端搜索历史 & 快照回放 ──

  Future<void> loadHistory() async {
    final hv = state.vertical.historyVertical;
    if (hv == null || !ref.read(sessionStoreProvider).isReady) {
      state = state.copyWith(history: const [], historyLoading: false);
      return;
    }
    final seq = _historySeq.next;
    state = state.copyWith(historyLoading: true);
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/search/history',
        query: {'limit': 20, 'vertical': hv},
      );
      if (!_historySeq.isCurrent(seq)) return;
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['items'] ?? raw['history'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      final parsed = [
        for (final el in list)
          if (el is Map) SearchHistoryItem.fromJson(Map<String, dynamic>.from(el)),
      ];
      state = state.copyWith(history: parsed, historyLoading: false);
    } catch (_) {
      if (_historySeq.isCurrent(seq)) {
        state = state.copyWith(historyLoading: false);
      }
    }
  }

  Future<void> deleteHistoryItem(int id) async {
    state = state.copyWith(
      history: state.history.where((e) => e.id != id).toList(),
    );
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/search/history/$id',
      );
    } catch (_) {}
    unawaited(loadHistory());
  }

  Future<void> deleteHistoryGroup(HistoryGroup group) async {
    final ids = {for (final i in group.items) i.id};
    state = state.copyWith(
      history: state.history.where((e) => !ids.contains(e.id)).toList(),
    );
    for (final id in ids) {
      try {
        await _mc.unwrap<dynamic>(
          Channel.general,
          'DELETE',
          '/api/v1/search/history/$id',
        );
      } catch (_) {}
    }
    unawaited(loadHistory());
  }

  Future<void> clearServerHistory() async {
    final hv = state.vertical.historyVertical;
    if (hv == null) return;
    state = state.copyWith(history: const []);
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/search/history',
        query: {'vertical': hv},
      );
    } catch (_) {}
    unawaited(loadHistory());
  }

  /// 点选一条历史记录：有快照则离线秒开快照，否则发起实时搜索。
  Future<void> openHistoryItem(SearchHistoryItem item) async {
    _userChangedVertical = true;
    if (item.vertical == 'titles') {
      state = state.copyWith(
        vertical: SearchVertical.media,
        query: item.keyword,
        submittedQuery: item.keyword,
        browsing: false,
      );
      if (item.hasSnapshot) {
        await _loadMediaSnapshot(item.id, keyword: item.keyword);
      } else {
        await _searchMedia(item.keyword);
      }
      return;
    }
    final scope = item.scope;
    state = state.copyWith(
      vertical: SearchVertical.torrent,
      query: item.keyword,
      submittedQuery: item.keyword,
      browsing: item.keyword.trim().isEmpty,
      alsoKeywords: item.alsoKeywords,
      scope: scope,
      torrentView: scope.posterMode
          ? TorrentResultView.poster
          : TorrentResultView.group,
    );
    if (item.hasSnapshot) {
      await _loadTorrentSnapshot(item.id, keyword: item.keyword);
    } else {
      await _startTorrentStream(
        item.keyword,
        also: item.alsoKeywords,
        scope: scope,
      );
    }
  }

  // ── 媒体库垂直搜索 ──

  Future<void> _searchLibrary(
    String query, {
    String? cursor,
    required bool fresh,
  }) async {
    final seq = _librarySeq.next;
    state = state.copyWith(
      librarySearching: fresh,
      libraryLoadingMore: !fresh,
      libraryError: null,
      submittedQuery: query,
      libraryNextCursor: fresh ? null : state.libraryNextCursor,
    );
    try {
      final body = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/search/library',
        query: {
          'q': query,
          'limit': 24,
          if (cursor != null) 'cursor': cursor,
        },
      );
      if (!_librarySeq.isCurrent(seq)) return;
      final incoming = <LibrarySearchHit>[
        for (final el in (body['items'] as List<dynamic>? ?? const []))
          if (el is Map) LibrarySearchHit.fromJson(Map<String, dynamic>.from(el)),
      ];
      final merged = fresh
          ? incoming
          : [
              ...state.libraryHits,
              for (final h in incoming)
                if (!state.libraryHits.any((e) => e.itemId == h.itemId)) h,
            ];
      state = state.copyWith(
        librarySearching: false,
        libraryLoadingMore: false,
        libraryHits: merged,
        libraryPeople: fresh
            ? [
                for (final el in (body['people'] as List<dynamic>? ?? const []))
                  if (el is Map)
                    LibrarySearchPerson.fromJson(Map<String, dynamic>.from(el)),
              ]
            : state.libraryPeople,
        librarySuggestions: fresh
            ? [
                for (final el
                    in (body['suggestions'] as List<dynamic>? ?? const []))
                  if (el is Map)
                    SearchSuggestion.fromJson(Map<String, dynamic>.from(el)),
              ]
            : state.librarySuggestions,
        libraryNextCursor: body['next_cursor']?.toString(),
        libraryIndexPending: body['index_pending'] == true,
      );
    } on ApiException catch (e) {
      if (!_librarySeq.isCurrent(seq)) return;
      if (cursor != null && e.httpStatus == 400) {
        await _searchLibrary(query, fresh: true);
        return;
      }
      state = state.copyWith(
        librarySearching: false,
        libraryLoadingMore: false,
        libraryError: e.friendlyMessage,
      );
    } catch (_) {
      if (!_librarySeq.isCurrent(seq)) return;
      state = state.copyWith(
        librarySearching: false,
        libraryLoadingMore: false,
        libraryError: '媒体库搜索失败，请稍后重试',
      );
    }
  }

  Future<void> loadMoreLibrary() async {
    final cursor = state.libraryNextCursor;
    if (cursor == null || state.libraryLoadingMore || state.librarySearching) {
      return;
    }
    final q = state.submittedQuery.isNotEmpty
        ? state.submittedQuery
        : state.query.trim();
    if (q.isEmpty) return;
    await _searchLibrary(q, cursor: cursor, fresh: false);
  }

  // ── 影视垂直搜索（POST /api/v1/search/titles provider='all' + 快照回放） ──

  Future<void> _loadMediaSnapshot(int historyId, {required String keyword}) async {
    final seq = _mediaSeq.next;
    state = state.copyWith(
      mediaSearching: true,
      mediaSnapshotAt: null,
      doubanHits: null,
      doubanError: null,
      tmdbHits: null,
      tmdbError: null,
    );
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/search/history/$historyId/results',
      );
      if (!_mediaSeq.isCurrent(seq)) return;
      if (raw['vertical']?.toString() != 'titles') {
        await _searchMedia(keyword);
        return;
      }
      final items = <MediaSearchHit>[
        for (final el in (raw['items'] as List<dynamic>? ?? const []))
          if (el is Map)
            if (MediaSearchHit.fromJson(Map<String, dynamic>.from(el))
                case final h?)
              h,
      ];
      state = state.copyWith(
        mediaSearching: false,
        mediaSnapshotAt: (raw['snapshot_at'] ?? '').toString(),
        doubanHits: items.where((e) => e.provider == 'douban').toList(),
        tmdbHits: items.where((e) => e.provider != 'douban').toList(),
      );
    } catch (_) {
      if (_mediaSeq.isCurrent(seq)) {
        await _searchMedia(keyword);
      }
    }
  }

  Future<void> researchMedia() async {
    final q = state.submittedQuery.isNotEmpty
        ? state.submittedQuery
        : state.query.trim();
    if (q.isEmpty) return;
    await _searchMedia(q);
  }

  Future<void> _searchMedia(String query) async {
    final seq = _mediaSeq.next;
    state = state.copyWith(
      mediaSearching: true,
      mediaSnapshotAt: null,
      submittedQuery: query,
      doubanHits: null,
      doubanError: null,
      tmdbHits: null,
      tmdbError: null,
    );
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/search/titles',
        body: {
          'query': query,
          'provider': 'all',
          'save_history': true,
        },
      );
      if (!_mediaSeq.isCurrent(seq)) return;
      final titles = <MediaSearchHit>[
        for (final el in (raw['titles'] as List<dynamic>? ?? const []))
          if (el is Map)
            if (MediaSearchHit.fromJson(Map<String, dynamic>.from(el))
                case final h?)
              h,
      ];
      String? doubanErr;
      String? tmdbErr;
      for (final el in (raw['providers'] as List<dynamic>? ?? const [])) {
        if (el is! Map) continue;
        final prov = (el['provider'] ?? '').toString();
        final ok = el['success'] != false;
        if (!ok) {
          final msg = (el['message'] ?? '').toString().trim();
          if (prov == 'douban') {
            doubanErr = msg.isNotEmpty ? msg : '豆瓣搜索暂时不可用';
          } else if (prov == 'tmdb') {
            tmdbErr = msg.isNotEmpty ? msg : 'TMDB 搜索暂时不可用';
          }
        }
      }
      state = state.copyWith(
        mediaSearching: false,
        doubanHits: titles.where((e) => e.provider == 'douban').toList(),
        tmdbHits: titles.where((e) => e.provider != 'douban').toList(),
        doubanError: doubanErr,
        tmdbError: tmdbErr,
      );
      unawaited(loadHistory());
    } on ApiException catch (e) {
      if (!_mediaSeq.isCurrent(seq)) return;
      state = state.copyWith(
        mediaSearching: false,
        doubanHits: const [],
        tmdbHits: const [],
        doubanError: e.friendlyMessage,
        tmdbError: e.friendlyMessage,
      );
    } catch (_) {
      if (!_mediaSeq.isCurrent(seq)) return;
      state = state.copyWith(
        mediaSearching: false,
        doubanHits: const [],
        tmdbHits: const [],
        doubanError: '影视检索失败，请检查网络连接',
        tmdbError: '影视检索失败，请检查网络连接',
      );
    }
  }

  // ── 站点资源 PT：SSE 流式搜索 + 快照回放 + 单站重试 + 跨站分页 ──

  void _applyTorrentRecompute({
    List<TorrentHit>? items,
    TorrentFilters? filters,
    TorrentSort? sort,
    TorrentResultView? view,
  }) {
    final nextItems = items ?? state.torrentItems;
    final nextFilters = filters ?? state.torrentFilters;
    final nextSort = sort ?? state.torrentSort;
    final filtered = nextItems
        .where((h) => TorrentSearchLogic.matches(h, nextFilters))
        .toList();
    final sorted = TorrentSearchLogic.sorted(filtered, nextSort);
    final facets = TorrentSearchLogic.facets(nextItems, nextFilters);
    final entities = TorrentSearchLogic.entities(nextItems);
    final smartKeys = TorrentSearchLogic.smartSortKeys(nextItems);

    state = state.copyWith(
      torrentItems: nextItems,
      torrentFilters: nextFilters,
      torrentSort: nextSort,
      torrentView: view ?? state.torrentView,
      torrentFiltered: filtered,
      torrentSorted: sorted,
      torrentFacets: facets,
      torrentEntities: entities,
      torrentSmartSortKeys: smartKeys,
    );
  }

  void setTorrentSort(TorrentSort sort) => _applyTorrentRecompute(sort: sort);

  void toggleTorrentFacet(TorrentFilterDim dim, String value) =>
      _applyTorrentRecompute(filters: state.torrentFilters.toggled(dim, value));

  void clearTorrentDim(TorrentFilterDim dim) =>
      _applyTorrentRecompute(filters: state.torrentFilters.cleared(dim));

  void clearAllTorrentFilters() =>
      _applyTorrentRecompute(filters: const TorrentFilters());

  void setTorrentView(TorrentResultView view) =>
      state = state.copyWith(torrentView: view);

  static bool _noMorePages(List<SiteProgress> statuses) =>
      statuses.isNotEmpty &&
      statuses.every(
        (s) => s.state == SiteProgressState.ok && s.hasMore == false,
      );

  Future<void> _loadTorrentSnapshot(
    int historyId, {
    required String keyword,
  }) async {
    _cancelTorrentStreams();
    final seq = ++_torrentStreamSeq;
    state = state.copyWith(
      torrentPhase: TorrentStreamPhase.connecting,
      torrentFatalError: null,
      torrentItems: const [],
      torrentSites: const [],
      torrentTotalElapsedMs: null,
      torrentSnapshotAt: null,
      torrentAlsoSearched: const [],
      torrentPage: 1,
      torrentExhausted: false,
      torrentFilters: const TorrentFilters(),
    );
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/search/history/$historyId/results',
      );
      if (seq != _torrentStreamSeq) return;
      if (raw['vertical']?.toString() != 'torrents') {
        await _startTorrentStream(
          keyword,
          also: state.alsoKeywords,
          scope: state.scope,
        );
        return;
      }
      final items = <TorrentHit>[
        for (final el in (raw['items'] as List<dynamic>? ?? const []))
          if (el is Map) TorrentHit.fromJson(Map<String, dynamic>.from(el)),
      ];
      final sites = <SiteProgress>[
        for (final el in (raw['sites'] as List<dynamic>? ?? const []))
          if (el is Map)
            SiteProgress.fromStatusJson(Map<String, dynamic>.from(el)),
      ];
      final also = <String>[
        for (final a in (raw['also_keywords'] as List<dynamic>? ?? const []))
          if (a != null && a.toString().trim().isNotEmpty) a.toString().trim(),
      ];
      state = state.copyWith(
        torrentPhase: TorrentStreamPhase.done,
        torrentSites: sites,
        torrentTotalElapsedMs: (raw['elapsed_ms'] as num?)?.toInt(),
        torrentSnapshotAt: (raw['snapshot_at'] ?? '').toString(),
        torrentAlsoSearched: also,
      );
      _applyTorrentRecompute(items: items);
    } on ApiException catch (e) {
      if (seq != _torrentStreamSeq) return;
      state = state.copyWith(
        torrentPhase: TorrentStreamPhase.error,
        torrentFatalError: e.friendlyMessage,
      );
    } catch (_) {
      if (seq != _torrentStreamSeq) return;
      await _startTorrentStream(
        keyword,
        also: state.alsoKeywords,
        scope: state.scope,
      );
    }
  }

  Future<void> researchTorrents() async {
    final kw = state.browsing ? '' : state.submittedQuery;
    state = state.copyWith(torrentSnapshotAt: null);
    await _startTorrentStream(
      kw,
      also: state.alsoKeywords,
      scope: state.scope,
    );
  }

  Future<void> _startTorrentStream(
    String keyword, {
    required List<String> also,
    required SearchScope scope,
  }) async {
    _cancelTorrentStreams();
    final seq = ++_torrentStreamSeq;
    state = state.copyWith(
      torrentPhase: TorrentStreamPhase.connecting,
      torrentFatalError: null,
      torrentItems: const [],
      torrentSites: const [],
      torrentTotalElapsedMs: null,
      torrentSnapshotAt: null,
      torrentAlsoSearched: const [],
      torrentPage: 1,
      torrentLoadingMore: false,
      torrentExhausted: false,
      torrentFilters: const TorrentFilters(),
      torrentFiltered: const [],
      torrentSorted: const [],
      torrentFacets: const TorrentFacets(),
      torrentEntities: const {},
    );

    final qs = scope.buildQueryString(
      keyword: keyword,
      alsoKeywords: also,
      page: 1,
    );
    final stream = _sse.stream(
      '/api/v1/search/torrents/stream?$qs',
      autoReconnect: false,
      terminalEvents: const {'done'},
      connectTimeout: const Duration(seconds: 15),
    );

    final completer = Completer<void>();
    _torrentSub = stream.listen(
      (event) {
        if (seq != _torrentStreamSeq) return;
        _handleStreamEvent(event);
      },
      onError: (Object err) async {
        if (seq != _torrentStreamSeq) return;
        if (err is SseUnsupportedException &&
            (err.statusCode == 404 || err.statusCode == 405)) {
          await _fallbackBlockingTorrentSearch(
            seq: seq,
            keyword: keyword,
            also: also,
            scope: scope,
          );
        } else if (err is ApiException) {
          state = state.copyWith(
            torrentPhase: TorrentStreamPhase.error,
            torrentFatalError: err.friendlyMessage,
          );
        } else {
          state = state.copyWith(
            torrentPhase: TorrentStreamPhase.error,
            torrentFatalError: '连接搜索服务失败，请检查网络或重试',
          );
        }
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (seq == _torrentStreamSeq &&
            state.torrentPhase != TorrentStreamPhase.done &&
            state.torrentPhase != TorrentStreamPhase.error) {
          state = state.copyWith(torrentPhase: TorrentStreamPhase.done);
        }
        if (seq == _torrentStreamSeq) {
          unawaited(loadHistory());
        }
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  void _handleStreamEvent(SseEvent event) {
    final json = event.decodeJson();
    if (json == null) return;
    switch (event.name) {
      case 'start':
        final sites = <SiteProgress>[
          for (final el in (json['sites'] as List<dynamic>? ?? const []))
            if (el is Map)
              SiteProgress(
                siteId: (el['site_id'] ?? '').toString(),
                siteName: (el['site_name'] ?? el['site_id'] ?? '').toString(),
                state: SiteProgressState.searching,
              ),
        ];
        final also = <String>[
          for (final a in (json['also_keywords'] as List<dynamic>? ?? const []))
            if (a != null && a.toString().trim().isNotEmpty) a.toString().trim(),
        ];
        state = state.copyWith(
          torrentPhase: TorrentStreamPhase.streaming,
          torrentSites: sites,
          torrentAlsoSearched: also,
        );
      case 'site_start':
        break;
      case 'site_result':
        final siteId = (json['site_id'] ?? '').toString();
        final count = (json['count'] as num?)?.toInt() ?? 0;
        final elapsed = (json['elapsed_ms'] as num?)?.toInt();
        final hits = <TorrentHit>[
          for (final el in (json['items'] as List<dynamic>? ?? const []))
            if (el is Map) TorrentHit.fromJson(Map<String, dynamic>.from(el)),
        ];
        final updatedSites = _patchSite(
          state.torrentSites,
          siteId,
          (s) => s.copyWith(
            state: SiteProgressState.ok,
            count: count,
            error: null,
            elapsedMs: elapsed,
          ),
        );
        state = state.copyWith(torrentSites: updatedSites);
        _applyTorrentRecompute(items: [...state.torrentItems, ...hits]);
      case 'site_error':
        final siteId = (json['site_id'] ?? '').toString();
        final err = (json['error'] ?? '站点请求失败').toString();
        final elapsed = (json['elapsed_ms'] as num?)?.toInt();
        state = state.copyWith(
          torrentSites: _patchSite(
            state.torrentSites,
            siteId,
            (s) => s.copyWith(
              state: SiteProgressState.error,
              error: err,
              elapsedMs: elapsed,
            ),
          ),
        );
      case 'done':
        final elapsed = (json['elapsed_ms'] as num?)?.toInt();
        final statuses = <SiteProgress>[
          for (final el in (json['sites'] as List<dynamic>? ?? const []))
            if (el is Map)
              SiteProgress.fromStatusJson(Map<String, dynamic>.from(el)),
        ];
        state = state.copyWith(
          torrentPhase: TorrentStreamPhase.done,
          torrentTotalElapsedMs: elapsed,
          torrentSites: statuses.isNotEmpty ? statuses : state.torrentSites,
          torrentExhausted: _noMorePages(statuses),
        );
      default:
        break;
    }
  }

  List<SiteProgress> _patchSite(
    List<SiteProgress> list,
    String siteId,
    SiteProgress Function(SiteProgress) fn,
  ) =>
      [for (final s in list) s.siteId == siteId ? fn(s) : s];

  /// 流式端点 404 回退传统 `GET /api/v1/search/torrents`。
  Future<void> _fallbackBlockingTorrentSearch({
    required int seq,
    required String keyword,
    required List<String> also,
    required SearchScope scope,
  }) async {
    try {
      final qs = scope.buildQueryString(
        keyword: keyword,
        alsoKeywords: also,
        page: 1,
      );
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/search/torrents?$qs',
      );
      if (seq != _torrentStreamSeq) return;
      final hits = <TorrentHit>[
        for (final el in (raw['items'] as List<dynamic>? ?? const []))
          if (el is Map) TorrentHit.fromJson(Map<String, dynamic>.from(el)),
      ];
      final sites = <SiteProgress>[
        for (final el in (raw['sites'] as List<dynamic>? ?? const []))
          if (el is Map)
            SiteProgress.fromStatusJson(Map<String, dynamic>.from(el)),
      ];
      final alsoResp = <String>[
        for (final a in (raw['also_keywords'] as List<dynamic>? ?? const []))
          if (a != null && a.toString().trim().isNotEmpty) a.toString().trim(),
      ];
      state = state.copyWith(
        torrentPhase: TorrentStreamPhase.done,
        torrentSites: sites,
        torrentAlsoSearched: alsoResp,
        torrentExhausted: _noMorePages(sites),
      );
      _applyTorrentRecompute(items: hits);
      unawaited(loadHistory());
    } on ApiException catch (e) {
      if (seq != _torrentStreamSeq) return;
      state = state.copyWith(
        torrentPhase: TorrentStreamPhase.error,
        torrentFatalError: e.friendlyMessage,
      );
    } catch (_) {
      if (seq != _torrentStreamSeq) return;
      state = state.copyWith(
        torrentPhase: TorrentStreamPhase.error,
        torrentFatalError: '种子检索失败，请确认已配置可用 PT 站点',
      );
    }
  }

  /// 单站重试（对齐 iOS `TorrentSearchModel.retrySite`）。
  void retrySite(String siteId) {
    final seq = _torrentStreamSeq;
    final remaining =
        state.torrentItems.where((h) => h.siteId != siteId).toList();
    state = state.copyWith(
      torrentSites: _patchSite(
        state.torrentSites,
        siteId,
        (s) => s.copyWith(
          state: SiteProgressState.searching,
          count: 0,
          error: null,
          elapsedMs: null,
        ),
      ),
    );
    _applyTorrentRecompute(items: remaining);

    final single = state.scope.copyWith(siteIds: [siteId]);
    final kw = state.browsing ? '' : state.submittedQuery;
    final qs = single.buildQueryString(
      keyword: kw,
      alsoKeywords: state.alsoKeywords,
      page: 1,
    );
    late StreamSubscription<SseEvent> sub;
    sub = _sse
        .stream(
          '/api/v1/search/torrents/stream?$qs',
          autoReconnect: false,
          terminalEvents: const {'done'},
        )
        .listen(
      (ev) {
        if (seq != _torrentStreamSeq) return;
        final json = ev.decodeJson();
        if (json == null) return;
        if (ev.name == 'site_result') {
          final id = (json['site_id'] ?? siteId).toString();
          final count = (json['count'] as num?)?.toInt() ?? 0;
          final elapsed = (json['elapsed_ms'] as num?)?.toInt();
          final hits = <TorrentHit>[
            for (final el in (json['items'] as List<dynamic>? ?? const []))
              if (el is Map) TorrentHit.fromJson(Map<String, dynamic>.from(el)),
          ];
          state = state.copyWith(
            torrentSites: _patchSite(
              state.torrentSites,
              id,
              (s) => s.copyWith(
                state: SiteProgressState.ok,
                count: count,
                error: null,
                elapsedMs: elapsed,
              ),
            ),
          );
          _applyTorrentRecompute(items: [...state.torrentItems, ...hits]);
        } else if (ev.name == 'site_error') {
          final id = (json['site_id'] ?? siteId).toString();
          final err = (json['error'] ?? '重试失败').toString();
          final elapsed = (json['elapsed_ms'] as num?)?.toInt();
          state = state.copyWith(
            torrentSites: _patchSite(
              state.torrentSites,
              id,
              (s) => s.copyWith(
                state: SiteProgressState.error,
                error: err,
                elapsedMs: elapsed,
              ),
            ),
          );
        }
      },
      onError: (_) {
        _auxSubs.remove(sub);
        if (seq != _torrentStreamSeq) return;
        state = state.copyWith(
          torrentSites: _patchSite(
            state.torrentSites,
            siteId,
            (s) => s.state == SiteProgressState.searching
                ? s.copyWith(state: SiteProgressState.error, error: '重试失败')
                : s,
          ),
        );
      },
      onDone: () {
        _auxSubs.remove(sub);
        if (seq != _torrentStreamSeq) return;
        state = state.copyWith(
          torrentSites: _patchSite(
            state.torrentSites,
            siteId,
            (s) => s.state == SiteProgressState.searching
                ? s.copyWith(state: SiteProgressState.error, error: '重试失败')
                : s,
          ),
        );
      },
    );
    _auxSubs.add(sub);
  }

  /// 跨站分页加载第 N 页（去重合并，对齐 iOS `TorrentSearchModel.loadMore`）。
  void loadMoreTorrents() {
    if (state.torrentLoadingMore ||
        state.torrentExhausted ||
        state.torrentPhase != TorrentStreamPhase.done ||
        state.torrentSnapshotAt != null) {
      return;
    }
    final seq = _torrentStreamSeq;
    final next = state.torrentPage + 1;
    state = state.copyWith(torrentLoadingMore: true);

    final kw = state.browsing ? '' : state.submittedQuery;
    final qs = state.scope.buildQueryString(
      keyword: kw,
      alsoKeywords: state.alsoKeywords,
      page: next,
    );
    var added = 0;
    var lastPage = false;

    late StreamSubscription<SseEvent> sub;
    sub = _sse
        .stream(
          '/api/v1/search/torrents/stream?$qs',
          autoReconnect: false,
          terminalEvents: const {'done'},
        )
        .listen(
      (ev) {
        if (seq != _torrentStreamSeq) return;
        final json = ev.decodeJson();
        if (json == null) return;
        if (ev.name == 'done') {
          final statuses = <SiteProgress>[
            for (final el in (json['sites'] as List<dynamic>? ?? const []))
              if (el is Map)
                SiteProgress.fromStatusJson(Map<String, dynamic>.from(el)),
          ];
          lastPage = _noMorePages(statuses);
        } else if (ev.name == 'site_result') {
          final seen = {for (final h in state.torrentItems) h.rowKey};
          final fresh = <TorrentHit>[];
          for (final el in (json['items'] as List<dynamic>? ?? const [])) {
            if (el is Map) {
              final h = TorrentHit.fromJson(Map<String, dynamic>.from(el));
              if (seen.add(h.rowKey)) fresh.add(h);
            }
          }
          if (fresh.isNotEmpty) {
            added += fresh.length;
            _applyTorrentRecompute(items: [...state.torrentItems, ...fresh]);
          }
        }
      },
      onError: (_) {
        _auxSubs.remove(sub);
        if (seq == _torrentStreamSeq) {
          state = state.copyWith(torrentLoadingMore: false);
        }
      },
      onDone: () {
        _auxSubs.remove(sub);
        if (seq != _torrentStreamSeq) return;
        state = state.copyWith(
          torrentLoadingMore: false,
          torrentPage: next,
          torrentExhausted: added == 0 || lastPage,
        );
      },
    );
    _auxSubs.add(sub);
  }

  // ── 下载与投给订阅状态更新 ──

  void setDownloadState(String hitKey, TorrentSubmitState next) {
    state = state.copyWith(
      downloadStates: {...state.downloadStates, hitKey: next},
    );
  }

  Future<void> refreshDownloadPrefs() async {
    if (!ref.read(permissionsProvider).isAdmin) return;
    await prefsStore.refresh(_mc);
  }

  Future<void> forgetDownloadPref(String category) async {
    await prefsStore.forget(category, _mc);
  }

  /// 按记忆直接提交（确认条「确认下载」）：返回 `(result, needsFullDialog, error)`。
  Future<({DownloadSubmitResult? result, bool needsDialog, String? error})>
      confirmRememberedDownload(
    DownloadTargetRequest request,
    DownloadTargetPref pref,
  ) async {
    setDownloadState(request.hitKey, TorrentSubmitState.submitting);
    try {
      final res = await submitRememberedDownload(_mc, request, pref);
      if (res == null) {
        setDownloadState(request.hitKey, TorrentSubmitState.idle);
        return (result: null, needsDialog: true, error: null);
      }
      setDownloadState(
        request.hitKey,
        res.alreadyExists ? TorrentSubmitState.exists : TorrentSubmitState.done,
      );
      return (result: res, needsDialog: false, error: null);
    } on ApiException catch (e) {
      setDownloadState(request.hitKey, TorrentSubmitState.error);
      return (result: null, needsDialog: false, error: e.friendlyMessage);
    } catch (_) {
      setDownloadState(request.hitKey, TorrentSubmitState.error);
      return (result: null, needsDialog: false, error: '提交下载失败，请稍后重试');
    }
  }

  /// 手动选种：投给指定订阅（`POST /api/v1/subscriptions/{id}/selected-torrent-downloads`）。
  Future<({int? unitCount, String? error})> grabForSubscription(
    TorrentHit hit,
  ) async {
    final target = state.grabTarget;
    if (target == null) return (unitCount: null, error: '缺少目标订阅');
    final cur = state.grabStates[hit.rowKey] ?? TorrentSubmitState.idle;
    if (cur == TorrentSubmitState.submitting || cur == TorrentSubmitState.done) {
      return (unitCount: null, error: null);
    }
    state = state.copyWith(
      grabStates: {...state.grabStates, hit.rowKey: TorrentSubmitState.submitting},
    );
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/subscriptions/${target.id}/selected-torrent-downloads',
        body: {
          'site_id': hit.siteId,
          'torrent_id': hit.torrentId,
          'title': hit.title,
          'subtitle': hit.subtitle,
          if (hit.category != null) 'category': hit.category,
          if (hit.rawAttrs != null)
            'attrs': hit.rawAttrs
          else if (hit.attrs != null)
            'attrs': hit.attrs!.toJson(),
          if (hit.downloadUrl != null) 'download_url': hit.downloadUrl,
          'size_bytes': hit.sizeBytes,
          'seeders': hit.seeders,
          'is_free': hit.free,
          if (hit.hitAndRun != null) 'hit_and_run': hit.hitAndRun,
          if (hit.uploadTime != null) 'publish_time': hit.uploadTime,
        },
      );
      final units = (raw['units'] as List<dynamic>? ?? const []).length;
      state = state.copyWith(
        grabStates: {...state.grabStates, hit.rowKey: TorrentSubmitState.done},
      );
      return (unitCount: units, error: null);
    } on ApiException catch (e) {
      state = state.copyWith(
        grabStates: {...state.grabStates, hit.rowKey: TorrentSubmitState.error},
      );
      return (unitCount: null, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(
        grabStates: {...state.grabStates, hit.rowKey: TorrentSubmitState.error},
      );
      return (unitCount: null, error: '投给订阅失败，请稍后重试');
    }
  }
}

final searchProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
