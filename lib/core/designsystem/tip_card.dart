import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/mc_l10n.dart';
import 'mc_glass.dart';
import 'mc_icons.dart';
import 'theme.dart';

/// 内联液态玻璃使用提示卡（1:1 对齐 iOS `MovieClaw/DesignSystem/TipCard.swift`）。
///
/// 版式照 Apple TipKit：左侧轻微弹跳提示图标、标题与正文说明、右上角关闭按钮。
/// 何时出现、关闭与行为上报由调用方结合 `tipsStoreProvider` 决定。
class McTipCard extends StatefulWidget {
  const McTipCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onClose,
    this.action,
    this.margin,
    this.animateIcon = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onClose;
  final Widget? action;
  final EdgeInsetsGeometry? margin;
  final bool animateIcon;

  @override
  State<McTipCard> createState() => _McTipCardState();
}

class _McTipCardState extends State<McTipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounceOffset;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _bounceOffset = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 4.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 4.0, end: -1.5)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -1.5, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    if (widget.animateIcon) {
      _periodicTimer = Timer.periodic(
        const Duration(milliseconds: 2800),
        (_) {
          if (mounted) _controller.forward(from: 0);
        },
      );
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = McL10n.of(context);
    Widget card = Semantics(
      container: true,
      child: McLiquidGlass(
        tone: McGlassTone.regular,
        radius: 22,
        blurSigma: 22,
        withShadow: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 30,
                child: AnimatedBuilder(
                  animation: _bounceOffset,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _bounceOffset.value),
                    child: child,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 24,
                    color: McTokens.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: McText.titleSm.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: McText.sub.copyWith(color: McTokens.textMuted),
                    ),
                    if (widget.action != null) ...[
                      const SizedBox(height: 10),
                      widget.action!,
                    ],
                  ],
                ),
              ),
            ),
            Semantics(
              button: true,
              label: l10n.close,
              child: Tooltip(
                message: l10n.close,
                child: McPressable(
                  onTap: widget.onClose,
                  haptic: true,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        McIcons.close2,
                        size: 16,
                        color: McTokens.textFaint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.margin != null) {
      card = Padding(padding: widget.margin!, child: card);
    }
    return card;
  }
}
