import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exception.dart';
import 'collection_detail_controller.dart';
import 'mc_api.dart';
import 'models.dart';

/* ────────────────────── 影人详情（GET /api/v1/people/{tmdbPersonId}） ────────────────────── */

class PersonState {
  const PersonState({
    this.loading = false,
    this.error,
    this.notFound = false,
    this.person,
  });

  final bool loading;
  final String? error;
  final bool notFound;
  final PersonView? person;

  PersonState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    bool? notFound,
    PersonView? person,
  }) =>
      PersonState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        notFound: notFound ?? this.notFound,
        person: person ?? this.person,
      );
}

class PersonArg {
  const PersonArg({required this.personId, this.personName});

  final int personId;
  final String? personName;

  @override
  bool operator ==(Object other) =>
      other is PersonArg &&
      other.personId == personId &&
      other.personName == personName;

  @override
  int get hashCode => Object.hash(personId, personName);
}

class PersonController
    extends AutoDisposeFamilyNotifier<PersonState, PersonArg> {
  @override
  PersonState build(PersonArg arg) {
    Future.microtask(load);
    return const PersonState(loading: true);
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true, notFound: false);
    try {
      final person = await _api.personDetail(arg.personId);
      state = state.copyWith(loading: false, person: person);
    } on ApiException catch (e) {
      if (e.httpStatus == 404) {
        state = state.copyWith(loading: false, notFound: true);
      } else {
        state = state.copyWith(loading: false, error: '加载失败：${e.message}');
      }
    } catch (_) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }
}

final personProvider = NotifierProvider.autoDispose
    .family<PersonController, PersonState, PersonArg>(PersonController.new);

/* ────────────────────── 跨库类型墙（movie / tv / video） ────────────────────── */

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
    this.reversed = false,
    this.watch,
    this.endReached = false,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;
  final LibraryKindSummaryView? summary;
  final List<LibraryKindGenreView> genres;
  final String? genre;
  final String sort;
  final bool reversed;
  final String? watch; // null | unwatched | unfinished | seen
  final List<LibraryItemView> items;
  final bool endReached;

  String? get orderParam =>
      wallSortMetaOf(sort).orderParam(reversed: reversed);

  KindWallState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    LibraryKindSummaryView? summary,
    List<LibraryKindGenreView>? genres,
    String? genre,
    bool clearGenre = false,
    String? sort,
    bool? reversed,
    String? watch,
    bool clearWatch = false,
    List<LibraryItemView>? items,
    bool? endReached,
  }) =>
      KindWallState(
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        summary: summary ?? this.summary,
        genres: genres ?? this.genres,
        genre: clearGenre ? null : (genre ?? this.genre),
        sort: sort ?? this.sort,
        reversed: reversed ?? this.reversed,
        watch: clearWatch ? null : (watch ?? this.watch),
        items: items ?? this.items,
        endReached: endReached ?? this.endReached,
      );
}

class KindWallArg {
  const KindWallArg({
    required this.kind,
    this.initialGenre,
    this.initialWatch,
    this.initialSort,
    this.initialOrder,
  });

  final String kind; // movie | tv | video
  final String? initialGenre;
  final String? initialWatch;
  final String? initialSort;
  final String? initialOrder;

  @override
  bool operator ==(Object other) =>
      other is KindWallArg &&
      other.kind == kind &&
      other.initialGenre == initialGenre &&
      other.initialWatch == initialWatch &&
      other.initialSort == initialSort &&
      other.initialOrder == initialOrder;

  @override
  int get hashCode =>
      Object.hash(kind, initialGenre, initialWatch, initialSort, initialOrder);
}

class KindWallController
    extends AutoDisposeFamilyNotifier<KindWallState, KindWallArg> {
  String get _sortPrefKey => 'movieclaw.library.kind-wall-sort.${arg.kind}';

  static List<WallSortMeta> sortOptionsFor(String kind) {
    const base = [
      'added_at',
      'title',
      'release_date',
      'rating',
      'runtime',
      'size',
      'last_played',
    ];
    final keys = kind == 'video'
        ? base.where((k) => k != 'rating' && k != 'release_date')
        : base;
    return keys.map(wallSortMetaOf).toList();
  }

  @override
  KindWallState build(KindWallArg arg) {
    final initSort =
        (arg.initialSort != null && arg.initialSort!.isNotEmpty)
            ? arg.initialSort!
            : 'added_at';
    final initRev = arg.initialOrder != null
        ? (wallSortMetaOf(initSort).naturalAsc
            ? arg.initialOrder == 'desc'
            : arg.initialOrder == 'asc')
        : false;
    Future.microtask(load);
    return KindWallState(
      loading: true,
      genre: arg.initialGenre,
      watch: arg.initialWatch,
      sort: initSort,
      reversed: initRev,
    );
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> _hydrateSortIfNoExplicit() async {
    if (arg.initialSort != null && arg.initialSort!.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sortPrefKey);
      if (raw == null || raw.isEmpty) return;
      final rev = raw.endsWith(':rev');
      final base = rev ? raw.substring(0, raw.length - 4) : raw;
      final allowed = sortOptionsFor(arg.kind).map((e) => e.value).toSet();
      if (allowed.contains(base)) {
        state = state.copyWith(sort: base, reversed: rev);
      }
    } catch (_) {}
  }

  Future<void> _persistSort(String sort, bool reversed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortPrefKey, reversed ? '$sort:rev' : sort);
    } catch (_) {}
  }

  Future<void> load() async {
    await _hydrateSortIfNoExplicit();
    if (arg.kind != 'video') {
      _api.libraryKindGenresTyped(arg.kind).then((list) {
        state = state.copyWith(genres: list);
      }).catchError((_) {});
    }
    await reload();
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, endReached: false, clearError: true);
    try {
      final results = await Future.wait([
        _api
            .libraryKindSummary(
              arg.kind,
              genres: state.genre,
              watch: state.watch,
            )
            .catchError((_) => const LibraryKindSummaryView()),
        _api.libraryKindItems(
          arg.kind,
          limit: 60,
          offset: 0,
          sort: state.sort,
          order: state.orderParam,
          watch: state.watch,
          genres: state.genre,
        ),
      ]);
      final summary = results[0] as LibraryKindSummaryView;
      final items = results[1] as List<LibraryItemView>;
      state = state.copyWith(
        loading: false,
        summary: summary,
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
      final more = await _api.libraryKindItems(
        arg.kind,
        limit: 60,
        offset: state.items.length,
        sort: state.sort,
        order: state.orderParam,
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

  Future<void> setGenre(String? genre) async {
    state = state.copyWith(genre: genre, clearGenre: genre == null);
    await reload();
  }

  Future<void> setSort(String sort, {bool reversed = false}) async {
    state = state.copyWith(sort: sort, reversed: reversed);
    await _persistSort(sort, reversed);
    await reload();
  }

  Future<void> toggleDirection() async {
    final nextRev = !state.reversed;
    state = state.copyWith(reversed: nextRev);
    await _persistSort(state.sort, nextRev);
    await reload();
  }

  Future<void> setWatch(String? watch) async {
    state = state.copyWith(watch: watch, clearWatch: watch == null);
    await reload();
  }
}

final kindWallProvider = NotifierProvider.autoDispose
    .family<KindWallController, KindWallState, KindWallArg>(
  KindWallController.new,
);
