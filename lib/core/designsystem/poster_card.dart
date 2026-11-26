import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../image/image_urls.dart';
import 'mc_glass.dart';
import 'mc_icons.dart';
import 'theme.dart';

/// 锁死框比例的封面绘制器（对齐 iOS `LibraryArtwork` + Web `PosterImage`）：
/// 主图真实宽高比与目标框比例偏差超过 5% 时，自动以同图放大 `1.25x` + 高斯模糊压暗铺底，
/// 中央完整展示清晰原图，避免海报被裁头或拉伸变形。
class McArtwork extends StatelessWidget {
  const McArtwork({
    super.key,
    required this.url,
    this.imageAspect,
    this.frameAspect = McTokens.posterAspect,
    this.widthPx = 480,
    this.fallbackText,
    this.placeholderIcon = McIcons.film,
  });

  final String? url;
  final double? imageAspect;
  final double frameAspect;
  final int widthPx;
  final String? fallbackText;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final resolved = McImageUrls.resolve(url, widthPx: widthPx);
    final placeholder = Container(
      color: McTokens.posterPlaceholder,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: fallbackText != null && fallbackText!.isNotEmpty
          ? Text(
              fallbackText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: McText.titleSm.copyWith(color: const Color(0x3DFFFFFF)),
            )
          : Icon(placeholderIcon, size: 28, color: McTokens.textFaint),
    );

    Widget child;
    final ia = imageAspect;
    if (resolved.isEmpty) {
      child = placeholder;
    } else if (ia != null && ia > 0 && (ia - frameAspect).abs() > 0.05) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.45,
            child: Transform.scale(
              scale: 1.25,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: CachedNetworkImage(
                  imageUrl: resolved,
                  httpHeaders: mcImageHeaders(),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                ),
              ),
            ),
          ),
          const ColoredBox(color: Color(0x40000000)),
          Center(
            child: AspectRatio(
              aspectRatio: ia,
              child: CachedNetworkImage(
                imageUrl: resolved,
                httpHeaders: mcImageHeaders(),
                fit: BoxFit.contain,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
            ),
          ),
        ],
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: resolved,
        httpHeaders: mcImageHeaders(),
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      );
    }

    return AspectRatio(aspectRatio: frameAspect, child: ClipRect(child: child));
  }
}

/// 全站唯一竖版/通用海报卡片（1:1 对齐 iOS `LibraryPosterCell` & Web `PosterCard`）：
/// - 默认 `2:3` 锁死比例 + `12dp` 圆角 + `1px McTokens.line` 细内沿
/// - 左上：深透胶囊角标（带可选状态色点）
/// - 右上：评分（`★ 8.1` 等宽数字）或已看绿色圆勾 + 红色收藏桃心
/// - 底部：仅在显式传入 `progress` 时画 `2.5dp` 冷银白细进度线（去除了旧版刺眼电光蓝）
/// - 下方：单行 `14sp w600` 片名 + 单行 `13sp` 等宽数字副标题（年份 · 评分）
class McPosterCard extends StatelessWidget {
  const McPosterCard({
    super.key,
    required this.title,
    this.posterUrl,
    this.width = 122,
    this.aspect,
    this.imageAspect,
    this.radius = McTokens.posterRadius,
    this.subtitle,
    this.badge,
    this.badgeDotColor,
    this.rating,
    this.progress,
    this.played = false,
    this.favorite = false,
    this.dead = false,
    this.workingLabel,
    this.abnormalLabel,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? posterUrl;
  final double? width;
  final double? aspect;
  final double? imageAspect;
  final double radius;
  final String? subtitle;
  final String? badge;
  final Color? badgeDotColor;
  final double? rating;
  final double? progress;
  final bool played;
  final bool favorite;
  final bool dead;
  final String? workingLabel;
  final String? abnormalLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    Widget artwork = McArtwork(
      url: posterUrl,
      imageAspect: imageAspect,
      frameAspect: aspect ?? McTokens.posterAspect,
      widthPx: (aspect ?? McTokens.posterAspect) > 1.0 ? 640 : 480,
    );

    if (dead) {
      artwork = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 0.5, 0,
        ]),
        child: artwork,
      );
    }

    Widget card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: workingLabel != null ? McTokens.info : McTokens.line,
              width: workingLabel != null ? 1.8 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 0.5),
            child: Stack(
              children: [
                artwork,
                if (badge != null && badge!.isNotEmpty)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _CapsuleBadge(
                      text: badge!,
                      dotColor: badgeDotColor,
                    ),
                  ),
                if (played || favorite || (rating != null && rating! > 0))
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rating != null && rating! > 0 && !played)
                          _CapsuleBadge(
                            text: '★ ${rating!.toStringAsFixed(1)}',
                          ),
                        if (played)
                          Container(
                            width: 21,
                            height: 21,
                            decoration: BoxDecoration(
                              color: McTokens.ok.withValues(alpha: 0.88),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              McIcons.check,
                              size: 12,
                              color: McTokens.onAccent,
                            ),
                          ),
                        if (favorite) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x94000000),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              McIcons.heart2Fill,
                              size: 12,
                              color: McTokens.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (workingLabel != null && workingLabel!.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      color: const Color(0xEB070C14),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: McTokens.info,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              workingLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.micro.copyWith(color: McTokens.info),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (progress != null && progress! > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 2.8,
                      backgroundColor: const Color(0x66000000),
                      valueColor: const AlwaysStoppedAnimation(
                        McTokens.accentStrong,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: McText.posterTitle,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.caption,
          ),
        ],
        if (abnormalLabel != null && abnormalLabel!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: dead ? McTokens.textFaint : McTokens.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  abnormalLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (width != null) card = SizedBox(width: width, child: card);
    return McPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: card,
    );
  }
}

