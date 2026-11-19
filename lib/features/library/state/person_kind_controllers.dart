import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_api.dart';
import 'models.dart';

/// 人物下钻状态（对齐 Kotlin LibraryPersonScreen.kt：GET /search/library?person_id 游标分页）。
class PersonState {
  const PersonState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.items = const [],
    this.nextCursor,
    this.indexPending = false,
    this.endReached = false,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;
  final List<LibrarySearchHit> items;
  final String? nextCursor;
  final bool indexPending;
  final bool endReached;

  PersonState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    List<LibrarySearchHit>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? indexPending,
    bool? endReached,
  }) =>
      PersonState(
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        indexPending: indexPending ?? this.indexPending,
        endReached: endReached ?? this.endReached,
      );
}

class PersonArg {
  const PersonArg({required this.personId, this.personName});

  final int personId;
  final String? personName;

  @override
  bool operator ==(Object other) =>
      other is PersonArg && other.personId == personId && other.personName == personName;

  @override
  int get hashCode => Object.hash(personId, personName);
}

class PersonController extends AutoDisposeFamilyNotifier<PersonState, PersonArg> {
  @override
  PersonState build(PersonArg arg) {
    Future.microtask(() => load());
    return const PersonState();
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final view = await _api.searchLibraryByPerson(arg.personId, limit: 60);
      state = state.copyWith(
        loading: false,
        items: view.items,
        nextCursor: view.nextCursor,
        indexPending: view.indexPending,
        endReached: view.nextCursor == null,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || state.nextCursor == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final view = await _api.searchLibraryByPerson(
        arg.personId,
        limit: 60,
        cursor: state.nextCursor,
      );
      state = state.copyWith(
        loadingMore: false,
        items: [...state.items, ...view.items],
        nextCursor: view.nextCursor,
        indexPending: view.indexPending,
        endReached: view.nextCursor == null,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }
}

final personProvider =
    NotifierProvider.autoDispose.family<PersonController, PersonState, PersonArg>(
        PersonController.new);

/// 类型墙状态（对齐 Kotlin KindWallScreen.kt：跨库 kind + genres 筛选的墙）。
class KindWallState {
  const KindWallState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.summary,
    this.genres = const [],
    this.items = const [],
    this.genre,
    this.sort = 'added_at',
    this.order,
    this.watch,
    this.endReached = false,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;

  /// 跨库部数（计数单源：/libraries/kinds/{kind}）。
  final LibraryKindSummaryView? summary;

  /// 可选的类型筛选（来自 /libraries/kinds/{kind}/genres 的 TMDB 类型块）。
  final List<Map<String, dynamic>> genres;
  final String? genre;
  final String sort;
  final String? order;
  final String? watch;
  final List<LibraryItemView> items;
  final bool endReached;

  KindWallState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    LibraryKindSummaryView? summary,
    List<Map<String, dynamic>>? genres,
    String? genre,
    bool clearGenre = false,
    String? sort,
    String? order,
    bool clearOrder = false,
    String? watch,
    bool clearWatch = false,
    List<LibraryItemView>? items,
    bool? endReached,
  }) =>
      KindWallState(
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
        summary: summary ?? this.summary,
        genres: genres ?? this.genres,
        genre: clearGenre ? null : (genre ?? this.genre),
        sort: sort ?? this.sort,
        order: clearOrder ? null : (order ?? this.order),
        watch: clearWatch ? null : (watch ?? this.watch),
        items: items ?? this.items,
        endReached: endReached ?? this.endReached,
      );
}

class KindWallArg {
  const KindWallArg({required this.kind});

  /// movie / tv
  final String kind;

  @override
  bool operator ==(Object other) => other is KindWallArg && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

class KindWallController extends AutoDisposeFamilyNotifier<KindWallState, KindWallArg> {
  @override
  KindWallState build(KindWallArg arg) {
    Future.microtask(() => load());
    return const KindWallState();
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final summary = await _api.libraryKindSummary(arg.kind);
      state = state.copyWith(loading: false, summary: summary);
    } catch (_) {}
    try {
      state = state.copyWith(genres: await _api.libraryKindGenres(arg.kind));
    } catch (_) {}
    await reload();
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, endReached: false);
    try {
      final items = await _api.libraryKindItems(
        arg.kind,
        sort: state.sort,
        order: state.order,
        watch: state.watch,
        genres: state.genre,
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
      final more = await _api.libraryKindItems(
        arg.kind,
        offset: state.items.length,
        sort: state.sort,
        order: state.order,
        watch: state.watch,
        genres: state.genre,
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

  void setGenre(String? genre) {
    state = state.copyWith(genre: genre, clearGenre: genre == null);
    reload();
  }

  void setSort(String sort, String? order) {
    state = state.copyWith(sort: sort, order: order, clearOrder: order == null);
    reload();
  }

  void setWatch(String? watch) {
    state = state.copyWith(watch: watch, clearWatch: watch == null);
    reload();
  }
}

final kindWallProvider =
    NotifierProvider.autoDispose.family<KindWallController, KindWallState, KindWallArg>(
        KindWallController.new);
