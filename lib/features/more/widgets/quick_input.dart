import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../../agent/state/agent_state.dart';

/// AI 快捷发起胶囊（`McAgentQuickBar`：一句话直接新建 AI 任务并跳入对话页）。
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
      final newId =
          accepted['sessionId']?.toString() ??
          accepted['session_id']?.toString();
      if (!mounted) return;
      if (newId == null || newId.isEmpty) {
        throw StateError('missing session id');
      }
      _controller.clear();
      context.push('/agent/session/$newId');
    } catch (_) {
      if (!mounted) return;
      McToast.error(McStrings.quickInputSendFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        6,
        McTokens.pagePadding,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 5, 6, 5),
        decoration: BoxDecoration(
          color: McTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(McTokens.pillRadius),
          border: Border.all(color: McTokens.lineStrong, width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              McIcons.aiStarFill,
              size: 18,
              color: McTokens.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_sending,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: McText.body,
                decoration: InputDecoration(
                  hintText: McStrings.quickInputPlaceholder,
                  hintStyle: McText.body.copyWith(color: McTokens.textFaint),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            McPressable(
              onTap: _sending ? null : _send,
              haptic: true,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: McTokens.accentStrong,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: _sending
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: McTokens.onAccent,
                        ),
                      )
                    : const Icon(
                        McIcons.arrowUp,
                        size: 18,
                        color: McTokens.onAccent,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