class _CapsuleBadge extends StatelessWidget {
  const _CapsuleBadge({required this.text, this.dotColor});

  final String text;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(McTokens.pillRadius),
        border: Border.all(color: const Color(0x1FFFFFFF), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: McText.micro.copyWith(color: const Color(0xF2FFFFFF)),
          ),
        ],
      ),
    );
  }
}

/// 16:9 横版「接下来继续 / 刚刚入库」剧照卡片（1:1 对齐参考实机图 `scene-1.jpg` & `scene-2.jpg`）：
/// - `16:9` 圆角 `12dp` + `1px line` 描边
/// - 图内中央或右下圆形液态玻璃播放钮、左下时间戳、贴底细银白进度条
/// - 图下片名 + 年份/季集 + 相对时间副行
class McUpNextCard extends StatelessWidget {
  const McUpNextCard({
    super.key,
    required this.title,
    this.backdropUrl,
    this.subtitle,
    this.footnote,
    this.timeLabel,
    this.badge,
    this.progress,
    this.width = 232,
    this.centerPlayIcon = true,
    this.onPlay,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? backdropUrl;
  final String? subtitle;
  final String? footnote;
  final String? timeLabel;
  final String? badge;
  final double? progress;
  final double width;
  final bool centerPlayIcon;
  final VoidCallback? onPlay;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: McPressable(
        onTap: onTap ?? onPlay,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(McTokens.posterRadius),
                border: Border.all(color: McTokens.line, width: 1),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(McTokens.posterRadius - 0.5),
                child: Stack(
                  children: [
                    McArtwork(
                      url: backdropUrl,
                      frameAspect: McTokens.backdropAspect,
                      widthPx: 640,
                    ),
                    // 底部压暗托住时间与播放钮
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 54,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xA6000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (badge != null && badge!.isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _CapsuleBadge(text: badge!),
                      ),
                    if (centerPlayIcon)
                      Positioned.fill(
                        child: Center(
                          child: GestureDetector(
                            onTap: onPlay ?? onTap,
                            child: const McLiquidGlass(
                              radius: 22,
                              blurSigma: 14,
                              withShadow: false,
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  McIcons.playFill,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: onPlay ?? onTap,
                          child: const McLiquidGlass(
                            radius: 16,
                            blurSigma: 14,
                            withShadow: false,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                McIcons.playFill,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (timeLabel != null && timeLabel!.isNotEmpty)
                      Positioned(
                        left: 10,
                        bottom: (progress != null && progress! > 0) ? 9 : 7,
                        child: Text(
                          timeLabel!,
                          style: McText.micro.copyWith(
                            color: const Color(0xEBFFFFFF),
                          ),
                        ),
                      ),
                    if (progress != null && progress! > 0)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress!.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: const Color(0x4DFFFFFF),
                            valueColor: const AlwaysStoppedAnimation(
                              McTokens.accentStrong,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.posterTitle,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption,
              ),
            ],
            if (footnote != null && footnote!.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                footnote!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption.copyWith(color: McTokens.textFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
