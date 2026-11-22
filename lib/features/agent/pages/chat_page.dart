
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../state/agent_state.dart';
import '../widgets/bubble.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 对话页（1:1 对齐 Kotlin 会话页）：消息流 + 底部输入框（模型 chip + 发送）。
/// sessionId 为空 = 新对话（首次发送后由服务器分配）。
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

  Future<void> _submit() async {
    final controller = ref.read(chatProvider.notifier);
    final text = _input.text.trim();
    if (text.isEmpty && ref.read(chatProvider).attachments.isEmpty) return;
    _input.clear();
    if (_editingMessageId != null) {
      final id = _editingMessageId;
      setState(() => _editingMessageId = null);
      await controller.resendEdited(id!, text);
    } else {
      await controller.send(text);
    }
  }

  /// 选图并上传附件（对齐安卓 AgentComposerBar：图片先传后发）。
  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 2048, imageQuality: 90);
    if (x == null) return;
    await ref.read(chatProvider.notifier).uploadAttachment(x.path);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final scheme = Theme.of(context).colorScheme;
    final form = McFormWatch.of(context);
    final windowClass = mcWindowClassOf(form);
    var selectedLabel = '默认模型';
    if (chat.modelRef != null) {
      for (final m in chat.models) {
        if (m.ref == chat.modelRef) selectedLabel = m.label;
      }
      if (selectedLabel == '默认模型') selectedLabel = chat.modelRef!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          // 模型 chip（TV 聚焦环）。
          McFocusRing(
            borderRadius: 20,
            child: PopupMenuButton<String?>(
            tooltip: '选择模型',
            onSelected: (refId) =>
                ref.read(chatProvider.notifier).setModel(refId),
            itemBuilder: (context) => [
              const PopupMenuItem<String?>(
                value: null,
                child: Text('默认模型'),
              ),
              for (final model in chat.models)
                PopupMenuItem<String?>(
                  value: model.ref,
                  child: Text(model.label +
                      (model.ref == chat.modelRef ? ' ✓' : '')),
                ),
            ],
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(selectedLabel, style: const TextStyle(fontSize: 12)),
                    const Icon(McIcons.arrowDropDown, size: 16),
                  ],
                ),
              ),
            ),
          ),
          ),
          // 停止生成（运行中才有意义；TV 聚焦环）。
          if (chat.sending)
            McFocusRing(
              borderRadius: 24,
              child: IconButton(
                tooltip: '停止',
                icon: const Icon(McIcons.stopCircle),
                onPressed: () => ref.read(chatProvider.notifier).stop(),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.loading && chat.bubbles.isEmpty
                ? const McLoadingView()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
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
          if (_editingMessageId != null)
            Container(
              width: double.infinity,
              color: scheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(McIcons.edit, size: 14),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('正在改写这条消息')),
                  GestureDetector(
                    onTap: () => setState(() => _editingMessageId = null),
                    child: const Icon(McIcons.close2, size: 16),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              // 平板/TV：输入区限宽居中，避免横屏拉满。
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: windowClass == McWindowClass.compact
                        ? double.infinity
                        : 720,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chat.attachments.isNotEmpty ||
                          chat.uploadingAttachment)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              for (final a in chat.attachments)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    label: Text(
                                      a.name.length > 18
                                          ? '${a.name.substring(0, 18)}…'
                                          : a.name,
                                    ),
                                    onDeleted: () => ref
                                        .read(chatProvider.notifier)
                                        .removeAttachment(a.attachmentId),
                                  ),
                                ),
                              if (chat.uploadingAttachment)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                            ],
                          ),
                        ),
                      Row(
                children: [
                  McFocusRing(
                    borderRadius: 20,
                    child: IconButton(
                      tooltip: '添加图片',
                      icon: const Icon(McIcons.attachment2Fill),
                      onPressed: chat.uploadingAttachment
                          ? null
                          : _pickAttachment,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '问我任何问题…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  McFocusRing(
                    borderRadius: 20,
                    child: IconButton.filled(
                      onPressed: chat.sending ? null : _submit,
                      icon: const Icon(McIcons.send),
                    ),
                  ),
                ],
                ),
                    ],
                  ),
              ),
            ),
          ),
            ),
          if (chat.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                chat.error!,
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
