import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_rows.dart';
import 'mc_api.dart';
import 'models.dart';

/// 媒体库首页状态（对齐 Kotlin LibraryScreen.kt 的 LibraryHome ViewModel）：
/// 有序行清单 + 每行内容。隐藏行不发请求；同一来源同一排序只请求一次。
class LibraryHomeState {
  const LibraryHomeState({
    this.loading = false,
    this.error,
    this.rows = const [],
    this.upNext = const [],
    this.favorites = const [],
    this.rowItems = const {},
    this.kindGenres = const {},
    this.kindSummaries = const {},
  });

  final bool loading;
  final String? error;

  /// 合并后的全部行（含隐藏行；渲染时过滤 hidden）。
  final List<HomeRow> rows;

  /// 「接下来继续」行内容。
  final List<UpNextItem> upNext;

  /// 「我的收藏」行内容。
  final List<LibraryItemView> favorites;

  /// 逐行取数结果，键 = 行 id。
  final Map<String, List<LibraryItemView>> rowItems;

  /// 类型色块行内容，键 = `genres:<kind>`（元素为 TMDB 类型块原始 JSON）。
  final Map<String, List<Map<String, dynamic>>> kindGenres;

  /// 类型行计数，键 = `genres:<kind>`。
  final Map<String, LibraryKindSummaryView> kindSummaries;

  /// 隐藏行之外真正要渲染的行。
  List<HomeRow> get visibleRows => rows.where((r) => !r.hidden).toList();

  /// 顶部统计一行：N 部 · 共占用 S（所有可见库求和）。
  (int, int) get storageStats {
    var count = 0;
    var bytes = 0;
    for (final r in rows) {
      final k = r.kind;
      if (k is LibraryRowKind) {
        count += k.library.stats.itemCount;
        bytes += k.library.stats.totalSizeBytes;
      }
    }
    return (count, bytes);
  }

  LibraryHomeState copyWith({
    bool? loading,
    String? error,
    List<HomeRow>? rows,
    List<UpNextItem>? upNext,
    List<LibraryItemView>? favorites,
    Map<String, List<LibraryItemView>>? rowItems,
    Map<String, List<Map<String, dynamic>>>? kindGenres,
    Map<String, LibraryKindSummaryView>? kindSummaries,
  }) =>
      LibraryHomeState(
        loading: loading ?? this.loading,
        error: error,
        rows: rows ?? this.rows,
        upNext: upNext ?? this.upNext,
        favorites: favorites ?? this.favorites,
        rowItems: rowItems ?? this.rowItems,
        kindGenres: kindGenres ?? this.kindGenres,
        kindSummaries: kindSummaries ?? this.kindSummaries,
      );
}

class LibraryHomeController extends Notifier<LibraryHomeState> {
  @override
  LibraryHomeState build() => const LibraryHomeState();

  LibraryApi get _api => ref.read(libraryApiProvider);

  /// 加载首页：库 → 合集 → ui/preferences → 合并行 → 逐行取数。
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
      final rows = HomeRows.build(prefs, libs, collections);
      state = state.copyWith(loading: false, rows: rows);
      // 逐行取数（与 Kotlin 同口径：隐藏行不发请求）。
      await _loadRowData(state.visibleRows);
    } catch (e) {
      state = state.copyWith(loading: false, error: '与后端通信失败，正在自动重试');
    }
  }

  Future<void> _loadRowData(List<HomeRow> rows) async {
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
            favorites: await _api.favorites(
              limit: 20,
              unwatchedFirst: k.sort == 'unwatched_first',
              sort: sort,
              order: HomeRows.orderParam(sort ?? 'favorited_at', k.reversed),
            ),
          );
        } else if (k is LibraryRowKind) {
          if (state.rowItems.containsKey(row.id)) continue;
          final items = await _api.libraryItems(
            k.library.id,
            limit: 20,
            filterQuery: _rowQuery(k.sort, k.reversed, k.unwatched),
          );
          state = state.copyWith(
            rowItems: {...state.rowItems, row.id: items},
          );
        } else if (k is CollectionRowKind) {
          if (state.rowItems.containsKey(row.id)) continue;
          final items = await _api.collectionItems(
            k.collection.id,
            limit: 20,
            sort: k.sort,
            order: HomeRows.orderParam(k.sort, k.reversed),
          );
          state = state.copyWith(rowItems: {...state.rowItems, row.id: items});
        } else if (k is GenresRowKind) {
          if (state.kindGenres.containsKey(row.id)) continue;
          final genres = await _api.libraryKindGenres(k.kind);
          state = state.copyWith(kindGenres: {...state.kindGenres, row.id: genres});
          final summary = await _api.libraryKindSummary(k.kind);
          state = state.copyWith(kindSummaries: {...state.kindSummaries, row.id: summary});
        }
      } catch (_) {
        // 单行失败不拖垮整页：该行渲染为空态，下拉刷新重试。
      }
    }
  }

  Map<String, String?> _rowQuery(String sort, bool reversed, bool unwatched) {
    final order = HomeRows.orderParam(sort, reversed);
    return {
      'sort': sort,
      if (order != null) 'order': order,
      if (unwatched) 'w': 'unwatched',
    };
  }
}

final libraryHomeProvider =
    NotifierProvider<LibraryHomeController, LibraryHomeState>(
        LibraryHomeController.new);
