
import 'package:flutter/material.dart';

import '../state/agent_state.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 对话气泡（1:1 对齐 Kotlin Bubble 渲染）：
/// user = 半透明白玻璃（white 10%，圆角 18），点按浮现 复制/改写；
/// assistant = 普通文本；process = 折叠块（进行中「思考中…」，完成「已思考，调用 N 次工具」）；
/// system = 居中小字。
class BubbleView extends StatelessWidget {
  const BubbleView({
    super.key,
    required this.bubble,
    this.onEdit,
    this.running = false,
  });

  final Bubble bubble;
  final void Function(String messageId)? onEdit;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (bubble.role) {
      case 'user':
        return Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onLongPress: () => _showActions(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Text(bubble.text),
            ),
          ),
        );
      case 'process':
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ProcessBlockView(
              bubble: bubble,
              inProgress: running,
            ),
          ),
        );
      case 'system':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: Text(
              bubble.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        );
      case 'tool':
        return const SizedBox.shrink();
      default:
        if (bubble.streaming && bubble.text.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('思考中…',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(bubble.text),
          ),
        );
    }
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(McIcons.copy),
              title: const Text('复制'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                // TODO(剪贴板确认反馈)：内容已进系统剪贴板。
              },
            ),
            if (onEdit != null)
              ListTile(
                leading: const Icon(McIcons.edit),
                title: const Text('改写'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit!(bubble.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 过程折叠块（对齐 Kotlin ProcessBlock）：进行中「思考中…/正在执行 X…」，
/// 完成「已思考，调用 N 次工具」；点开看思考原文与工具调用列表。
class ProcessBlockView extends StatelessWidget {
  const ProcessBlockView({
    super.key,
    required this.bubble,
    required this.inProgress,
  });

  final Bubble bubble;
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = inProgress
        ? (bubble.toolCalls.isEmpty ? '思考中…' : '正在执行中…')
        : (bubble.processSummary ?? '过程');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        title: Row(
          children: [
            Icon(McIcons.aiSearchFill,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        children: [
          if (bubble.thinking != null)
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                bubble.thinking!,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          for (final call in bubble.toolCalls)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '🛠 ${call.name}',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
