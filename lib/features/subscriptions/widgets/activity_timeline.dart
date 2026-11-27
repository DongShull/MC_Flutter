import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/models.dart';

/// 可折叠的排查记录区（1:1 对齐 iOS `ActivityLogSection`）：
/// 默认折叠，展开显示语义色圆点 + 服务端中文句子 + 相对时间。
class ActivityLogSection extends StatefulWidget {
  const ActivityLogSection({
    super.key,
    required this.activities,
    this.initiallyExpanded = false,
  });

  final List<SubActivityView> activities;
  final bool initiallyExpanded;

  @override
  State<ActivityLogSection> createState() => _ActivityLogSectionState();
}

class _ActivityLogSectionState extends State<ActivityLogSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '排查记录',
                    style: McText.sub.semibold.copyWith(
                      color: McTokens.text.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.activities.length}',
                    style: McText.caption.faint.tabular,
                  ),
                  const Spacer(),
                  Icon(
                    _open ? McIcons.arrowDownS : McIcons.chevronRight,
                    size: 14,
                    color: McTokens.textFaint,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1, color: McTokens.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
              child: ActivityTimeline(activities: widget.activities),
            ),
          ],
        ],
      ),
    );
  }
}

/// 活动时间线：语义色圆点 + 竖连线 + 后端渲染的中文句子 + 相对时间。
class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({super.key, required this.activities});

  final List<SubActivityView> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('暂无活动记录', style: McText.caption.faint),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < activities.length; i++)
          _row(activities[i], isLast: i == activities.length - 1),
      ],
    );
  }

  Widget _row(SubActivityView item, {required bool isLast}) {
    final color = WantedLogic.activityColor(item.type);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.only(top: 5),
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      item.message,
                      style: McText.caption.copyWith(
                        color: McTokens.text.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    SubsFormat.relative(item.createdAt),
                    style: McText.micro.faint.tabular,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
