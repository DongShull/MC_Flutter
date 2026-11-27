import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/detail_controller.dart';

/// 详情页全出血沉浸剧照头（1:1 对齐 iOS `LibraryItemDetailView`）：
/// - 支持透明底片名 ClearLogo（`entry.logoUrl`），无图或加载失败时平滑回退文字标题；
/// - 剧照直抵物理屏幕顶部，下拉越界以底边为锚点等比放大，上滑带轻视差；
/// - 承托当前集标签、事实行（年份·片长·评分）与多版本聚合分辨率/HDR 徽标。
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.entry,
    this.selectedEpisode,
    this.activeFile,
    this.onBack,
    this.ambientColor = McTokens.bg,
    this.scrollOffset = 0,
    this.scrollOffsetListenable,
  });

  final DetailEntry entry;
  final EpisodeEntry? selectedEpisode;
  final DetailFileInfo? activeFile;
  final VoidCallback? onBack;
  final Color ambientColor;
  final double scrollOffset;
  final ValueListenable<double>? scrollOffsetListenable;

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

  List<String> _aggregatedBadges() {
    final sources = entry.isMovie
        ? entry.files.where((f) => f.state == 'in_place').toList()
        : (activeFile != null ? [activeFile!] : const <DetailFileInfo>[]);

    final resolutions = <String>{
      for (final f in sources)
        if (f.resolution != null && f.resolution!.isNotEmpty)
          mcFormatResolution(f.resolution!),
    };
    if (resolutions.isEmpty &&
        entry.resolution != null &&
        entry.resolution!.isNotEmpty) {
      resolutions.add(mcFormatResolution(entry.resolution!));
    }

    const hdrPriority = ['Dolby Vision', 'HDR10+', 'HDR10', 'HLG', 'HDR'];
    final hdrs = <String>{
      for (final f in sources)
        if (f.hdr != null && f.hdr!.isNotEmpty) f.hdr!,
    }.toList()
      ..sort((a, b) {
        final ia = hdrPriority.indexOf(a);
        final ib = hdrPriority.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    if (hdrs.isEmpty) {
      if (entry.hdrLabel != null && entry.hdrLabel!.isNotEmpty) {
        hdrs.add(entry.hdrLabel!);
      } else if (entry.hdr) {
        hdrs.add('HDR');
      }
    }

    return [
      if (entry.officialRating != null && entry.officialRating!.isNotEmpty)
        entry.officialRating!,
      ...resolutions,
      ...hdrs,
    ];
  }

  Widget _buildTitleArt(bool wide) {
    final resolvedLogo = McImageUrls.resolve(entry.logoUrl, widthPx: 720);
    final fallbackText = Text(
      entry.title,
      textAlign: wide ? TextAlign.start : TextAlign.center,
      style: McText.titleLg.copyWith(
        fontSize: wide ? 28 : 24,
        height: 1.2,
        letterSpacing: -0.3,
        shadows: const [
          Shadow(color: Color(0x66000000), blurRadius: 8),
        ],
      ),
    );
    if (resolvedLogo.isEmpty) return fallbackText;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: wide ? 360 : 260,
        maxHeight: wide ? 110 : 88,
      ),
      child: Align(
        alignment: wide ? Alignment.bottomLeft : Alignment.bottomCenter,
        child: CachedNetworkImage(
          imageUrl: resolvedLogo,
          httpHeaders: mcImageHeaders(),
          fit: BoxFit.contain,
          alignment: wide ? Alignment.bottomLeft : Alignment.bottomCenter,
          fadeInDuration: const Duration(milliseconds: 220),
          placeholder: (_, __) => fallbackText,
          errorWidget: (_, __, ___) => fallbackText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final form = McFormWatch.of(context);
    final wide = form != McDeviceForm.phone;
    final pad = wide ? McTokens.pagePaddingWide : McTokens.pagePadding;
    final heroHeight = topPad + (wide ? 388.0 : 344.0);

    final rawHero = entry.backdropUrl ?? entry.posterUrl;
    final resolvedHero = McImageUrls.resolve(rawHero, widthPx: 1280);
    final Widget heroImage = resolvedHero.isEmpty
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
            fadeInDuration: const Duration(milliseconds: 220),
            imageBuilder: (_, provider) => DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: provider,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            placeholder: (_, __) => const ColoredBox(
              color: McTokens.posterPlaceholder,
            ),
            errorWidget: (_, __, ___) => const ColoredBox(
              color: McTokens.posterPlaceholder,
            ),
          );

    Widget buildHeroTransform(double offset, Widget? child) {
      final stretch = offset < 0
          ? (1.0 + (-offset) / heroHeight).clamp(1.0, 1.35)
          : 1.0;
      final parallax = offset > 0 ? math.min(offset * 0.26, 72.0) : 0.0;
      return Transform.translate(
        offset: Offset(0, parallax),
        child: Transform.scale(
          scale: stretch,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      );
    }

    final factTokens = <String>[
      if (entry.year != null) entry.year.toString(),
      if (_runtimeText != null) _runtimeText!,
      if (entry.isTv && entry.seasons.isNotEmpty) '共 ${entry.seasons.length} 季',
      if (entry.genres.isNotEmpty) entry.genres.take(3).join(' / '),
    ];

    final badges = _aggregatedBadges();
    final ep = selectedEpisode;

    final infoColumn = Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitleArt(wide),
        if (entry.isTv && ep != null) ...[
          const SizedBox(height: 6),
          Text(
            '${ep.seasonNumber == 0 ? '特别篇' : '第 ${ep.seasonNumber} 季'}第 ${ep.episodeNumber} 集'
            '${ep.name.isNotEmpty ? ' · ${ep.name}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: McText.sub.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else if (entry.originalTitle != null &&
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
          Positioned.fill(
            child: ClipRect(
              child: scrollOffsetListenable != null
                  ? ValueListenableBuilder<double>(
                      valueListenable: scrollOffsetListenable!,
                      builder: (_, offset, child) =>
                          buildHeroTransform(offset, child),
                      child: heroImage,
                    )
                  : buildHeroTransform(scrollOffset, heroImage),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.36, 0.74, 1.0],
                  colors: [
                    Color(0x38000000),
                    Color(0x14000000),
                    Color(0xCC000000),
                    McTokens.bg,
                  ],
                ),
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
