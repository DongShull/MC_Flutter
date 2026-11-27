import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/session/permissions.dart';
import '../../../core/storage/page_snapshots.dart';
import 'home_model.dart';
import 'mc_api.dart';
import 'models.dart';
import 'subscription_index.dart';

/// 订阅列表控制器。
class SubscriptionsListController
    extends Notifier<AsyncValue<List<SubscriptionView>>> {
  String? _kind;

  @override
  AsyncValue<List<SubscriptionView>> build() =>
      const AsyncValue<List<SubscriptionView>>.loading();

  Future<void> load({String? kind}) async {
    _kind = kind;
    state = const AsyncValue<List<SubscriptionView>>.loading();
    await _fetch(kind);
  }

  Future<void> reload() => _fetch(_kind);

  Future<void> _fetch(String? kind) async {
    try {
      final subs =
          await ref.read(subscriptionsApiProvider).subscriptions(kind: kind);
      state = AsyncValue<List<SubscriptionView>>.data(subs);
    } catch (e, st) {
      state = AsyncValue<List<SubscriptionView>>.error(e, st);
    }
  }
}

final subscriptionsListProvider = NotifierProvider<SubscriptionsListController,
    AsyncValue<List<SubscriptionView>>>(SubscriptionsListController.new);

/// 订阅详情控制器（保留兼容外部引用）。
class SubscriptionDetailController
    extends FamilyNotifier<AsyncValue<SubscriptionView?>, int> {
  late int id;

  List<SubActivityView> _activities = const [];
  List<SubActivityView> get activities => _activities;

  String? _notice;
  String? get notice => _notice;
  void consumeNotice() => _notice = null;

  @override
  AsyncValue<SubscriptionView?> build(int arg) {
    id = arg;
    return const AsyncValue<SubscriptionView?>.loading();
  }

  Future<void> load() async {
    state = const AsyncValue<SubscriptionView?>.loading();
    final api = ref.read(subscriptionsApiProvider);
    try {
      final results = await Future.wait([
        api.subscription(id),
        api.activities(id),
      ]);
      _activities = results[1] as List<SubActivityView>;
      state =
          AsyncValue<SubscriptionView?>.data(results[0] as SubscriptionView?);
    } catch (e, st) {
      state = AsyncValue<SubscriptionView?>.error(e, st);
    }
  }
}

final subscriptionDetailProvider = NotifierProvider.family<
    SubscriptionDetailController,
    AsyncValue<SubscriptionView?>,
    int>(SubscriptionDetailController.new);

/// 首页与海报墙共用的数据包（1:1 对齐 iOS `SubscriptionsHomeFeed`）：
/// 订阅全集 + 整周日程 + 刚刚入库 + 下载任务快照 + ETA 映射。
class SubsHomeBundle {
  const SubsHomeBundle({
    required this.subs,
    required this.today,
    required this.recent,
    required this.etas,
    this.tasks = const [],
    this.nowMs,
  });

  final List<SubscriptionView> subs;
  final List<TodayArrivalView> today;
  final List<RecentArrivalView> recent;
  final Map<String, int> etas;
  final List<DownloadTaskView> tasks;
  final int? nowMs;

  SubsHome home() => SubsHome(
        subs,
        today,
        recent,
        etas,
        nowMs: nowMs,
        tasks: tasks,
      );

  SubsHomeBundle copyWith({
    List<SubscriptionView>? subs,
    List<TodayArrivalView>? today,
    List<RecentArrivalView>? recent,
    Map<String, int>? etas,
    List<DownloadTaskView>? tasks,
    int? nowMs,
  }) =>
      SubsHomeBundle(
        subs: subs ?? this.subs,
        today: today ?? this.today,
        recent: recent ?? this.recent,
        etas: etas ?? this.etas,
        tasks: tasks ?? this.tasks,
        nowMs: nowMs ?? this.nowMs,
      );
}

