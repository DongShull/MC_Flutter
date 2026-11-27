import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/player/session/playback_session_api.dart';

/// 播放器底部液态玻璃控制胶囊行：
/// - 左侧连体胶囊 `[ 音轨 | 字幕 ]`（字幕菜单带 AI 徽章、不可用原因置灰、PGS 烧录提示）；
/// - 右侧：下一集 / 选集 / 投屏(AirPlay/DLNA) / 横竖屏旋转 / 等宽倍速。
class PlayerBottomControls extends StatelessWidget {
  const PlayerBottomControls({
    super.key,
    required this.isEpisode,
    required this.hasNext,
    required this.onNext,
    required this.onEpisodes,
    required this.onCast,
    required this.speed,
    required this.onPickSpeed,
    required this.onNotice,
    this.audioTracks = const [],
    this.subtitles = const [],
    this.selectedAudioTrack,
    this.selectedSubtitleTrack,
    required this.onPickAudio,
    required this.onPickSubtitle,
    this.showOrientationToggle = false,
    this.isLandscape = true,
    this.onToggleOrientation,
    this.onAirPlay,
  });

  final bool isEpisode;
  final bool hasNext;
  final VoidCallback onNext;
  final VoidCallback onEpisodes;
  final VoidCallback onCast;
  final double speed;
  final ValueChanged<double> onPickSpeed;
  final ValueChanged<String> onNotice;

  final List<PlaybackAudioTrack> audioTracks;
  final List<PlaybackSubtitleTrack> subtitles;
  final String? selectedAudioTrack;
  final String? selectedSubtitleTrack;
  final ValueChanged<String> onPickAudio;
  final ValueChanged<String> onPickSubtitle;

  final bool showOrientationToggle;
  final bool isLandscape;
  final VoidCallback? onToggleOrientation;
  final VoidCallback? onAirPlay;

