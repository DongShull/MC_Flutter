import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';

/// 下拉二楼 35mm 胶片走片状态器（1:1 对齐 iOS `ReelsFloor.swift`）：
/// - 跟踪下拉距离 `pull` 与是否越线 `armed`；
/// - 过线时触发重震反馈，松手进入刷片页。
class ReelsFloorController extends ChangeNotifier {
  static const double revealSpan = 20.0;
  static const double armBeyond = 35.0;

  double _pull = 0;
  double? _refreshedAt;
  bool _armed = false;
  bool _dragging = false;
  int _lastFrameIndex = 0;

  double get pull => _pull;
  bool get armed => _armed;

  double get reveal {
    final base = _refreshedAt;
    if (base == null) return 0;
    return ((_pull - base) / revealSpan).clamp(0.0, 1.0);
  }

  double get progress {
    final base = _refreshedAt;
    if (base == null) return 0;
    return ((_pull - base) / armBeyond).clamp(0.0, 1.0);
  }

  void markRefreshTriggered() {
    if (_dragging && _refreshedAt == null) {
      _refreshedAt = _pull;
      notifyListeners();
    }
  }

  void updatePull(double pullPx, {required bool dragging}) {
    final wasDragging = _dragging;
    _dragging = dragging;
    if (dragging && !wasDragging) {
      _refreshedAt = null;
    }
    _pull = math.max(0.0, pullPx);

    final pastLine = _refreshedAt != null && _pull >= _refreshedAt! + armBeyond;
    if (dragging && pastLine != _armed) {
      _armed = pastLine;
      if (_armed) {
        HapticFeedback.heavyImpact();
      }
    }

    if (reveal > 0 && !_armed) {
      final idx = ((_pull * 2.6) / 124.0).round();
      if (idx != _lastFrameIndex) {
        _lastFrameIndex = idx;
        HapticFeedback.selectionClick();
      }
    }
    notifyListeners();
  }

  /// 松手返回是否触发进入二楼刷片。
  bool releaseAndCheckEnter() {
    final shouldEnter = _dragging && _armed;
    _dragging = false;
    _armed = false;
    _refreshedAt = null;
    _pull = 0;
    notifyListeners();
    return shouldEnter;
  }

  void reset() {
    _dragging = false;
    _armed = false;
    _refreshedAt = null;
    _pull = 0;
    notifyListeners();
  }
}

/// 35mm 胶片走片组件（冷银石墨片基 + 透光齿孔 + 放映灯辉光 + 拉丝钢压片门，对齐 `ReelsFilmStrip`）。
class ReelsFilmStrip extends StatelessWidget {
  const ReelsFilmStrip({
    super.key,
    required this.controller,
    this.stills = const [],
  });

  final ReelsFloorController controller;
  final List<String> stills;

  static const double _frameW = 112;
  static const double _frameH = 70;
  static const double _step = 124;
  static const double _bandH = 104;
  static const double _travel = 2.6;
  static const int _sideCount = 3;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final reveal = controller.reveal;
        final progress = controller.progress;
        final armed = controller.armed;
        if (reveal <= 0.01) return const SizedBox.shrink();

        final rawPos = controller.pull * _travel;
        final pos = armed ? (rawPos / _step).round() * _step : rawPos;
        final base = (pos / _step).floor();
        final frac = pos - base * _step;

        return IgnorePointer(
          child: Opacity(
            opacity: reveal,
            child: Transform.translate(
              offset: Offset(-(1.0 - reveal) * 120.0, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    armed ? '松手进入片段放映厅' : '继续下拉进入片段',
                    style: McText.sub.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                      color: armed ? McTokens.accentStrong : McTokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: _bandH + 22,
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final half = constraints.maxWidth / 2;
                        final gateGap = _frameW / 2 + 9 + (armed ? 0 : 14);
                        return ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.18, 0.82, 1.0],
                          ).createShader(rect),
                          blendMode: BlendMode.dstIn,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // 冷白放映灯背光
                              Container(
                                width: 320 + 60 * progress,
                                height: _bandH,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Color.fromRGBO(
                                        204,
                                        220,
                                        255,
                                        (0.16 + 0.34 * progress)
                                            .clamp(0.0, 0.7),
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // 35mm 弧形胶片格
                              for (var k = base - _sideCount;
                                  k <= base + _sideCount;
                                  k++)
                                _buildCell(
                                  k: k,
                                  x: (k - base) * _step - frac,
                                  halfWidth: half,
                                  progress: progress,
                                ),
                              // 中心片门边框与两片拉丝钢压片板
                              Container(
                                width: _frameW + 6,
                                height: _frameH + 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: McTokens.accentStrong.withValues(
                                      alpha: armed ? 0.9 : 0.28,
                                    ),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                              for (final side in const [-1.0, 1.0])
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  transform: Matrix4.translationValues(
                                    side * gateGap,
                                    0,
                                    0,
                                  ),
                                  width: 6,
                                  height: _frameH + 22,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        const Color(0xFF30333B),
                                        Color.fromRGBO(
                                          (204 + 18 * progress).round(),
                                          (214 + 15 * progress).round(),
                                          (224 + 13 * progress).round(),
                                          1,
                                        ),
                                        const Color(0xFF262930),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell({
    required int k,
    required double x,
    required double halfWidth,
    required double progress,
  }) {
    final c = halfWidth > 0 ? x / halfWidth : 0.0;
    final near = (1.0 - c.abs() * 1.35).clamp(0.0, 1.0);
    final light = (near * (0.35 + 0.65 * progress)).clamp(0.0, 1.0);
    final url = stills.isEmpty
        ? null
        : stills[((k % stills.length) + stills.length) % stills.length];
    final holeColor =
        Color.fromRGBO(227, 235, 247, (0.1 + 0.75 * light).clamp(0.0, 1.0));
    final baseColor = Color.fromRGBO(
      (18 + 30 * light).round(),
      (20 + 33 * light).round(),
      (24 + 36 * light).round(),
      0.97,
    );

    return Transform.translate(
      offset: Offset(x, 18 * c * c),
      child: Transform.rotate(
        angle: c * 0.11,
        child: Transform.scale(
          scale: (1.0 - 0.16 * c * c).clamp(0.7, 1.0),
          child: Container(
            width: _step + 8,
            height: _bandH,
            color: baseColor,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sprockets(holeColor),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    width: _frameW,
                    height: _frameH,
                    child: url != null && url.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: McImageUrls.resolve(url, widthPx: 240),
                            httpHeaders: mcImageHeaders(),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: Color(0xFF1A1D26),
                              child: Center(
                                child: Icon(
                                  McIcons.film,
                                  size: 20,
                                  color: McTokens.textMuted,
                                ),
                              ),
                            ),
                          )
                        : const ColoredBox(
                            color: Color(0xFF1A1D26),
                            child: Center(
                              child: Icon(
                                McIcons.film,
                                size: 20,
                                color: McTokens.textMuted,
                              ),
                            ),
                          ),
                  ),
                ),
                _sprockets(holeColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sprockets(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 11,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// 走片时背景压暗遮罩。
class ReelsFloorDim extends StatelessWidget {
  const ReelsFloorDim({super.key, required this.controller});

  final ReelsFloorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final alpha = (controller.reveal * 0.3 + controller.progress * 0.3)
            .clamp(0.0, 0.7);
        if (alpha <= 0.01) return const SizedBox.shrink();
        return IgnorePointer(
          child: ColoredBox(color: Colors.black.withValues(alpha: alpha)),
        );
      },
    );
  }
}
