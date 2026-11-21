import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_api.dart';
import 'models.dart';
import 'home_model.dart';
import 'subscription_events.dart';
import 'subscription_index.dart';

/// 订阅列表控制器（对齐 SubsHomeScreen 的列表拉取 + SubscriptionEvents 重拉）。
class SubscriptionsListController
    extends Notifier<AsyncValue<List<SubscriptionView>>> {
  String? _kind;

  @override
  AsyncValue<List<SubscriptionView>> build() =>
      const AsyncValue<List<SubscriptionView>>.loading();

  /// 加载列表；[kind] 为 null = 全部。SubscriptionEvents.revision 变化后调用 reload。
  Future<void> load({String? kind}) async {
    _kind = kind;
    state = const AsyncValue<List<SubscriptionView>>.loading();
    await _fetch(kind);
  }

  /// 静默重拉（保留旧数据，用于事件通知后的刷新）。
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

/// 订阅详情控制器（对齐 SubscriptionDetailScreen.kt 的 VM：详情 + 活动时间线 + ops）。
class SubscriptionDetailController
    extends FamilyNotifier<AsyncValue<SubscriptionView?>, int> {
  late int id;

  List<SubActivityView> _activities = const [];

  /// 活动时间线（message 服务端渲染原样展示）。
  List<SubActivityView> get activities => _activities;

  String? _notice;

  /// 轻提示（对应 McNotice），页面消费后 consumeNotice()。
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

  Future<void> _act(Future<void> Function() op, String done) async {
    try {
      await op();
      _notice = done;
      await load();
    } catch (e) {
      _notice = '操作失败：$e';
    }
  }

  /// 手动立即搜索。
  Future<void> searchNow() => _act(
        () => ref.read(subscriptionsApiProvider).searchNow(id),
        '已重新排队，正在搜索缺失资源',
      );

  /// 洗版（成员不带 rule_set_id 沿用当前组）。
  Future<void> upgradeRun({int? ruleSetId}) => _act(
        () => ref
            .read(subscriptionsApiProvider)
            .upgradeRun(id, ruleSetId: ruleSetId),
        '洗版已开始，进展在「追踪明细」里跟进',
      );

  /// 调整订阅（换选季）：PATCH 只带 selected_seasons。
  Future<void> updateSeasons(List<int> seasons) => _act(
        () => ref.read(subscriptionsApiProvider).update(id, {
          'selected_seasons': seasons..sort(),
        }),
        '已更新选季',
      );

  /// 更换规则组：PATCH 只带 rule_set_id（超管专属）。
  Future<void> updateRuleSet(int ruleSetId) => _act(
        () => ref
            .read(subscriptionsApiProvider)
            .update(id, {'rule_set_id': ruleSetId}),
        '已更换规则组',
      );

  /// 自动续订开关。
  Future<void> setFollowFuture(bool v) => _act(
        () =>
            ref.read(subscriptionsApiProvider).setFollowFuture(id, enabled: v),
        v ? '已开启自动续订' : '已关闭自动续订',
      );

  /// 暂停 / 恢复追踪。
  Future<void> setTracking(bool paused) => _act(
        () => ref
            .read(subscriptionsApiProvider)
            .setTrackingState(id, paused: paused),
        paused ? '已暂停追踪' : '已恢复追踪',
      );

  /// 取消订阅（不动已下载内容）；成功后通知列表重拉 + 索引摘除。
  Future<bool> unsubscribe() async {
    try {
      await ref.read(subscriptionsApiProvider).delete(id);
      SubscriptionEvents.notifyChanged();
      ref.read(subscriptionIndexProvider).remove(id);
      _notice = '订阅已取消';
      return true;
    } catch (e) {
      _notice = '取消失败：$e';
      return false;
    }
  }
}

final subscriptionDetailProvider = NotifierProvider.family<
    SubscriptionDetailController,
    AsyncValue<SubscriptionView?>,
    int>(SubscriptionDetailController.new);

/// 首页数据包：订阅全集 + 日程 + 刚刚入库 + 下载 ETA（对齐鸿蒙 SubscriptionsPage 的加载口径）。
class SubsHomeBundle {
  const SubsHomeBundle({
    required this.subs,
    required this.today,
    required this.recent,
    required this.etas,
  });

  final List<SubscriptionView> subs;
  final List<TodayArrivalView> today;
  final List<RecentArrivalView> recent;
  final Map<String, int> etas;

  SubsHome home() => SubsHome(subs, today, recent, etas);
}

/// 首页控制器：一次性拉三份列表；ETA（管理员接口）失败静默置空。
class SubscriptionsHomeController extends Notifier<AsyncValue<SubsHomeBundle>> {
  @override
  AsyncValue<SubsHomeBundle> build() =>
      const AsyncValue<SubsHomeBundle>.loading();

  Future<void> load() async {
    state = const AsyncValue<SubsHomeBundle>.loading();
    await _fetch();
  }

  Future<void> reload() => _fetch();

  Future<void> _fetch() async {
    final api = ref.read(subscriptionsApiProvider);
    try {
      final etas = <String, int>{};
      try {
        for (final t in await api.downloadTasks()) {
          if (t.infoHash.isNotEmpty) {
            etas[t.infoHash.toLowerCase()] = t.etaSeconds;
          }
        }
      } catch (_) {
        // 非管理员拿不到下载任务：ETA 回退估算。
      }
      final results = await Future.wait([
        api.subscriptions(),
        api.todayArrivals(),
        api.recentArrivals(),
      ]);
      state = AsyncValue<SubsHomeBundle>.data(SubsHomeBundle(
        subs: results[0] as List<SubscriptionView>,
        today: results[1] as List<TodayArrivalView>,
        recent: results[2] as List<RecentArrivalView>,
        etas: etas,
      ));
    } catch (e, st) {
      state = AsyncValue<SubsHomeBundle>.error(e, st);
    }
  }
}

final subscriptionsHomeProvider =
    NotifierProvider<SubscriptionsHomeController, AsyncValue<SubsHomeBundle>>(
        SubscriptionsHomeController.new);
