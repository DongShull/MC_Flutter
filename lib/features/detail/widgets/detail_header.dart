import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/detail_controller.dart';

/// 详情页全出血沉浸剧照头（1:1 对齐 iOS `LibraryItemDetailView` & `scene-1.jpg`）：
/// - 剧照直抵物理屏幕顶部，下拉越界以底边为锚点等比放大，上滑带轻视差；
/// - 底部四段柔和渐变无缝溶入 `ambientColor`（`HeroEdgeColor` 底边动态取色）；
/// - 承托片名、等宽年份/片长/评分事实行与 `4K / HDR` 微徽标。
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.entry,
    this.onBack,
    this.ambientColor = McTokens.bg,
    this.scrollOffset = 0,
  });

  final DetailEntry entry;
  final VoidCallback? onBack;
  final Color ambientColor;
  final double scrollOffset;

  String? get _runtimeText {
    final mins = entry.runtimeMinutes;
    if (mins == null || mins <= 0) return null;
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${h}h';
    }
    return '$mins 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final form = McFormWatch.of(context);
    final wide = form != McDeviceForm.phone;
    final pad = wide ? McTokens.pagePaddingWide : McTokens.pagePadding;
    final heroHeight = topPad + (wide ? 372.0 : 328.0);

    final rawHero = entry.backdropUrl ?? entry.posterUrl;
    final resolvedHero = McImageUrls.resolve(rawHero, widthPx: 1280);
    final stretch = scrollOffset < 0
        ? (1.0 + (-scrollOffset) / heroHeight).clamp(1.0, 1.35)
        : 1.0;
    final parallax = scrollOffset > 0 ? math.min(scrollOffset * 0.26, 72.0) : 0.0;

    final factTokens = <String>[
      if (entry.year != null) entry.year.toString(),
      if (_runtimeText != null) _runtimeText!,
      if (entry.isTv && entry.seasons.isNotEmpty) '共 ${entry.seasons.length} 季',
    ];

    final badges = <String>[
      if (entry.officialRating != null && entry.officialRating!.isNotEmpty)
        entry.officialRating!,
      if (entry.resolution != null && entry.resolution!.isNotEmpty)
        entry.resolution!.toUpperCase(),
      if (entry.hdr) 'HDR',
    ];

    final infoColumn = Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.title,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: McText.titleLg.copyWith(
            fontSize: wide ? 26 : 23,
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
        if (entry.originalTitle != null &&
            entry.originalTitle!.isNotEmpty &&
            entry.originalTitle != entry.title) ...[
          const SizedBox(height: 4),
          Text(
            entry.originalTitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: McText.caption.faint,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            if (factTokens.isNotEmpty)
              Text(
                factTokens.join(' · '),
                style: McText.caption.muted.tabular,
              ),
            if (entry.rating != null && entry.rating! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (factTokens.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('·', style: McText.caption.faint),
                    ),
                  const Icon(
                    McIcons.star2Fill,
                    size: 13,
                    color: McTokens.warning,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    entry.rating!.toStringAsFixed(1),
                    style: McText.caption
                        .copyWith(
                          color: McTokens.text,
                          fontWeight: FontWeight.w600,
                        )
                        .tabular,
                  ),
                ],
              ),
            for (final badge in badges)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: McTokens.surfaceInset,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: McTokens.line, width: 1),
                ),
                child: Text(
                  badge,
                  style: McText.micro.copyWith(color: McTokens.textMuted),
                ),
              ),
          ],
        ),
        if (entry.tagline != null && entry.tagline!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            entry.tagline!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: McText.caption.copyWith(
              color: McTokens.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          ClipRect(
            child: Transform.translate(
              offset: Offset(0, parallax),
              child: Transform.scale(
                scale: stretch,
                alignment: Alignment.bottomCenter,
                child: resolvedHero.isEmpty
                    ? Container(
                        color: McTokens.posterPlaceholder,
                        alignment: Alignment.center,
                        child: const Icon(
                          McIcons.film,
                          size: 44,
                          color: McTokens.textFaint,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: resolvedHero,
                        httpHeaders: mcImageHeaders(),
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 240),
                        placeholder: (_, __) =>
                            const ColoredBox(color: McTokens.posterPlaceholder),
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: McTokens.posterPlaceholder),
                      ),
              ),
            ),
          ),
          // 四段式渐隐遮罩：将剧照底边无缝溶入 HeroEdgeColor 页面氛围色
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.42, 0.76, 1.0],
                colors: [
                  const Color(0x38000000),
                  ambientColor.withValues(alpha: 0.14),
                  ambientColor.withValues(alpha: 0.84),
                  ambientColor,
                ],
              ),
            ),
          ),
          Positioned(
            left: pad,
            right: pad,
            bottom: 8,
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 112,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(McTokens.posterRadius),
                          border: Border.all(
                            color: McTokens.lineStrong,
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x99000000),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: McArtwork(
                          url: entry.posterUrl ?? entry.backdropUrl,
                          widthPx: 360,
                          fallbackText: entry.title,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: infoColumn),
                    ],
                  )
                : infoColumn,
          ),
        ],
      ),
    );
  }
}
