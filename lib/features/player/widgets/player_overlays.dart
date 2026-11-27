import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/player/playback_watchdogs.dart';
import '../../../core/player/session/playback_session_api.dart';
import '../state/player_controller.dart';

/// 控制台 / 选集抽屉底部的氛围模糊背景（对齐 iOS `DeckAmbience.swift`）。
class DeckAmbienceBackdrop extends StatelessWidget {
  const DeckAmbienceBackdrop({super.key, this.artworkUrl});

  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    final resolved =
        artworkUrl != null && artworkUrl!.isNotEmpty
            ? McImageUrls.resolve(artworkUrl, widthPx: 240)
            : '';
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0A0C12)),
          if (resolved.isNotEmpty)
            Transform.scale(
              scale: 1.35,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                child: Opacity(
                  opacity: 0.45,
                  child: CachedNetworkImage(
                    imageUrl: resolved,
                    httpHeaders: mcImageHeaders(),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE6000000),
                  Color(0x55000000),
                  Color(0xB3000000),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 暂停遮罩（Netflix 风格大字片名，在暂停且控制层隐藏时展示）。
class PausedOverlay extends StatelessWidget {
  const PausedOverlay({
    super.key,
    required this.title,
    this.episodeLabel,
  });

  final String title;
  final String? episodeLabel;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x33000000),
              Color(0x66000000),
              Color(0xCC000000),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 56),
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已暂停',
              style: McText.caption.copyWith(
                letterSpacing: 3,
                color: const Color(0x99FFFFFF),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.titleLg.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Color(0xAA000000), blurRadius: 12),
                ],
              ),
            ),
            if (episodeLabel != null && episodeLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                episodeLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.sub.copyWith(color: const Color(0xB8FFFFFF)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 片段模式结束卡片（对齐 iOS `PlayerClipEndCard`）：支持「看全片」与「重播片段」。
class ClipEndCard extends StatelessWidget {
  const ClipEndCard({
    super.key,
    required this.onReplay,
    required this.onWatchFull,
  });

  final VoidCallback onReplay;
  final VoidCallback onWatchFull;

  @override
  Widget build(BuildContext context) {
    return McLiquidGlass(
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 224,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '片段播放完毕',
              style: McText.micro.copyWith(color: McTokens.textMuted),
            ),
            const SizedBox(height: 3),
            Text(
              '继续观看完整影片？',
              style: McText.sub.semibold.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 14),
            McActionPill(
              label: '看全片',
              icon: McIcons.play2Fill,
              primary: true,
              expanded: true,
              height: 40,
              onTap: onWatchFull,
            ),
            const SizedBox(height: 8),
            McActionPill(
              label: '重播片段',
              icon: McIcons.refreshS,
              primary: false,
              expanded: true,
              height: 40,
              onTap: onReplay,
            ),
          ],
        ),
      ),
    );
  }
}

/// 剧集片尾「即将播放下一集」卡片（对齐 iOS `PlayerUpNextCard`）：
/// - 仅在服务端片尾 `outro(toEnd)` 或真正播完时出现；
/// - 展示下一集 16:9 剧照、8 秒填充倒计时按钮；
/// - 连续自动连播满 3 集后停止倒计时，改为询问「还在看吗？」。
class UpNextCard extends StatelessWidget {
  const UpNextCard({
    super.key,
    required this.nextEpisode,
    required this.countdownProgress,
    required this.stillWatchingPrompt,
    required this.onPlayNow,
    required this.onDismiss,
  });

  final EpisodeItem nextEpisode;

  /// `0.0..1.0` 倒计时进度；`null` 表示不自动倒计时（如连播满 3 集）。
  final double? countdownProgress;
  final bool stillWatchingPrompt;
  final VoidCallback onPlayNow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final resolvedStill =
        nextEpisode.stillUrl != null && nextEpisode.stillUrl!.isNotEmpty
            ? McImageUrls.resolve(nextEpisode.stillUrl, widthPx: 320)
            : '';
    final remainSec = countdownProgress != null
        ? ((1.0 - countdownProgress!.clamp(0.0, 1.0)) *
                SkipSegmentsHelper.autoNextMs /
                1000)
            .ceil()
            .clamp(1, 8)
        : null;
    final eyebrow = stillWatchingPrompt
        ? '还在看吗？'
        : (remainSec != null ? '即将播放 · $remainSec 秒' : '下一集');

