import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/agent_state.dart';
import '../widgets/bubble.dart';

/// AI 助手会话页（1:1 对齐参考图 `scene-4.zh.jpg`）：
/// - 纯黑无界背景 + 顶部液态玻璃返回圆钮与模型选择胶囊；
/// - 右对齐冷银灰用户气泡（`#C5CEDB` 底 + 深黑字）+ 左对齐 AI 阅读流；
/// - 底部悬浮液态玻璃输入胶囊 + 亮银白圆形发送钮。
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(chatProvider.notifier);
      if (widget.sessionId != null) {
        controller.openSession(widget.sessionId!);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _submit() async {
    final controller = ref.read(chatProvider.notifier);
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    if (_editingMessageId != null) {
      final id = _editingMessageId;
      setState(() => _editingMessageId = null);
      await controller.resendEdited(id!, text);
    } else {
      await controller.send(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final form = McFormWatch.of(context);
    final wide = mcWindowClassOf(form) != McWindowClass.compact;
    final topPad = MediaQuery.paddingOf(context).top;

    var selectedLabel = '默认模型';
    if (chat.modelRef != null) {
      for (final m in chat.models) {
        if (m.ref == chat.modelRef) selectedLabel = m.label;
      }
      if (selectedLabel == '默认模型') selectedLabel = chat.modelRef!;
    }

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: chat.loading && chat.bubbles.isEmpty
                    ? const McLoadingView()
                    : chat.bubbles.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const McBrandMark(size: 42),
                              const SizedBox(height: 14),
                              const Text('MovieClaw AI 助手', style: McText.title),
                              const SizedBox(height: 6),
                              Text(
                                '你可以让我帮你找片、订阅新番、检查下载进度或整理媒体库。',
                                textAlign: TextAlign.center,
                                style: McText.caption.muted,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: wide ? 760 : double.infinity,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              McTokens.pagePadding,
                              topPad + 64,
                              McTokens.pagePadding,
                              16,
                            ),
                            itemCount: chat.bubbles.length,
                            itemBuilder: (context, index) {
                              final bubble = chat.bubbles[index];
                              return BubbleView(
                                bubble: bubble,
                                running: chat.sending && bubble.streaming,
                                onEdit: (messageId) {
                                  setState(() {
                                    _editingMessageId = messageId;
                                    _input.text = bubble.text;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
              ),
              if (_editingMessageId != null)
                Container(
                  width: double.infinity,
                  color: McTokens.surfaceSolid,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        McIcons.edit2,
                        size: 14,
                        color: McTokens.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '正在改写并重发这条消息',
                          style: McText.caption.copyWith(color: McTokens.text),
                        ),
                      ),
                      McPressable(
                        onTap: () => setState(() => _editingMessageId = null),
                        child: const Icon(
                          McIcons.close2,
                          size: 16,
                          color: McTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (chat.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    chat.error!,
                    style: McText.caption.copyWith(color: McTokens.danger),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 760 : double.infinity,
                      ),
                      child: McLiquidGlass(
                        radius: 26,
                        blurSigma: 24,
                        padding: const EdgeInsets.fromLTRB(16, 5, 6, 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submit(),
                                style: McText.body,
                                decoration: InputDecoration(
                                  hintText: '向 AI 说一句话…',
                                  hintStyle: McText.body.copyWith(
                                    color: McTokens.textFaint,
                                  ),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            McFocusRing(
                              borderRadius: 20,
                              child: McPressable(
                                onTap: chat.sending
                                    ? () => ref.read(chatProvider.notifier).stop()
                                    : _submit,
                                haptic: true,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: chat.sending
                                        ? McTokens.danger
                                        : McTokens.accentStrong,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    chat.sending
                                        ? McIcons.stopFilled
                                        : McIcons.arrowUp,
                                    size: 18,
                                    color: chat.sending
                                        ? Colors.white
                                        : McTokens.onAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 顶部吸顶雾与液态玻璃导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: McFloatingDetailBar(
              onBack: _back,
              title: 'AI 助手',
              titleVisible: true,
              trailing: [
                McFocusRing(
                  borderRadius: 20,
                  child: PopupMenuButton<String?>(
                    tooltip: '切换模型',
                    onSelected: (refId) =>
                        ref.read(chatProvider.notifier).setModel(refId),
                    itemBuilder: (_) => [
                      const PopupMenuItem<String?>(
                        value: null,
                        child: Text('默认模型'),
                      ),
                      for (final model in chat.models)
                        PopupMenuItem<String?>(
                          value: model.ref,
                          child: Text(
                            model.label +
                                (model.ref == chat.modelRef ? ' ✓' : ''),
                          ),
                        ),
                    ],
                    child: McLiquidGlass(
                      radius: McTokens.pillRadius,
                      withShadow: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 112),
                            child: Text(
                              selectedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.micro.copyWith(
                                color: McTokens.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            McIcons.arrowDownS,
                            size: 14,
                            color: McTokens.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
