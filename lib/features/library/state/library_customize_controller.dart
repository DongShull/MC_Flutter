import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_rows.dart';
import 'mc_api.dart';
import 'models.dart';

/// 自定义首页状态（对齐 Kotlin LibraryCustomizeScreen.kt）：
/// 持有完整的行清单（含隐藏行）、未落盘的本地编辑、以及每行的取数结果。
class CustomizeState {
  const CustomizeState({
    this.loading = false,
    this.error,
    this.rows = const [],
    this.rowItems = const {},
    this.upNext = const [],
    this.favorites = const [],
    this.kindGenres = const {},
    this.dirty = false,
    this.saving = false,
    this.savedAt,
  });

  final bool loading;
  final String? error;
  final List<HomeRow> rows;

  /// 预览取数结果（只对可见行取，隐藏行不发请求）。
  final Map<String, List<LibraryItemView>> rowItems;
  final List<UpNextItem> upNext;
  final List<LibraryItemView> favorites;
  final Map<String, List<Map<String, dynamic>>> kindGenres;

  /// 本地有未保存修改。
  final bool dirty;
  final bool saving;
  final DateTime? savedAt;

  List<HomeRow> get visibleRows => rows.where((r) => !r.hidden).toList();

  CustomizeState copyWith({
    bool? loading,
    String? error,
    List<HomeRow>? rows,
    Map<String, List<LibraryItemView>>? rowItems,
    List<UpNextItem>? upNext,
    List<LibraryItemView>? favorites,
    Map<String, List<Map<String, dynamic>>>? kindGenres,
    bool? dirty,
    bool? saving,
    DateTime? savedAt,
    bool clearSavedAt = false,
  }) =>
      CustomizeState(
        loading: loading ?? this.loading,
        error: error,
        rows: rows ?? this.rows,
        rowItems: rowItems ?? this.rowItems,
        upNext: upNext ?? this.upNext,
        favorites: favorites ?? this.favorites,
        kindGenres: kindGenres ?? this.kindGenres,
        dirty: dirty ?? this.dirty,
        saving: saving ?? this.saving,
        savedAt: clearSavedAt ? null : (savedAt ?? this.savedAt),
      );
}

class LibraryCustomizeController extends Notifier<CustomizeState> {
  @override
  CustomizeState build() => const CustomizeState();

  LibraryApi get _api => ref.read(libraryApiProvider);

  /// 与首页相同的合并规则构建行清单，然后对可见行逐行取预览数据。
  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final libs = await _api.libraries();
      final collections = await _api.collections();
      final prefsRaw = await _api.uiPreferences();
      final homeJson = prefsRaw['home'];
      final rowsJson = homeJson is Map<String, dynamic>
          ? homeJson['rows'] as List<dynamic>? ?? []
          : const <dynamic>[];
      final prefs = rowsJson
          .whereType<Map<String, dynamic>>()
          .map(HomeRowPref.fromJson)
          .toList();
      state = state.copyWith(
        loading: false,
        rows: HomeRows.build(prefs, libs, collections),
      );
      await _loadPreviews(state.visibleRows);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  Future<void> _loadPreviews(List<HomeRow> rows) async {
    for (final row in rows) {
      try {
        final k = row.kind;
        if (k is UpNextRowKind) {
          if (state.upNext.isNotEmpty) continue;
          state = state.copyWith(upNext: await _api.upNext(limit: 20));
        } else if (k is FavoritesRowKind) {
          if (state.favorites.isNotEmpty) continue;
          final sort = k.sort == 'unwatched_first' ? null : k.sort;
          state = state.copyWith(
            favorites: (await _api.favorites(
              limit: 20,
              unwatchedFirst: k.sort == 'unwatched_first',
              sort: sort,
              order: HomeRows.orderParam(sort ?? 'favorited_at', k.reversed),
            )).items,
          );
        } else if (k is LibraryRowKind) {
          if (state.rowItems.containsKey(row.id)) continue;
          final order = HomeRows.orderParam(k.sort, k.reversed);
          state = state.copyWith(
            rowItems: {
              ...state.rowItems,
              row.id: await _api.libraryItems(
                k.library.id,
                limit: 20,
                filterQuery: {
                  'sort': k.sort,
                  if (order != null) 'order': order,
                  if (k.unwatched) 'w': 'unwatched',
                },
              ),
            },
          );
        } else if (k is CollectionRowKind) {
          if (state.rowItems.containsKey(row.id)) continue;
          state = state.copyWith(
            rowItems: {
              ...state.rowItems,
              row.id: await _api.collectionItems(
                k.collection.id,
                limit: 20,
                sort: k.sort,
                order: HomeRows.orderParam(k.sort, k.reversed),
              ),
            },
          );
        } else if (k is GenresRowKind) {
          if (state.kindGenres.containsKey(row.id)) continue;
          state = state.copyWith(
            kindGenres: {
              ...state.kindGenres,
              row.id: await _api.libraryKindGenres(k.kind),
            },
          );
        }
      } catch (_) {
        // 单行预览失败不阻塞其他行。
      }
    }
  }

