import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/agent/agent_ai_consent.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/push/push_center.dart';
import '../state/agent_state.dart';
import '../state/models.dart';
import '../widgets/agent_companion.dart';
import '../widgets/bubble.dart';

/// AI 助手会话页（1:1 对齐 iOS `AgentConversationView` + `AgentComposer` + `AgentQuickBar`）：
/// - App Store 5.1.2(i) 隐私同意门禁（取消时保留草稿）；
/// - 未配置 LLM 服务商提示横幅（跳转 `/settings/ai`）；
/// - 弯月小幕伴侣 `AgentMoonCompanion`；
/// - 图片上传（最多 4 张，相册/拍照）、`/skill:name ` 技能芯片与行内 `/` 自动补全；
/// - 自适应思考强度控件（隐藏 / 开关 / 「更快 ↔ 更聪明」滑块）与模型选择弹层；
/// - 自动吸底滚动 + 悬浮「回到底部 ↓」按钮 + 改写/重试确认框 + `PushCenter` 前台静默。
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
  static const int _maxAttachments = 4;

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
  final _focusNode = FocusNode();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  final List<String> _selectedSkills = <String>[];
  final List<AgentTurnImage> _attachedImages = <AgentTurnImage>[];
  int _uploadingCount = 0;
  String? _uploadError;

  String? _editingMessageId;
  bool _followsLatest = true;
  bool _showScrollToBottom = false;
  bool _routeReplacedForNewSession = false;
  String? _trackedVisiblePath;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(chatProvider.notifier);
      final current = ref.read(chatProvider);
      if (widget.sessionId != null) {
        _syncVisibleSessionPath(widget.sessionId);
        // 若刚刚从 /agent/new 替换路由进入同一活跃流式会话，避免重复拉转录打断流
        if (current.sessionId != widget.sessionId ||
            (!current.sending && current.bubbles.isEmpty)) {
          controller.openSession(widget.sessionId!);
        }
      } else if (!widget.embedded) {
        _syncVisibleSessionPath(null);
        controller.resetNewSession();
      }
      unawaited(controller.checkLlmProviders());
    });
  }

  @override
  void dispose() {
    if (_trackedVisiblePath != null &&
        PushCenter.instance.visibleSessionPath == _trackedVisiblePath) {
      PushCenter.instance.visibleSessionPath = null;
    }
    _input.removeListener(_onInputChanged);
    _focusNode.removeListener(_onFocusChanged);
    _input.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _syncVisibleSessionPath(String? sessionId) {
    final nextPath =
        (sessionId != null && sessionId.isNotEmpty) ? '/sessions/$sessionId' : null;
    if (_trackedVisiblePath == nextPath) return;
    _trackedVisiblePath = nextPath;
    PushCenter.instance.visibleSessionPath = nextPath;
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onInputChanged() {
    // 若用户完整键入 `/skill:<known> ` 并紧跟空格，自动收拢为可移除芯片
    final skills = ref.read(chatProvider).skills;
    if (skills.isNotEmpty) {
      final raw = _input.text;
      final known = {for (final s in skills) s.name.toLowerCase(): s.name};
      final match = RegExp(r'(?:^|\s)/skill:([A-Za-z0-9._-]+)\s$').firstMatch(raw);
      if (match != null) {
        final key = (match.group(1) ?? '').toLowerCase();
        final canonical = known[key];
        if (canonical != null) {
          final prefix = raw.substring(0, match.start);
          final cleaned = prefix.isEmpty ? '' : '$prefix ';
          _addSkillChip(canonical);
          _input.value = TextEditingValue(
            text: cleaned,
            selection: TextSelection.collapsed(offset: cleaned.length),
          );
          return;
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _addSkillChip(String name) {
    final lower = name.toLowerCase();
    if (_selectedSkills.any((s) => s.toLowerCase() == lower)) return;
    setState(() => _selectedSkills.add(name));
  }

  void _removeSkillChip(String name) {
    setState(() => _selectedSkills.remove(name));
  }

  void _applyAutocompleteSkill(
    AgentSkill skill,
    ({String query, int start, int end}) slash,
  ) {
    final raw = _input.text;
    final before = raw.substring(0, slash.start);
    final after = raw.substring(slash.end);
    final next = '$before$after'.replaceFirst(RegExp(r'^\s+'), '');
    _addSkillChip(skill.name);
    _input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focusNode.requestFocus();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  bool _handleScrollNotification(ScrollNotification n) {
    if (!_scroll.hasClients) return false;
    final pos = _scroll.position;
    final dist = pos.maxScrollExtent - pos.pixels;
    final nearBottom = dist <= 88;

    if (n is UserScrollNotification ||
        (n is ScrollUpdateNotification && n.dragDetails != null)) {
      if (!nearBottom && _followsLatest) {
        setState(() {
          _followsLatest = false;
          _showScrollToBottom = true;
        });
      } else if (nearBottom && (!_followsLatest || _showScrollToBottom)) {
        setState(() {
          _followsLatest = true;
          _showScrollToBottom = false;
        });
      }
    } else if (nearBottom && _showScrollToBottom) {
      setState(() {
        _followsLatest = true;
        _showScrollToBottom = false;
      });
    }
    return false;
  }

  Future<void> _pickImages({required bool camera}) async {
    if (_editingMessageId != null) return;
    final remaining = _maxAttachments - _attachedImages.length - _uploadingCount;
    if (remaining <= 0) {
      McToast.info('单条消息最多附加 $_maxAttachments 张图片');
      return;
    }
    setState(() => _uploadError = null);

    try {
      final picked = <XFile>[];
      if (camera) {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 85,
        );
        if (file != null) picked.add(file);
      } else {
        final files = await _picker.pickMultiImage(
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 85,
          limit: remaining > 1 ? remaining : null,
        );
        picked.addAll(files.take(remaining));
      }
      if (picked.isEmpty || !mounted) return;

      setState(() => _uploadingCount += picked.length);
      final ctrl = ref.read(chatProvider.notifier);
      for (final file in picked) {
        try {
          final ext = file.name.toLowerCase();
          final mime = ext.endsWith('.png')
              ? 'image/png'
              : ext.endsWith('.webp')
                  ? 'image/webp'
                  : 'image/jpeg';
          final uploaded = await ctrl.uploadImage(
            filePath: file.path,
            fileName: file.name.isNotEmpty ? file.name : 'image.jpg',
            contentType: mime,
          );
          if (!mounted) return;
          setState(() {
            if (_attachedImages.length < _maxAttachments) {
              _attachedImages.add(uploaded);
            }
          });
        } catch (e) {
          if (!mounted) return;
          setState(() => _uploadError = '图片上传失败：$e');
        } finally {
          if (mounted) {
            setState(() => _uploadingCount = (_uploadingCount - 1).clamp(0, 99));
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = '无法读取图片：$e');
    }
  }

  Future<bool> _confirmDestructive({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: McTokens.lineStrong),
        ),
        title: Text(title, style: McText.title),
        content: Text(message, style: McText.body.muted),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                color: McTokens.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit([String? presetText]) async {
    final chat = ref.read(chatProvider);
    if (chat.sending || chat.llmConfigured == false || _uploadingCount > 0) {
      return;
    }

    final rawText = (presetText ?? _input.text).trim();
    final isRewrite = _editingMessageId != null && presetText == null;
    final prefix = presetText == null
        ? _selectedSkills.map(AgentSkillText.token).join()
        : '';
    final composed = '$prefix$rawText'.trim();
    final imagesToSend =
        (presetText == null && !isRewrite) ? List<AgentTurnImage>.from(_attachedImages) : const <AgentTurnImage>[];

    if (composed.isEmpty && imagesToSend.isEmpty) return;

    // 1. 强制隐私同意门禁（App Store 5.1.2(i)）：取消时原样保留草稿、技能与附件！
    final agreed = await ensureAgentAiConsent(
      context,
      ref,
      providerNames: chat.providerNames,
    );
    if (!agreed || !mounted) return;

    // 2. 改写历史消息前必须确认截断后续轮次
    if (isRewrite) {
      final editId = _editingMessageId!;
      final confirmed = await _confirmDestructive(
        title: '替换并重新提问？',
        message: '改写后将丢弃这条消息之后的全部对话与回答，并从此处重新生成。',
        confirmLabel: '替换并重发',
      );
      if (!confirmed || !mounted) return;

      _input.clear();
      setState(() {
        _editingMessageId = null;
        _selectedSkills.clear();
        _followsLatest = true;
        _showScrollToBottom = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      await ref.read(chatProvider.notifier).resendEdited(editId, composed);
      return;
    }

    // 3. 常规发送（清空草稿，开启吸底跟随）
    if (presetText == null) {
      _input.clear();
      setState(() {
        _selectedSkills.clear();
        _attachedImages.clear();
        _uploadError = null;
        _followsLatest = true;
        _showScrollToBottom = false;
      });
    } else {
      setState(() {
        _followsLatest = true;
        _showScrollToBottom = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final sid = await ref.read(chatProvider.notifier).send(
          composed,
          images: imagesToSend,
        );
    if (mounted && sid != null && sid.isNotEmpty) {
      _syncVisibleSessionPath(sid);
      if (!widget.embedded &&
          widget.sessionId == null &&
          !_routeReplacedForNewSession) {
        _routeReplacedForNewSession = true;
        context.replace('/agent/session/${Uri.encodeComponent(sid)}');
      }
    }
  }

  Future<void> _handleRetry(String messageId) async {
    final chat = ref.read(chatProvider);
    if (chat.sending || chat.llmConfigured == false) return;

    final agreed = await ensureAgentAiConsent(
      context,
      ref,
      providerNames: chat.providerNames,
    );
    if (!agreed || !mounted) return;

    final idx = chat.bubbles.indexWhere((b) => b.id == messageId);
    final hasFollowingTurns = idx >= 0 &&
        chat.bubbles.sublist(idx + 1).any((b) => b.role == 'user');
    final confirmed = await _confirmDestructive(
      title: '重新生成回答？',
      message: hasFollowingTurns
          ? '该轮之后的后续对话将被清除，并基于这条提问重新生成回答。'
          : '将丢弃当前回答并重新让 AI 生成一次。',
      confirmLabel: '重新生成',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _followsLatest = true;
      _showScrollToBottom = false;
    });
    await ref.read(chatProvider.notifier).retryAssistant(messageId: messageId);
  }

  void _startEditBubble(Bubble bubble, Set<String> knownSkills) {
    final parsed = AgentSkillText.parseTokens(
      bubble.text,
      allow: knownSkills.isEmpty ? null : knownSkills,
    );
    setState(() {
      _editingMessageId = bubble.id;
      _selectedSkills
        ..clear()
        ..addAll(parsed.names);
      _attachedImages.clear();
      _uploadError = null;
    });
    _input.text = parsed.text;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focusNode.requestFocus();
  }

  void _openComposerActionsSheet(List<AgentSkill> skills) {
    final canAttach = _editingMessageId == null &&
        _attachedImages.length + _uploadingCount < _maxAttachments;
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Text('附件与快捷技能', style: McText.title),
              ),
              if (_editingMessageId == null)
                McInsetGroup(
                  header: '上传图片（最多 $_maxAttachments 张）',
                  margin: const EdgeInsets.only(bottom: 14),
                  children: [
                    McInsetRow(
                      icon: McIcons.imageUpload,
                      iconColor: canAttach ? McTokens.info : McTokens.textFaint,
                      title: '从相册选择图片',
                      subtitle: canAttach
                          ? '已选 ${_attachedImages.length}/$_maxAttachments 张'
                          : '已达到单条消息上限',
                      onTap: canAttach
                          ? () {
                              Navigator.of(ctx).pop();
                              _pickImages(camera: false);
                            }
                          : null,
                    ),
                    McInsetRow(
                      icon: McIcons.cameraLens,
                      iconColor: canAttach ? McTokens.ok : McTokens.textFaint,
                      title: '拍照并上传',
                      subtitle: '拍摄海报、字幕或报错界面发给 AI 分析',
                      onTap: canAttach
                          ? () {
                              Navigator.of(ctx).pop();
                              _pickImages(camera: true);
                            }
                          : null,
                    ),
                  ],
                ),
              if (skills.isNotEmpty)
                McInsetGroup(
                  header: '服务端已挂载技能（输入 / 可随时补全）',
                  margin: const EdgeInsets.only(bottom: 14),
                  children: [
                    for (final skill in skills)
                      McInsetRow(
                        icon: McIcons.puzzle,
                        iconColor: McTokens.accent,
                        title: skill.title,
                        subtitle:
                            skill.description ?? '/skill:${skill.name}',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _addSkillChip(skill.name);
                          if (skill.prompt != null &&
                              skill.prompt!.trim().isNotEmpty &&
                              _input.text.trim().isEmpty) {
                            _input.text = skill.prompt!.trim();
                            _input.selection = TextSelection.collapsed(
                              offset: _input.text.length,
                            );
                          }
                          _focusNode.requestFocus();
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

  void _openModelThinkingSheet() {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final chat = sheetRef.watch(chatProvider);
          final ctrl = sheetRef.read(chatProvider.notifier);
          final stops = chat.thinkingLevels;
          final shape = AgentThinking.shape(stops);

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 540),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
                      child: Text('模型与思考深度', style: McText.title),
                    ),
                    // ── 自适应思考强度控件（AgentThinkingSlider） ──
                    _AgentThinkingSection(
                      stops: stops,
                      shape: shape,
                      selected: chat.thinkingLevel,
                      onChanged: (lv) => ctrl.setThinkingLevel(lv),
                    ),
                    const SizedBox(height: 14),
                    // ── 模型列表 ──
                    McInsetGroup(
                      header: '切换模型',
                      margin: EdgeInsets.zero,
                      children: [
                        McInsetRow(
                          icon: McIcons.aiStar,
                          iconColor: chat.modelRef == null
                              ? McTokens.accentStrong
                              : McTokens.textMuted,
                          title: '默认模型',
                          subtitle: '跟随服务器全局默认配置',
                          trailing: chat.modelRef == null
                              ? const Icon(
                                  McIcons.check,
                                  size: 16,
                                  color: McTokens.accentStrong,
                                )
                              : null,
                          onTap: () => ctrl.setModel(null),
                        ),
                        for (final m in chat.models)
                          McInsetRow(
                            icon: McIcons.aiStarFill,
                            iconColor: (m.ref == chat.modelRef ||
                                    (chat.modelRef == null && m.isDefault))
                                ? McTokens.accentStrong
                                : McTokens.textMuted,
                            title: m.label + (m.isDefault ? '（默认）' : ''),
                            subtitle: m.providerName.isNotEmpty
                                ? m.providerName
                                : m.ref,
                            trailing: (m.ref == chat.modelRef ||
                                    (chat.modelRef == null && m.isDefault))
                                ? const Icon(
                                    McIcons.check,
                                    size: 16,
                                    color: McTokens.accentStrong,
                                  )
                                : null,
                            onTap: () => ctrl.setModel(m.ref),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  AgentCompanionState _companionActivity(ChatState chat) {
    if (chat.sending) return AgentCompanionState.working;
    return switch (chat.outcome) {
      ChatRunOutcome.working => AgentCompanionState.working,
      ChatRunOutcome.complete => AgentCompanionState.complete,
      ChatRunOutcome.failed => AgentCompanionState.failed,
      ChatRunOutcome.idle => AgentCompanionState.idle,
    };
  }

  @override
  Widget build(BuildContext context) {
    // 监听状态变更：新建会话自动同步 PushCenter 与路由 + 吸底自动滚动
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (next.sessionId != prev?.sessionId) {
        _syncVisibleSessionPath(next.sessionId);
        if (!widget.embedded &&
            widget.sessionId == null &&
            next.sessionId != null &&
            next.sessionId!.isNotEmpty &&
            !_routeReplacedForNewSession &&
            mounted) {
          _routeReplacedForNewSession = true;
          context.replace(
            '/agent/session/${Uri.encodeComponent(next.sessionId!)}',
          );
        }
      }
      final prevLen = prev?.bubbles.length ?? 0;
      final nextLen = next.bubbles.length;
      final prevTail = prevLen > 0 ? prev!.bubbles.last : null;
      final nextTail = nextLen > 0 ? next.bubbles.last : null;
      final contentChanged = prevLen != nextLen ||
          prevTail?.text.length != nextTail?.text.length ||
          (prevTail?.thinking?.length ?? 0) !=
              (nextTail?.thinking?.length ?? 0) ||
          (prevTail?.toolCalls.length ?? 0) !=
              (nextTail?.toolCalls.length ?? 0);
      if (contentChanged && _followsLatest) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _followsLatest) {
            _scrollToBottom(animated: !next.sending);
          }
        });
      }
    });

    final chat = ref.watch(chatProvider);
    final form = McFormWatch.of(context);
    final wide = mcWindowClassOf(form) != McWindowClass.compact;
    final topPad = MediaQuery.paddingOf(context).top;
    final llmBlocked = chat.llmConfigured == false;
    final knownSkillSet = {
      for (final s in chat.skills) s.name.toLowerCase(),
    };

    // 行内 `/` 技能自动补全候选
    final slashMatch = AgentSkillText.slashQuery(_input.text);
    final slashSuggestions = (slashMatch != null && !llmBlocked)
        ? chat.skills.where((s) {
            final q = slashMatch.query;
            if (q.isEmpty) return true;
            return s.name.toLowerCase().contains(q) ||
                s.title.toLowerCase().contains(q) ||
                (s.description?.toLowerCase().contains(q) ?? false);
          }).take(6).toList()
        : const <AgentSkill>[];

    var selectedLabel = '默认模型';
    if (chat.modelRef != null) {
      for (final m in chat.models) {
        if (m.ref == chat.modelRef) selectedLabel = m.label;
      }
      if (selectedLabel == '默认模型') selectedLabel = chat.modelRef!;
    }
    final thinkingShape = AgentThinking.shape(chat.thinkingLevels);
    final thinkingShort = chat.thinkingLevel != null
        ? AgentThinking.label(chat.thinkingLevel)
        : null;

    final canSend = !llmBlocked &&
        _uploadingCount == 0 &&
        (_input.text.trim().isNotEmpty ||
            _selectedSkills.isNotEmpty ||
            _attachedImages.isNotEmpty);

    final trailingControls = <Widget>[
      McFocusRing(
        borderRadius: 20,
        child: McPressable(
          onTap: _openModelThinkingSheet,
          child: McLiquidGlass(
            radius: McTokens.pillRadius,
            withShadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (thinkingShape != AgentThinkingShape.hidden) ...[
                  Icon(
                    McIcons.lightning,
                    size: 13,
                    color: thinkingShort != null
                        ? McTokens.accentStrong
                        : McTokens.textMuted,
                  ),
                  const SizedBox(width: 4),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: Text(
                    thinkingShort != null
                        ? '$selectedLabel · $thinkingShort'
                        : selectedLabel,
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
      PopupMenuButton<String>(
        tooltip: '会话与显示选项',
        onSelected: (action) async {
          final router = GoRouter.of(context);
          final ctrl = ref.read(chatProvider.notifier);
          if (action == 'toggle_process') {
            await ctrl.setShowProcess(!chat.showProcess);
          } else if (action == 'compact') {
            final ok = await ctrl.compactCurrentSession();
            if (ok) McToast.success('已压缩当前会话上下文');
          } else if (action == 'fork') {
            final newId = await ctrl.forkCurrentSession();
            if (newId != null && mounted) {
              McToast.success('已分叉并切换至新会话');
              if (!widget.embedded) {
                router.pushReplacement(
                  '/agent/session/${Uri.encodeComponent(newId)}',
                );
              }
            }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            value: 'toggle_process',
            child: Row(
              children: [
                Icon(
                  chat.showProcess ? McIcons.checkCircleFill : McIcons.circler,
                  size: 16,
                  color:
                      chat.showProcess ? McTokens.accentStrong : McTokens.textMuted,
                ),
                const SizedBox(width: 8),
                const Text('显示思考与工具过程'),
              ],
            ),
          ),
          if (chat.sessionId != null) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'compact',
              child: Text('压缩上下文 (Compact)'),
            ),
            const PopupMenuItem<String>(
              value: 'fork',
              child: Text('分叉为新会话 (Fork)'),
            ),
          ],
        ],
        child: const McLiquidGlass(
          radius: McTokens.pillRadius,
          withShadow: false,
          padding: EdgeInsets.all(8),
          child: Icon(McIcons.more, size: 16, color: McTokens.text),
        ),
      ),
    ];

    final attentive = _focusNode.hasFocus &&
        (_input.text.trim().isNotEmpty ||
            _selectedSkills.isNotEmpty ||
            _attachedImages.isNotEmpty);

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    if (chat.loading && chat.bubbles.isEmpty)
                      const McLoadingView()
                    else if (chat.bubbles.isEmpty)
                      Center(
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
                                      Opacity(
                                        opacity: llmBlocked ? 0.45 : 1.0,
                                        child: McPressable(
                                          onTap: llmBlocked
                                              ? null
                                              : () => _submit(p.$3),
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
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        p.$2,
                                                        style: McText.sub
                                                            .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        p.$3,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            McText.micro.faint,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
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
                    else
                      NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: wide ? 780 : double.infinity,
                            ),
                            child: ListView.builder(
                              controller: _scroll,
                              padding: EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                topPad + 64,
                                McTokens.pagePadding,
                                24,
                              ),
                              itemCount: chat.bubbles.length,
                              itemBuilder: (itemContext, index) {
                                final bubble = chat.bubbles[index];
                                return BubbleView(
                                  bubble: bubble,
                                  sessionId: chat.sessionId,
                                  knownSkills: knownSkillSet.isEmpty
                                      ? null
                                      : knownSkillSet,
                                  showProcess: chat.showProcess,
                                  running: chat.sending && bubble.streaming,
                                  onEdit: (messageId) =>
                                      _startEditBubble(bubble, knownSkillSet),
                                  onRetry: _handleRetry,
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
                                          '/agent/session/${Uri.encodeComponent(newId)}',
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
                    // ── 悬浮「回到底部 ↓」按钮 ──
                    if (_showScrollToBottom && chat.bubbles.isNotEmpty)
                      Positioned(
                        right: 18,
                        bottom: 10,
                        child: McPressable(
                          onTap: () {
                            setState(() {
                              _followsLatest = true;
                              _showScrollToBottom = false;
                            });
                            _scrollToBottom();
                          },
                          child: McLiquidGlass(
                            radius: McTokens.pillRadius,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '回到底部',
                                  style: McText.micro.copyWith(
                                    color: McTokens.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  McIcons.arrowDown,
                                  size: 13,
                                  color: McTokens.accentStrong,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── 未接入 LLM 服务商提示横幅（AgentLLMSetupNotice） ──
              if (llmBlocked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 780 : double.infinity,
                      ),
                      child: _AgentLlmSetupNotice(
                        onConfigure: () async {
                          await context.push('/settings/ai');
                          if (!mounted) return;
                          final ctrl = ref.read(chatProvider.notifier);
                          await Future.wait([
                            ctrl.checkLlmProviders(),
                            ctrl.loadModels(),
                          ]);
                        },
                      ),
                    ),
                  ),
                ),
              // ── 行内 `/` 技能自动补全浮层 ──
              if (slashMatch != null && slashSuggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 780 : double.infinity,
                      ),
                      child: _SlashSkillPopup(
                        skills: slashSuggestions,
                        onSelect: (s) => _applyAutocompleteSkill(s, slashMatch),
                      ),
                    ),
                  ),
                ),
              // ── 改写历史消息横幅 ──
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
                          '正在改写并重发这条消息（原图片附件将自动保留）',
                          style: McText.caption.copyWith(color: McTokens.text),
                        ),
                      ),
                      McPressable(
                        onTap: () => setState(() {
                          _editingMessageId = null;
                          _selectedSkills.clear();
                          _input.clear();
                        }),
                        child: const Icon(
                          McIcons.close,
                          size: 16,
                          color: McTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_uploadError != null || chat.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    _uploadError ?? chat.error!,
                    style: McText.caption.copyWith(color: McTokens.danger),
                  ),
                ),
              // ── 底部输入区 + 趴在右上角的弯月伴侣 `AgentMoonCompanion` ──
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 780 : double.infinity,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: AgentMoonCompanion(
                                activity: _companionActivity(chat),
                                attentive: attentive,
                              ),
                            ),
                          ),
                          McLiquidGlass(
                            radius: 26,
                            blurSigma: 24,
                            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 已选技能芯片 + 图片缩略图托盘
                                if (_selectedSkills.isNotEmpty ||
                                    _attachedImages.isNotEmpty ||
                                    _uploadingCount > 0)
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(6, 2, 6, 8),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        for (final skillName in _selectedSkills)
                                          _ComposerSkillChip(
                                            name: skillName,
                                            onRemove: () =>
                                                _removeSkillChip(skillName),
                                          ),
                                        for (var i = 0;
                                            i < _attachedImages.length;
                                            i++)
                                          _ComposerImageThumb(
                                            image: _attachedImages[i],
                                            onRemove: () => setState(
                                              () => _attachedImages.removeAt(i),
                                            ),
                                          ),
                                        if (_uploadingCount > 0)
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: McTokens.surfaceInset,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: McTokens.line,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: McTokens.accentStrong,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Tooltip(
                                      message: '上传图片 / 技能与快捷指令',
                                      child: McPressable(
                                        onTap: llmBlocked
                                            ? null
                                            : () => _openComposerActionsSheet(
                                                  chat.skills,
                                                ),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: const BoxDecoration(
                                            color: McTokens.surfaceInset,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            McIcons.addS,
                                            size: 18,
                                            color: llmBlocked
                                                ? McTokens.textFaint
                                                : McTokens.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _input,
                                        focusNode: _focusNode,
                                        enabled: !llmBlocked,
                                        minLines: 1,
                                        maxLines: 5,
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (_) => _submit(),
                                        style: McText.body,
                                        decoration: InputDecoration(
                                          hintText: llmBlocked
                                              ? '请先前往「设置 → AI 模型」接入服务商'
                                              : '向 AI 说一句话，输入 / 调用技能…',
                                          hintStyle: McText.body.copyWith(
                                            color: McTokens.textFaint,
                                          ),
                                          filled: false,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
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
                                            ? () => ref
                                                .read(chatProvider.notifier)
                                                .stop()
                                            : (canSend ? _submit : null),
                                        haptic: true,
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: chat.sending
                                                ? McTokens.danger
                                                : (canSend
                                                    ? McTokens.accentStrong
                                                    : McTokens.surfaceInset),
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
                                                : (canSend
                                                    ? McTokens.onAccent
                                                    : McTokens.textFaint),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
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
                          Expanded(
                            child: Text(
                              chat.sessionTitle?.isNotEmpty == true
                                  ? chat.sessionTitle!
                                  : (chat.sessionId == null ? '新对话' : '实时会话'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.sub.copyWith(
                                color: McTokens.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                    title: chat.sessionTitle?.isNotEmpty == true
                        ? chat.sessionTitle!
                        : 'AI 助手',
                    titleVisible: true,
                    trailing: trailingControls,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 未配置 LLM 服务商时的引导横幅（1:1 对齐 iOS `AgentLLMSetupNotice`）。
class _AgentLlmSetupNotice extends StatelessWidget {
  const _AgentLlmSetupNotice({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: McTokens.warn.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(McIcons.aiStar, size: 18, color: McTokens.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '尚未接入 AI 模型服务商',
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '配置 OpenAI / Anthropic / 兼容接口后即可使用智能助手',
                  style: McText.micro.muted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          McActionPill(
            label: '去配置',
            primary: true,
            height: 32,
            onTap: onConfigure,
          ),
        ],
      ),
    );
  }
}

/// 行内 `/` 技能自动补全列表。
class _SlashSkillPopup extends StatelessWidget {
  const _SlashSkillPopup({
    required this.skills,
    required this.onSelect,
  });

  final List<AgentSkill> skills;
  final void Function(AgentSkill skill) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: McTokens.surfaceSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: McTokens.lineStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < skills.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: McTokens.line),
            McPressable(
              onTap: () => onSelect(skills[i]),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      McIcons.puzzle,
                      size: 15,
                      color: McTokens.accentStrong,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚡ ${skills[i].name}',
                            style: McText.sub.copyWith(
                              color: McTokens.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (skills[i].description != null &&
                              skills[i].description!.isNotEmpty)
                            Text(
                              skills[i].description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.micro.muted,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '/skill:${skills[i].name}',
                      style: McText.micro.faint,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerSkillChip extends StatelessWidget {
  const _ComposerSkillChip({
    required this.name,
    required this.onRemove,
  });

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 6, 4),
      decoration: BoxDecoration(
        color: McTokens.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: McTokens.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '⚡ $name',
            style: McText.micro.copyWith(
              color: McTokens.accentStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              McIcons.close,
              size: 12,
              color: McTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerImageThumb extends StatelessWidget {
  const _ComposerImageThumb({
    required this.image,
    required this.onRemove,
  });

  final AgentTurnImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: image.localPath != null && File(image.localPath!).existsSync()
                ? Image.file(File(image.localPath!), fit: BoxFit.cover)
                : Container(
                    color: McTokens.surfaceInset,
                    alignment: Alignment.center,
                    child: const Icon(
                      McIcons.image3Fill,
                      size: 18,
                      color: McTokens.textMuted,
                    ),
                  ),
          ),
        ),
        Positioned(
          top: -5,
          right: -5,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: McTokens.surfaceSolid,
                shape: BoxShape.circle,
                border: Border.all(color: McTokens.lineStrong),
              ),
              alignment: Alignment.center,
              child: const Icon(McIcons.close, size: 11, color: McTokens.text),
            ),
          ),
        ),
      ],
    );
  }
}

/// 自适应思维链强度控件（1:1 对齐 iOS `AgentThinkingSlider`）：
/// - `hidden`: 不支持调整；
/// - `toggle`: 单档开关（如 `['off']` → 开启/关闭）；
/// - `slider`: 多档离散滑块 + 「更快 ↔ 更聪明」轴标 + 恢复默认。
class _AgentThinkingSection extends StatelessWidget {
  const _AgentThinkingSection({
    required this.stops,
    required this.shape,
    required this.selected,
    required this.onChanged,
  });

  final List<String> stops;
  final AgentThinkingShape shape;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (shape == AgentThinkingShape.hidden) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: McTokens.line),
        ),
        child: Row(
          children: [
            const Icon(McIcons.lightning, size: 15, color: McTokens.textFaint),
            const SizedBox(width: 8),
            Text(
              '当前模型不支持自定义思考深度',
              style: McText.caption.muted,
            ),
          ],
        ),
      );
    }

    if (shape == AgentThinkingShape.toggle) {
      final onlyStop = stops.first;
      final isOffStop = onlyStop == 'off';
      final selectedCustom = selected == onlyStop;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: McTokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  McIcons.lightning,
                  size: 15,
                  color: McTokens.accentStrong,
                ),
                const SizedBox(width: 6),
                Text(
                  '思考模式 · ${isOffStop ? (selectedCustom ? '关闭' : '开启（默认）') : AgentThinking.label(selected)}',
                  style: McText.sub.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: isOffStop ? '开启（默认）' : '模型默认',
                    primary: !selectedCustom,
                    height: 36,
                    onTap: () => onChanged(null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: McActionPill(
                    label: AgentThinking.label(onlyStop),
                    primary: selectedCustom,
                    height: 36,
                    onTap: () => onChanged(onlyStop),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 多档离散滑块（默认 + stops）
    final idx = selected == null
        ? -1
        : stops.indexOf(selected!);
    final sliderValue = (idx < 0 ? (stops.length / 2).floor() : idx).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                McIcons.lightning,
                size: 15,
                color: McTokens.accentStrong,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '思维链强度 · ${AgentThinking.label(selected)}',
                  style: McText.sub.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (selected != null)
                McPressable(
                  onTap: () => onChanged(null),
                  child: Text(
                    '恢复默认',
                    style: McText.micro.copyWith(
                      color: McTokens.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: selected == null
                  ? McTokens.textMuted
                  : McTokens.accentStrong,
              inactiveTrackColor: McTokens.line,
              thumbColor: selected == null
                  ? McTokens.textMuted
                  : McTokens.accentStrong,
              overlayColor: McTokens.accentSoft,
              trackHeight: 3.5,
            ),
            child: Slider(
              value: sliderValue.clamp(0, (stops.length - 1).toDouble()),
              min: 0,
              max: (stops.length - 1).toDouble(),
              divisions: stops.length - 1,
              label: AgentThinking.label(
                stops[sliderValue.round().clamp(0, stops.length - 1)],
              ),
              onChanged: (v) {
                final i = v.round().clamp(0, stops.length - 1);
                onChanged(stops[i]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('更快', style: McText.micro.faint),
                Text(
                  stops.map(AgentThinking.label).join(' · '),
                  style: McText.micro.faint,
                ),
                Text('更聪明', style: McText.micro.faint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
