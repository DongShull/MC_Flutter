import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../agent/state/agent_state.dart';

/// 页底快捷输入卡（对齐鸿蒙 AgentQuickInput，管理员会话段常驻）：
/// 输入框 + 发送 → 新建会话（POST /agent/sessions）→ 进会话页；
/// 发送中 busy 禁发，失败 SnackBar，成功后清空输入框。
class QuickInputCard extends ConsumerStatefulWidget {
  const QuickInputCard({super.key});

  @override
  ConsumerState<QuickInputCard> createState() => _QuickInputCardState();
}

class _QuickInputCardState extends ConsumerState<QuickInputCard> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final accepted = await ref.read(agentApiProvider).start(content: content);
      final newId = accepted['sessionId']?.toString() ??
          accepted['session_id']?.toString();
      if (!mounted) return;
      if (newId == null || newId.isEmpty) {
        throw StateError('missing session id');
      }
      _controller.clear();
      context.push('/agent/session/$newId');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(McStrings.quickInputSendFailed),
          behavior: SnackBarBehavior.floating,
          width: 360,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_sending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: McStrings.quickInputPlaceholder,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(fontSize: 15, color: scheme.onSurface),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: '发送',
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(McIcons.send, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
