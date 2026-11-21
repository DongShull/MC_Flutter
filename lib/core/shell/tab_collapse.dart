import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 主界面内容滚动 → 底栏收起信号（对齐鸿蒙 TabBarCollapse.ets）：
/// 向下滑累计超阈值且离顶超过 24 才收起；回滑累计超 10、回到顶部（≤8）或点圆钮放回。
/// 累计位移而不是单帧 dy，避免慢速滚动永远达不到阈值。
class TabCollapseBus extends ChangeNotifier {
  TabCollapseBus._();

  static final TabCollapseBus instance = TabCollapseBus._();

  bool collapsed = false;
  double _lastTop = -1;
  int _direction = 0;
  double _distance = 0;

  /// 内容滚动上报（传当前离顶 pixels）。换页签时调 [reset]。
  void onScroll(double top) {
    final dy = _lastTop >= 0 ? top - _lastTop : 0.0;
    _lastTop = top;
    if (top <= 8) {
      _set(false);
      _direction = 0;
      _distance = 0;
      return;
    }
    if (dy == 0) return;
    final direction = dy > 0 ? 1 : -1;
    _distance =
        direction == _direction ? _distance + dy.abs() : dy.abs();
    _direction = direction;
    if (direction > 0 && _distance > 6 && top > 24) {
      _set(true);
      return;
    }
    if (direction < 0 && _distance > 10) {
      _set(false);
    }
  }

  /// 放回整条底栏（换页签、点圆形按钮）。
  void expand() {
    _lastTop = -1;
    _direction = 0;
    _distance = 0;
    _set(false);
  }

  void _set(bool v) {
    if (collapsed != v) {
      collapsed = v;
      notifyListeners();
    }
  }

  /// 换页签复位（新页面的滚动位置与旧页无关）。
  void reset() {
    _lastTop = -1;
    _direction = 0;
    _distance = 0;
    _set(false);
  }
}

/// 供壳层 watch 的 collapse 状态（监听 [TabCollapseBus.instance]）。
final tabCollapseProvider = ChangeNotifierProvider<TabCollapseBus>((ref) {
  return TabCollapseBus.instance;
});
