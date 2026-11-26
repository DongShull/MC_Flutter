import 'package:flutter/material.dart';

import '../../../core/models/format.dart';
import '../../../core/player/session/playback_session_api.dart';
import '../../../core/designsystem/theme.dart';

/// 全屏播放器进度条（对齐 `player.jpg` 银玻璃实机规范）：
/// - 已播轨迹纯白 `#FFFFFF` + 可跳片头/片尾段琥珀色 `#F5C451` + 底轨半透白；
/// - 圆形亮白滑块（拖动态跟手微放大）；
/// - 底部左右展示等宽时间戳（`0:26` / `-0:23`）。
class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.onScrubPreview,
    this.skipSegments = const [],
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration>? onScrubPreview;
  final List<PlaybackSkipSegment> skipSegments;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  Duration? _scrub;

  double get _fraction {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    final shown = (_scrub ?? widget.position).inMilliseconds;
    return (shown / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return const SizedBox(height: 24);
    final shown = _scrub ?? widget.position;
    final remainSeconds =
        ((total - shown.inMilliseconds).clamp(0, total) / 1000).floor();
    final scrubbing = _scrub != null;
    final thumbSize = scrubbing ? 15.0 : 11.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 22,
            child: LayoutBuilder(
              builder: (context, constraints) {
                Duration targetOf(double x) => Duration(
                  milliseconds:
                      ((x / constraints.maxWidth).clamp(0.0, 1.0) * total)
                          .round(),
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => widget.onSeek(targetOf(d.localPosition.dx)),
                  onHorizontalDragStart: (d) {
                    final t = targetOf(d.localPosition.dx);
                    setState(() => _scrub = t);
                    widget.onScrubPreview?.call(t);
                  },
                  onHorizontalDragUpdate: (d) {
                    final t = targetOf(d.localPosition.dx);
                    setState(() => _scrub = t);
                    widget.onScrubPreview?.call(t);
                  },
                  onHorizontalDragEnd: (_) {
                    final t = _scrub;
                    setState(() => _scrub = null);
                    widget.onScrubPreview?.call(
                      t ?? widget.position,
                    );
                    if (t != null) widget.onSeek(t);
                  },
                  onHorizontalDragCancel: () => setState(() => _scrub = null),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: scrubbing ? 5 : 3.5,
                          decoration: BoxDecoration(
                            color: const Color(0x47FFFFFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        for (final seg in widget.skipSegments)
                          if (seg.endMs > seg.startMs && seg.startMs < total)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: (seg.endMs / total).clamp(
                                  0.0,
                                  1.0,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FractionallySizedBox(
                                    widthFactor:
                                        1.0 -
                                        (seg.startMs / total).clamp(0.0, 1.0),
                                    child: Container(
                                      height: scrubbing ? 6 : 4.5,
                                      decoration: BoxDecoration(
                                        color: McTokens.warning,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        FractionallySizedBox(
                          widthFactor: _fraction,
                          child: Container(
                            height: scrubbing ? 5 : 3.5,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(_fraction * 2 - 1, 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: thumbSize,
                            height: thumbSize,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x80000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mcFormatClock(shown.inSeconds),
                style: McText.micro
                    .copyWith(
                      color: const Color(0xCCF3F5F9),
                      fontWeight: FontWeight.w500,
                    )
                    .tabular,
              ),
              Text(
                '-${mcFormatClock(remainSeconds)}',
                style: McText.micro
                    .copyWith(
                      color: McTokens.textMuted,
                      fontWeight: FontWeight.w500,
                    )
                    .tabular,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
