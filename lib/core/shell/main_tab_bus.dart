/// 主壳页签总线：其他域可请求「切到某页签」，主壳监听并执行切换；consume() 读完即清。
library;

import 'package:flutter/foundation.dart';

/// 主壳页签顺序（1:1 对齐 iOS `MainTabView.swift`：媒体库首页 / 订阅 / 发现 / 活动 / 我的）。
enum MainTab { library, subscriptions, discover, activity, more }

/// 切页签请求总线。
class MainTabBus extends ChangeNotifier {
  MainTabBus._();

  static final MainTabBus instance = MainTabBus._();

  MainTab? _pending;

  /// 请求切到某页签（重复请求覆盖）。
  void open(MainTab tab) {
    _pending = tab;
    notifyListeners();
  }

  /// 主壳取走并清空当前请求；无请求返回 null。
  MainTab? consume() {
    final t = _pending;
    _pending = null;
    return t;
  }
}
