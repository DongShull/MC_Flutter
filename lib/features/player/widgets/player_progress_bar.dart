import 'package:flutter/material.dart';

import '../../../core/player/session/playback_session_api.dart';

/// 进度条：点按 = 直接跳；拖动 = 跟手预览、松手才跳（Android/iOS 同款）。
/// 实测参数对齐 Android：左右内距 35、轨 3dp 白 30%、句柄 11dp 白点。
/// 会话响应带 skipSegments 时，可跳区间在轨上用琥珀色标出（对齐 skip-intro 设计）。
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
  /// 拖动中的预览回调（null = 非拖动态）；页面拿去画中央预览浮层。
  final ValueChanged<Duration>? onScrubPreview;

  /// 播放会话下发的可跳区间（片头/片尾；空 = 未识别或旧服务端）。
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35),
      child: SizedBox(
        height: 14,
        child: total <= 0
            ? const SizedBox.shrink()
            : LayoutBuilder(builder: (context, constraints) {
                Duration targetOf(double x) => Duration(
                    milliseconds: ((x / constraints.maxWidth).clamp(0.0, 1.0) * total).round());
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => widget.onSeek(targetOf(details.localPosition.dx)),
                  onHorizontalDragStart: (details) {
                    final t = targetOf(details.localPosition.dx);
                    setState(() => _scrub = t);
                    widget.onScrubPreview?.call(t);
                  },
                  onHorizontalDragUpdate: (details) {
                    final t = targetOf(details.localPosition.dx);
                    setState(() => _scrub = t);
                    widget.onScrubPreview?.call(t);
                  },
                  onHorizontalDragEnd: (_) {
                    final t = _scrub;
                    setState(() => _scrub = null);
                    if (t != null) widget.onSeek(t);
                  },
                  onHorizontalDragCancel: () => setState(() => _scrub = null),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // 可跳区间：琥珀色块（起止毫秒 → 轨上占比）。
                        for (final seg in widget.skipSegments)
                          if (total > 0 &&
                              seg.endMs > seg.startMs &&
                              seg.startMs < total)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor:
                                    (seg.endMs / total).clamp(0.0, 1.0),
                                alignment: Alignment.centerLeft,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FractionallySizedBox(
                                    widthFactor: 1.0 -
                                        (seg.startMs / total)
                                            .clamp(0.0, 1.0),
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.amber
                                            .withValues(alpha: 0.9),
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        FractionallySizedBox(
                          widthFactor: _fraction,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(_fraction * 2 - 1, 0),
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
      ),
    );
  }
}