    return McLiquidGlass(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (resolvedStill.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 104,
                      height: 58,
                      child: CachedNetworkImage(
                        imageUrl: resolvedStill,
                        httpHeaders: mcImageHeaders(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: McTokens.surfaceInset,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: McText.micro
                            .copyWith(color: McTokens.textMuted)
                            .tabular,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextEpisode.code,
                        style: McText.caption.copyWith(
                          color: const Color(0xB8FFFFFF),
                        ),
                      ),
                      Text(
                        nextEpisode.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.semibold.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                McGlassIconButton(
                  icon: McIcons.close,
                  size: 28,
                  iconSize: 14,
                  tooltip: '继续看片尾',
                  onTap: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 12),
            McPressable(
              onTap: onPlayNow,
              haptic: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 36,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: countdownProgress == null
                            ? Colors.white
                            : const Color(0x55FFFFFF),
                      ),
                      if (countdownProgress != null)
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: countdownProgress!.clamp(0.0, 1.0),
                          child: const ColoredBox(color: Colors.white),
                        ),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              McIcons.play2Fill,
                              size: 14,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '立即播放',
                              style: McText.caption.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 跳过片头 / 广告 / 预告 / 片尾胶囊按钮。
class SkipSegmentPill extends StatelessWidget {
  const SkipSegmentPill({
    super.key,
    required this.segment,
    required this.onSkip,
  });

  final PlaybackSkipSegment segment;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return McActionPill(
      label: SkipSegmentsHelper.label(segment),
      icon: McIcons.skipForwardFill,
      primary: true,
      height: 38,
      onTap: onSkip,
    );
  }
}

/// 自动跳过提示胶囊：「已跳过片头 · 撤回」 / 「本剧以后自动跳过片头 · 不用」。
class SkipNoticePill extends StatelessWidget {
  const SkipNoticePill({
    super.key,
    required this.notice,
    required this.onUndo,
    required this.onDecline,
  });

  final SkipNotice notice;
  final VoidCallback onUndo;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final actionLabel = notice.actionLabel;
    return McLiquidGlass(
      radius: McTokens.pillRadius,
      padding: EdgeInsets.fromLTRB(16, 6, actionLabel != null ? 6 : 16, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            notice.message,
            style: McText.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 10),
            McPressable(
              onTap: notice.kind == SkipNoticeKind.skipped ? onUndo : onDecline,
              haptic: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  actionLabel,
                  style: McText.micro.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 弱网画质降档建议卡（对齐 iOS `PlayerQualityOfferView`）：只建议、绝不自动强切。
class QualityOfferCard extends StatelessWidget {
  const QualityOfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onDismiss,
  });

  final QualityOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final measured =
        LoadingSpeedMeter.formatBandwidth(offer.measuredBps) ?? '较慢';
    final requiredStr =
        LoadingSpeedMeter.formatBandwidth(offer.requiredBps) ?? '较高码率';
    return McLiquidGlass(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前网速较慢',
              style: McText.sub.semibold.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '实测带宽 $measured，当前片源需要约 $requiredStr，建议切换为 ${offer.tier} 流畅播放。',
              style: McText.caption.copyWith(color: const Color(0xCCFFFFFF)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                McChip(label: '保持原画', compact: true, onTap: onDismiss),
                const SizedBox(width: 8),
                McChip(
                  label: '切换 ${offer.tier}',
                  selected: true,
                  compact: true,
                  onTap: onAccept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 折叠屏半折桌面模式下半屏控制台（对齐 iOS `PlayerTabletopDeck.swift`）：
/// 折痕上方全屏播片，折痕下方铺设 `DeckAmbienceBackdrop` + 人体工学播控面板。
class PlayerTabletopDeck extends StatelessWidget {
  const PlayerTabletopDeck({
    super.key,
    required this.title,
    this.subtitle,
    this.artworkUrl,
    required this.playing,
    required this.speed,
    required this.progressBar,
    required this.bottomControls,
    required this.onTogglePlay,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onOpenSettings,
    required this.onBack,
  });

  final String title;
  final String? subtitle;
  final String? artworkUrl;
  final bool playing;
  final double speed;
  final Widget progressBar;
  final Widget bottomControls;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DeckAmbienceBackdrop(artworkUrl: artworkUrl),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    McGlassIconButton(
                      icon: McIcons.arrowLeftS,
                      size: 36,
                      iconSize: 20,
                      onTap: onBack,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.titleSm,
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.caption.muted,
                            ),
                        ],
                      ),
                    ),
                    McGlassIconButton(
                      icon: McIcons.more,
                      size: 36,
                      iconSize: 18,
                      onTap: onOpenSettings,
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    McGlassIconButton(
                      icon: McIcons.replay10,
                      size: 48,
                      iconSize: 22,
                      onTap: onSeekBack,
                    ),
                    const SizedBox(width: 32),
                    McPressable(
                      onTap: onTogglePlay,
                      haptic: true,
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: McLiquidGlass(
                          radius: 32,
                          child: Center(
                            child: Icon(
                              playing ? McIcons.pauseS : McIcons.play2Fill,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    McGlassIconButton(
                      icon: McIcons.forward10,
                      size: 48,
                      iconSize: 22,
                      onTap: onSeekForward,
                    ),
                  ],
                ),
                const Spacer(),
                progressBar,
                const SizedBox(height: 8),
                bottomControls,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
