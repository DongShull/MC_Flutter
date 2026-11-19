import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 播放器手势层 —— 逐条对齐 Android PlayerGestureLayer.kt（原对齐 iOS）的语义与常量：
///  · 单击立即生效（不为等双击延迟）；双击事后推断（0.3s 窗口），三击按新的单击算
///  · 首次移动超过 12px 才判定方向：横向 → 定位（满屏一划 = 90 秒），纵向 → 亮度/音量
///  · 长按 0.5s = 2× 变速（仅播放中可触发；移动超阈值即作废）
///  · 起始点落在上下 32px 边缘守卫内才接手势，否则交给系统
///  · 竖向调节只在 12%–76% 高度、且距左右边 ≥32px 时生效，其余区域放弃该手势
///  · 满行程 = 视口高度的 60%
/// 控制层排除由布局承担：手势层是控制层下方的兄弟节点，控件上的触摸不会落到这里。
class PlayerGestureLayer extends StatefulWidget {
  const PlayerGestureLayer({
    super.key,
    required this.enabled,
    required this.canHold,
    required this.onTap,
    required this.onDoubleTap,
    required this.onScrubStart,
    required this.onScrubTo,
    required this.onScrubEnd,
    required this.onAdjustStart,
    required this.onAdjust,
    required this.onAdjustEnd,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.child,
  });

  final bool enabled;
  final bool canHold;
  final VoidCallback onTap;
  final ValueChanged<double> onDoubleTap; // xRatio 0..1
  final VoidCallback onScrubStart;
  final ValueChanged<double> onScrubTo; // deltaRatio 相对起点
  final VoidCallback onScrubEnd;
  final ValueChanged<bool> onAdjustStart; // true = 亮度（左半屏）
  final void Function(bool brightness, double delta) onAdjust;
  final VoidCallback onAdjustEnd;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final Widget child;

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

/// 供 UI 复用的常量（定位满屏行程等）。
const int kPlayerFullSweepSeekMs = 90000;

enum _GestureIntent { undecided, scrub, adjust, hold, cancel }

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  static const double _activatePx = 12;
  static const double _edgeGuardPx = 32;
  static const int _doubleTapWindowMs = 300;
  static const int _holdDelayMs = 500;
  static const double _fullSweepRatio = 0.6;
  static const double _adjustTopExclude = 0.12;
  static const double _adjustBottomExclude = 0.24;

  int? _pointerId;
  Offset _start = Offset.zero;
  _GestureIntent _intent = _GestureIntent.undecided;
  bool _isBrightness = false;
  Timer? _holdTimer;
  int _lastTapAt = 0;

  bool _insideEdgeGuard(Offset p, Size size) =>
      p.dy > _edgeGuardPx && p.dy < size.height - _edgeGuardPx;

  bool _insideAdjustBand(Offset p, Size size) {
    final ratio = p.dy / size.height;
    final withinVertical =
        ratio >= _adjustTopExclude && ratio <= 1 - _adjustBottomExclude;
    final withinHorizontal =
        p.dx >= _edgeGuardPx && p.dx <= size.width - _edgeGuardPx;
    return withinVertical && withinHorizontal;
  }

  void _onDown(PointerDownEvent event, Size size) {
    if (!widget.enabled) return;
    _start = event.position;
    _intent = _GestureIntent.undecided;
    _isBrightness = false;
    if (!_insideEdgeGuard(_start, size)) return;
    _pointerId = event.pointer;
    if (widget.canHold) {
      _holdTimer = Timer(const Duration(milliseconds: _holdDelayMs), () {
        if (_intent == _GestureIntent.undecided) {
          _intent = _GestureIntent.hold;
          widget.onHoldStart();
        }
      });
    }
  }

  void _onMove(PointerMoveEvent event, Size size) {
    if (_pointerId != event.pointer) return;
    final position = event.position;
    if (_intent == _GestureIntent.undecided) {
      final dx = position.dx - _start.dx;
      final dy = position.dy - _start.dy;
      if (math.sqrt(dx * dx + dy * dy) > _activatePx) {
        _holdTimer?.cancel();
        if (dx.abs() >= dy.abs()) {
          _intent = _GestureIntent.scrub;
          widget.onScrubStart();
        } else if (_insideAdjustBand(_start, size)) {
          _intent = _GestureIntent.adjust;
          _isBrightness = _start.dx < size.width / 2;
          widget.onAdjustStart(_isBrightness);
        } else {
          // 竖向滑动落在排除区（顶部/底部/左右边缘）：整个手势作废
          _intent = _GestureIntent.cancel;
        }
      }
    }
    switch (_intent) {
      case _GestureIntent.scrub:
        widget.onScrubTo((position.dx - _start.dx) / size.width);
      case _GestureIntent.adjust:
        widget.onAdjust(
          _isBrightness,
          -(position.dy - _start.dy) / (size.height * _fullSweepRatio),
        );
      default:
        break;
    }
  }

  void _onUp(PointerUpEvent event, Size size) {
    if (_pointerId != event.pointer) return;
    _finish(size);
  }

  void _onCancel(PointerCancelEvent event, Size size) {
    if (_pointerId != event.pointer) return;
    _intent = _GestureIntent.cancel;
    _finish(size);
  }

  void _finish(Size size) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pointerId = null;
    switch (_intent) {
      case _GestureIntent.hold:
        widget.onHoldEnd();
      case _GestureIntent.scrub:
        widget.onScrubEnd();
      case _GestureIntent.adjust:
        widget.onAdjustEnd();
      case _GestureIntent.undecided:
        final now = DateTime.now().millisecondsSinceEpoch;
        final isDouble = now - _lastTapAt <= _doubleTapWindowMs;
        if (isDouble) {
          _lastTapAt = 0; // 三击视为新的单击
          widget.onDoubleTap((_start.dx / size.width).clamp(0.0, 1.0));
        } else {
          _lastTapAt = now;
          widget.onTap();
        }
      case _GestureIntent.cancel:
        break;
    }
    _intent = _GestureIntent.undecided;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerDown: (e) => _onDown(e, size),
          onPointerMove: (e) => _onMove(e, size),
          onPointerUp: (e) => _onUp(e, size),
          onPointerCancel: (e) => _onCancel(e, size),
          behavior: HitTestBehavior.opaque,
          child: widget.child,
        );
      },
    );
  }
}
