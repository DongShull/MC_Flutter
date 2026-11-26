import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/agent_state.dart';
import '../state/models.dart';

/// AI 会话消息气泡（Silver-Glass 结构化 Markdown + 富媒体影视卡片 + 分叉/重试动作栏）：
/// - `user`：右对齐冷银灰圆角气泡（`#C5CEDB` 实底 + `#0B0C0F` 深黑字），支持右键/长按复制或改写重发；
/// - `process`：紧凑圆角折叠推理过程卡 + `show_media_cards_v1` 交互式影视海报横滑排；
/// - `assistant`：左对齐结构化 Markdown 正文（标题/代码块一键复制/列表/引用/粗体行内代码）+ 快捷动作栏。
class BubbleView extends ConsumerWidget {
  const BubbleView({
    super.key,
    required this.bubble,
    this.onEdit,
    this.onRetry,
    this.onFork,
    this.running = false,
  });

  final Bubble bubble;
  final void Function(String messageId)? onEdit;
  final void Function(String messageId)? onRetry;
  final void Function(String messageId)? onFork;
  final bool running;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (bubble.role) {
      case 'user':
        return Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onSecondaryTapUp: (d) =>
                _showUserActions(context, globalPos: d.globalPosition),
            child: McPressable(
              onTap: null,
              onLongPress: () => _showUserActions(context),
              scaleDown: 0.98,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
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
          ),
        );
      case 'process':
        final cards = bubble.mediaCards.isNotEmpty
            ? bubble.mediaCards
            : AgentMediaCard.extractFromToolCalls(bubble.toolCalls);
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProcessBlockView(bubble: bubble, inProgress: running),
                if (cards.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  AgentMediaCardsRow(cards: cards),
                ],
              ],
            ),
          ),
        );
      case 'system':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: McTokens.line),
              ),
              child: Text(
                bubble.text,
                textAlign: TextAlign.center,
                style: McText.caption.faint,
              ),
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
        final cards = bubble.mediaCards.isNotEmpty
            ? bubble.mediaCards
            : AgentMediaCard.extractFromToolCalls(bubble.toolCalls);
        return Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onSecondaryTapUp: (d) =>
                _showAssistantActions(context, globalPos: d.globalPosition),
            onLongPress: () => _showAssistantActions(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  McAgentMarkdownView(markdown: bubble.text),
                  if (cards.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    AgentMediaCardsRow(cards: cards),
                  ],
                  if (!bubble.streaming && bubble.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniBubbleAction(
                          icon: McIcons.copy,
                          tooltip: '复制回复',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: bubble.text));
                            McToast.success('已复制到剪贴板');
                          },
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(width: 4),
                          _MiniBubbleAction(
                            icon: McIcons.refreshS,
                            tooltip: '重新生成',
                            onTap: () => onRetry!(bubble.id),
                          ),
                        ],
                        if (onFork != null) ...[
                          const SizedBox(width: 4),
                          _MiniBubbleAction(
                            icon: McIcons.merge,
                            tooltip: '从此处分叉新会话',
                            onTap: () => onFork!(bubble.id),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
    }
  }

  void _showUserActions(BuildContext context, {Offset? globalPos}) {
    showMcContextActions(
      context: context,
      title: '用户消息',
      globalPosition: globalPos,
      actions: [
        McPosterMenuAction(
          icon: McIcons.copy,
          label: '复制消息内容',
          onTap: () {
            Clipboard.setData(ClipboardData(text: bubble.text));
            McToast.success('已复制到剪贴板');
          },
        ),
        if (onEdit != null)
          McPosterMenuAction(
            icon: McIcons.edit2,
            label: '编辑并重新发送',
            onTap: () => onEdit!(bubble.id),
          ),
      ],
    );
  }

  void _showAssistantActions(BuildContext context, {Offset? globalPos}) {
    showMcContextActions(
      context: context,
      title: 'AI 回复操作',
      globalPosition: globalPos,
      actions: [
        McPosterMenuAction(
          icon: McIcons.copy,
          label: '复制全文 Markdown',
          onTap: () {
            Clipboard.setData(ClipboardData(text: bubble.text));
            McToast.success('已复制到剪贴板');
          },
        ),
        if (onRetry != null)
          McPosterMenuAction(
            icon: McIcons.refreshS,
            label: '重新生成此回复',
            onTap: () => onRetry!(bubble.id),
          ),
        if (onFork != null)
          McPosterMenuAction(
            icon: McIcons.merge,
            label: '从此处分叉为新会话',
            onTap: () => onFork!(bubble.id),
          ),
      ],
    );
  }
}

class _MiniBubbleAction extends StatelessWidget {
  const _MiniBubbleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: McPressable(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: McTokens.surfaceInset,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: McTokens.line),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 13.5, color: McTokens.textMuted),
        ),
      ),
    );
  }
}

