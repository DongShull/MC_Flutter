import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_icons.dart';

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
    required this.speed,
    required this.onPickSpeed,
    required this.onNotice,
  });

  final bool isEpisode;
  final bool hasNext;
  final VoidCallback onNext;
  final VoidCallback onEpisodes;
  final double speed;
  final ValueChanged<double> onPickSpeed;
  final ValueChanged<String> onNotice;

  Widget _pill(Widget child) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: child,
      );

  void _showTrackMenu(BuildContext context, {required bool subtitle}) {
    // TODO(playback-session): 音轨/字幕轨列表来自会话响应（audioTracks/subtitles）。
    // video_player 路线当前只保证内嵌轨由引擎直出，此处先给占位选择。
    onNotice(subtitle ? '字幕轨选择待会话接口接入（占位）' : '音轨选择待会话接口接入（占位）');
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
