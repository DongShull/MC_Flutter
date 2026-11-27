import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/models.dart';
import '../state/network_tier.dart';
import '../state/reel_inline_player.dart';

/// 单页竖屏片段：
/// - 16:9 居中真内联视频播放画格（`MediaKit` / `PlayerService` 自动循环 `[startMs, endMs]`）+ 首帧渐隐剧照垫底；
/// - 内联片段字幕叠字 + 单击播停 + 长按 2× 倍速 + 贴底实时片段进度条；
/// - 交互式画质切换胶囊（`原画 / 1080p / 720p / 480p`）+ 「全屏观看」胶囊（进入 PlaybackClip 模式）；
/// - `logoUrl` 透明片名图 + 评分徽章 + 真实导演头像点击跳转影人页 + 右下带观看进度环的交互列。
class ReelPage extends StatefulWidget {
  const ReelPage({
    super.key,
    required this.item,
    this.active = false,
    this.session,
    required this.qualityMaxHeight,
    required this.favorite,
    required this.played,
    required this.onToggleFavorite,
    required this.onTogglePlayed,
    required this.onOpenDetail,
    required this.onShare,
    required this.onFullscreen,
    required this.onPickQuality,
    this.onOpenPerson,
  });

  final ReelItemView item;
  final bool active;
  final ReelInlineSession? session;
  final int? qualityMaxHeight;
  final bool favorite;
  final bool played;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;
  final VoidCallback onOpenDetail;
  final VoidCallback onShare;
  final VoidCallback onFullscreen;
  final ValueChanged<int?> onPickQuality;
  final void Function(int tmdbPersonId, String name)? onOpenPerson;

