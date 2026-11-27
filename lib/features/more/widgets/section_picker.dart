import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';

/// 三段式圆角胶囊分段切换器 `[ 会话 | 下载 | 服务器 ]`（支持自定义徽标颜色：待处理红点 / 更新蓝点）。
class SectionPicker extends StatelessWidget {
  const SectionPicker({
    super.key,
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onSelect,
    this.badgeIndex,
    this.badgeColor = McTokens.danger,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onSelect;
  final int? badgeIndex;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        14,
        McTokens.pagePadding,
        4,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.pillRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: McPressable(
                onTap: () => onSelect(i),
                haptic: true,
                scaleDown: 0.98,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 9,
                  ),
                  decoration: i == selected
                      ? McGlass.decoration(
                          McGlassTone.strong,
                          radius: McTokens.pillRadius,
                        )
                      : BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            McTokens.pillRadius,
                          ),
                        ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            icons[i],
                            size: 16,
                            color: i == selected
                                ? McTokens.text
                                : McTokens.textMuted,
                          ),
                          if (badgeIndex == i)
                            Positioned(
                              right: -4,
                              top: -3,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: McText.sub.copyWith(
                            color: i == selected
                                ? McTokens.text
                                : McTokens.textMuted,
                            fontWeight: i == selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
