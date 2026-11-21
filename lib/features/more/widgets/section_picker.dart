import 'package:flutter/material.dart';

/// 三段胶囊分段选择器（对齐鸿蒙 SectionPicker）：
/// 圆角 27 容器内等宽分段按钮，选中高亮；服务器段可带提醒红点。
class SectionPicker extends StatelessWidget {
  const SectionPicker({
    super.key,
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onSelect,
    this.badgeIndex,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onSelect;

  /// 带红点的段下标（服务器段：admin 且有提醒时），null 表示无。
  final int? badgeIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? scheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      badgeIndex == i
                          ? Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(icons[i],
                                    size: 16,
                                    color: i == selected
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurfaceVariant),
                                Positioned(
                                  right: -3,
                                  top: -3,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: scheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Icon(icons[i],
                              size: 16,
                              color: i == selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: i == selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
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