  void _mark(List<HomeRow> rows) =>
      state = state.copyWith(rows: rows, dirty: true, clearSavedAt: true);

  /// 隐藏 / 显示（只藏不删，行保留在原位）。
  void setHidden(String rowId, bool hidden) {
    _mark([
      for (final r in state.rows)
        if (r.id == rowId) HomeRow(id: r.id, hidden: hidden, kind: r.kind) else r,
    ]);
  }

  /// 删除（仅 row:/kind: 行可删，其余只允许隐藏）。
  void removeRow(String rowId) {
    _mark(state.rows.where((r) => r.id != rowId).toList());
  }

  /// 拖拽排序：把 from 位置的行移到 to 位置。
  void reorder(int from, int to) {
    final rows = [...state.rows];
    final row = rows.removeAt(from);
    rows.insert(to, row);
    _mark(rows);
  }

  /// 改行排序（行内可配排序：added_at / release_date / last_played / rating / random / title …）。
  void setRowSort(String rowId, String sort, bool reversed) {
    _mark([
      for (final r in state.rows)
        if (r.id == rowId)
          HomeRow(id: r.id, hidden: r.hidden, kind: _withSort(r.kind, sort, reversed))
        else r,
    ]);
  }

  HomeRowKind _withSort(HomeRowKind kind, String sort, bool reversed) {
    final k = kind;
    if (k is LibraryRowKind) {
      return HomeRowKind.library(
        library: k.library,
        sort: sort,
        reversed: reversed,
        unwatched: k.unwatched,
        name: k.name,
        builtin: k.builtin,
      );
    }
    if (k is CollectionRowKind) {
      return HomeRowKind.collection(
        collection: k.collection,
        sort: sort,
        reversed: reversed,
        name: k.name,
      );
    }
    if (k is FavoritesRowKind) {
      return HomeRowKind.favorites(sort: sort, reversed: reversed);
    }
    return kind;
  }

  /// 是否观看过滤（unwatched 仅 sort != last_played 时生效，由 HomeRows 常量约束 UI）。
  void setUnwatched(String rowId, bool unwatched) {
    _mark([
      for (final r in state.rows)
        if (r.id == rowId && r.kind is LibraryRowKind)
          HomeRow(
            id: r.id,
            hidden: r.hidden,
            kind: HomeRowKind.library(
              library: (r.kind as LibraryRowKind).library,
              sort: (r.kind as LibraryRowKind).sort,
              reversed: (r.kind as LibraryRowKind).reversed,
              unwatched: unwatched,
              name: (r.kind as LibraryRowKind).name,
              builtin: (r.kind as LibraryRowKind).builtin,
            ),
          )
        else r,
    ]);
  }

  /// 加「媒体库」新行（追加到最后）。
  void addLibraryRow(LibraryView library) {
    _mark([
      ...state.rows,
      HomeRow(
        id: HomeRows.newRowId(),
        kind: HomeRowKind.library(
          library: library,
          sort: 'added_at',
          reversed: false,
          unwatched: false,
        ),
      ),
    ]);
  }

  /// 加「合集」新行（追加到最后）。
  void addCollectionRow(CollectionView collection) {
    _mark([
      ...state.rows,
      HomeRow(
        id: HomeRows.newRowId(),
        kind: HomeRowKind.collection(
          collection: collection,
          sort: collection.sort,
          reversed: false,
        ),
      ),
    ]);
  }

  /// 恢复出厂布局（不落盘，直到点保存）。
  Future<void> resetToDefault() async {
    try {
      final libs = await _api.libraries();
      _mark(HomeRows.defaultRows(libs.where((l) => !l.excludeFromHome).toList()));
    } catch (_) {}
  }

  /// 保存：以服务器完整偏好为底，只替换 home.rows（PUT 整体覆盖）。
  Future<bool> save() async {
    if (!state.dirty || state.saving) return false;
    state = state.copyWith(saving: true, error: null);
    try {
      final prefsRaw = await _api.uiPreferences();
      // PUT 是整体覆盖：以服务器完整偏好为底，只替换 home.rows。
      final homeJson = prefsRaw['home'];
      final body = <String, dynamic>{
        ...prefsRaw,
        'home': <String, dynamic>{
          ...(homeJson is Map<String, dynamic> ? homeJson : const {}),
          'rows':
              HomeRows.toPrefs(state.rows).map((r) => r.toJson()).toList(),
        },
      };
      await _api.updateUiPreferences(body);
      state = state.copyWith(saving: false, dirty: false, savedAt: DateTime.now());
      return true;
    } catch (e) {
      state = state.copyWith(saving: false, error: '保存失败，请重试');
      return false;
    }
  }
}

final libraryCustomizeProvider =
    NotifierProvider<LibraryCustomizeController, CustomizeState>(
        LibraryCustomizeController.new);
