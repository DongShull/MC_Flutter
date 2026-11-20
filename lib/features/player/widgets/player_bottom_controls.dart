import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/player/session/playback_session_api.dart';

/// 进度条上方的工具行（Android PlayerBottomControls）：
/// 左胶囊 = 音轨 / 字幕（占位菜单），右胶囊 = 下一集 / 选集 / 倍速。
/// 倍速选中后走 ⋮ 面板；这里保留「下一集」入口（电影没有下一集/选集）。
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

  /// 会话响应里的可选轨道（空 = 服务器未提供轨道信息，菜单给提示）。
  final List<PlaybackAudioTrack> audioTracks;
  final List<PlaybackSubtitleTrack> subtitles;
  final String? selectedAudioTrack;
  final String? selectedSubtitleTrack;
  final ValueChanged<String> onPickAudio;
  final ValueChanged<String> onPickSubtitle;

  Widget _pill(Widget child) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: child,
      );

  /// 菜单条目统一视图（ref / 主文案 / 副文案）。
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

  /// 音轨/字幕轨菜单：条目来自播放会话响应；换轨走重开会话（PlayerController.switchTrack）。
  void _showTrackMenu(BuildContext context, {required bool subtitle}) {
    final entries = _trackEntries(subtitle: subtitle);
    final selected = subtitle ? selectedSubtitleTrack : selectedAudioTrack;
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xE610121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                subtitle ? '字幕' : '音轨',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (entries.isEmpty)
              const ListTile(
                dense: true,
                enabled: false,
                title: Text('服务器未提供轨道信息',
                    style: TextStyle(color: Colors.white54)),
              )
            else ...[
              if (subtitle)
                ListTile(
                  dense: true,
                  title: Text(
                    '关闭字幕',
                    style: TextStyle(
                      color: (selected ?? '').isEmpty ? primary : Colors.white,
                    ),
                  ),
                  trailing: (selected ?? '').isEmpty
                      ? Icon(McIcons.check, color: primary)
                      : null,
                  onTap: () {
                    onPickSubtitle('off');
                    Navigator.of(context).pop();
                  },
                ),
              for (final (ref, label, detail) in entries)
                ListTile(
                  dense: true,
                  title: Text(
                    label,
                    style: TextStyle(color: ref == selected ? primary : Colors.white),
                  ),
                  subtitle: detail.isEmpty
                      ? null
                      : Text(detail,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54)),
                  trailing: ref == selected
                      ? Icon(McIcons.check, color: primary)
                      : null,
                  onTap: () {
                    if (subtitle) {
                      onPickSubtitle(ref);
                    } else {
                      onPickAudio(ref);
                    }
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSpeedMenu(BuildContext context) {
    const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xE610121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('倍速', style: TextStyle(color: Colors.white)),
            ),
            for (final s in speeds)
              ListTile(
                dense: true,
                title: Text(
                  s == 1.0 ? '倍速 · 常速' : '$s x',
                  style: TextStyle(
                    color: s == speed
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                  ),
                ),
                trailing: s == speed
                    ? Icon(McIcons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  onPickSpeed(s);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _pill(McFocusRing(child: TextButton.icon(
            onPressed: () => _showTrackMenu(context, subtitle: false),
            icon: const Icon(McIcons.equalizer, size: 18, color: Colors.white),
            label: const Text('音轨', style: TextStyle(color: Colors.white)),
          ))),
          const SizedBox(width: 8),
          _pill(McFocusRing(child: TextButton.icon(
            onPressed: () => _showTrackMenu(context, subtitle: true),
            icon: const Icon(McIcons.closedCaptioning, size: 18, color: Colors.white),
            label: const Text('字幕', style: TextStyle(color: Colors.white)),
          ))),
          const Spacer(),
          if (hasNext)
            _pill(McFocusRing(child: IconButton(
              onPressed: onNext,
              icon: const Icon(McIcons.skipForwardFill, color: Colors.white),
              tooltip: '下一集',
            ))),
          if (isEpisode) ...[
            const SizedBox(width: 8),
            _pill(McFocusRing(child: IconButton(
              onPressed: onEpisodes,
              icon: const Icon(McIcons.playListAdd, color: Colors.white),
              tooltip: '选集',
            ))),
            const SizedBox(width: 8),
          ],
          _pill(McFocusRing(child: IconButton(
              onPressed: onCast,
              icon: const Icon(McIcons.cast, color: Colors.white),
              tooltip: '投屏',
            ))),
          const SizedBox(width: 8),
          _pill(McFocusRing(child: TextButton(
            onPressed: () => _showSpeedMenu(context),
            child: Text(
              speed == 1.0 ? '倍速' : '${_label(speed)}x',
              style: const TextStyle(color: Colors.white),
            ),
          ))),
        ],
      ),
    );
  }

  static String _label(double speed) =>
      speed == speed.roundToDouble()
          ? speed.round().toString()
          : speed.toStringAsFixed(speed == 0.5 || speed == 1.5 || speed == 2.5 ? 1 : 2);
}