/// 首页与海报墙共享控制器：
/// - 账号隔离的 `PageSnapshots` 冷启动秒显（隔天快照丢弃过期 `today-arrivals`）；
/// - 10s 轮询 `refreshArrivals()` + `refreshTasks()`，20s 轮询 `refreshRecent()`；
/// - 同步写入 `SubscriptionIndex` 保证全站已订阅角标一致。
class SubscriptionsHomeController extends Notifier<AsyncValue<SubsHomeBundle>> {
  static const _feedSnapshotName = 'subscriptions-feed';

  String? _ownerKey;
  DateTime? _refreshedAt;
  bool _snapshotChecked = false;

  @override
  AsyncValue<SubsHomeBundle> build() =>
      const AsyncValue<SubsHomeBundle>.loading();

  ({String origin, String username, String ownerKey}) _currentOwner() {
    final session = ref.read(sessionStoreProvider);
    final origin = session.baseUrl ?? '';
    final username = session.accountUsername;
    return (
      origin: origin,
      username: username,
      ownerKey: PageSnapshots.ownerKey(origin: origin, username: username),
    );
  }

  void _adoptOwnerIfNeeded() {
    final cur = _currentOwner();
    if (_ownerKey == cur.ownerKey) return;
    _ownerKey = cur.ownerKey;
    _refreshedAt = null;
    _snapshotChecked = false;
    state = const AsyncValue<SubsHomeBundle>.loading();
  }

