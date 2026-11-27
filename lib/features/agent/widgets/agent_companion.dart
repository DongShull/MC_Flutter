import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/designsystem/theme.dart';

/// 小幕伴侣状态（对齐 iOS `AgentCompanionState`）。
enum AgentCompanionState {
  idle,
  attentive,
  working,
  complete,
  failed;

  String get semanticLabel => switch (this) {
        AgentCompanionState.idle => '小幕休息中',
        AgentCompanionState.attentive => '小幕正在倾听',
        AgentCompanionState.working => '小幕思考处理中',
        AgentCompanionState.complete => '小幕已完成回复',
        AgentCompanionState.failed => '小幕遇到了一点问题',
      };
}

/// 趴在 AI 输入框右上方的「小幕」弯月伴侣（1:1 对齐 iOS `AgentCompanion.swift`）：
/// - 响应 `idle` / `attentive` / `working` / `complete` / `failed` 五种情绪状态；
/// - 轻点打招呼触发短暂气泡问候与弹跳；
/// - 严格遵循系统 `MediaQuery.disableAnimationsOf(context)` 减弱动态效果设置。
class AgentMoonCompanion extends StatefulWidget {
  const AgentMoonCompanion({
    super.key,
    required this.activity,
    this.attentive = false,
  });

  final AgentCompanionState activity;
  final bool attentive;

  @override
  State<AgentMoonCompanion> createState() => _AgentMoonCompanionState();
}

