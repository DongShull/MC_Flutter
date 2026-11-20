import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart';

/// 果冻拉伸动效（对应飞牛 flutter_assets/shaders/stretch_effect.frag）。
///
/// 实现分两条路线，运行时自动降级：
/// 1. shader 路线：加载 [McStretchShader.assetPath]，把内容 RepaintBoundary
///    快照经 fragment shader 沿拖拽轴做非线性 UV 压缩，得到与原版一致的
///    「冻拉伸」效果；
/// 2. Dart 回退路线：shader 加载失败或快照不可用时，改用弹簧驱动的
///    Transform 缩放近似同款果冻形变。
///
/// 输入统一来自滚动越界（OverscrollNotification），由临界阻尼弹簧平滑，
/// 松手后自动回弹到零。本文件只依赖 Flutter SDK，供各 feature 安全引用。

/// 全局 shader 加载器：只尝试一次，失败后所有实例都走 Dart 回退路线。
class McStretchShader {
  McStretchShader._();

  static const String assetPath = 'assets/shaders/mc_stretch.frag';

  static ui.FragmentProgram? _program;
  static bool _tried = false;
  static bool _failed = false;

  /// 尝试加载 shader；返回 null 表示本环境不支持，走 Dart 回退。
  static Future<ui.FragmentProgram?> load() async {
    if (_tried) {
      return _failed ? null : _program;
    }
    _tried = true;
    try {
      _program = await ui.FragmentProgram.fromAsset(assetPath);
    } catch (_) {
      // .frag 运行时编译不可用（无 shaderc / Impeller 差异等）。
      _failed = true;
    }
    return _failed ? null : _program;
  }
}

/// 拉伸量动力学：临界阻尼弹簧 + 无输入自动回零。
class McStretchDynamics {
  /// [ticker] 可稍后用 [attachTicker] 注入；为空且未注入时可用 [debugTick] 手动驱动（单测）。
  McStretchDynamics(this._onChanged);

  final VoidCallback _onChanged;
  Ticker? _ticker;

  /// 当前拉伸量（逻辑像素，带符号：正=向下/右越界）。
  double value = 0;
  double _target = 0;
  double _velocity = 0;
  int _lastInputMs = DateTime.now().millisecondsSinceEpoch;
  bool _active = false;

  /// 弹簧参数：刚度/阻尼按临界阻尼比约 1 调校，回弹快且不振荡。
  static const double _stiffness = 180;
  static const double _damping = 27;
  static const double maxTarget = 220;
  static const int _inputIdleMs = 60;
  static const double _step = 1 / 120;

  /// 记一笔越界输入（OverscrollNotification 的 overscroll 增量）。
  void apply(double delta) {
    _target = (_target + delta).clamp(-maxTarget, maxTarget);
    _lastInputMs = DateTime.now().millisecondsSinceEpoch;
    _start();
  }

  /// 立即回弹（ScrollEndNotification / 手势结束）。
  void release() {
    _target = 0;
    _start();
  }

  /// 注入宿主 State 的 ticker（State.initState 中 createTicker 后调用）。
  void attachTicker(Ticker ticker) {
    _ticker = ticker;
  }

  void _start() {
    if (_active) return;
    _active = true;
    _ticker?.start();
  }

  void tick(Duration elapsed) {
    // 输入停止超过 idle 阈值则目标归零（手势已停，开始回弹）。
    final idle =
        DateTime.now().millisecondsSinceEpoch - _lastInputMs > _inputIdleMs;
    if (idle) {
      _target = 0;
    }
    // 半隐式欧拉积分（固定步长，与帧率解耦）。
    _velocity += (-_stiffness * (value - _target) - _damping * _velocity) * _step;
    value += _velocity * _step;
    if (_target == 0 && value.abs() < 0.1 && _velocity.abs() < 0.5) {
      value = 0;
      _velocity = 0;
      _active = false;
      _onChanged();
      _ticker?.stop();
      return;
    }
    _onChanged();
  }

  @visibleForTesting
  void debugTick(Duration elapsed) => tick(elapsed);

  void dispose() {
    _ticker?.dispose();
  }
}

/// 果冻拉伸容器。
///
/// 用法：包住可滚动内容（如 PageView / ListView），滚动越界时内容沿拖拽
/// 方向呈现冻拉伸并自动回弹。只消费越界通知，不改变滚动行为。
class McStretchContainer extends StatefulWidget {
  const McStretchContainer({
    required this.child,
    this.axis = Axis.vertical,
    this.maxStretchFactor = 0.22,
    this.stretchIntensity = 0.85,
    super.key,
  });

  final Widget child;

  /// 滚动方向（决定消费 y 还是 x 越界分量）。
  final Axis axis;

  /// 最大拉伸幅度（相对容器尺寸的比例，0..1）。
  final double maxStretchFactor;

  /// 传给 shader 的 u_max_stretch_intensity。
  final double stretchIntensity;

  @override
  State<McStretchContainer> createState() => _McStretchContainerState();
}

