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
import '../state/models.dart';
import '../widgets/bubble.dart';

/// AI 助手会话页（支持独立路由页与桌面/iPad 双栏内嵌模式）：
/// - 纯黑无界背景 + 顶部模型选择、思考深度切换与会话压缩/分叉菜单；
/// - 空白页内置高频影视操作推荐指令卡，一键开聊；
/// - 底部悬浮液态玻璃输入胶囊 + `/` 技能选择器 + 亮银白发送钮。
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    this.sessionId,
    this.embedded = false,
  });

  final String? sessionId;
  final bool embedded;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  static const List<(IconData, String, String)> _starterPrompts = [
    (
      McIcons.film,
      '高分科幻推荐',
      '帮我推荐今晚适合看的 4K 高分科幻电影，顺便看看我的媒体库里有没有。',
    ),
    (
      McIcons.download,
      '排查卡住的任务',
      '检查当前订阅和下载器里有没有卡住或失败的任务，并给出处理建议。',
    ),
    (
      McIcons.folderInfo,
      '巡检未识别文件',
      '盘点媒体库里尚未识别的异常视频文件，帮我分析应该如何匹配 TMDB。',
    ),
    (
      McIcons.calendarTodo,
      '新番追更订阅',
      '搜索本季评分最高的悬疑剧或新番动画，列出卡片方便我直接订阅。',
    ),
  ];

  final _input = TextEditingController();
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(chatProvider.notifier);
      if (widget.sessionId != null) {
        controller.openSession(widget.sessionId!);
      } else if (!widget.embedded) {
        controller.resetNewSession();
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

  Future<void> _submit([String? presetText]) async {
    final controller = ref.read(chatProvider.notifier);
    final text = (presetText ?? _input.text).trim();
    if (text.isEmpty) return;
    if (presetText == null) _input.clear();
    if (_editingMessageId != null) {
      final id = _editingMessageId;
      setState(() => _editingMessageId = null);
      await controller.resendEdited(id!, text);
    } else {
      await controller.send(text);
    }
  }

  void _openSkillPicker(List<AgentSkill> skills) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Text('快捷技能与常用指令', style: McText.title),
              ),
              if (skills.isNotEmpty)
                McInsetGroup(
                  header: '服务端已挂载技能',
                  margin: const EdgeInsets.only(bottom: 14),
                  children: [
                    for (final skill in skills)
                      McInsetRow(
                        icon: McIcons.puzzle,
                        iconColor: McTokens.accent,
                        title: skill.title,
                        subtitle: skill.description ?? '/${skill.name}',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          final fill = skill.prompt ?? '/${skill.name} ';
                          _input.text = fill;
                          _input.selection = TextSelection.collapsed(
                            offset: _input.text.length,
                          );
                        },
                      ),
                  ],
                ),
              McInsetGroup(
                header: '一键执行场景',
                margin: EdgeInsets.zero,
                children: [
                  for (final item in _starterPrompts)
                    McInsetRow(
                      icon: item.$1,
                      title: item.$2,
                      subtitle: item.$3,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _submit(item.$3);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

    final trailingControls = <Widget>[
      if (chat.thinkingLevels.isNotEmpty)
        PopupMenuButton<String?>(
          tooltip: '思考深度',
          onSelected: (lv) =>
              ref.read(chatProvider.notifier).setThinkingLevel(lv),
          itemBuilder: (_) => [
            const PopupMenuItem<String?>(
              value: null,
              child: Text('默认思考深度'),
            ),
            for (final lv in chat.thinkingLevels)
              PopupMenuItem<String?>(
                value: lv,
                child: Text(
                  lv + (lv == chat.thinkingLevel ? ' ✓' : ''),
                ),
              ),
          ],
          child: McLiquidGlass(
            radius: McTokens.pillRadius,
            withShadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  McIcons.lightning,
                  size: 13,
                  color: McTokens.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  chat.thinkingLevel ?? '自动思考',
                  style: McText.micro.copyWith(color: McTokens.text),
                ),
              ],
            ),
          ),
        ),
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
                  model.label + (model.ref == chat.modelRef ? ' ✓' : ''),
                ),
              ),
          ],
          child: McLiquidGlass(
            radius: McTokens.pillRadius,
            withShadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    selectedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.micro.copyWith(color: McTokens.text),
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
      if (chat.sessionId != null)
        PopupMenuButton<String>(
          tooltip: '会话操作',
          onSelected: (action) async {
            final router = GoRouter.of(context);
            final ctrl = ref.read(chatProvider.notifier);
            if (action == 'compact') {
              final ok = await ctrl.compactCurrentSession();
              if (ok) McToast.success('已压缩当前会话上下文');
            } else if (action == 'fork') {
              final newId = await ctrl.forkCurrentSession();
              if (newId != null && mounted) {
                McToast.success('已分叉并切换至新会话');
                if (!widget.embedded) {
                  router.pushReplacement('/agent/session/$newId');
                }
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
              value: 'compact',
              child: Text('压缩上下文 (Compact)'),
            ),
            PopupMenuItem<String>(
              value: 'fork',
              child: Text('分叉为新会话 (Fork)'),
            ),
          ],
          child: const McLiquidGlass(
            radius: McTokens.pillRadius,
            withShadow: false,
            padding: EdgeInsets.all(8),
            child: Icon(McIcons.more, size: 16, color: McTokens.text),
          ),
        ),
    ];

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
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                topPad + 72,
                                24,
                                24,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 680),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const McBrandMark(size: 44),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'MovieClaw AI 助手',
                                      style: McText.title,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '找片鉴片、创建季追更、排查下载卡死或巡检媒体库，一句话直达。',
                                      textAlign: TextAlign.center,
                                      style: McText.caption.muted,
                                    ),
                                    const SizedBox(height: 24),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        for (final p in _starterPrompts)
                                          McPressable(
                                            onTap: () => _submit(p.$3),
                                            scaleDown: 0.98,
                                            child: Container(
                                              width: 280,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: McTokens.surfaceInset,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: McTokens.line,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    p.$1,
                                                    size: 18,
                                                    color: McTokens.accent,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          p.$2,
                                                          style: McText.sub
                                                              .copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          p.$3,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: McText
                                                              .micro.faint,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: wide ? 780 : double.infinity,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  McTokens.pagePadding,
                                  topPad + 64,
                                  McTokens.pagePadding,
                                  16,
                                ),
                                itemCount: chat.bubbles.length,
                                itemBuilder: (itemContext, index) {
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
                                    onRetry: (messageId) => ref
                                        .read(chatProvider.notifier)
                                        .retryAssistant(messageId: messageId),
                                    onFork: (messageId) async {
                                      final router = GoRouter.of(context);
                                      final newId = await ref
                                          .read(chatProvider.notifier)
                                          .forkCurrentSession(
                                            entryId: messageId,
                                          );
                                      if (newId != null && mounted) {
                                        McToast.success('已从该节点分叉新会话');
                                        if (!widget.embedded) {
                                          router.pushReplacement(
                                            '/agent/session/$newId',
                                          );
                                        }
                                      }
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
                          McIcons.close,
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
                        maxWidth: wide ? 780 : double.infinity,
                      ),
                      child: McLiquidGlass(
                        radius: 26,
                        blurSigma: 24,
                        padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Tooltip(
                              message: '技能与快捷指令',
                              child: McPressable(
                                onTap: () => _openSkillPicker(chat.skills),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: McTokens.surfaceInset,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    McIcons.puzzle,
                                    size: 16,
                                    color: McTokens.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submit(),
                                style: McText.body,
                                decoration: InputDecoration(
                                  hintText: '向 AI 说一句话，或点左侧图标选技能…',
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: widget.embedded
                ? SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            chat.sessionId == null ? '新对话' : '实时会话',
                            style: McText.sub.copyWith(
                              color: McTokens.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          for (var i = 0; i < trailingControls.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            trailingControls[i],
                          ],
                        ],
                      ),
                    ),
                  )
                : McFloatingDetailBar(
                    onBack: _back,
                    title: 'AI 助手',
                    titleVisible: true,
                    trailing: trailingControls,
                  ),
          ),
        ],
      ),
    );
  }
}