  Future<void> _restoreSnapshotIfNeeded() async {
    if (_snapshotChecked || state.hasValue) return;
    _snapshotChecked = true;
    final cur = _currentOwner();
    if (cur.origin.isEmpty || cur.username.isEmpty) return;

    final index = ref.read(subscriptionIndexProvider);
    await index.restoreSnapshot();
    final cachedSubs = index.subscriptions;
    final snap = await PageSnapshots.readMap(
      _feedSnapshotName,
      origin: cur.origin,
      username: cur.username,
    );
    if (_ownerKey != cur.ownerKey || state.hasValue) return;
    if (cachedSubs == null && snap == null) return;

    final subs = cachedSubs ?? const <SubscriptionView>[];
    var today = const <TodayArrivalView>[];
    var recent = const <RecentArrivalView>[];
    var tasks = const <DownloadTaskView>[];

    if (snap != null) {
      final savedAt = DateTime.tryParse((snap['saved_at'] ?? '').toString());
      final now = DateTime.now();
      final isToday = savedAt != null &&
          savedAt.year == now.year &&
          savedAt.month == now.month &&
          savedAt.day == now.day;
      if (isToday && snap['week'] is List) {
        today = (snap['week'] as List)
            .whereType<Map>()
            .map((e) => TodayArrivalView.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      if (snap['recent'] is List) {
        recent = (snap['recent'] as List)
            .whereType<Map>()
            .map((e) => RecentArrivalView.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      if (snap['tasks'] is List) {
        tasks = (snap['tasks'] as List)
            .whereType<Map>()
            .map((e) => DownloadTaskView.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }

    state = AsyncValue<SubsHomeBundle>.data(
      SubsHomeBundle(
        subs: subs,
        today: today,
        recent: recent,
        etas: _etasOf(tasks),
        tasks: tasks,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _saveSnapshot(SubsHomeBundle bundle) {
    final cur = _currentOwner();
    if (cur.origin.isEmpty || cur.username.isEmpty) return;
    unawaited(
      PageSnapshots.write(
        _feedSnapshotName,
        {
          'saved_at': DateTime.now().toIso8601String(),
          'week': bundle.today.map((e) => e.toJson()).toList(),
          'recent': bundle.recent.map((e) => e.toJson()).toList(),
          'tasks': bundle.tasks.map((e) => e.toJson()).toList(),
        },
        origin: cur.origin,
        username: cur.username,
      ),
    );
  }

  Map<String, int> _etasOf(List<DownloadTaskView> tasks) => {
        for (final t in tasks)
          if (t.infoHash.isNotEmpty) t.infoHash.toLowerCase(): t.etaSeconds,
      };

  Future<void> load() async {
    _adoptOwnerIfNeeded();
    await _restoreSnapshotIfNeeded();
    await _fetchAll();
  }

  /// 海报墙复用首页数据时使用：30s 内刷过就不重复请求。
  Future<void> refreshIfStale({Duration maxAge = const Duration(seconds: 30)}) async {
    _adoptOwnerIfNeeded();
    await _restoreSnapshotIfNeeded();
    if (state.hasValue &&
        _refreshedAt != null &&
        DateTime.now().difference(_refreshedAt!) < maxAge) {
      return;
    }
    await _fetchAll();
  }

  Future<void> reload() async {
    _adoptOwnerIfNeeded();
    await _fetchAll();
  }

  Future<void> _fetchAll() async {
    final cur = _currentOwner();
    final api = ref.read(subscriptionsApiProvider);
    final isAdmin = ref.read(permissionsProvider).isAdmin;
    try {
      final subsFuture = api.subscriptions();
      final todayFuture =
          api.todayArrivals().catchError((_) => state.valueOrNull?.today ?? <TodayArrivalView>[]);
      final recentFuture =
          api.recentArrivals().catchError((_) => state.valueOrNull?.recent ?? <RecentArrivalView>[]);
      final tasksFuture = isAdmin
          ? api.downloadTasks().catchError((_) => state.valueOrNull?.tasks ?? <DownloadTaskView>[])
          : Future.value(<DownloadTaskView>[]);

      final results = await Future.wait([
        subsFuture,
        todayFuture,
        recentFuture,
        tasksFuture,
      ]);
      if (_ownerKey != cur.ownerKey) return;

      final subs = results[0] as List<SubscriptionView>;
      final today = results[1] as List<TodayArrivalView>;
      final recent = results[2] as List<RecentArrivalView>;
      final tasks = results[3] as List<DownloadTaskView>;

      ref.read(subscriptionIndexProvider).ingest(subs);

      final bundle = SubsHomeBundle(
        subs: subs,
        today: today,
        recent: recent,
        etas: _etasOf(tasks),
        tasks: tasks,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      _refreshedAt = DateTime.now();
      state = AsyncValue<SubsHomeBundle>.data(bundle);
      _saveSnapshot(bundle);
    } catch (e, st) {
      if (_ownerKey != cur.ownerKey) return;
      if (!state.hasValue) {
        state = AsyncValue<SubsHomeBundle>.error(e, st);
      }
    }
  }

  /// 10s 轮询：刷新整周日程与管理员下载任务快照。
  Future<void> refreshArrivalsAndTasks() async {
    final prev = state.valueOrNull;
    if (prev == null || prev.subs.isEmpty) return;
    final cur = _currentOwner();
    final api = ref.read(subscriptionsApiProvider);
    final isAdmin = ref.read(permissionsProvider).isAdmin;
    try {
      final todayFuture =
          api.todayArrivals().catchError((_) => prev.today);
      final tasksFuture = isAdmin
          ? api.downloadTasks().catchError((_) => prev.tasks)
          : Future.value(prev.tasks);
      final results = await Future.wait([todayFuture, tasksFuture]);
      if (_ownerKey != cur.ownerKey) return;
      final latest = state.valueOrNull;
      if (latest == null) return;
      final today = results[0] as List<TodayArrivalView>;
      final tasks = results[1] as List<DownloadTaskView>;
      final next = latest.copyWith(
        today: today,
        tasks: tasks,
        etas: _etasOf(tasks),
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      _refreshedAt = DateTime.now();
      state = AsyncValue<SubsHomeBundle>.data(next);
      _saveSnapshot(next);
    } catch (_) {}
  }

  /// 20s 轮询：刷新刚刚入库。
  Future<void> refreshRecent() async {
    final prev = state.valueOrNull;
    if (prev == null || prev.subs.isEmpty) return;
    final cur = _currentOwner();
    try {
      final recent = await ref.read(subscriptionsApiProvider).recentArrivals();
      if (_ownerKey != cur.ownerKey) return;
      final latest = state.valueOrNull;
      if (latest == null) return;
      final next = latest.copyWith(
        recent: recent,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      state = AsyncValue<SubsHomeBundle>.data(next);
      _saveSnapshot(next);
    } catch (_) {}
  }
}

final subscriptionsHomeProvider =
    NotifierProvider<SubscriptionsHomeController, AsyncValue<SubsHomeBundle>>(
  SubscriptionsHomeController.new,
);