  void _showAudioMenu(BuildContext context) {
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
              child: Text('选择音轨', style: McText.titleSm),
            ),
            if (audioTracks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('当前会话未提供可切换音轨', style: McText.caption.muted),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      math.min(280.0, MediaQuery.sizeOf(ctx).height * 0.65),
                ),
                child: SingleChildScrollView(
                  child: McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      for (final t in audioTracks)
                        Opacity(
                          opacity: (t.unavailableReason == null ||
                                  t.unavailableReason!.isEmpty)
                              ? 1.0
                              : 0.45,
                          child: McInsetRow(
                            title: t.label,
                            subtitle: t.unavailableReason != null &&
                                    t.unavailableReason!.isNotEmpty
                                ? t.unavailableReason
                                : (t.isDefault ? '默认音轨' : null),
                            trailing: t.ref == selectedAudioTrack
                                ? const Icon(
                                    McIcons.check,
                                    size: 18,
                                    color: McTokens.accentStrong,
                                  )
                                : null,
                            onTap: (t.unavailableReason != null &&
                                    t.unavailableReason!.isNotEmpty)
                                ? null
                                : () {
                                    onPickAudio(t.ref);
                                    Navigator.of(ctx).pop();
                                  },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSubtitleMenu(BuildContext context) {
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
              child: Text('选择字幕', style: McText.titleSm),
            ),
            if (subtitles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('当前片源暂无字幕轨', style: McText.caption.muted),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      math.min(320.0, MediaQuery.sizeOf(ctx).height * 0.65),
                ),
                child: SingleChildScrollView(
                  child: McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      McInsetRow(
                        title: '关闭字幕',
                        trailing: (selectedSubtitleTrack ?? '').isEmpty
                            ? const Icon(
                                McIcons.check,
                                size: 18,
                                color: McTokens.accentStrong,
                              )
                            : null,
                        onTap: () {
                          onPickSubtitle('off');
                          Navigator.of(ctx).pop();
                        },
                      ),
                      for (final t in subtitles)
                        Opacity(
                          opacity: t.isAvailable ? 1.0 : 0.42,
                          child: McInsetRow(
                            title: t.label,
                            subtitle: t.isBitmap
                                ? '${t.detail} · 需服务端压制（会短暂重载）'
                                : (t.detail.isEmpty ? null : t.detail),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (t.isAi)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: McTokens.accentStrong
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: McTokens.accentStrong
                                            .withValues(alpha: 0.6),
                                        width: 0.7,
                                      ),
                                    ),
                                    child: Text(
                                      'AI',
                                      style: McText.micro.copyWith(
                                        color: McTokens.accentStrong,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (t.trackRef == selectedSubtitleTrack)
                                  const Icon(
                                    McIcons.check,
                                    size: 18,
                                    color: McTokens.accentStrong,
                                  ),
                              ],
                            ),
                            onTap: !t.isAvailable
                                ? () => onNotice(
                                      t.unavailableReason ?? '该字幕轨当前不可用',
                                    )
                                : () {
                                    onPickSubtitle(t.trackRef);
                                    Navigator.of(ctx).pop();
                                  },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSpeedMenu(BuildContext context) {
    const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
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
              child: Text('播放倍速', style: McText.titleSm),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    math.min(340.0, MediaQuery.sizeOf(ctx).height * 0.65),
              ),
              child: SingleChildScrollView(
                child: McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final s in speeds)
                      McInsetRow(
                        title: s == 1.0 ? '1.0x（正常）' : '${_label(s)}x',
                        trailing: s == speed
                            ? const Icon(
                                McIcons.check,
                                size: 18,
                                color: McTokens.accentStrong,
                              )
                            : null,
                        onTap: () {
                          onPickSpeed(s);
                          Navigator.of(ctx).pop();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentTap({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? tooltip,
    bool compact = false,
  }) {
    final tip = tooltip ?? label;
    return Tooltip(
      message: tip,
      child: Semantics(
        button: true,
        label: tip,
        child: McFocusRing(
          borderRadius: 999,
          child: McPressable(
            onTap: onTap,
            haptic: true,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: McTokens.text),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: McText.caption
                        .copyWith(
                          color: McTokens.text,
                          fontWeight: FontWeight.w500,
                        )
                        .tabular,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioSubPill(BuildContext context, {bool compact = false}) {
    return McLiquidGlass(
      radius: McTokens.pillRadius,
      withShadow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmentTap(
            icon: McIcons.equalizer,
            label: '音轨',
            tooltip: '选择音轨',
            compact: compact,
            onTap: () => _showAudioMenu(context),
          ),
          Container(width: 1, height: 16, color: McTokens.lineStrong),
          _segmentTap(
            icon: McIcons.closedCaptioning,
            label: '字幕',
            tooltip: '选择字幕',
            compact: compact,
            onTap: () => _showSubtitleMenu(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesPill({bool compact = false}) {
    return McLiquidGlass(
      radius: McTokens.pillRadius,
      withShadow: false,
      child: _segmentTap(
        icon: McIcons.playListAdd,
        label: '选集',
        tooltip: '选择剧集',
        compact: compact,
        onTap: onEpisodes,
      ),
    );
  }

  Widget _buildSpeedPill(BuildContext context, {bool compact = false}) {
    final speedLabel = speed == 1.0 ? '倍速' : '${_label(speed)}x';
    return Tooltip(
      message: '播放倍速',
      child: Semantics(
        button: true,
        label: '播放倍速：$speedLabel',
        child: McLiquidGlass(
          radius: McTokens.pillRadius,
          withShadow: false,
          child: McFocusRing(
            borderRadius: 999,
            child: McPressable(
              onTap: () => _showSpeedMenu(context),
              haptic: true,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 11 : 13,
                  vertical: 8,
                ),
                child: Text(
                  speedLabel,
                  style: McText.caption
                      .copyWith(
                        color: McTokens.text,
                        fontWeight: FontWeight.w600,
                      )
                      .tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSecondaryActions() {
    final actions = <Widget>[];
    void addAction(Widget w) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.add(w);
    }

    if (hasNext) {
      addAction(
        McFocusRing(
          borderRadius: 20,
          child: McGlassIconButton(
            icon: McIcons.skipForwardFill,
            tooltip: '下一集',
            onTap: onNext,
          ),
        ),
      );
    }
    if (onAirPlay != null) {
      addAction(
        McFocusRing(
          borderRadius: 20,
          child: McGlassIconButton(
            icon: McIcons.dlna,
            tooltip: '隔空播放 AirPlay',
            onTap: onAirPlay!,
          ),
        ),
      );
    }
    addAction(
      McFocusRing(
        borderRadius: 20,
        child: McGlassIconButton(
          icon: McIcons.cast,
          tooltip: 'DLNA 投屏',
          onTap: onCast,
        ),
      ),
    );
    if (showOrientationToggle && onToggleOrientation != null) {
      addAction(
        McFocusRing(
          borderRadius: 20,
          child: McGlassIconButton(
            icon: isLandscape
                ? McIcons.screenVertical
                : McIcons.screenHorizontal,
            tooltip: isLandscape ? '切换竖屏' : '切换横屏',
            onTap: onToggleOrientation!,
          ),
        ),
      );
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildAudioSubPill(context, compact: true),
                    const Spacer(),
                    if (isEpisode) ...[
                      _buildEpisodesPill(compact: true),
                      const SizedBox(width: 8),
                    ],
                    _buildSpeedPill(context, compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildSecondaryActions(),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildAudioSubPill(context),
              const Spacer(),
              if (hasNext) ...[
                McFocusRing(
                  borderRadius: 20,
                  child: McGlassIconButton(
                    icon: McIcons.skipForwardFill,
                    tooltip: '下一集',
                    onTap: onNext,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isEpisode) ...[
                _buildEpisodesPill(),
                const SizedBox(width: 8),
              ],
              if (onAirPlay != null) ...[
                McFocusRing(
                  borderRadius: 20,
                  child: McGlassIconButton(
                    icon: McIcons.dlna,
                    tooltip: '隔空播放 AirPlay',
                    onTap: onAirPlay!,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              McFocusRing(
                borderRadius: 20,
                child: McGlassIconButton(
                  icon: McIcons.cast,
                  tooltip: 'DLNA 投屏',
                  onTap: onCast,
                ),
              ),
              const SizedBox(width: 8),
              if (showOrientationToggle && onToggleOrientation != null) ...[
                McFocusRing(
                  borderRadius: 20,
                  child: McGlassIconButton(
                    icon: isLandscape
                        ? McIcons.screenVertical
                        : McIcons.screenHorizontal,
                    tooltip: isLandscape ? '切换竖屏' : '切换横屏',
                    onTap: onToggleOrientation!,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _buildSpeedPill(context),
            ],
          ),
        );
      },
    );
  }

  static String _label(double speed) => speed == speed.roundToDouble()
      ? speed.round().toString()
      : speed.toStringAsFixed(
          speed == 0.5 || speed == 1.5 || speed == 2.5 ? 1 : 2,
        );
}
