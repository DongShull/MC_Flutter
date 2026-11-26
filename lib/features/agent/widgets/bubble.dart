import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/agent_state.dart';

/// AI 会话消息气泡（1:1 对齐参考图 `scene-4.zh.jpg`）：
/// - `user`：右对齐冷银灰圆角气泡（`#C5CEDB` 实底 + `#0B0C0F` 深黑字），长按弹出复制/改写；
/// - `process`：紧凑圆角折叠过程卡（思考链 + 工具调用徽标）；
/// - `assistant`：左对齐舒展阅读正文（`15.5sp` 行高 `1.55`）。
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
    switch (bubble.role) {
      case 'user':
        return Align(
          alignment: Alignment.centerRight,
          child: McPressable(
            onTap: null,
            onLongPress: () => _showActions(context),
            scaleDown: 0.98,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFC5CEDB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                bubble.text,
                style: McText.body.copyWith(
                  color: McTokens.onAccent,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ),
          ),
        );
      case 'process':
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: ProcessBlockView(bubble: bubble, inProgress: running),
          ),
        );
      case 'system':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              bubble.text,
              textAlign: TextAlign.center,
              style: McText.caption.faint,
            ),
          ),
        );
      case 'tool':
        return const SizedBox.shrink();
      default:
        if (bubble.streaming && bubble.text.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: McTokens.accentStrong,
                  ),
                ),
                const SizedBox(width: 8),
                Text('思考中…', style: McText.caption.muted),
              ],
            ),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SelectableText(
              bubble.text,
              style: McText.bodyLg.copyWith(
                fontSize: 15.5,
                height: 1.55,
                color: McTokens.text,
              ),
            ),
          ),
        );
    }
  }

  void _showActions(BuildContext context) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              icon: McIcons.copy,
              title: '复制消息内容',
              onTap: () {
                Clipboard.setData(ClipboardData(text: bubble.text));
                Navigator.of(ctx).pop();
                McToast.success('已复制到剪贴板');
              },
            ),
            if (onEdit != null)
              McInsetRow(
                icon: McIcons.edit2,
                title: '编辑并重新发送',
                onTap: () {
                  Navigator.of(ctx).pop();
                  onEdit!(bubble.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

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
    final label = inProgress
        ? (bubble.toolCalls.isEmpty ? '正在思考…' : '正在调用工具…')
        : (bubble.processSummary ?? '已完成推理过程');
    return Container(
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          iconColor: McTokens.textFaint,
          collapsedIconColor: McTokens.textFaint,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                McIcons.aiStarFill,
                size: 14,
                color: inProgress ? McTokens.info : McTokens.textMuted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted,
                ),
              ),
            ],
          ),
          children: [
            if (bubble.thinking != null && bubble.thinking!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  bubble.thinking!,
                  style: McText.caption.faint,
                ),
              ),
            if (bubble.toolCalls.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final call in bubble.toolCalls)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: McTokens.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: McTokens.line, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            McIcons.terminal,
                            size: 12,
                            color: McTokens.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            call.name,
                            style: McText.micro.copyWith(
                              color: McTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