/// 银玻璃结构化 Markdown 渲染器（零外部依赖，支持标题/代码块复制/引用/列表/行内粗体与代码）。
class McAgentMarkdownView extends StatelessWidget {
  const McAgentMarkdownView({super.key, required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(markdown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildBlock(context, blocks[i]),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, _MdBlock block) {
    switch (block.kind) {
      case _MdKind.heading:
        final size = block.level == 1
            ? 20.0
            : (block.level == 2 ? 17.5 : 16.0);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SelectableText.rich(
            TextSpan(
              children: _inlineSpans(
                block.text,
                McText.title.copyWith(
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ),
        );
      case _MdKind.code:
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: McTokens.surfaceInset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: McTokens.lineStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: McTokens.line)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      McIcons.codeBox,
                      size: 13,
                      color: McTokens.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        block.lang.isEmpty ? 'code' : block.lang,
                        style: McText.micro.muted,
                      ),
                    ),
                    McPressable(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: block.text));
                        McToast.success('代码已复制');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            McIcons.copy,
                            size: 12,
                            color: McTokens.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '复制',
                            style: McText.micro.copyWith(
                              color: McTokens.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  block.text,
                  style: McText.body.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                    color: McTokens.text,
                  ),
                ),
              ),
            ],
          ),
        );
      case _MdKind.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: McTokens.surfaceInset,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(10),
            ),
            border: Border(
              left: BorderSide(color: McTokens.accent, width: 3),
            ),
          ),
          child: SelectableText.rich(
            TextSpan(
              children: _inlineSpans(
                block.text,
                McText.body.copyWith(color: McTokens.textMuted, height: 1.5),
              ),
            ),
          ),
        );
      case _MdKind.listItem:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                block.bullet,
                style: McText.body.copyWith(
                  color: McTokens.accent,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                ),
              ),
            ),
            Expanded(
              child: SelectableText.rich(
                TextSpan(
                  children: _inlineSpans(
                    block.text,
                    McText.bodyLg.copyWith(
                      fontSize: 15.2,
                      height: 1.55,
                      color: McTokens.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case _MdKind.divider:
        return const Divider(color: McTokens.line, height: 12);
      case _MdKind.paragraph:
        return SelectableText.rich(
          TextSpan(
            children: _inlineSpans(
              block.text,
              McText.bodyLg.copyWith(
                fontSize: 15.5,
                height: 1.56,
                color: McTokens.text,
              ),
            ),
          ),
        );
    }
  }

  static List<_MdBlock> _parseBlocks(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_MdBlock>[];
    final para = <String>[];
    var inCode = false;
    var codeLang = '';
    final codeBuf = <String>[];

    void flushPara() {
      if (para.isEmpty) return;
      blocks.add(_MdBlock.paragraph(para.join('\n')));
      para.clear();
    }

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.startsWith('```')) {
        if (inCode) {
          blocks.add(_MdBlock.code(codeBuf.join('\n'), codeLang));
          codeBuf.clear();
          codeLang = '';
          inCode = false;
        } else {
          flushPara();
          inCode = true;
          codeLang = trimmed.substring(3).trim();
        }
        continue;
      }
      if (inCode) {
        codeBuf.add(line);
        continue;
      }
      final t = trimmed.trimLeft();
      if (t.isEmpty) {
        flushPara();
        continue;
      }
      if (t == '---' || t == '***') {
        flushPara();
        blocks.add(const _MdBlock(_MdKind.divider, ''));
        continue;
      }
      final headingMatch = RegExp(r'^(#{1,4})\s+(.+)$').firstMatch(t);
      if (headingMatch != null) {
        flushPara();
        blocks.add(
          _MdBlock.heading(
            headingMatch.group(2)!,
            headingMatch.group(1)!.length,
          ),
        );
        continue;
      }
      if (t.startsWith('> ') || t == '>') {
        flushPara();
        blocks.add(_MdBlock.quote(t.length > 2 ? t.substring(2) : ''));
        continue;
      }
      final ulMatch = RegExp(r'^[-*•]\s+(.+)$').firstMatch(t);
      if (ulMatch != null) {
        flushPara();
        blocks.add(_MdBlock.listItem('•', ulMatch.group(1)!));
        continue;
      }
      final olMatch = RegExp(r'^(\d+\.)\s+(.+)$').firstMatch(t);
      if (olMatch != null) {
        flushPara();
        blocks.add(_MdBlock.listItem(olMatch.group(1)!, olMatch.group(2)!));
        continue;
      }
      para.add(trimmed);
    }
    if (inCode && codeBuf.isNotEmpty) {
      blocks.add(_MdBlock.code(codeBuf.join('\n'), codeLang));
    }
    flushPara();
    if (blocks.isEmpty) {
      blocks.add(_MdBlock.paragraph(raw));
    }
    return blocks;
  }

  static List<InlineSpan> _inlineSpans(String input, TextStyle base) {
    final spans = <InlineSpan>[];
    final tokenRe = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*)');
    var cursor = 0;
    for (final m in tokenRe.allMatches(input)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, m.start), style: base));
      }
      final tok = m.group(0)!;
      if (tok.startsWith('`') && tok.endsWith('`') && tok.length >= 2) {
        spans.add(
          TextSpan(
            text: ' ${tok.substring(1, tok.length - 1)} ',
            style: McText.body.copyWith(
              fontFamily: 'monospace',
              fontSize: (base.fontSize ?? 15) * 0.88,
              color: McTokens.accentStrong,
              backgroundColor: McTokens.surfaceRaised,
            ),
          ),
        );
      } else if (tok.startsWith('**') && tok.endsWith('**') && tok.length >= 4) {
        spans.add(
          TextSpan(
            text: tok.substring(2, tok.length - 2),
            style: base.copyWith(
              fontWeight: FontWeight.w700,
              color: McTokens.accentStrong,
            ),
          ),
        );
      }
      cursor = m.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor), style: base));
    }
    return spans;
  }
}