  @override
  State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> {
  bool _overviewExpanded = false;

  void _showQualityPicker(BuildContext context) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 4, 6, 12),
              child: Text('片段画质（按当前网络记住）', style: McText.titleSm),
            ),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final opt in ReelQualityOption.all)
                  McInsetRow(
                    title: opt.label,
                    subtitle: opt.hint,
                    trailing: opt.maxHeight == widget.qualityMaxHeight
                        ? const Icon(
                            McIcons.check,
                            size: 18,
                            color: McTokens.accentStrong,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onPickQuality(opt.maxHeight);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final title = item.title;
    final rawCover = title.backdropUrl ?? item.coverUrl ?? title.posterUrl;
    final resolvedCover = McImageUrls.resolve(rawCover, widthPx: 960);
    final resolvedLogo = title.logoUrl != null && title.logoUrl!.isNotEmpty
        ? McImageUrls.resolve(title.logoUrl, widthPx: 480)
        : '';
    final overview =
        (title.episode?.overview ?? title.overview)?.trim() ?? '';
    final leadDirector =
        title.directors.isNotEmpty ? title.directors.first : null;
    final directorNames = title.directors.map((e) => e.name).join(' / ');
    final directorAvatar =
        leadDirector?.avatarUrl != null && leadDirector!.avatarUrl!.isNotEmpty
            ? McImageUrls.resolve(leadDirector.avatarUrl, widthPx: 120)
            : '';
    final session = widget.session;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bandWidth = constraints.maxWidth;
        final bandHeight = bandWidth * 9 / 16;
        final bandTop = (constraints.maxHeight * 0.44 - bandHeight / 2).clamp(
          72.0,
          double.infinity,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // 整页手势区：单击暂停/继续，长按 2× 倍速（竖向滑动交给 PageView）
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => session?.togglePause(),
                onLongPressStart: (_) => session?.setHoldSpeed(true),
                onLongPressEnd: (_) => session?.setHoldSpeed(false),
                onLongPressCancel: () => session?.setHoldSpeed(false),
                child: const SizedBox.expand(),
              ),
            ),

            // 16:9 居中真内联视频画格
            Positioned(
              left: 0,
              right: 0,
              top: bandTop,
              height: bandHeight,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (session != null)
                      KeyedSubtree(
                        key: ObjectKey(session),
                        child: session.buildVideoView(),
                      ),
                    // 首帧出来前垫剧照，出画后淡出
                    if (session != null)
                      ValueListenableBuilder<bool>(
                        valueListenable: session.hasFirstFrame,
                        builder: (_, ready, __) => IgnorePointer(
                          ignoring: ready,
                          child: AnimatedOpacity(
                            opacity: ready ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 220),
                            child: _coverStill(resolvedCover),
                          ),
                        ),
                      )
                    else
                      _coverStill(resolvedCover),

                    // 内联片段字幕叠字
                    if (session != null)
                      ValueListenableBuilder<String?>(
                        valueListenable: session.subtitleText,
                        builder: (_, sub, __) {
                          if (sub == null || sub.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            left: 14,
                            right: 14,
                            bottom: 10,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x99000000),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    sub,
                                    textAlign: TextAlign.center,
                                    style: McText.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // 缓冲 / 暂停 / 失败态中心提示
                    if (widget.active && session != null)
                      _VideoStatusOverlay(session: session),

                    // 长按 2× 倍速徽标
                    if (session != null)
                      ValueListenableBuilder<bool>(
                        valueListenable: session.holdSpeed,
                        builder: (_, holding, __) {
                          if (!holding) return const SizedBox.shrink();
                          return Positioned(
                            top: 10,
                            left: 12,
                            child: IgnorePointer(
                              child: McLiquidGlass(
                                radius: McTokens.pillRadius,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '▶▶ 2.0x',
                                  style: McText.micro
                                      .copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      )
                                      .tabular,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // 画格下方：交互式画质切换胶囊 + 全屏观看胶囊（播放时柔和压暗不抢视线）
            Positioned(
              left: 16,
              right: 16,
              top: bandTop + bandHeight + 12,
              child: session != null
                  ? ValueListenableBuilder<bool>(
                      valueListenable: session.paused,
                      builder: (_, isPaused, __) => AnimatedOpacity(
                        opacity: isPaused ? 1.0 : 0.72,
                        duration: const Duration(milliseconds: 220),
                        child: _videoActionRow(context),
                      ),
                    )
                  : _videoActionRow(context),
            ),

            // 右下交互列（收藏 / 详情 / 带进度环的已看 / 真实分享）
            Positioned(
              right: 12,
              bottom: 58,
              child: ReelActions(
                favorite: widget.favorite,
                played: widget.played,
                progressPercent: title.progressPercent,
                onToggleFavorite: widget.onToggleFavorite,
                onOpenDetail: widget.onOpenDetail,
                onTogglePlayed: widget.onTogglePlayed,
                onShare: widget.onShare,
              ),
            ),

            // 左下角信息区：透明片名 Logo / 评分徽章 / 导演头像行 / 简介
            Positioned(
              left: 16,
              right: 84,
              bottom: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (resolvedLogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 180,
                          maxHeight: 44,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: resolvedLogo,
                          httpHeaders: mcImageHeaders(),
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (title.rating != null && title.rating! > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x33F5C451),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0x66F5C451),
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              McIcons.star2Fill,
                              size: 11,
                              color: McTokens.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              title.rating!.toStringAsFixed(1),
                              style: McText.micro
                                  .copyWith(
                                    color: McTokens.warning,
                                    fontWeight: FontWeight.w700,
                                  )
                                  .tabular,
                            ),
                            if (title.genres.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                title.genres.take(2).join(' · '),
                                style: McText.micro.copyWith(
                                  color: const Color(0xCCFFFFFF),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (directorNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: McPressable(
                        onTap: (leadDirector?.tmdbPersonId != null &&
                                widget.onOpenPerson != null)
                            ? () => widget.onOpenPerson!(
                                  leadDirector!.tmdbPersonId!,
                                  leadDirector.name,
                                )
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipOval(
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: McTokens.surfaceInset,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: McTokens.lineStrong,
                                    width: 1,
                                  ),
                                ),
                                child: directorAvatar.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: directorAvatar,
                                        httpHeaders: mcImageHeaders(),
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(
                                          McIcons.user,
                                          size: 16,
                                          color: McTokens.textMuted,
                                        ),
                                      )
                                    : const Icon(
                                        McIcons.user,
                                        size: 16,
                                        color: McTokens.textMuted,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                directorNames,
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
                    ),
                  if (overview.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(
                        () => _overviewExpanded = !_overviewExpanded,
                      ),
                      child: Text(
                        title.episode != null
                            ? 'S${title.episode!.season}E${title.episode!.episode}${title.episode!.name != null ? '「${title.episode!.name}」' : ''} $overview'
                            : overview,
                        maxLines: _overviewExpanded ? 8 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.copyWith(
                          height: 1.42,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xDCF3F5F9),
                          shadows: const [
                            Shadow(color: Color(0x99000000), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 贴底实时片段进度条（按当前片段起止实时推进）
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: session != null
                  ? ValueListenableBuilder<double>(
                      valueListenable: session.progress,
                      builder: (_, p, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: p.clamp(0.0, 1.0),
                          minHeight: 2.5,
                          backgroundColor: const Color(0x33FFFFFF),
                          color: Colors.white,
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        value: 0,
                        minHeight: 2.5,
                        backgroundColor: Color(0x33FFFFFF),
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _coverStill(String url) {
    if (url.isEmpty) return const ColoredBox(color: Colors.black);
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: mcImageHeaders(),
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
    );
  }

  Widget _videoActionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _OutlineCapsule(
          label: ReelsQuality.label(widget.qualityMaxHeight),
          trailingIcon: McIcons.arrowDownS,
          onTap: () => _showQualityPicker(context),
        ),
        _OutlineCapsule(
          label: '全屏观看',
          icon: McIcons.fullscreen1,
          onTap: widget.onFullscreen,
        ),
      ],
    );
  }
}

class _VideoStatusOverlay extends StatelessWidget {
  const _VideoStatusOverlay({required this.session});

  final ReelInlineSession session;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: session.error,
      builder: (_, err, __) {
        if (err != null && err.isNotEmpty) {
          return Center(
            child: McLiquidGlass(
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(McIcons.alert1, size: 16, color: McTokens.danger),
                  const SizedBox(width: 6),
                  Text(err, style: McText.caption),
                ],
              ),
            ),
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: session.paused,
          builder: (_, isPaused, __) {
            if (isPaused) {
              return Center(
                child: IgnorePointer(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      McIcons.play2Fill,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }
            return ValueListenableBuilder<bool>(
              valueListenable: session.buffering,
              builder: (_, isBuf, __) {
                if (!isBuf) return const SizedBox.shrink();
                return const Center(
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            );
          },
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
    this.progressPercent,
    required this.onToggleFavorite,
    required this.onOpenDetail,
    required this.onTogglePlayed,
    required this.onShare,
  });

  final bool favorite;
  final bool played;
  final int? progressPercent;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenDetail;
  final VoidCallback onTogglePlayed;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final pct = (!played && progressPercent != null && progressPercent! > 0)
        ? (progressPercent!.clamp(1, 99) / 100.0)
        : 0.0;

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
        McPressable(
          onTap: onTogglePlayed,
          haptic: true,
          child: SizedBox(
            width: 52,
            child: Column(
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: played
                      ? const Icon(
                          McIcons.checkCircleFill,
                          size: 26,
                          color: McTokens.ok,
                        )
                      : CustomPaint(
                          painter: _WatchedRingPainter(progress: pct),
                          child: const Center(
                            child: Icon(
                              McIcons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  played
                      ? '已看'
                      : (pct > 0 ? '${(pct * 100).round()}%' : '已看'),
                  style: McText.micro.copyWith(
                    fontWeight: FontWeight.w500,
                    color: played ? McTokens.ok : McTokens.text,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _ReelIcon(icon: McIcons.share, label: '分享', onTap: onShare),
      ],
    );
  }
}

class _WatchedRingPainter extends CustomPainter {
  const _WatchedRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final bgPaint = Paint()
      ..color = const Color(0x4DFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final fgPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WatchedRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
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

class _OutlineCapsule extends StatelessWidget {
  const _OutlineCapsule({
    required this.label,
    this.icon,
    this.trailingIcon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return McPressable(
      onTap: onTap,
      haptic: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x40000000),
          borderRadius: BorderRadius.circular(McTokens.pillRadius),
          border: Border.all(color: const Color(0x59FFFFFF), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: McText.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 3),
              Icon(trailingIcon, size: 13, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}