class _McStretchContainerState extends State<McStretchContainer>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();

  late final McStretchDynamics _dynamics;

  ui.FragmentProgram? _program;
  bool _disposed = false;
  ui.Image? _snapshot;
  double _lastSnapshotStretch = -1;

  @override
  void initState() {
    super.initState();
    _dynamics = McStretchDynamics(_onDynamicsChanged);
    _dynamics.attachTicker(createTicker(_dynamics.tick));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadShader();
  }

  Future<void> _loadShader() async {
    if (_program != null) return;
    final p = await McStretchShader.load();
    if (_disposed || p == null || !mounted) return;
    setState(() => _program = p);
  }

  void _onDynamicsChanged() {
    if (_disposed) return;
    if (_program != null) {
      _scheduleSnapshot();
    }
    setState(() {});
  }

  // ── 快照（shader 路线）───────────────────────────────────────────

  void _scheduleSnapshot() {
    final stretch = _dynamics.value.abs();
    if (_snapshot != null && (stretch - _lastSnapshotStretch).abs() < 2) {
      return;
    }
    _lastSnapshotStretch = stretch;
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_disposed || !mounted || _program == null) return;
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return;
    try {
      final image = await ro.toImage(pixelRatio: 1.0);
      if (!mounted || _disposed) {
        image.dispose();
        return;
      }
      setState(() {
        _snapshot?.dispose();
        _snapshot = image;
      });
    } catch (_) {
      // 快照失败（如测试环境无 GPU 层）→ 保持 Dart 回退路线。
    }
  }

  // ── 通知处理 ────────────────────────────────────────────────────

  bool _onNotification(Notification n) {
    if (n is OverscrollNotification) {
      _dynamics.apply(n.overscroll);
      return false;
    }
    if (n is ScrollEndNotification) {
      _dynamics.release();
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _snapshot?.dispose();
    _dynamics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stretch = _dynamics.value.abs();
    final useShader = _program != null && _snapshot != null && stretch > 0.5;

    Widget content = RepaintBoundary(key: _boundaryKey, child: widget.child);

    if (!useShader) {
      content = ClipRect(
        child: Transform.scale(
          scaleX: widget.axis == Axis.vertical
              ? _crossScale(stretch)
              : _alongScale(stretch),
          scaleY: widget.axis == Axis.vertical
              ? _alongScale(stretch)
              : _crossScale(stretch),
          alignment: _anchor(_dynamics.value),
          child: content,
        ),
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        NotificationListener<Notification>(
          onNotification: _onNotification,
          child: content,
        ),
        if (useShader)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _McStretchPainter(
                  shader: _program!.fragmentShader(),
                  image: _snapshot!,
                  overscrollY: widget.axis == Axis.vertical ? _norm(_dynamics.value) : 0,
                  overscrollX: widget.axis == Axis.horizontal ? _norm(_dynamics.value) : 0,
                  intensity: widget.stretchIntensity,
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _norm(double px) {
    final size = _boundaryKey.currentContext?.size;
    final extent = (widget.axis == Axis.vertical
            ? size?.height ?? 1.0
            : size?.width ?? 1.0)
        .clamp(1.0, double.infinity);
    return (px / extent).clamp(-1.0, 1.0);
  }

  /// 沿拉伸轴轻微伸长，横轴微缩（果冻体积感）。
  double _alongScale(double stretch) {
    final f = (stretch / McStretchDynamics.maxTarget).clamp(0.0, 1.0);
    return 1 + 0.18 * f * widget.maxStretchFactor / 0.22;
  }

  double _crossScale(double stretch) {
    final f = (stretch / McStretchDynamics.maxTarget).clamp(0.0, 1.0);
    return 1 - 0.10 * f * widget.maxStretchFactor / 0.22;
  }

  /// 锚定在对侧边缘：向上拉时内容向下锚定并向拉伸边缘伸长。
  Alignment _anchor(double value) {
    if (widget.axis == Axis.vertical) {
      return value >= 0 ? Alignment.topCenter : Alignment.bottomCenter;
    }
    return value >= 0 ? Alignment.centerLeft : Alignment.centerRight;
  }
}

/// shader 路线的绘制器：uniform 布局与 mc_stretch.frag 一致。
///
/// effect_uniforms.glsl 先占用 float 0..2（u_size）、3（u_time）、4（u_delta），
/// 自定义 float 从 5 开始；sampler 单独编号从 0 开始。
class _McStretchPainter extends CustomPainter {
  _McStretchPainter({
    required ui.FragmentShader shader,
    required this.image,
    required this.overscrollY,
    required this.overscrollX,
    required this.intensity,
  })  : _shader = shader,
        _interpolationStrength = 0.35;

  final ui.FragmentShader _shader;
  final ui.Image image;
  final double overscrollY;
  final double overscrollX;
  final double intensity;
  final double _interpolationStrength;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (overscrollY == 0 && overscrollX == 0) return;
    _shader
      ..setFloat(0, size.width) // u_size.x
      ..setFloat(1, size.height) // u_size.y
      ..setFloat(2, 0) // u_time（未使用）
      ..setFloat(3, 0) // u_delta（未使用）
      ..setFloat(4, overscrollY)
      ..setFloat(5, overscrollX)
      ..setFloat(6, intensity)
      ..setFloat(7, _interpolationStrength)
      ..setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = _shader);
  }

  @override
  bool shouldRepaint(_McStretchPainter old) =>
      old.overscrollY != overscrollY ||
      old.overscrollX != overscrollX ||
      old.intensity != intensity ||
      old.image != image;
}