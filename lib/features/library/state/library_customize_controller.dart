import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_rows.dart';
import 'mc_api.dart';
import 'models.dart';

/// 自定义首页状态（1:1 对齐 upstream iOS `LibraryCustomizeView.swift`）：
/// - 持有完整的行清单（含隐藏行）、库与合集候选；
/// - 每次改动先落本地草稿，400ms 防抖自动 PUT `/ui/preferences`；
/// - `resetToDefault()` 直接保存空 `[]` 回到出厂默认布局。
class CustomizeState {
  const CustomizeState({
    this.loading = false,
    this.error,
    this.saveError,
    this.rows = const [],
    this.libraries = const [],
    this.collections = const [],
    this.dirty = false,
    this.saving = false,
    this.savedAt,
  });

  final bool loading;
  final String? error;
  final String? saveError;
  final List<HomeRow> rows;
  final List<LibraryView> libraries;
  final List<CollectionView> collections;
  final bool dirty;
  final bool saving;
  final DateTime? savedAt;

  List<HomeRow> get visibleRows => rows.where((r) => !r.hidden).toList();
  int get hiddenCount => rows.where((r) => r.hidden).length;

  CustomizeState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    String? saveError,
    bool clearSaveError = false,
    List<HomeRow>? rows,
    List<LibraryView>? libraries,
    List<CollectionView>? collections,
    bool? dirty,
    bool? saving,
    DateTime? savedAt,
    bool clearSavedAt = false,
  }) =>
      CustomizeState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        saveError: clearSaveError ? null : (saveError ?? this.saveError),
        rows: rows ?? this.rows,
        libraries: libraries ?? this.libraries,
        collections: collections ?? this.collections,
        dirty: dirty ?? this.dirty,
        saving: saving ?? this.saving,
        savedAt: clearSavedAt ? null : (savedAt ?? this.savedAt),
      );
}

class LibraryCustomizeController extends Notifier<CustomizeState> {
  Timer? _debounce;
  Map<String, dynamic>? _fullPrefs;

