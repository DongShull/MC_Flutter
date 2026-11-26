import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/player/session/playback_session_api.dart';

/// 播放器底部液态玻璃控制胶囊行（对齐 `player.jpg` 实机控制层）：
/// - 左侧连体液态玻璃胶囊 `[ 音轨 | 字幕 ]`；
/// - 右侧液态玻璃胶囊：下一集 / 选集 / 投屏 / 等宽倍速。
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

  List<(String, String, String)> _trackEntries({required bool subtitle}) {
    if (subtitle) {
      return [for (final t in subtitles) (t.trackRef, t.label, t.detail)];
    }
    return [
      for (final t in audioTracks)
        (
          t.ref,
          t.label,
          [
            if (t.codec != null && t.codec!.isNotEmpty) t.codec!,
            if (t.channels != null) '${t.channels} 声道',
          ].join(' · '),
        ),
    ];
  }

  void _showTrackMenu(BuildContext context, {required bool subtitle}) {
    final entries = _trackEntries(subtitle: subtitle);
    final selected = subtitle ? selectedSubtitleTrack : selectedAudioTrack;
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
              child: Text(
                subtitle ? '选择字幕' : '选择音轨',
                style: McText.titleSm,
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('当前会话未提供可切换轨道', style: McText.caption.muted),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      if (subtitle)
                        McInsetRow(
                          title: '关闭字幕',
                          trailing: (selected ?? '').isEmpty
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
                      for (final (ref, label, detail) in entries)
                        McInsetRow(
                          title: label,
                          subtitle: detail.isEmpty ? null : detail,
                          trailing: ref == selected
                              ? const Icon(
                                  McIcons.check,
                                  size: 18,
                                  color: McTokens.accentStrong,
                                )
                              : null,
                          onTap: () {
                            if (subtitle) {
                              onPickSubtitle(ref);
                            } else {
                              onPickAudio(ref);
                            }
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
            McInsetGroup(
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
          ],
        ),
      ),
    );
  }

  Widget _segmentTap({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return McFocusRing(
      borderRadius: 999,
      child: McPressable(
        onTap: onTap,
        haptic: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 左侧连体液态玻璃胶囊：[ 音轨 | 字幕 ]
          McLiquidGlass(
            radius: McTokens.pillRadius,
            withShadow: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _segmentTap(
                  icon: McIcons.equalizer,
                  label: '音轨',
                  onTap: () => _showTrackMenu(context, subtitle: false),
                ),
                Container(width: 1, height: 16, color: McTokens.lineStrong),
                _segmentTap(
                  icon: McIcons.closedCaptioning,
                  label: '字幕',
                  onTap: () => _showTrackMenu(context, subtitle: true),
                ),
              ],
            ),
          ),
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
            McLiquidGlass(
              radius: McTokens.pillRadius,
              withShadow: false,
              child: _segmentTap(
                icon: McIcons.playListAdd,
                label: '选集',
                onTap: onEpisodes,
              ),
            ),
            const SizedBox(width: 8),
          ],
          McFocusRing(
            borderRadius: 20,
            child: McGlassIconButton(
              icon: McIcons.cast,
              tooltip: '投屏',
              onTap: onCast,
            ),
          ),
          const SizedBox(width: 8),
          McLiquidGlass(
            radius: McTokens.pillRadius,
            withShadow: false,
            child: McFocusRing(
              borderRadius: 999,
              child: McPressable(
                onTap: () => _showSpeedMenu(context),
                haptic: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    speed == 1.0 ? '倍速' : '${_label(speed)}x',
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
        ],
      ),
    );
  }

  static String _label(double speed) => speed == speed.roundToDouble()
      ? speed.round().toString()
      : speed.toStringAsFixed(
          speed == 0.5 || speed == 1.5 || speed == 2.5 ? 1 : 2,
        );
}
