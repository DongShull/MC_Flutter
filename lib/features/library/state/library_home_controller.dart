import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/session_providers.dart';
import 'home_rows.dart';
import 'mc_api.dart';
import 'models.dart';

/// 媒体库首页的整页数据（1:1 对齐鸿蒙 LibraryHomeStore.ets + LibraryHomeView 的轮询口径）：
/// - 库、合集、接下来继续、收藏、各行条目并发取；
/// - 库状态、要取的行、合集都没变时不重拉各行条目（空闲 30 秒一轮不必打 1+N 个请求）；
/// - 瞬时失败不清已有数据，只置 failed 让页面挂提示条；一次都没成功过才整页报错；
/// - 有库在扫描/整理时 busyUntil 往后 12 秒，期间保持 3 秒快轮询（同 Web recentlyBusy）。
class LibraryHomeState {
  const LibraryHomeState({
    this.libraries,
    this.collections = const [],
    this.prefs,
    this.upNext = const [],
    this.favorites = const FavoritesResult(),
    this.itemsByKey = const {},
    this.failed = false,
    this.busyUntil = 0,
    this.isAdmin = false,
  });

  /// null = 还没成功拿到过库列表。
  final List<LibraryView>? libraries;
  final List<CollectionView> collections;

  /// 首页行清单偏好（ui.preferences.home.rows）；null = 还没拉到。
  final List<HomeRowPref>? prefs;
  final List<UpNextItem> upNext;
  final FavoritesResult favorites;

  /// 各行条目，键见 [LibraryHomeController.fetchKey] / [LibraryHomeController.coverKey]。
  final Map<String, List<LibraryItemView>> itemsByKey;
  final bool failed;

  /// 扫描/整理结束后的 12 秒快轮询窗口（epoch 毫秒）。
  final int busyUntil;
  final bool isAdmin;

  /// 当前账号能浏览的库（超管只有管理权的库不出现在首页卡片里）。
  List<LibraryView> get visibleLibraries =>
      (libraries ?? const <LibraryView>[]).where((l) => l.viewerAccess).toList();

  /// 要渲染的行：合并规则后去掉隐藏行；鸿蒙首页不渲染类型色块行。
  List<HomeRow> get rows => HomeRows.build(prefs ?? const [], libraries ?? const [], collections)
      .where((r) => !r.hidden && r.kind is! GenresRowKind)
      .toList();

  bool get recentlyBusy => busyUntil > DateTime.now().millisecondsSinceEpoch;

  LibraryHomeState copyWith({
    List<LibraryView>? libraries,
    List<CollectionView>? collections,
    List<HomeRowPref>? prefs,
    List<UpNextItem>? upNext,
    FavoritesResult? favorites,
    Map<String, List<LibraryItemView>>? itemsByKey,
    bool? failed,
    int? busyUntil,
    bool? isAdmin,
  }) =>
      LibraryHomeState(
        libraries: libraries ?? this.libraries,
        collections: collections ?? this.collections,
        prefs: prefs ?? this.prefs,
        upNext: upNext ?? this.upNext,
        favorites: favorites ?? this.favorites,
        itemsByKey: itemsByKey ?? this.itemsByKey,
        failed: failed ?? this.failed,
        busyUntil: busyUntil ?? this.busyUntil,
        isAdmin: isAdmin ?? this.isAdmin,
      );
}

class LibraryHomeController extends Notifier<LibraryHomeState> {
  /// 每行取的条数（同 Web）。
  static const rowCount = 20;

  Timer? _poll;
  Future<void>? _inFlight;
  String? _owner;
  String? _rowsFingerprint;
  bool _roleLoaded = false;

  @override
  LibraryHomeState build() {
    ref.onDispose(() => _poll?.cancel());
    return const LibraryHomeState();
  }

  LibraryApi get _api => ref.read(libraryApiProvider);

  /// 一行取数的缓存键：同一个库同一种排序同一方向（同一个未看开关）只请求一次。
  static String fetchKey(HomeRow row) {
    final k = row.kind;
    if (k is LibraryRowKind) {
      return 'lib:${k.library.id}:${k.sort}:${k.reversed}:${k.unwatched}';
    }
    if (k is CollectionRowKind) return 'col:${k.collection.id}:${k.sort}:${k.reversed}';
    return row.id;
  }

  /// 库卡片封面用的那批条目，与默认的「最近添加」行共用一份。
  static String coverKey(int libraryId) => 'lib:$libraryId:added_at:false:false';

  /// 兼容旧调用（自定义首页保存后刷新）：等同 [reload]。
  Future<void> load() => reload();

  /// 刷新整页；并发调用合并为同一次。完成后按忙闲排下一轮轮询。
  Future<void> reload() {
    _poll?.cancel();
    final running = _inFlight;
    if (running != null) return running;
    final task = _load().whenComplete(() {
      _inFlight = null;
      _scheduleNextPoll();
    });
    _inFlight = task;
    return task;
  }