  @override
  CustomizeState build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });
    return const CustomizeState();
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true, clearSaveError: true);
    try {
      final results = await Future.wait<dynamic>([
        _api.libraries(scope: 'all'),
        _api.collections(),
        _api.uiPreferences(),
      ]);
      final libs = results[0] as List<LibraryView>;
      final cols = results[1] as List<CollectionView>;
      final prefsRaw = results[2] as Map<String, dynamic>;
      _fullPrefs = prefsRaw;
      final homeJson = prefsRaw['home'];
      final rowsJson = homeJson is Map
          ? homeJson['rows'] as List<dynamic>? ?? const []
          : const <dynamic>[];
      final prefs = rowsJson
          .whereType<Map>()
          .map((m) => HomeRowPref.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      state = state.copyWith(
        loading: false,
        libraries: libs,
        collections: cols,
        rows: HomeRows.build(prefs, libs, cols),
        dirty: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: '加载失败，请下拉重试');
    }
  }

  void _commit(List<HomeRow> next) {
    state = state.copyWith(
      rows: next,
      dirty: true,
      clearSaveError: true,
      clearSavedAt: true,
    );
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      save();
    });
  }

  /// 页面离开前刷掉防抖窗口里还没发出去的保存。
  Future<void> flushPendingSave() async {
    if (_debounce?.isActive == true || state.dirty) {
      _debounce?.cancel();
      await save();
    }
  }

  void setHidden(String rowId, bool hidden) {
    _commit([
      for (final r in state.rows)
        if (r.id == rowId) r.copyWith(hidden: hidden) else r,
    ]);
  }

  /// 删除（严格遵循 `row.removable()`：仅 `row:` / `kind:` 可删）。
  void removeRow(String rowId) {
    final target = state.rows.where((r) => r.id == rowId).firstOrNull;
    if (target == null || !target.removable()) return;
    _commit(state.rows.where((r) => r.id != rowId).toList());
  }

  void reorder(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= state.rows.length || to >= state.rows.length) {
      return;
    }
    final rows = [...state.rows];
    final row = rows.removeAt(from);
    rows.insert(to, row);
    _commit(rows);
  }

  void setRowName(String rowId, String rawName) {
    final name = rawName.length > 40 ? rawName.substring(0, 40) : rawName;
    _commit([
      for (final r in state.rows)
        if (r.id == rowId) r.copyWith(kind: _withName(r.kind, name)) else r,
    ]);
  }

  void setRowSort(String rowId, String sort, bool reversed) {
    _commit([
      for (final r in state.rows)
        if (r.id == rowId)
          r.copyWith(
            unfinished: sort == 'last_played' ? false : r.unfinished,
            kind: _withSort(r.kind, sort, reversed),
          )
        else
          r,
    ]);
  }

  /// 3 态观看过滤：`''`（全部）/ `'unwatched'`（未看）/ `'unfinished'`（未看完）。
  void setWatch(String rowId, String watch) {
    final isUnfinished = watch == 'unfinished';
    final isUnwatched = watch == 'unwatched';
    _commit([
      for (final r in state.rows)
        if (r.id == rowId)
          r.copyWith(
            unfinished: isUnfinished,
            kind: _withUnwatched(r.kind, isUnwatched),
          )
        else
          r,
    ]);
  }

  HomeRowKind _withName(HomeRowKind kind, String name) {
    if (kind is LibraryRowKind) {
      return HomeRowKind.library(
        library: kind.library,
        sort: kind.sort,
        reversed: kind.reversed,
        unwatched: kind.unwatched,
        name: name,
        builtin: kind.builtin,
      );
    }
    if (kind is MediaKindRowKind) {
      return HomeRowKind.mediaKind(
        kind: kind.kind,
        libraries: kind.libraries,
        sort: kind.sort,
        reversed: kind.reversed,
        unwatched: kind.unwatched,
        name: name,
        builtin: kind.builtin,
      );
    }
    if (kind is CollectionRowKind) {
      return HomeRowKind.collection(
        collection: kind.collection,
        sort: kind.sort,
        reversed: kind.reversed,
        name: name,
      );
    }
    return kind;
  }

  HomeRowKind _withSort(HomeRowKind kind, String sort, bool reversed) {
    if (kind is LibraryRowKind) {
      return HomeRowKind.library(
        library: kind.library,
        sort: sort,
        reversed: reversed,
        unwatched: sort == 'last_played' ? false : kind.unwatched,
        name: kind.name,
        builtin: kind.builtin,
      );
    }
    if (kind is MediaKindRowKind) {
      return HomeRowKind.mediaKind(
        kind: kind.kind,
        libraries: kind.libraries,
        sort: sort,
        reversed: reversed,
        unwatched: sort == 'last_played' ? false : kind.unwatched,
        name: kind.name,
        builtin: kind.builtin,
      );
    }
    if (kind is CollectionRowKind) {
      return HomeRowKind.collection(
        collection: kind.collection,
        sort: sort,
        reversed: reversed,
        name: kind.name,
      );
    }
    if (kind is FavoritesRowKind) {
      return HomeRowKind.favorites(sort: sort, reversed: reversed);
    }
    return kind;
  }

  HomeRowKind _withUnwatched(HomeRowKind kind, bool unwatched) {
    if (kind is LibraryRowKind) {
      return HomeRowKind.library(
        library: kind.library,
        sort: kind.sort,
        reversed: kind.reversed,
        unwatched: unwatched,
        name: kind.name,
        builtin: kind.builtin,
      );
    }
    if (kind is MediaKindRowKind) {
      return HomeRowKind.mediaKind(
        kind: kind.kind,
        libraries: kind.libraries,
        sort: kind.sort,
        reversed: kind.reversed,
        unwatched: unwatched,
        name: kind.name,
        builtin: kind.builtin,
      );
    }
    return kind;
  }

  HomeRow addLibraryRow(LibraryView library) {
    final row = HomeRows.newLibraryRow(library);
    _commit([...state.rows, row]);
    return row;
  }

  HomeRow addMediaKindRow(String kind, List<LibraryView> libraries) {
    final row = HomeRows.newMediaKindRow(kind, libraries);
    _commit([...state.rows, row]);
    return row;
  }

  HomeRow addCollectionRow(CollectionView collection) {
    final row = HomeRows.newCollectionRow(collection);
    _commit([...state.rows, row]);
    return row;
  }

  /// 恢复出厂布局：向服务端保存空清单 `[]`（约定：空清单 = 出厂布局）。
  Future<bool> resetToDefault() async {
    _debounce?.cancel();
    state = state.copyWith(saving: true, clearSaveError: true);
    try {
      await _putHomeRows(const []);
      final defaults = HomeRows.defaultRows(state.libraries);
      state = state.copyWith(
        saving: false,
        dirty: false,
        rows: defaults,
        savedAt: DateTime.now(),
      );
      return true;
    } catch (_) {
      state = state.copyWith(saving: false, saveError: '恢复默认失败，请重试');
      return false;
    }
  }

  Future<bool> save() async {
    if (state.saving) return false;
    final rowsSnapshot = state.rows;
    state = state.copyWith(saving: true, clearSaveError: true);
    try {
      await _putHomeRows(
        HomeRows.toPrefs(rowsSnapshot).map((r) => r.toJson()).toList(),
      );
      state = state.copyWith(
        saving: false,
        dirty: false,
        savedAt: DateTime.now(),
      );
      return true;
    } catch (_) {
      state = state.copyWith(saving: false, saveError: '保存失败，请重试');
      return false;
    }
  }

  Future<void> _putHomeRows(List<Map<String, dynamic>> rowsJson) async {
    final base = _fullPrefs ?? await _api.uiPreferences();
    final homeJson = base['home'];
    final body = <String, dynamic>{
      ...base,
      'home': <String, dynamic>{
        ...(homeJson is Map ? Map<String, dynamic>.from(homeJson) : const {}),
        'rows': rowsJson,
      },
    };
    await _api.updateUiPreferences(body);
    _fullPrefs = body;
  }
}

final libraryCustomizeProvider =
    NotifierProvider<LibraryCustomizeController, CustomizeState>(
      LibraryCustomizeController.new,
    );
