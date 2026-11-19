/// 订阅域事件总线（对齐 SubscriptionEvents.kt）：
/// 取消 / 新建订阅后 notifyChanged()，列表页监听后重拉——
/// 否则「取消后返回卡片还在，冷启动才消失」。
library;

/// 订阅列表变更信号（简单代次计数，监听方对比 revision 决定是否重拉）。
class SubscriptionEvents {
  SubscriptionEvents._();

  static int _revision = 0;

  /// 当前版本号；每次 notifyChanged 自增。
  static int get revision => _revision;

  /// 通知全站：订阅列表已变（取消 / 新建 / 恢复后调用）。
  static void notifyChanged() => _revision++;
}
