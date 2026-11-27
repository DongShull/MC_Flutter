import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/player_controller.dart';
import 'player_overlays.dart';

/// 选集抽屉（对齐 iOS `PlayerEpisodeDrawer.swift` + `DeckAmbience`）：
/// - 16:9 剧照缩略图 + 已看对勾 / 看了一半底部细进度条 + 缺集置灰；
/// - 正在播的那一集独立成 Hero 卡：大剧照 + 实时进度条 + 剩余分钟 + 防剧透简介（其余未看集绝不展示简介）；
/// - 配合 `PlayerPage` 内的画面让位缩放（`PlayerEpisodeStage`）与 `DeckAmbienceBackdrop` 氛围背景。
class PlayerEpisodePicker extends StatefulWidget {
  const PlayerEpisodePicker({
    super.key,
    required this.args,
    required this.currentSeason,
    required this.currentEpisode,
    required this.onSelect,
    required this.onDismiss,
    this.onSeasonChanged,
    this.loading = false,
    this.asDrawer = false,
    this.livePosition = Duration.zero,
    this.liveDuration = Duration.zero,
    this.artworkUrl,
  });

  final PlayerPageArgs args;
  final int currentSeason;
  final int currentEpisode;
  final void Function(int season, EpisodeItem episode) onSelect;
  final VoidCallback onDismiss;
  final ValueChanged<int>? onSeasonChanged;
  final bool loading;
  final bool asDrawer;
  final Duration livePosition;
  final Duration liveDuration;
  final String? artworkUrl;

  @override
  State<PlayerEpisodePicker> createState() => _PlayerEpisodePickerState();
}

class _PlayerEpisodePickerState extends State<PlayerEpisodePicker> {
  late int _season =
      widget.args.seasons.contains(widget.currentSeason) ||
              widget.args.seasons.isEmpty
          ? widget.currentSeason
          : widget.args.seasons.first;

  List<EpisodeItem> get _episodes => widget.args.episodes
      .where((e) => widget.args.seasons.isEmpty || e.season == _season)
      .toList();

