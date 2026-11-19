// IMPLEMENTED — 1:1 重写自 MovieClaw feature/search/SearchViewModel.kt（库内搜索分支）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/notify/debounce_guard.dart';
import 'search_mode_memory.dart';

/// 一条命中：条目 + 它在哪些库 + 为什么命中（LibrarySearchHit）。
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
    final itemMap = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final match = o['match'];
    final matchMap = match is Map ? Map<String, dynamic>.from(match) : <String, dynamic>{};
    return LibrarySearchHit(
      itemId: (itemMap['id'] as num? ?? 0).toInt(),
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

  static LibrarySearchPerson fromJson(Map<String, dynamic> o) => LibrarySearchPerson(
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

/// 搜索页状态（对齐 SearchViewModel.UiState 的库内搜索部分）。
class SearchState {
  const SearchState({
    this.mode = 'library',
    this.query = '',
    this.searching = false,
    this.error,
    this.submittedQuery = '',
    this.hits = const [],
    this.people = const [],
    this.suggestions = const [],
    this.nextCursor,
    this.indexPending = false,
    this.selectedPerson,
    this.history = const [],
  });

  final String mode;
  final String query;
  final bool searching;
  final String? error;
  final String submittedQuery;
  final List<LibrarySearchHit> hits;
  final List<LibrarySearchPerson> people;
  final List<SearchSuggestion> suggestions;
  final String? nextCursor;
  final bool indexPending;
  final LibrarySearchPerson? selectedPerson;
  final List<String> history;

  SearchState copyWith({
    String? mode,
    String? query,
    bool? searching,
    Object? error = _sentinel,
    String? submittedQuery,
    List<LibrarySearchHit>? hits,
    List<LibrarySearchPerson>? people,
    List<SearchSuggestion>? suggestions,
    Object? nextCursor = _sentinel,
    bool? indexPending,
    Object? selectedPerson = _sentinel,
    List<String>? history,
  }) =>
      SearchState(
        mode: mode ?? this.mode,
        query: query ?? this.query,
        searching: searching ?? this.searching,
        error: identical(error, _sentinel) ? this.error : error as String?,
        submittedQuery: submittedQuery ?? this.submittedQuery,
        hits: hits ?? this.hits,
        people: people ?? this.people,
        suggestions: suggestions ?? this.suggestions,
        nextCursor: identical(nextCursor, _sentinel) ? this.nextCursor : nextCursor as String?,
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
  final _seq = SeqGuard(); // 请求序号校验：只允许最后一次请求更新界面
  McClient? _client;
  McClient get _mc => _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  SearchState build() {
    ref.onDispose(_debounce.dispose);
    Future.microtask(() async {
      await SearchModeMemory.instance.load();
      if (SearchModeMemory.instance.mode != null) {
        state = state.copyWith(mode: SearchModeMemory.instance.mode);
      }
      await _loadHistory();
    });
    return const SearchState();
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
        nextCursor: null,
        selectedPerson: null,
      );
      return;
    }
    // 防抖 350ms：连打字只查最后一次（旧请求靠 _seq 作废）。
    _debounce(() => search(q));
  }

  /// 立即搜索（提交/点历史词）。写历史记录。
  Future<void> search(String q, {String? cursor}) async {
    final query = q.trim();
    if (query.isEmpty) return;
    await _doSearch(query, cursor: cursor, fresh: cursor == null);
    if (cursor == null) await _rememberHistory(query);
  }

  Future<void> _doSearch(String query, {String? cursor, required bool fresh}) async {
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
            if (el is Map) LibrarySearchHit.fromJson(Map<String, dynamic>.from(el)),
        ],
        people: [
          for (final el in (body['people'] as List<dynamic>? ?? const []))
            if (el is Map) LibrarySearchPerson.fromJson(Map<String, dynamic>.from(el)),
        ],
        suggestions: [
          for (final el in (body['suggestions'] as List<dynamic>? ?? const []))
            if (el is Map) SearchSuggestion.fromJson(Map<String, dynamic>.from(el)),
        ],
        nextCursor: body['next_cursor']?.toString(),
        indexPending: body['index_pending'] == true,
      );
    } on ApiException catch (e) {
      if (!_seq.isCurrent(seq)) return;
      // 游标过期/权限变化返回 400 → 自动重新搜索（fresh，不带游标）。
      if (cursor != null && (e.httpStatus == 400)) {
        await _doSearch(query, fresh: true);
        return;
      }
      state = state.copyWith(searching: false, error: e.friendlyMessage);
    } catch (_) {
      if (!_seq.isCurrent(seq)) return;
      state = state.copyWith(searching: false, error: '网络错误，请稍后重试');
    }
  }

  /// 人物行点击 → 下钻这个人的库内作品。
  Future<void> selectPerson(LibrarySearchPerson p) async {
    state = state.copyWith(selectedPerson: p);
    await _doSearch(state.submittedQuery.isEmpty ? state.query : state.submittedQuery, fresh: true);
  }

  Future<void> clearPerson() async {
    state = state.copyWith(selectedPerson: null);
    await _doSearch(state.submittedQuery.isEmpty ? state.query : state.submittedQuery, fresh: true);
  }

  void rememberMode(String mode) {
    state = state.copyWith(mode: mode);
    SearchModeMemory.instance.remember(mode);
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

final searchProvider = NotifierProvider<SearchController, SearchState>(SearchController.new);