  /// 页面离开（dispose）时停轮询。
  void stopPolling() => _poll?.cancel();

  void _scheduleNextPoll() {
    _poll?.cancel();
    _poll = Timer(Duration(seconds: _pollInterval()), reload);
  }

  /// 轮询间隔：忙 3s / 刷元数据 5s / 有待入账 10s / 空闲 30s（同 Web）。
  int _pollInterval() {
    final libs = state.libraries ?? const <LibraryView>[];
    if (libs.any((l) => l.scanning || l.organizing) || state.recentlyBusy) return 3;
    if (libs.any((l) => l.metadataRefresh?.refreshing ?? false)) return 5;
    if (libs.any((l) => !l.scanning && !l.organizing && l.lastScanDeferred > 0)) return 10;
    return 30;
  }

  /// 以当前账号身份使用：换了账号就清空旧账号的数据，并尝试 0ms 读冷启动快照。
  Future<void> _adopt() async {
    final session = ref.read(sessionStoreProvider);
    final key = '${session.baseUrl ?? ''}|${session.username}';
    if (key == _owner) return;
    _owner = key;
    _rowsFingerprint = null;
    _roleLoaded = false;
    state = const LibraryHomeState();
    if ((session.baseUrl ?? '').isEmpty) return;
    await _hydrateSnapshot(key);
  }

  String _snapKey(String owner) => 'mc_lib_home_snap_v1_$owner';

