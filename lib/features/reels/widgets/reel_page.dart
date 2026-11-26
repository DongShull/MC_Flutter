import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/models.dart';
import '../state/network_tier.dart';

/// 单页竖屏片段：16:9 居中画格 + 液态玻璃起播圆钮与画质/全屏胶囊 + 右下交互列 + 贴底银白进度线。
class ReelPage extends StatelessWidget {
  const ReelPage({
    super.key,
    required this.item,
    required this.favorite,
    required this.played,
    required this.onToggleFavorite,
    required this.onTogglePlayed,
    required this.onOpenDetail,
    required this.onShare,
    required this.onPlay,
  });

  final ReelItemView item;
  final bool favorite;
  final bool played;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;
  final VoidCallback onOpenDetail;
  final VoidCallback onShare;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final rawCover = item.coverUrl ?? title.backdropUrl ?? title.posterUrl;
    final resolvedCover = McImageUrls.resolve(rawCover, widthPx: 960);
    final overview =
        (title.episode?.overview ?? title.overview)?.trim() ?? '';
    final director = title.directors.isEmpty
        ? ''
        : title.directors.map((e) => e.name).join(' / ');
    final progress = title.progressPercent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bandWidth = constraints.maxWidth;
        final bandHeight = bandWidth * 9 / 16;
        final bandTop = (constraints.maxHeight * 0.45 - bandHeight / 2).clamp(
          0.0,
          double.infinity,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: bandTop,
              height: bandHeight,
              child: GestureDetector(
                onTap: onPlay,
                child: ColoredBox(
                  color: McTokens.bg,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (resolvedCover.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: resolvedCover,
                          httpHeaders: mcImageHeaders(),
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      Center(
                        child: McGlassIconButton(
                          icon: McIcons.play2Fill,
                          size: 60,
                          iconSize: 28,
                          onTap: onPlay,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: bandTop + bandHeight + 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<String>(
                    future: NetworkTier.current(),
                    builder: (context, snap) => _GlassCapsule(
                      label: snap.data ?? '原画',
                      onTap: onPlay,
                    ),
                  ),
                  _GlassCapsule(
                    label: '看全片',
                    icon: McIcons.fullscreen1,
                    onTap: onPlay,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 64,
              child: ReelActions(
                favorite: favorite,
                played: played,
                onToggleFavorite: onToggleFavorite,
                onOpenDetail: onOpenDetail,
                onTogglePlayed: onTogglePlayed,
                onShare: onShare,
              ),
            ),
            Positioned(
              left: 16,
              right: 84,
              bottom: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (director.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: McTokens.surfaceInset,
                              border: Border.all(
                                color: McTokens.lineStrong,
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              McIcons.user,
                              size: 15,
                              color: McTokens.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              director,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.sub.copyWith(
                                color: McTokens.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title.kind == 'tv' ? '主创' : '导演',
                            style: McText.caption.muted,
                          ),
                        ],
                      ),
                    ),
                  if (overview.isNotEmpty)
                    Text(
                      overview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: McText.sub.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xD6F3F5F9),
                      ),
                    ),
                ],
              ),
            ),
            if (progress != null && progress > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(1, 99) / 100,
                    minHeight: 2.5,
                    backgroundColor: const Color(0x38FFFFFF),
                    color: McTokens.accentStrong,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ReelActions extends StatelessWidget {
  const ReelActions({
    super.key,
    required this.favorite,
    required this.played,
    required this.onToggleFavorite,
    required this.onOpenDetail,
    required this.onTogglePlayed,
    required this.onShare,
  });

  final bool favorite;
  final bool played;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenDetail;
  final VoidCallback onTogglePlayed;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReelIcon(
          icon: favorite ? McIcons.heart2Fill : McIcons.heart2,
          label: '收藏',
          color: favorite ? McTokens.danger : McTokens.text,
          onTap: onToggleFavorite,
        ),
        const SizedBox(height: 18),
        _ReelIcon(
          icon: McIcons.movie,
          label: '详情',
          iconSize: 22,
          onTap: onOpenDetail,
        ),
        const SizedBox(height: 18),
        _ReelIcon(
          icon: played ? McIcons.checkCircleFill : McIcons.checkCircle,
          label: '已看',
          color: played ? McTokens.ok : McTokens.text,
          onTap: onTogglePlayed,
        ),
        const SizedBox(height: 18),
        _ReelIcon(icon: McIcons.share, label: '分享', onTap: onShare),
      ],
    );
  }
}

class _ReelIcon extends StatelessWidget {
  const _ReelIcon({
    required this.icon,
    required this.label,
    this.color = McTokens.text,
    this.iconSize = 25,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return McPressable(
      onTap: onTap,
      haptic: true,
      child: SizedBox(
        width: 52,
        child: Column(
          children: [
            Icon(icon, size: iconSize, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: McText.micro.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return McPressable(
      onTap: onTap,
      child: McLiquidGlass(
        tone: McGlassTone.secondary,
        radius: McTokens.pillRadius,
        withShadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: McTokens.text),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: McText.caption.copyWith(
                color: McTokens.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