enum _MdKind { heading, paragraph, code, quote, listItem, divider }

class _MdBlock {
  const _MdBlock(
    this.kind,
    this.text, {
    this.level = 1,
    this.lang = '',
    this.bullet = '•',
  });

  factory _MdBlock.heading(String text, int level) =>
      _MdBlock(_MdKind.heading, text, level: level);
  factory _MdBlock.paragraph(String text) => _MdBlock(_MdKind.paragraph, text);
  factory _MdBlock.code(String text, String lang) =>
      _MdBlock(_MdKind.code, text, lang: lang);
  factory _MdBlock.quote(String text) => _MdBlock(_MdKind.quote, text);
  factory _MdBlock.listItem(String bullet, String text) =>
      _MdBlock(_MdKind.listItem, text, bullet: bullet);

  final _MdKind kind;
  final String text;
  final int level;
  final String lang;
  final String bullet;
}

/// `show_media_cards_v1` 交互式银玻璃影视卡片排（点击进媒体库详情或发现详情，一键打开订阅抽屉）。
class AgentMediaCardsRow extends ConsumerWidget {
  const AgentMediaCardsRow({super.key, required this.cards});

  final List<AgentMediaCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final card = cards[index];
          final poster = McImageUrls.resolve(card.posterUrl, widthPx: 360);
          final canOpenLibrary =
              card.libraryId != null && card.mediaItemId != null;
          final canSubscribe =
              card.titleRef != null && card.titleRef!.trim().isNotEmpty;
          return McPressable(
            onTap: () {
              if (canOpenLibrary) {
                context.push('/detail/${card.libraryId}/${card.mediaItemId}');
              } else if (canSubscribe) {
                context.push(
                  '/discover/title?ref=${Uri.encodeQueryComponent(card.titleRef!)}',
                );
              } else {
                context.push(
                  '/search?q=${Uri.encodeQueryComponent(card.title)}',
                );
              }
            },
            scaleDown: 0.98,
            child: Container(
              width: 286,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: McTokens.lineStrong),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 112,
                      height: double.infinity,
                      child: poster.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: poster,
                              httpHeaders: mcImageHeaders(),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _posterFallback(),
                            )
                          : _posterFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: McText.sub.copyWith(
                            fontWeight: FontWeight.w700,
                            color: McTokens.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (card.year != null)
                              Text(
                                '${card.year}',
                                style: McText.micro.muted,
                              ),
                            if (card.rating != null && card.rating! > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    McIcons.starFill,
                                    size: 11,
                                    color: McTokens.warn,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    card.rating!.toStringAsFixed(1),
                                    style: McText.micro.copyWith(
                                      color: McTokens.warn,
                                    ),
                                  ),
                                ],
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: card.inLibrary
                                    ? McTokens.ok.withValues(alpha: 0.16)
                                    : McTokens.surfaceRaised,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                card.inLibrary ? '已入库' : '可订阅',
                                style: McText.micro.copyWith(
                                  color: card.inLibrary
                                      ? McTokens.ok
                                      : McTokens.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (card.overview != null &&
                            card.overview!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              card.overview!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: McText.caption.faint,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: McActionPill(
                                label: canOpenLibrary
                                    ? '立即观看'
                                    : (canSubscribe ? '一键订阅' : '去搜索'),
                                icon: canOpenLibrary
                                    ? McIcons.playFill
                                    : (canSubscribe
                                        ? McIcons.bookmark
                                        : McIcons.search),
                                primary: true,
                                height: 32,
                                onTap: () {
                                  if (canOpenLibrary) {
                                    context.push(
                                      '/detail/${card.libraryId}/${card.mediaItemId}',
                                    );
                                  } else if (canSubscribe) {
                                    showSubscribeSheet(
                                      context,
                                      ref,
                                      titleRef: card.titleRef!,
                                    );
                                  } else {
                                    context.push(
                                      '/search?q=${Uri.encodeQueryComponent(card.title)}',
                                    );
                                  }
                                },
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
          );
        },
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: McTokens.surfaceRaised,
      alignment: Alignment.center,
      child: const Icon(McIcons.film, size: 26, color: McTokens.textFaint),
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
      child: Material(
        color: Colors.transparent,
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
      ),
    );
  }
}
