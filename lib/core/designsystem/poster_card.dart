import '../../../core/image/image_urls.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'mc_icons.dart';

/// 海报卡片（全 App 唯一实现，审核重构 #3）：
/// 四份实现（library McPosterCard / discover McDiscoverPosterCard /
/// detail DetailPosterCard / 订阅域）的参数并集。
/// 版式：海报(默认 2:3) + 标题 + 副标题；角标=[badge] 左上、评分 [rating] 右上、
/// [progress] 底部进度条。
class McPosterCard extends StatelessWidget {
  const McPosterCard({
    super.key,
    required this.title,
    this.posterUrl,
    this.width = 120,
    this.aspect,
    this.radius = 8,
    this.subtitle,
    this.badge,
    this.rating,
    this.progress,
    this.onTap,
  });

  final String title;
  final String? posterUrl;

  /// 卡片宽度；传 null 则随父约束自适应（网格布局用）。
  final double? width;

  /// 海报宽高比，null 用海报默认 2/3（横版条目传 16/9）。
  final double? aspect;

  /// 海报圆角。
  final double radius;
  final String? subtitle;

  /// 左上角文本角标（分辨率 / 「S1」等）。
  final String? badge;

  /// 评分（右…左上角，>0 才画，显示 1 位小数）。
  final double? rating;

  /// 0..1 继续观看进度条；null 或 <=0 不画。
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: aspect ?? 2 / 3,
                child: _poster(context),
              ),
              if (badge != null)
                Positioned(
                  left: 6,
                  top: 6,
                  child: _tag(badge!, Colors.black.withValues(alpha: 0.6),
                      Colors.white),
                ),
              if (rating != null && rating! > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: _tag(
                      rating!.toStringAsFixed(1),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.white),
                ),
              if (progress != null && progress! > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    valueColor: const AlwaysStoppedAnimation(McColors.accent),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
      ],
    );
    if (width != null) card = SizedBox(width: width, child: card);
    return InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: card);
  }

  Widget _poster(BuildContext context) {
    final empty = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(McIcons.movie,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.3),
          size: 32),
    );
    if (posterUrl == null || posterUrl!.isEmpty) return empty;
    return CachedNetworkImage(
      imageUrl: McImageUrls.resolve(posterUrl),
      fit: BoxFit.cover,
      placeholder: (_, __) => empty,
      errorWidget: (_, __, ___) => empty,
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}