  Future<void> _hydrateSnapshot(String owner) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_snapKey(owner));
      if (raw == null || raw.isEmpty || owner != _owner) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final libs = (map['libraries'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => LibraryView.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (libs.isEmpty) return;
      final cols = (map['collections'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => CollectionView.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      final upNext = (map['up_next'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => UpNextItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      final favItems = (map['favorites'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => LibraryItemView.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      final itemsMapRaw = map['items_by_key'];
      final itemsByKey = <String, List<LibraryItemView>>{};
      if (itemsMapRaw is Map) {
        for (final e in itemsMapRaw.entries) {
          if (e.value is List) {
            itemsByKey[e.key.toString()] = (e.value as List)
                .whereType<Map>()
                .map((m) => LibraryItemView.fromJson(Map<String, dynamic>.from(m)))
                .toList();
          }
        }
      }
      if (state.libraries == null && owner == _owner) {
        state = state.copyWith(
          libraries: libs,
          collections: cols,
          upNext: upNext,
          favorites: FavoritesResult(
            items: favItems,
            total: (map['favorites_total'] as num?)?.toInt() ?? favItems.length,
          ),
          itemsByKey: itemsByKey,
          isAdmin: map['is_admin'] == true,
        );
      }
    } catch (_) {}
  }

  Future<void> _persistSnapshot(String? owner) async {
    if (owner == null || owner.isEmpty || state.libraries == null) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'libraries': [for (final l in state.libraries!) l.toJson()],
        'collections': [for (final c in state.collections) c.toJson()],
        'up_next': [for (final u in state.upNext) u.toJson()],
        'favorites': [for (final f in state.favorites.items) f.toJson()],
        'favorites_total': state.favorites.total,
        'items_by_key': {
          for (final e in state.itemsByKey.entries)
            e.key: [for (final it in e.value.take(12)) it.toJson()],
        },
        'is_admin': state.isAdmin,
      });
      await sp.setString(_snapKey(owner), payload);
    } catch (_) {}
  }

  Future<void> _load() async {
    await _adopt();
    final owner = _owner;
    try {
      // 偏好：拉到为止（失败保持 null，下一轮再拉；写成 [] 会覆盖用户自定义的行）。
      var prefs = state.prefs;
      if (prefs == null) {
        try {
          final raw = await _api.uiPreferences();
          final home = raw['home'];
          final rowsJson =
              home is Map<String, dynamic> ? home['rows'] as List<dynamic>? ?? [] : const [];
          prefs = rowsJson.whereType<Map<String, dynamic>>().map(HomeRowPref.fromJson).toList();
        } catch (_) {}
      }
      final plan = HomeRows.build(prefs ?? const [], const [], const [])
          .where((r) => !r.hidden)
          .toList();
      final wantsUpNext = plan.any((r) => r.kind is UpNextRowKind);
      final favKind = plan.map((r) => r.kind).whereType<FavoritesRowKind>().firstOrNull;

      // 接下来继续、收藏两行只看行清单，与库、合集同时发请求。
      final libsTask = _api.libraries();
      final colsTask = _api.collections().catchError((_) => state.collections);
      final upNextTask = wantsUpNext
          ? _api.upNext(limit: rowCount).then<List<UpNextItem>?>((v) => v).catchError((_) => null)
          : Future<List<UpNextItem>?>.value(const []);
      final favTask = favKind == null
          ? Future<FavoritesResult?>.value(const FavoritesResult())
          : _fetchFavorites(favKind);
      if (!_roleLoaded) unawaited(_loadRole());

      final libs = await libsTask;
      final cols = await colsTask;
      if (owner != _owner) return;

      final busy = libs.any((l) => l.scanning || l.organizing);
      final now = DateTime.now().millisecondsSinceEpoch;
      state = state.copyWith(
        libraries: libs,
        collections: cols,
        prefs: prefs,
        failed: false,
        busyUntil: busy ? now + 12000 : null,
      );

      // 各行条目：库状态、要取的行、合集都没变时跳过。
      final fetches = _rowFetches(state.rows, libs);
      final fingerprint = [
        for (final l in libs) l.fingerprint,
        '#',
        ...(fetches.keys.toList()..sort()),
        '#',
        for (final c in cols) '${c.id}:${c.name}:${c.sort}:${c.itemCount}',
      ].join(',');
      if (fingerprint != _rowsFingerprint) {
        final next = <String, List<LibraryItemView>>{};
        await Future.wait([
          for (final e in fetches.entries)
            e.value().then((items) => next[e.key] = items).catchError((_) => next[e.key] = []),
        ]);
        if (owner != _owner) return;
        _rowsFingerprint = fingerprint;
        state = state.copyWith(itemsByKey: next);
      }

      final upNext = await upNextTask;
      final favorites = await favTask;
      if (owner != _owner) return;
      state = state.copyWith(upNext: upNext, favorites: favorites);
      unawaited(_persistSnapshot(owner));
    } catch (_) {
      if (owner == _owner) state = state.copyWith(failed: true);
    }
  }

  /// 首页卡片快捷标记收藏或已看并立即刷新。
  Future<void> toggleItemMark(
    int mediaItemId, {
    bool? favorite,
    bool? played,
  }) async {
    await _api.setItemMark(mediaItemId, favorite: favorite, played: played);
    _rowsFingerprint = null;
    await reload();
  }

  Future<FavoritesResult?> _fetchFavorites(FavoritesRowKind k) async {
    try {
      final unwatchedFirst = k.sort == 'unwatched_first';
      final sort = unwatchedFirst ? 'favorited_at' : k.sort;
      return await _api.favorites(
        limit: rowCount,
        unwatchedFirst: unwatchedFirst,
        sort: sort,
        order: unwatchedFirst ? null : HomeRows.orderParam(sort, k.reversed),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRole() async {
    try {
      final role = await _api.currentRole();
      _roleLoaded = true;
      state = state.copyWith(isAdmin: role == 'admin');
    } catch (_) {}
  }

  /// 显示中的行各自要打的请求，按缓存键去重；排序与截断交给服务端。
  Map<String, Future<List<LibraryItemView>> Function()> _rowFetches(
    List<HomeRow> rows,
    List<LibraryView> libs,
  ) {
    final fetches = <String, Future<List<LibraryItemView>> Function()>{};
    for (final row in rows) {
      final k = row.kind;
      if (k is LibraryRowKind) {
        // 「最近观看」行只要播过的（w=seen）。
        final watch = k.sort == 'last_played' ? 'seen' : (k.unwatched ? 'unwatched' : null);
        final order = HomeRows.orderParam(k.sort, k.reversed);
        fetches[fetchKey(row)] = () => _api.libraryItems(
              k.library.id,
              limit: rowCount,
              filterQuery: {
                'sort': k.sort,
                if (order != null) 'order': order,
                if (watch != null) 'w': watch,
              },
            );
      } else if (k is CollectionRowKind) {
        fetches[fetchKey(row)] = () => _api.collectionItems(
              k.collection.id,
              limit: rowCount,
              sort: k.sort,
              order: HomeRows.orderParam(k.sort, k.reversed),
            );
      } else if (k is LibrariesRowKind) {
        // 库卡片封面与默认的「最近添加」行共用一份条目。
        for (final lib in libs.where((l) => l.viewerAccess)) {
          fetches.putIfAbsent(
            coverKey(lib.id),
            () => () => _api.libraryItems(lib.id,
                limit: rowCount, filterQuery: const {'sort': 'added_at'}),
          );
        }
      }
    }
    return fetches;
  }

  /// 清空观看记录（scope=all [+since] / scope=library）；返回删除的行数。
  Future<int> clearHistory({DateTime? since, int? libraryId}) async {
    final deleted = await _api.clearPlaybackHistory(
      scope: libraryId == null ? 'all' : 'library',
      since: since,
      libraryId: libraryId,
    );
    await reload();
    return deleted;
  }
}

final libraryHomeProvider =
    NotifierProvider<LibraryHomeController, LibraryHomeState>(LibraryHomeController.new);
