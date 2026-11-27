import 'package:flutter/material.dart';

import '../../../core/designsystem/theme.dart';
import '../state/player_controller.dart';

/// 影院级文本字幕叠加层：
/// - 支持 ASS `\an1..9` 九宫格定位标签（底居中 / 顶居中 / 左右对齐）；
/// - 支持持久化字号缩放 `fontScale`、距底百分比 `bottomMarginPercent`、半透黑底胶囊开关；
/// - 关闭底色胶囊时自动切换柔和文字投影（无硬描边黑缝，亮画面依旧清晰）。
class PlayerSubtitleOverlay extends StatelessWidget {
  const PlayerSubtitleOverlay({
    super.key,
    required this.cues,
    required this.fontScale,
    required this.bottomMarginPercent,
    required this.backgroundPill,
    this.chromeVisible = false,
  });

  final List<SubtitleCue> cues;
  final double fontScale;
  final double bottomMarginPercent;
  final bool backgroundPill;
  final bool chromeVisible;

  Alignment _alignmentFor(int an) => switch (an) {
        1 => Alignment.bottomLeft,
        2 => Alignment.bottomCenter,
        3 => Alignment.bottomRight,
        4 => Alignment.centerLeft,
        5 => Alignment.center,
        6 => Alignment.centerRight,
        7 => Alignment.topLeft,
        8 => Alignment.topCenter,
        9 => Alignment.topRight,
        _ => Alignment.bottomCenter,
      };

  TextAlign _textAlignFor(int an) => switch (an) {
        1 || 4 || 7 => TextAlign.left,
        3 || 6 || 9 => TextAlign.right,
        _ => TextAlign.center,
      };

  @override
  Widget build(BuildContext context) {
    if (cues.isEmpty) return const SizedBox.shrink();

    // 按 ASS \an 分组，保证顶部注释与底部对白可同时正确定位
    final byAlignment = <int, List<SubtitleCue>>{};
    for (final c in cues) {
      byAlignment.putIfAbsent(c.alignment, () => []).add(c);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final baseBottom = (h * (bottomMarginPercent / 100.0)).clamp(16.0, h * 0.35);
        final effectiveBottom = chromeVisible
            ? (baseBottom + 78.0).clamp(96.0, h * 0.45)
            : baseBottom;
        final topPad = chromeVisible ? 74.0 : 28.0;
        final horizPad = (w * 0.06).clamp(20.0, 64.0);
        final fontSize = (18.0 * fontScale).clamp(13.0, 34.0);

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final entry in byAlignment.entries)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizPad,
                    topPad,
                    horizPad,
                    effectiveBottom,
                  ),
                  child: Align(
                    alignment: _alignmentFor(entry.key),
                    child: Container(
                      padding: backgroundPill
                          ? const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            )
                          : EdgeInsets.zero,
                      decoration: backgroundPill
                          ? BoxDecoration(
                              color: const Color(0xA6000000),
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      child: Text(
                        entry.value.map((e) => e.text).join('\n'),
                        textAlign: _textAlignFor(entry.key),
                        style: McText.bodyLg.copyWith(
                          fontSize: fontSize,
                          height: 1.38,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: backgroundPill
                              ? null
                              : const [
                                  Shadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1.5),
                                  ),
                                  Shadow(
                                    color: Color(0x99000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
