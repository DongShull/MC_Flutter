import 'package:flutter/material.dart';

import 'mc_chrome.dart';
import 'mc_glass.dart';
import 'mc_icons.dart';
import 'theme.dart';

/// 加载 / 错误 / 空态 + 同形微光骨架屏（全 App 唯一状态视图出口）。
class McEmptyView extends StatelessWidget {
  const McEmptyView({
    super.key,
    required this.text,
    this.title,
    this.icon = McIcons.film,
    this.actionLabel,
    this.onRetry,
  });

  final String text;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: McTokens.surfaceInset,
                  shape: BoxShape.circle,
                  border: Border.all(color: McTokens.line, width: 1),
                ),
                child: Icon(icon, size: 24, color: McTokens.textFaint),
              ),
              const SizedBox(height: 14),
            ],
            if (title != null && title!.isNotEmpty) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: McText.titleSm,
              ),
              const SizedBox(height: 6),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: McText.sub.copyWith(color: McTokens.textMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              McActionPill(
                label: actionLabel ?? '重试',
                primary: false,
                tone: McGlassTone.secondary,
                height: 36,
                onTap: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class McLoadingView extends StatelessWidget {
  const McLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: McTokens.accent,
              ),
            ),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(label!, style: McText.sub),
            ],
          ],
        ),
      ),
    );
  }
}

class McErrorView extends StatelessWidget {
  const McErrorView({
    super.key,
    required this.text,
    this.title,
    this.onRetry,
  });

  final String text;
  final String? title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return McEmptyView(
      icon: McIcons.alert1,
      title: title,
      text: text,
      actionLabel: '重试',
      onRetry: onRetry,
    );
  }
}

/// 呼吸微光占位块（替代突兀的居中转圈，提供同形骨架屏）。
class McShimmerBox extends StatefulWidget {
  const McShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = McTokens.posterRadius,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  State<McShimmerBox> createState() => _McShimmerBoxState();
}

class _McShimmerBoxState extends State<McShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.92).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: McTokens.posterPlaceholder,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: McTokens.line, width: 0.8),
        ),
      ),
    );
  }
}

/// 沉浸 Hero + 两排海报的同形首屏骨架（对齐 iOS `DiscoverHeroSkeleton` + `DiscoverRowSkeleton`）。
class McFeedSkeleton extends StatelessWidget {
  const McFeedSkeleton({super.key, this.showHero = true});

  final bool showHero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHero) ...[
            const McShimmerBox(height: 440, radius: 0),
            const SizedBox(height: 28),
          ] else
            const SizedBox(height: 16),
          for (var r = 0; r < 2; r++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: McShimmerBox(width: 116, height: 20, radius: 6),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 205,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: McTokens.pagePadding,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < 4; c++) ...[
                          if (c > 0) const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              McShimmerBox(width: 118, height: 176),
                              SizedBox(height: 8),
                              McShimmerBox(width: 88, height: 12, radius: 4),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