  Widget _buildStill(EpisodeItem e, {required double width, required double radius}) {
    final resolved = e.stillUrl != null && e.stillUrl!.isNotEmpty
        ? McImageUrls.resolve(e.stillUrl, widthPx: (width * 2.5).round())
        : '';
    final height = (width * 9 / 16).roundToDouble();
    final progress = (!e.played && e.progressPercent != null && e.progressPercent! > 0)
        ? (e.progressPercent!.clamp(1, 99) / 100.0)
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: McTokens.surfaceInset),
            if (resolved.isNotEmpty)
              CachedNetworkImage(
                imageUrl: resolved,
                httpHeaders: mcImageHeaders(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(
                    McIcons.film,
                    size: 20,
                    color: McTokens.textMuted,
                  ),
                ),
              )
            else
              const Center(
                child: Icon(McIcons.film, size: 20, color: McTokens.textMuted),
              ),
            if (progress != null)
              Positioned(
                left: 5,
                right: 5,
                bottom: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: const Color(0x55FFFFFF),
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(EpisodeItem e) {
    final totalMs = widget.liveDuration.inMilliseconds;
    final posMs = widget.livePosition.inMilliseconds;
    final frac = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final remainMin =
        totalMs > 0 ? (((totalMs - posMs).clamp(0, totalMs)) / 60000).ceil() : null;

    return McPressable(
      onTap: widget.onDismiss,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x21FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x38FFFFFF), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStill(e, width: 120, radius: 11),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            McIcons.play2Fill,
                            size: 11,
                            color: McTokens.accentStrong,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '正在播放',
                            style: McText.micro.copyWith(
                              color: McTokens.accentStrong,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${e.episode}. ${e.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.semibold.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 防剧透原则：仅正在播放的这一集显示简介
            if (e.overview != null && e.overview!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                e.overview!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: McText.caption.copyWith(
                  color: const Color(0xB8FFFFFF),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 3,
                backgroundColor: const Color(0x38FFFFFF),
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mcFormatClock(widget.livePosition.inSeconds),
                  style: McText.micro.muted.tabular,
                ),
                if (remainMin != null)
                  Text(
                    '还剩约 $remainMin 分钟',
                    style: McText.micro.muted.tabular,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeRow(EpisodeItem e) {
    final meta = e.played
        ? '已看完'
        : (e.progressPercent != null && e.progressPercent! > 0)
            ? '已看 ${e.progressPercent}%'
            : (e.airDate ?? (!e.owned ? '缺少文件' : null));

    return Opacity(
      opacity: e.owned ? 1.0 : 0.4,
      child: McFocusRing(
        borderRadius: 14,
        child: McPressable(
          onTap: () => widget.onSelect(e.season, e),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: Row(
              children: [
                _buildStill(e, width: 102, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.episode}. ${e.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.copyWith(
                          color: e.played
                              ? const Color(0x99FFFFFF)
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meta != null && meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (e.played) ...[
                              const Icon(
                                McIcons.check,
                                size: 12,
                                color: McTokens.ok,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              meta,
                              style: McText.micro.muted.tabular,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final episodes = _episodes;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.args.seasons.isNotEmpty) ...[
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.args.seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final number = widget.args.seasons[i];
                return McChip(
                  label: number == 0 ? '特别篇' : '第 $number 季',
                  compact: true,
                  selected: number == _season,
                  onTap: () {
                    setState(() => _season = number);
                    widget.onSeasonChanged?.call(number);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (episodes.isEmpty)
          SizedBox(
            height: 140,
            child: widget.loading
                ? const McLoadingView()
                : Center(child: Text('本季暂无剧集数据', style: McText.caption.muted)),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 18),
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final e = episodes[index];
                final active = e.season == widget.currentSeason &&
                    e.episode == widget.currentEpisode;
                return active ? _buildHeroCard(e) : _buildEpisodeRow(e);
              },
            ),
          ),
      ],
    );

    final screen = MediaQuery.sizeOf(context);
    final isLandscape = screen.width > screen.height;
    final drawerWidth =
        widget.asDrawer ? (screen.width * 0.38).clamp(310.0, 400.0) : 440.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: const ColoredBox(color: Color(0x4D000000)),
        ),
        Align(
          alignment: widget.asDrawer
              ? (isLandscape ? Alignment.centerRight : Alignment.bottomCenter)
              : Alignment.center,
          child: ClipRRect(
            borderRadius: widget.asDrawer
                ? (isLandscape
                    ? const BorderRadius.horizontal(left: Radius.circular(26))
                    : const BorderRadius.vertical(top: Radius.circular(26)))
                : BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                width: widget.asDrawer && !isLandscape
                    ? double.infinity
                    : drawerWidth,
                height: widget.asDrawer
                    ? (isLandscape ? double.infinity : screen.height * 0.56)
                    : math.min(400.0, screen.height * 0.78),
                decoration: BoxDecoration(
                  color: const Color(0xE0131620),
                  border: Border.all(color: McTokens.lineStrong, width: 1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.artworkUrl != null &&
                        widget.artworkUrl!.isNotEmpty)
                      Opacity(
                        opacity: 0.35,
                        child: DeckAmbienceBackdrop(
                          artworkUrl: widget.artworkUrl,
                        ),
                      ),
                    SafeArea(
                      left: !widget.asDrawer || !isLandscape,
                      top: isLandscape,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '选集 · 共 ${episodes.length} 集',
                                        style: McText.titleSm,
                                      ),
                                    ],
                                  ),
                                ),
                                McGlassIconButton(
                                  icon: McIcons.close,
                                  size: 32,
                                  iconSize: 16,
                                  tooltip: '关闭选集',
                                  onTap: widget.onDismiss,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(child: body),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