class _AgentMoonCompanionState extends State<AgentMoonCompanion>
    with SingleTickerProviderStateMixin {
  static const _greetings = <String>[
    '我在听～',
    '今晚看点什么？',
    '随时待命！',
    '交给我来查～',
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  int _greetingIdx = 0;
  String? _greetingText;
  Timer? _greetingTimer;
  Timer? _completeResetTimer;
  AgentCompanionState _displayPose = AgentCompanionState.idle;
  AgentCompanionState? _prevActivity;

  @override
  void initState() {
    super.initState();
    _syncPose(initial: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AgentMoonCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != widget.activity ||
        oldWidget.attentive != widget.attentive) {
      _syncPose();
    }
  }

  void _syncPose({bool initial = false}) {
    final prev = _prevActivity;
    _prevActivity = widget.activity;
    _completeResetTimer?.cancel();

    var next = widget.activity;
    // 刚进入已结束的历史会话时不重复庆祝
    if (next == AgentCompanionState.complete &&
        prev != AgentCompanionState.working) {
      next = AgentCompanionState.idle;
    }
    if ((next == AgentCompanionState.idle ||
            next == AgentCompanionState.failed) &&
        widget.attentive) {
      next = AgentCompanionState.attentive;
    }

    if (initial) {
      _displayPose = next;
    } else if (_displayPose != next) {
      setState(() => _displayPose = next);
    }

    if (next == AgentCompanionState.complete) {
      _completeResetTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() {
          _displayPose = widget.attentive
              ? AgentCompanionState.attentive
              : AgentCompanionState.idle;
        });
      });
    }
  }

  void _syncAnimation() {
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _onTapGreet() {
    _greetingTimer?.cancel();
    final msg = switch (_displayPose) {
      AgentCompanionState.working => '正在努力思考中…',
      AgentCompanionState.failed => '刚才卡了一下，再试试吧',
      AgentCompanionState.complete => '搞定啦！',
      _ => _greetings[_greetingIdx++ % _greetings.length],
    };
    setState(() {
      _greetingText = msg;
      if (_displayPose == AgentCompanionState.idle) {
        _displayPose = AgentCompanionState.attentive;
      }
    });
    _greetingTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _greetingText = null;
        if (!widget.attentive && _displayPose == AgentCompanionState.attentive) {
          _displayPose = widget.activity == AgentCompanionState.working
              ? AgentCompanionState.working
              : AgentCompanionState.idle;
        }
      });
    });
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _completeResetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: _displayPose.semanticLabel,
      hint: '点按向小幕打招呼',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: _greetingText != null
                ? Container(
                    key: ValueKey(_greetingText),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: McTokens.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: McTokens.lineStrong),
                    ),
                    child: Text(
                      _greetingText!,
                      style: McText.micro.copyWith(color: McTokens.text),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          GestureDetector(
            onTap: _onTapGreet,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final phase = reduceMotion ? 0.0 : _controller.value;
                  final floatY = reduceMotion
                      ? 0.0
                      : switch (_displayPose) {
                          AgentCompanionState.working =>
                            -math.sin(phase * math.pi * 4) * 3.0,
                          AgentCompanionState.complete =>
                            -math.sin(phase * math.pi * 4).abs() * 4.5,
                          AgentCompanionState.attentive =>
                            -math.sin(phase * math.pi * 2) * 2.0 - 1.5,
                          AgentCompanionState.failed => 0.0,
                          AgentCompanionState.idle =>
                            -math.sin(phase * math.pi * 2) * 1.4,
                        };
                  return Transform.translate(
                    offset: Offset(0, floatY),
                    child: CustomPaint(
                      painter: _MoonMascotPainter(
                        pose: _displayPose,
                        phase: phase,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoonMascotPainter extends CustomPainter {
  const _MoonMascotPainter({
    required this.pose,
    required this.phase,
  });

  final AgentCompanionState pose;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.36;

    final glowColor = switch (pose) {
      AgentCompanionState.working => McTokens.info,
      AgentCompanionState.complete => McTokens.ok,
      AgentCompanionState.failed => McTokens.danger,
      AgentCompanionState.attentive => const Color(0xFF9A6BFF),
      AgentCompanionState.idle => McTokens.accent,
    };

    // 柔和环境光晕
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: pose == AgentCompanionState.working ? 0.36 : 0.2),
          glowColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius * 1.65));
    canvas.drawCircle(Offset(cx, cy), radius * 1.65, glowPaint);

    // 弯月主体（银玻璃极光渐变）
    final bodyRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final moonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: switch (pose) {
          AgentCompanionState.failed => const [
              Color(0xFFE5A4A4),
              Color(0xFFB56B6B),
            ],
          AgentCompanionState.complete => const [
              Color(0xFFA7F3D0),
              Color(0xFF36E2BD),
            ],
          AgentCompanionState.working => const [
              Color(0xFFDBEAFE),
              Color(0xFF7FB0FF),
              Color(0xFF9A6BFF),
            ],
          _ => const [
              Color(0xFFF3F5F9),
              Color(0xFFCDD6E6),
              Color(0xFF9FB0C9),
            ],
        },
      ).createShader(bodyRect);

    final fullCircle = Path()..addOval(bodyRect);
    final cutout = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(cx + radius * 0.56, cy - radius * 0.36),
          radius: radius * 0.72,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, fullCircle, cutout);
    canvas.drawPath(crescent, moonPaint);

    // 表情眼睛
    final eyePaint = Paint()
      ..color = McTokens.onAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final eyeFill = Paint()..color = McTokens.onAccent;

    final leftEye = Offset(cx - radius * 0.32, cy + radius * 0.1);
    final rightEye = Offset(cx + radius * 0.14, cy + radius * 0.2);

    switch (pose) {
      case AgentCompanionState.failed:
        // X X 眼
        for (final e in [leftEye, rightEye]) {
          canvas.drawLine(e + const Offset(-2.2, -2.2), e + const Offset(2.2, 2.2), eyePaint);
          canvas.drawLine(e + const Offset(2.2, -2.2), e + const Offset(-2.2, 2.2), eyePaint);
        }
        break;
      case AgentCompanionState.complete:
        // ^ ^ 开心笑眼
        for (final e in [leftEye, rightEye]) {
          final p = Path()
            ..moveTo(e.dx - 2.6, e.dy + 1.0)
            ..quadraticBezierTo(e.dx, e.dy - 2.6, e.dx + 2.6, e.dy + 1.0);
          canvas.drawPath(p, eyePaint);
        }
        break;
      case AgentCompanionState.working:
        // 专注亮点 + 轨道星点
        canvas.drawCircle(leftEye, 1.8, eyeFill);
        canvas.drawCircle(rightEye, 1.8, eyeFill);
        final angle = phase * math.pi * 2;
        final starPos = Offset(
          cx + math.cos(angle) * (radius * 1.15),
          cy + math.sin(angle) * (radius * 0.9),
        );
        canvas.drawCircle(
          starPos,
          2.2,
          Paint()..color = const Color(0xFF36E2BD),
        );
        break;
      case AgentCompanionState.attentive:
        // 睁大倾听眼
        canvas.drawCircle(leftEye, 2.1, eyeFill);
        canvas.drawCircle(rightEye, 2.1, eyeFill);
        canvas.drawCircle(
          leftEye + const Offset(-0.6, -0.6),
          0.7,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          rightEye + const Offset(-0.6, -0.6),
          0.7,
          Paint()..color = Colors.white,
        );
        break;
      case AgentCompanionState.idle:
        // 偶尔眨眼
        final blink = phase > 0.92;
        if (blink) {
          canvas.drawLine(leftEye + const Offset(-2.2, 0), leftEye + const Offset(2.2, 0), eyePaint);
          canvas.drawLine(rightEye + const Offset(-2.2, 0), rightEye + const Offset(2.2, 0), eyePaint);
        } else {
          canvas.drawCircle(leftEye, 1.7, eyeFill);
          canvas.drawCircle(rightEye, 1.7, eyeFill);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MoonMascotPainter old) =>
      old.pose != pose || old.phase != phase;
}
