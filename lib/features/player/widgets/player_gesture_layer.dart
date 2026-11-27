import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 播放器手势层（对齐 iOS `PlayerGestureLayer.swift`）：
/// - 单击与双击严格互斥（220ms 窗口）：双击左/右 ±10s 或中区播停绝不闪出控制栏；
/// - 双指捏合缩放（pinch-to-zoom）：外扩切换 `fill`（铺满），内收切换 `fit`（原始比例）；
/// - 横滑定位（满屏行程 90 秒）、左半屏竖滑亮度、右半屏竖滑音量、长按 0.5s 触发 2× 倍速；
/// - 上下 32px 边缘守卫，竖滑限定 12%–76% 高度且距左右边 ≥32px。
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
    this.onPinchMode,
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

  /// 双指缩放回调：`'fill'`（铺满屏幕）或 `'fit'`（原始比例）。
  final ValueChanged<String>? onPinchMode;
  final Widget child;

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

/// 供 UI 复用的常量（定位满屏行程 90 秒）。
const int kPlayerFullSweepSeekMs = 90000;

enum _GestureIntent { undecided, scrub, adjust, hold, pinch, cancel }

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  static const double _activatePx = 12;
  static const double _edgeGuardPx = 32;
  static const double _horizontalEdgeGuardPx = 24;
  static const int _doubleTapWindowMs = 230;
  static const double _doubleTapMaxDistancePx = 48;
  static const int _holdDelayMs = 500;
  static const double _fullSweepRatio = 0.6;
  static const double _adjustTopExclude = 0.12;
  static const double _adjustBottomExclude = 0.24;

  final Map<int, Offset> _activePointers = {};
  int? _pointerId;
  Offset _start = Offset.zero;
  double? _pinchBaseDistance;
  bool _pinchTriggered = false;
  _GestureIntent _intent = _GestureIntent.undecided;
  bool _isBrightness = false;
  Timer? _holdTimer;
  Timer? _singleTapTimer;
  int _lastTapAt = 0;
  Offset? _lastTapPos;

  @override
  void didUpdateWidget(covariant PlayerGestureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _cancelActiveGesture();
    } else if (oldWidget.canHold && !widget.canHold) {
      _holdTimer?.cancel();
      _holdTimer = null;
      if (_intent == _GestureIntent.hold) {
        _intent = _GestureIntent.cancel;
        widget.onHoldEnd();
      }
    }
  }

  void _cancelActiveGesture() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _singleTapTimer?.cancel();
    _singleTapTimer = null;
    _lastTapAt = 0;
    _lastTapPos = null;
    switch (_intent) {
      case _GestureIntent.hold:
        widget.onHoldEnd();
      case _GestureIntent.scrub:
        widget.onScrubEnd();
      case _GestureIntent.adjust:
        widget.onAdjustEnd();
      case _GestureIntent.undecided:
      case _GestureIntent.pinch:
      case _GestureIntent.cancel:
        break;
    }
    _intent = _GestureIntent.undecided;
    _pointerId = null;
    _activePointers.clear();
    _pinchBaseDistance = null;
    _pinchTriggered = false;
  }

  bool _insideEdgeGuard(Offset p, Size size) =>
      p.dy > _edgeGuardPx && p.dy < size.height - _edgeGuardPx;

  bool _insideHorizontalEdgeGuard(Offset p, Size size) =>
      p.dx > _horizontalEdgeGuardPx &&
      p.dx < size.width - _horizontalEdgeGuardPx;

  bool _insideAdjustBand(Offset p, Size size) {
    if (size.height <= 0 || size.width <= 0) return false;
    final ratio = p.dy / size.height;
    final withinVertical =
        ratio >= _adjustTopExclude && ratio <= 1 - _adjustBottomExclude;
    final withinHorizontal =
        p.dx >= _edgeGuardPx && p.dx <= size.width - _edgeGuardPx;
    return withinVertical && withinHorizontal;
  }

  double _currentTwoFingerDistance() {
    if (_activePointers.length < 2) return 0;
    final pts = _activePointers.values.take(2).toList();
    return (pts[0] - pts[1]).distance;
  }

  void _onDown(PointerDownEvent event, Size size) {
    if (!widget.enabled) return;
    final localPos = event.localPosition;
    _activePointers[event.pointer] = localPos;

    if (_activePointers.length == 2) {
      // 双指落下 -> 立即切为 pinch 意图，取消单击/长按/拖拽
      _holdTimer?.cancel();
      _singleTapTimer?.cancel();
      if (_intent == _GestureIntent.scrub) widget.onScrubEnd();
      if (_intent == _GestureIntent.adjust) widget.onAdjustEnd();
      if (_intent == _GestureIntent.hold) widget.onHoldEnd();
      _intent = _GestureIntent.pinch;
      _pinchBaseDistance = _currentTwoFingerDistance();
      _pinchTriggered = false;
      return;
    }

    if (_activePointers.length > 2) return;

    _start = localPos;
    _intent = _GestureIntent.undecided;
    _isBrightness = false;
    if (!_insideEdgeGuard(_start, size)) return;
    _pointerId = event.pointer;
    if (widget.canHold) {
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: _holdDelayMs), () {
        if (!mounted || !widget.enabled) return;
        if (_intent == _GestureIntent.undecided && _activePointers.length == 1) {
          _singleTapTimer?.cancel();
          _intent = _GestureIntent.hold;
          widget.onHoldStart();
        }
      });
    }
  }

  void _onMove(PointerMoveEvent event, Size size) {
    if (!widget.enabled) return;
    if (!_activePointers.containsKey(event.pointer)) return;
    final localPos = event.localPosition;
    _activePointers[event.pointer] = localPos;

    if (_intent == _GestureIntent.pinch) {
      if (_activePointers.length >= 2 &&
          !_pinchTriggered &&
          _pinchBaseDistance != null &&
          _pinchBaseDistance! > 16) {
        final dist = _currentTwoFingerDistance();
        final scale = dist / _pinchBaseDistance!;
        if (scale >= 1.16) {
          _pinchTriggered = true;
          widget.onPinchMode?.call('fill');
        } else if (scale <= 0.84) {
          _pinchTriggered = true;
          widget.onPinchMode?.call('fit');
        }
      }
      return;
    }

    if (_pointerId != event.pointer) return;
    if (_intent == _GestureIntent.undecided) {
      final dx = localPos.dx - _start.dx;
      final dy = localPos.dy - _start.dy;
      if (math.sqrt(dx * dx + dy * dy) > _activatePx) {
        _holdTimer?.cancel();
        _singleTapTimer?.cancel();
        if (dx.abs() >= dy.abs()) {
          if (_insideHorizontalEdgeGuard(_start, size)) {
            _intent = _GestureIntent.scrub;
            widget.onScrubStart();
          } else {
            _intent = _GestureIntent.cancel;
          }
        } else if (_insideAdjustBand(_start, size)) {
          _intent = _GestureIntent.adjust;
          _isBrightness = _start.dx < size.width / 2;
          widget.onAdjustStart(_isBrightness);
        } else {
          _intent = _GestureIntent.cancel;
        }
      }
    }
    switch (_intent) {
      case _GestureIntent.scrub:
        if (size.width > 0) {
          widget.onScrubTo((localPos.dx - _start.dx) / size.width);
        }
      case _GestureIntent.adjust:
        if (size.height > 0) {
          widget.onAdjust(
            _isBrightness,
            -(localPos.dy - _start.dy) / (size.height * _fullSweepRatio),
          );
        }
      default:
        break;
    }
  }

  void _onUp(PointerUpEvent event, Size size) {
    _activePointers.remove(event.pointer);
    if (_intent == _GestureIntent.pinch) {
      if (_activePointers.isEmpty) {
        _pinchBaseDistance = null;
        _pinchTriggered = false;
        _pointerId = null;
        _intent = _GestureIntent.undecided;
      }
      return;
    }
    if (_pointerId != event.pointer) return;
    _finish(size);
  }

  void _onCancel(PointerCancelEvent event, Size size) {
    _activePointers.remove(event.pointer);
    if (_intent == _GestureIntent.pinch) {
      if (_activePointers.isEmpty) {
        _pinchBaseDistance = null;
        _pinchTriggered = false;
        _pointerId = null;
        _intent = _GestureIntent.undecided;
      }
      return;
    }
    if (_pointerId != event.pointer) return;
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
      case _GestureIntent.pinch:
      case _GestureIntent.cancel:
        break;
    }
    _intent = _GestureIntent.undecided;
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
        final isDouble = _lastTapAt > 0 &&
            now - _lastTapAt <= _doubleTapWindowMs &&
            _lastTapPos != null &&
            (_start - _lastTapPos!).distance <= _doubleTapMaxDistancePx;
        if (isDouble) {
          _singleTapTimer?.cancel();
          _singleTapTimer = null;
          _lastTapAt = 0;
          _lastTapPos = null;
          final ratio =
              size.width > 0 ? (_start.dx / size.width).clamp(0.0, 1.0) : 0.5;
          widget.onDoubleTap(ratio);
        } else {
          _lastTapAt = now;
          _lastTapPos = _start;
          _singleTapTimer?.cancel();
          _singleTapTimer = Timer(
            const Duration(milliseconds: _doubleTapWindowMs),
            () {
              if (!mounted) return;
              _lastTapAt = 0;
              _lastTapPos = null;
              widget.onTap();
            },
          );
        }
      case _GestureIntent.pinch:
      case _GestureIntent.cancel:
        break;
    }
    _intent = _GestureIntent.undecided;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _singleTapTimer?.cancel();
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
