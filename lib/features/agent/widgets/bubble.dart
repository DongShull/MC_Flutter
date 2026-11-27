import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../../../core/navigation/external_media_link.dart';
import '../../../core/player/player_page_args.dart';
import '../state/agent_state.dart';
import '../state/models.dart';

/// AI 会话消息气泡（Silver-Glass GFM Markdown + 实时拉取 4 类媒体卡片 + 附件图灯箱 + 技能剥离 + 工具输出展开）。
class BubbleView extends ConsumerWidget {
  const BubbleView({
    super.key,
    required this.bubble,
    this.sessionId,
    this.knownSkills,
    this.showProcess = true,
    this.onEdit,
    this.onRetry,
    this.onFork,
    this.running = false,
  });

  final Bubble bubble;
  final String? sessionId;
  final Set<String>? knownSkills;
  final bool showProcess;
  final void Function(String messageId)? onEdit;
  final void Function(String messageId)? onRetry;
  final void Function(String messageId)? onFork;
  final bool running;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (bubble.role) {
      case 'handoff':
        final h = bubble.handoff;
        if (h == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AgentHandoffCard(handoff: h),
        );

      case 'user':
        final parsed = AgentSkillText.parseTokens(
          bubble.text,
          allow: knownSkills,
        );
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
                  maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5CEDB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (parsed.names.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final skillName in parsed.names)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: McTokens.onAccent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '⚡ $skillName',
                                style: McText.micro.copyWith(
                                  color: McTokens.onAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (bubble.images.isNotEmpty || parsed.text.isNotEmpty)
                        const SizedBox(height: 8),
                    ],
                    if (bubble.images.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < bubble.images.length; i++)
                            _UserAttachmentThumb(
                              image: bubble.images[i],
                              sessionId: sessionId,
                              onTap: () => _openAttachmentLightbox(
                                context,
                                bubble.images,
                                i,
                                sessionId,
                              ),
                            ),
                        ],
                      ),
                      if (parsed.text.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (parsed.text.isNotEmpty)
                      SelectionArea(
                        child: Text(
                          parsed.text,
                          style: McText.body.copyWith(
                            color: McTokens.onAccent,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

      case 'process':
        final liveGroups = bubble.mediaCardGroups.isNotEmpty
            ? bubble.mediaCardGroups
            : AgentMediaCardGroup.extractFromToolCalls(bubble.toolCalls);
        final legacyCards = bubble.mediaCards.isNotEmpty
            ? bubble.mediaCards
            : AgentMediaCard.extractFromToolCalls(bubble.toolCalls);
        final hasVisibleProcess = showProcess &&
            ((bubble.thinking?.trim().isNotEmpty ?? false) ||
                bubble.toolCalls.any(
                  (t) => !AgentMediaCardGroup.isMediaCardsTool(t.name),
                ));
        if (!hasVisibleProcess && liveGroups.isEmpty && legacyCards.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasVisibleProcess)
                  ProcessBlockView(bubble: bubble, inProgress: running),
                for (final group in liveGroups) ...[
                  if (hasVisibleProcess || group != liveGroups.first)
                    const SizedBox(height: 10),
                  AgentMediaCardGroupView(group: group),
                ],
                if (legacyCards.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  AgentMediaCardsRow(cards: legacyCards),
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
        final liveGroups = bubble.mediaCardGroups.isNotEmpty
            ? bubble.mediaCardGroups
            : AgentMediaCardGroup.extractFromToolCalls(bubble.toolCalls);
        final legacyCards = bubble.mediaCards.isNotEmpty
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
                  if (bubble.text.trim().isNotEmpty)
                    McAgentMarkdownView(markdown: bubble.text),
                  for (final group in liveGroups) ...[
                    const SizedBox(height: 10),
                    AgentMediaCardGroupView(group: group),
                  ],
                  if (legacyCards.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    AgentMediaCardsRow(cards: legacyCards),
                  ],
                  if (bubble.stopped || bubble.interrupted) ...[
                    const SizedBox(height: 6),
                    Text(
                      bubble.stopped ? '已停止' : '已中断',
                      style: McText.caption.faint,
                    ),
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
                            onTap: () =>
                                onRetry!(bubble.userMessageId ?? bubble.id),
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
        if (onEdit != null && !bubble.id.startsWith('local-'))
          McPosterMenuAction(
            icon: McIcons.edit2,
            label: '改写并重新提问',
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
            onTap: () => onRetry!(bubble.userMessageId ?? bubble.id),
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

/// 派生会话的来源卡片（`type: 'handoff'`，对齐 iOS `AgentHandoffCard`）。
class AgentHandoffCard extends StatelessWidget {
  const AgentHandoffCard({super.key, required this.handoff});

  final AgentHandoffInfo handoff;

  @override
  Widget build(BuildContext context) {
    final title = (handoff.sourceTitle?.trim().isNotEmpty ?? false)
        ? handoff.sourceTitle!.trim()
        : '会话 ${handoff.sourceSessionId.substring(0, handoff.sourceSessionId.length.clamp(0, 8))}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(McIcons.merge, size: 17, color: McTokens.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '延续自「$title」',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '已继承原会话上下文摘要，可随时返回查看完整对话。',
                  style: McText.caption.faint,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          McPressable(
            onTap: () => context.push(
              '/agent/session/${Uri.encodeComponent(handoff.sourceSessionId)}',
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '原会话',
                  style: McText.caption.copyWith(
                    color: McTokens.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  McIcons.arrowRightS,
                  size: 14,
                  color: McTokens.info,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 用户气泡里的图片缩略图（优先本地预览，回放走 `/api/v1/sessions/{sid}/attachments/{aid}`）。
class _UserAttachmentThumb extends StatelessWidget {
  const _UserAttachmentThumb({
    required this.image,
    required this.sessionId,
    required this.onTap,
  });

  final AgentTurnImage image;
  final String? sessionId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = image.localPath ?? agentLocalImagePreviews[image.attachmentId];
    final hasLocal = local != null && File(local).existsSync();
    final remoteUrl = (sessionId != null && sessionId!.isNotEmpty)
        ? McImageUrls.resolve(
            '/api/v1/sessions/${Uri.encodeComponent(sessionId!)}/attachments/${Uri.encodeComponent(image.attachmentId)}',
          )
        : '';

    return McPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 190, maxHeight: 150),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: hasLocal
              ? Image.file(File(local), fit: BoxFit.cover)
              : remoteUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: remoteUrl,
                      httpHeaders: mcImageHeaders(),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(
                        width: 110,
                        height: 110,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox(
                        width: 110,
                        height: 110,
                        child: Icon(McIcons.image3Fill, color: Colors.black45),
                      ),
                    )
                  : const SizedBox(
                      width: 110,
                      height: 110,
                      child: Icon(McIcons.image3Fill, color: Colors.black45),
                    ),
        ),
      ),
    );
  }
}

/// 全屏可双指缩放图片灯箱（附件图与 Markdown 图片共用）。
void _openAttachmentLightbox(
  BuildContext context,
  List<AgentTurnImage> images,
  int initialIndex,
  String? sessionId,
) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.94),
    builder: (ctx) => _ImageLightboxDialog(
      items: [
        for (final img in images)
          (
            localPath:
                img.localPath ?? agentLocalImagePreviews[img.attachmentId],
            remoteUrl: (sessionId != null && sessionId.isNotEmpty)
                ? McImageUrls.resolve(
                    '/api/v1/sessions/${Uri.encodeComponent(sessionId)}/attachments/${Uri.encodeComponent(img.attachmentId)}',
                  )
                : '',
            title: img.name ?? '图片',
          ),
      ],
      initialIndex: initialIndex,
    ),
  );
}

void _openUrlLightbox(BuildContext context, String url, {String? title}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.94),
    builder: (ctx) => _ImageLightboxDialog(
      items: [(localPath: null, remoteUrl: url, title: title ?? '图片')],
      initialIndex: 0,
    ),
  );
}

class _ImageLightboxDialog extends StatefulWidget {
  const _ImageLightboxDialog({
    required this.items,
    required this.initialIndex,
  });

  final List<({String? localPath, String remoteUrl, String title})> items;
  final int initialIndex;

  @override
  State<_ImageLightboxDialog> createState() => _ImageLightboxDialogState();
}

class _ImageLightboxDialogState extends State<_ImageLightboxDialog> {
  late final PageController _page =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.items[_index];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final hasLocal =
                  item.localPath != null && File(item.localPath!).existsSync();
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: hasLocal
                      ? Image.file(File(item.localPath!), fit: BoxFit.contain)
                      : CachedNetworkImage(
                          imageUrl: item.remoteUrl,
                          httpHeaders: mcImageHeaders(),
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
                            McIcons.image3Fill,
                            size: 48,
                            color: McTokens.textFaint,
                          ),
                        ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.items.length > 1
                        ? '${current.title} (${_index + 1}/${widget.items.length})'
                        : current.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.sub.copyWith(color: Colors.white),
                  ),
                ),
                McGlassIconButton(
                  icon: McIcons.close,
                  tooltip: '关闭预览',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
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

// ── 完整 GFM Markdown 渲染器（标题 / 代码块复制 / 引用 / GFM 表格 / 图片与带链接图片 /
//    任务列表 / 嵌套列表 / 粗体 / 斜体 / 删除线 / 行内代码 / 站内外可点链接） ──

class McAgentMarkdownView extends StatelessWidget {
  const McAgentMarkdownView({super.key, required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(markdown);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildBlock(context, blocks[i]),
          ],
        ],
      ),
    );
  }

  static void _handleLinkTap(BuildContext context, String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;
    final resolved = AppWebPathResolver.resolve(trimmed);
    if (resolved != null) {
      context.push(resolved);
      return;
    }
    ExternalMediaLink.open(trimmed);
  }

  Widget _buildBlock(BuildContext context, _MdBlock block) {
    switch (block.kind) {
      case _MdKind.heading:
        final size = switch (block.level) {
          1 => 20.0,
          2 => 17.5,
          3 => 16.0,
          _ => 15.0,
        };
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _InlineMarkdownText(
            text: block.text,
            style: McText.title.copyWith(
              fontSize: size,
              fontWeight: FontWeight.w700,
              height: 1.35,
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
              SelectionContainer.disabled(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              style:
                                  McText.micro.copyWith(color: McTokens.accent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Text(
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
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: McTokens.surfaceInset,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
            border: Border(left: BorderSide(color: McTokens.accent, width: 3)),
          ),
          child: _InlineMarkdownText(
            text: block.text,
            style: McText.body.copyWith(color: McTokens.textMuted, height: 1.5),
          ),
        );

      case _MdKind.table:
        return Container(
          decoration: BoxDecoration(
            color: McTokens.surfaceInset,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: McTokens.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: const TableBorder(
                horizontalInside: BorderSide(color: McTokens.line, width: 1),
                verticalInside: BorderSide(color: McTokens.line, width: 1),
              ),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0x14FFFFFF)),
                  children: [
                    for (final cell in block.tableHeader)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: _InlineMarkdownText(
                          text: cell,
                          style: McText.caption.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final row in block.tableRows)
                  TableRow(
                    children: [
                      for (var c = 0; c < block.tableHeader.length; c++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: _InlineMarkdownText(
                            text: c < row.length ? row[c] : '',
                            style: McText.caption.copyWith(
                              color: McTokens.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );

      case _MdKind.image:
        final resolvedUrl = McImageUrls.resolve(block.imageUrl, widthPx: 720);
        final effectiveUrl =
            resolvedUrl.isNotEmpty ? resolvedUrl : block.imageUrl;
        return McPressable(
          onTap: () {
            if (block.linkUrl != null && block.linkUrl!.isNotEmpty) {
              _handleLinkTap(context, block.linkUrl!);
            } else if (effectiveUrl.isNotEmpty) {
              _openUrlLightbox(context, effectiveUrl, title: block.text);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: McTokens.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: CachedNetworkImage(
                      imageUrl: effectiveUrl,
                      httpHeaders: mcImageHeaders(),
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          block.text.isEmpty ? block.imageUrl : block.text,
                          style: McText.caption.faint,
                        ),
                      ),
                    ),
                  ),
                  if (block.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                      child: Text(
                        block.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: McText.micro.faint,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

      case _MdKind.listItem:
        final indentPad = (block.indent.clamp(0, 6)) * 16.0;
        return Padding(
          padding: EdgeInsets.only(left: indentPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.checked != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 8),
                  child: Icon(
                    block.checked!
                        ? McIcons.checkCircleFill
                        : McIcons.circler,
                    size: 16,
                    color: block.checked! ? McTokens.ok : McTokens.textMuted,
                  ),
                )
              else
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
                child: _InlineMarkdownText(
                  text: block.text,
                  style: McText.bodyLg.copyWith(
                    fontSize: 15.2,
                    height: 1.55,
                    color: block.checked == true
                        ? McTokens.textMuted
                        : McTokens.text,
                    decoration: block.checked == true
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );

      case _MdKind.divider:
        return const Divider(color: McTokens.line, height: 12);

      case _MdKind.paragraph:
        return _InlineMarkdownText(
          text: block.text,
          style: McText.bodyLg.copyWith(
            fontSize: 15.5,
            height: 1.56,
            color: McTokens.text,
          ),
        );
    }
  }

  static final RegExp _tableSepRe =
      RegExp(r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$');
  static final RegExp _linkedImgRe = RegExp(
    r'\[!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)',
  );
  static final RegExp _imgRe = RegExp(
    r'!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)',
  );

  static List<String> _splitTableCells(String row) {
    var trimmed = row.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.split('|').map((c) => c.trim()).toList();
  }

  static List<_MdBlock> _splitParagraphWithImages(String text) {
    if (!text.contains('![')) return [_MdBlock.paragraph(text)];
    final matches = <({int start, int end, _MdBlock block})>[];
    for (final m in _linkedImgRe.allMatches(text)) {
      matches.add((
        start: m.start,
        end: m.end,
        block: _MdBlock.image(
          alt: m.group(1) ?? '',
          imageUrl: m.group(2) ?? '',
          linkUrl: m.group(3),
        ),
      ));
    }
    for (final m in _imgRe.allMatches(text)) {
      final overlaps = matches.any((e) => m.start < e.end && m.end > e.start);
      if (overlaps) continue;
      matches.add((
        start: m.start,
        end: m.end,
        block: _MdBlock.image(
          alt: m.group(1) ?? '',
          imageUrl: m.group(2) ?? '',
        ),
      ));
    }
    if (matches.isEmpty) return [_MdBlock.paragraph(text)];
    matches.sort((a, b) => a.start.compareTo(b.start));
    final out = <_MdBlock>[];
    var cursor = 0;
    for (final m in matches) {
      final before = text.substring(cursor, m.start).trim();
      if (before.isNotEmpty) out.add(_MdBlock.paragraph(before));
      out.add(m.block);
      cursor = m.end;
    }
    final after = text.substring(cursor).trim();
    if (after.isNotEmpty) out.add(_MdBlock.paragraph(after));
    return out;
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
      blocks.addAll(_splitParagraphWithImages(para.join('\n')));
      para.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimRight();
      if (trimmed.trimLeft().startsWith('```')) {
        if (inCode) {
          blocks.add(_MdBlock.code(codeBuf.join('\n'), codeLang));
          codeBuf.clear();
          codeLang = '';
          inCode = false;
        } else {
          flushPara();
          inCode = true;
          codeLang = trimmed.trimLeft().substring(3).trim();
        }
        continue;
      }
      if (inCode) {
        codeBuf.add(line);
        continue;
      }
      final leadingSpaces = line.length - line.trimLeft().length;
      final t = trimmed.trimLeft();
      if (t.isEmpty) {
        flushPara();
        continue;
      }
      if (t == '---' || t == '***' || t == '___') {
        flushPara();
        blocks.add(const _MdBlock(_MdKind.divider, ''));
        continue;
      }
      final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(t);
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
      // GFM 表格检测：表头含 | 且下一行匹配分隔线
      if (t.contains('|') &&
          i + 1 < lines.length &&
          _tableSepRe.hasMatch(lines[i + 1].trim())) {
        flushPara();
        final header = _splitTableCells(t);
        i += 2;
        final rows = <List<String>>[];
        while (i < lines.length) {
          final rLine = lines[i].trim();
          if (rLine.isEmpty || !rLine.contains('|')) {
            i--;
            break;
          }
          rows.add(_splitTableCells(rLine));
          i++;
        }
        blocks.add(_MdBlock.table(header, rows));
        continue;
      }
      if (t.startsWith('> ') || t == '>') {
        flushPara();
        final qLines = <String>[t.length > 2 ? t.substring(2) : ''];
        while (i + 1 < lines.length && lines[i + 1].trimLeft().startsWith('>')) {
          i++;
          final qt = lines[i].trimLeft();
          qLines.add(qt.length > 2 ? qt.substring(2) : '');
        }
        blocks.add(_MdBlock.quote(qLines.join('\n')));
        continue;
      }
      final ulMatch = RegExp(r'^[-*+•]\s+(.+)$').firstMatch(t);
      if (ulMatch != null) {
        flushPara();
        var itemText = ulMatch.group(1)!;
        bool? checked;
        if (itemText.startsWith('[ ] ')) {
          checked = false;
          itemText = itemText.substring(4);
        } else if (itemText.startsWith('[x] ') || itemText.startsWith('[X] ')) {
          checked = true;
          itemText = itemText.substring(4);
        }
        blocks.add(
          _MdBlock.listItem(
            '•',
            itemText,
            indent: leadingSpaces ~/ 2,
            checked: checked,
          ),
        );
        continue;
      }
      final olMatch = RegExp(r'^(\d+[.)])\s+(.+)$').firstMatch(t);
      if (olMatch != null) {
        flushPara();
        blocks.add(
          _MdBlock.listItem(
            olMatch.group(1)!,
            olMatch.group(2)!,
            indent: leadingSpaces ~/ 2,
          ),
        );
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
}

/// 支持可点击行内链接、粗体、斜体、删除线与行内代码的 Stateful 文本组件（安全释放 TapGestureRecognizer）。
class _InlineMarkdownText extends StatefulWidget {
  const _InlineMarkdownText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_InlineMarkdownText> createState() => _InlineMarkdownTextState();
}

class _InlineMarkdownTextState extends State<_InlineMarkdownText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  static final RegExp _tokenRe = RegExp(
    r'(`[^`]+`|\[[^\]]+\]\([^)\s]+\)|\*\*[^*]+\*\*|~~[^~]+~~|\*[^*\n]+\*)',
  );

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _buildSpans(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final input = widget.text;
    final base = widget.style;
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final m in _tokenRe.allMatches(input)) {
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
      } else if (tok.startsWith('[') && tok.contains('](')) {
        final sep = tok.indexOf('](');
        final label = tok.substring(1, sep);
        final url = tok.substring(sep + 2, tok.length - 1);
        final rec = TapGestureRecognizer()
          ..onTap = () => McAgentMarkdownView._handleLinkTap(context, url);
        _recognizers.add(rec);
        spans.add(
          TextSpan(
            text: label,
            recognizer: rec,
            style: base.copyWith(
              color: McTokens.info,
              decoration: TextDecoration.underline,
              decorationColor: McTokens.info.withValues(alpha: 0.6),
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
      } else if (tok.startsWith('~~') && tok.endsWith('~~') && tok.length >= 4) {
        spans.add(
          TextSpan(
            text: tok.substring(2, tok.length - 2),
            style: base.copyWith(
              color: McTokens.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        );
      } else if (tok.startsWith('*') && tok.endsWith('*') && tok.length >= 2) {
        spans.add(
          TextSpan(
            text: tok.substring(1, tok.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
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

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: _buildSpans(context)));
  }
}

enum _MdKind { heading, paragraph, code, quote, listItem, divider, table, image }

class _MdBlock {
  const _MdBlock(
    this.kind,
    this.text, {
    this.level = 1,
    this.lang = '',
    this.bullet = '•',
    this.indent = 0,
    this.checked,
    this.tableHeader = const [],
    this.tableRows = const [],
    this.imageUrl = '',
    this.linkUrl,
  });

  factory _MdBlock.heading(String text, int level) =>
      _MdBlock(_MdKind.heading, text, level: level);
  factory _MdBlock.paragraph(String text) => _MdBlock(_MdKind.paragraph, text);
  factory _MdBlock.code(String text, String lang) =>
      _MdBlock(_MdKind.code, text, lang: lang);
  factory _MdBlock.quote(String text) => _MdBlock(_MdKind.quote, text);
  factory _MdBlock.listItem(
    String bullet,
    String text, {
    int indent = 0,
    bool? checked,
  }) =>
      _MdBlock(
        _MdKind.listItem,
        text,
        bullet: bullet,
        indent: indent,
        checked: checked,
      );
  factory _MdBlock.table(List<String> header, List<List<String>> rows) =>
      _MdBlock(_MdKind.table, '', tableHeader: header, tableRows: rows);
  factory _MdBlock.image({
    required String alt,
    required String imageUrl,
    String? linkUrl,
  }) =>
      _MdBlock(_MdKind.image, alt, imageUrl: imageUrl, linkUrl: linkUrl);

  final _MdKind kind;
  final String text;
  final int level;
  final String lang;
  final String bullet;
  final int indent;
  final bool? checked;
  final List<String> tableHeader;
  final List<List<String>> tableRows;
  final String imageUrl;
  final String? linkUrl;
}

// ── 实时拉取的 4 类原生媒体卡片组（show_media_cards_v1 真实协议） ──

final Map<String, Map<String, dynamic>> _liveCardCache =
    <String, Map<String, dynamic>>{};

class AgentMediaCardGroupView extends StatelessWidget {
  const AgentMediaCardGroupView({super.key, required this.group});

  final AgentMediaCardGroup group;

  @override
  Widget build(BuildContext context) {
    final isWideCard = group.component == 'library' ||
        group.component == 'library_item';
    final rowHeight = isWideCard ? 196.0 : 238.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.title != null && group.title!.isNotEmpty) ...[
          Text(
            group.title!,
            style: McText.caption.copyWith(
              color: McTokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: group.specs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _LiveMediaCardItem(spec: group.specs[i]),
          ),
        ),
      ],
    );
  }
}

class _LiveMediaCardItem extends ConsumerStatefulWidget {
  const _LiveMediaCardItem({required this.spec});

  final AgentMediaCardSpec spec;

  @override
  ConsumerState<_LiveMediaCardItem> createState() => _LiveMediaCardItemState();
}

class _LiveMediaCardItemState extends ConsumerState<_LiveMediaCardItem> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = widget.spec.idKey;
    final cached = _liveCardCache[key];
    if (cached != null) {
      setState(() {
        _data = cached;
        _loading = false;
      });
      return;
    }

    final client = ref.read(mcClientProvider);
    try {
      Map<String, dynamic> result;
      switch (widget.spec.kind) {
        case AgentMediaCardKind.library:
          final id = widget.spec.libraryId!;
          result = await client.unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/libraries/$id',
          );
          break;
        case AgentMediaCardKind.title:
          final titleRef = widget.spec.titleRef!;
          result = await client.unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/discover/titles/${Uri.encodeComponent(titleRef)}',
          );
          break;
        case AgentMediaCardKind.libraryItem:
          final id = widget.spec.mediaItemId!;
          final info = await client.unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/playback/items/$id',
          );
          final libId = (info['library_id'] as num?)?.toInt();
          Map<String, dynamic>? detail;
          Map<String, dynamic>? watch;
          if (libId != null) {
            try {
              detail = await client.unwrap<Map<String, dynamic>>(
                Channel.general,
                'GET',
                '/api/v1/libraries/$libId/items/$id',
              );
            } catch (_) {}
          }
          try {
            watch = await client.unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/playback/resume',
              query: {
                'media_item_id': id,
                if (widget.spec.seasonNumber != null)
                  'season_number': widget.spec.seasonNumber,
                if (widget.spec.episodeNumber != null)
                  'episode_number': widget.spec.episodeNumber,
              },
            );
          } catch (_) {}
          result = {'info': info, 'detail': detail, 'watch': watch};
          break;
        case AgentMediaCardKind.subscription:
          final id = widget.spec.subscriptionId!;
          result = await client.unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/subscriptions/$id',
          );
          break;
      }
      _liveCardCache[key] = result;
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = widget.spec.kind == AgentMediaCardKind.library ||
        widget.spec.kind == AgentMediaCardKind.libraryItem;
    final width = isWide ? 216.0 : 132.0;

    if (_loading || _failed || _data == null) {
      return Container(
        width: width,
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: McTokens.line),
        ),
        alignment: Alignment.center,
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('未找到内容', style: McText.caption.faint),
      );
    }

    return switch (widget.spec.kind) {
      AgentMediaCardKind.library => _buildLibraryCard(context, _data!),
      AgentMediaCardKind.title => _buildTitleCard(context, _data!),
      AgentMediaCardKind.libraryItem => _buildLibraryItemCard(context, _data!),
      AgentMediaCardKind.subscription =>
        _buildSubscriptionCard(context, _data!),
    };
  }

  Widget _buildLibraryCard(BuildContext context, Map<String, dynamic> j) {
    final id = (j['id'] as num?)?.toInt() ?? widget.spec.libraryId ?? 0;
    final name = (j['name'] ?? '媒体库 #$id').toString();
    final kind = (j['kind'] ?? 'movie').toString();
    final stats = j['stats'] is Map
        ? Map<String, dynamic>.from(j['stats'] as Map)
        : const <String, dynamic>{};
    final itemCount = (stats['item_count'] as num?)?.toInt() ?? 0;
    final totalBytes = (stats['total_size_bytes'] as num?)?.toInt() ?? 0;
    final coverUrl =
        itemCount > 0 ? McImageUrls.resolve('/api/v1/libraries/$id/cover', widthPx: 360) : '';
    final kindLabel = switch (kind) {
      'tv' => '剧集',
      'video' => '视频',
      _ => '电影',
    };

    return McPressable(
      onTap: () => context.push('/library/detail/$id'),
      child: SizedBox(
        width: 216,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 216,
                height: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (coverUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: coverUrl,
                        httpHeaders: mcImageHeaders(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _fallbackBox(),
                      )
                    else
                      _fallbackBox(),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xC0000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 8,
                      right: 10,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                kindLabel,
                '$itemCount 部',
                if (totalBytes > 0) mcFormatBytes(totalBytes),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.muted.tabular,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleCard(BuildContext context, Map<String, dynamic> j) {
    final titleObj = j['title'] is Map
        ? Map<String, dynamic>.from(j['title'] as Map)
        : j;
    final links = j['library_links'] is List ? j['library_links'] as List : const [];
    final firstLink = links.whereType<Map>().firstOrNull;
    final title = (titleObj['title'] ?? '未知影片').toString();
    final year = (titleObj['year'] as num?)?.toInt();
    final rating = (titleObj['rating'] ?? titleObj['vote_average']) as num?;
    final poster = McImageUrls.resolve(
      (titleObj['poster_url'] ?? titleObj['poster_path'])?.toString(),
      widthPx: 240,
    );
    final refStr = widget.spec.titleRef!;
    final inLib = firstLink != null;

    return McPressable(
      onTap: () {
        if (inLib) {
          context.push(
            '/detail/${firstLink['library_id']}/${firstLink['media_item_id']}',
          );
        } else {
          context.push('/discover/title?ref=${Uri.encodeQueryComponent(refStr)}');
        }
      },
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 132,
                height: 186,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (poster.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: poster,
                        httpHeaders: mcImageHeaders(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _fallbackBox(),
                      )
                    else
                      _fallbackBox(),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: inLib
                              ? McTokens.ok.withValues(alpha: 0.9)
                              : Colors.black.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          inLib ? '已在库' : '发现',
                          style: McText.micro.copyWith(
                            color: inLib ? McTokens.onAccent : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.posterTitle,
            ),
            Text(
              [
                if (year != null) '$year',
                if (rating != null && rating > 0)
                  '★ ${rating.toDouble().toStringAsFixed(1)}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.micro.muted.tabular,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryItemCard(BuildContext context, Map<String, dynamic> j) {
    final info = Map<String, dynamic>.from((j['info'] as Map?) ?? const {});
    final detail = j['detail'] is Map
        ? Map<String, dynamic>.from(j['detail'] as Map)
        : null;
    final watch = j['watch'] is Map
        ? Map<String, dynamic>.from(j['watch'] as Map)
        : null;

    final libId = (info['library_id'] as num?)?.toInt() ?? 0;
    final itemId =
        (info['media_item_id'] as num?)?.toInt() ?? widget.spec.mediaItemId ?? 0;
    final title = (info['title'] ?? '媒体条目').toString();
    final kind = (info['kind'] ?? 'movie').toString();
    final year = (info['year'] as num?)?.toInt();
    final backdrop = McImageUrls.resolve(
      (detail?['backdrop_url'] ?? detail?['poster_url'] ?? info['poster_url'])
          ?.toString(),
      widthPx: 360,
    );
    final posMs = (watch?['position_ms'] as num?)?.toInt() ?? 0;
    final durMs = (watch?['duration_ms'] as num?)?.toInt() ?? 0;
    final progress = (posMs > 0 && durMs > 0)
        ? (posMs / durMs).clamp(0.0, 1.0)
        : null;
    final played = watch?['played'] == true;
    final epCode = (kind == 'tv' &&
            widget.spec.seasonNumber != null &&
            widget.spec.episodeNumber != null)
        ? mcEpisodeLabel(widget.spec.seasonNumber, widget.spec.episodeNumber)
        : null;

    return SizedBox(
      width: 216,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 216,
              height: 122,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  McPressable(
                    onTap: () => context.push('/detail/$libId/$itemId'),
                    child: backdrop.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: backdrop,
                            httpHeaders: mcImageHeaders(),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallbackBox(),
                          )
                        : _fallbackBox(),
                  ),
                  Center(
                    child: McPressable(
                      onTap: () => context.push(
                        '/player',
                        extra: PlayerPageArgs(
                          mediaItemId: itemId,
                          seasonNumber: widget.spec.seasonNumber,
                          episodeNumber: widget.spec.episodeNumber,
                          isEpisode: widget.spec.seasonNumber != null &&
                              widget.spec.episodeNumber != null,
                          title: title,
                          artworkUrl: backdrop.isNotEmpty ? backdrop : null,
                        ),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          McIcons.playFill,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (played)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: McTokens.ok,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '已看',
                          style: McText.micro.copyWith(color: McTokens.onAccent),
                        ),
                      ),
                    ),
                  if (progress != null)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          color: McTokens.accentStrong,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          McPressable(
            onTap: () => context.push('/detail/$libId/$itemId'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.posterTitle,
                ),
                Text(
                  [
                    if (year != null) '$year',
                    kind == 'tv' ? '剧集' : '电影',
                    if (epCode != null) epCode,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.micro.muted.tabular,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, Map<String, dynamic> j) {
    final id = (j['id'] as num?)?.toInt() ?? widget.spec.subscriptionId ?? 0;
    final media = j['media'] is Map
        ? Map<String, dynamic>.from(j['media'] as Map)
        : const <String, dynamic>{};
    final title = (media['title'] ?? j['title'] ?? '订阅 #$id').toString();
    final poster = McImageUrls.resolve(
      (media['poster_url'] ?? j['poster_url'])?.toString(),
      widthPx: 240,
    );
    final seasons = j['seasons'] is List ? j['seasons'] as List : const [];
    var totalEps = 0;
    var ownedEps = 0;
    for (final s in seasons.whereType<Map>()) {
      totalEps += (s['total_episodes'] ?? s['episode_count'] ?? 0) as int;
      ownedEps += (s['owned_episodes'] ?? s['owned_count'] ?? 0) as int;
    }
    final progress = totalEps > 0 ? (ownedEps / totalEps).clamp(0.0, 1.0) : null;
    final status = (j['status'] ?? '').toString();

    return McPressable(
      onTap: () => context.push('/subscriptions/detail/$id'),
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 132,
                height: 186,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (poster.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: poster,
                        httpHeaders: mcImageHeaders(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _fallbackBox(),
                      )
                    else
                      _fallbackBox(),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'completed'
                              ? McTokens.ok.withValues(alpha: 0.9)
                              : McTokens.info.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status == 'completed' ? '已收齐' : '追更中',
                          style: McText.micro.copyWith(color: McTokens.onAccent),
                        ),
                      ),
                    ),
                    if (progress != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(7, 12, 7, 6),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xCC000000)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$ownedEps / $totalEps 集',
                                style: McText.micro
                                    .copyWith(color: Colors.white)
                                    .tabular,
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  color: McTokens.ok,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.posterTitle,
            ),
            Text(
              totalEps > 0 ? '已收录 $ownedEps/$totalEps 集' : '订阅详情',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.micro.muted.tabular,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackBox() => Container(
        color: McTokens.posterPlaceholder,
        alignment: Alignment.center,
        child: const Icon(McIcons.film, size: 26, color: McTokens.textFaint),
      );
}

/// 兼容预填充地图格式的 `show_media_cards_v1` 卡片排（保留 `omnipotent_features_test.dart` 100% 兼容）。
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
                              Text('${card.year}', style: McText.micro.muted),
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
                                    style: McText.micro
                                        .copyWith(color: McTokens.warn),
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

  Widget _posterFallback() => Container(
        color: McTokens.posterPlaceholder,
        alignment: Alignment.center,
        child: const Icon(McIcons.film, size: 28, color: McTokens.textFaint),
      );
}

/// 折叠推理过程块（对齐 iOS `AgentProcessBlock` + `AgentToolRow`：
/// 支持流式工具参数、✓/✗/运行中状态、格式化 JSON/Bash 参数与可滚动工具 output！）。
class ProcessBlockView extends StatefulWidget {
  const ProcessBlockView({
    super.key,
    required this.bubble,
    this.inProgress = false,
  });

  final Bubble bubble;
  final bool inProgress;

  @override
  State<ProcessBlockView> createState() => _ProcessBlockViewState();
}

class _ProcessBlockViewState extends State<ProcessBlockView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final visibleTools = widget.bubble.toolCalls
        .where((t) => !AgentMediaCardGroup.isMediaCardsTool(t.name))
        .toList();
    final hasThinking = widget.bubble.thinking?.trim().isNotEmpty ?? false;
    final label = widget.bubble.processSummary?.isNotEmpty == true
        ? widget.bubble.processSummary!
        : (widget.inProgress ? '处理中…' : '处理过程');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        McPressable(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: McTokens.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.inProgress)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: McTokens.accent,
                    ),
                  )
                else
                  const Icon(
                    McIcons.aiStarFill,
                    size: 12,
                    color: McTokens.accent,
                  ),
                const SizedBox(width: 6),
                Text(label, style: McText.caption.muted),
                const SizedBox(width: 4),
                Icon(
                  _open ? McIcons.arrowDownS : McIcons.arrowRightS,
                  size: 13,
                  color: McTokens.textFaint,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasThinking) ...[
                  SelectableText(
                    widget.bubble.thinking!.trim(),
                    style: McText.caption.faint.copyWith(height: 1.45),
                  ),
                  if (visibleTools.isNotEmpty) const SizedBox(height: 10),
                ],
                for (var i = 0; i < visibleTools.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _AgentToolRow(tool: visibleTools[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AgentToolRow extends StatefulWidget {
  const _AgentToolRow({required this.tool});

  final ToolCall tool;

  @override
  State<_AgentToolRow> createState() => _AgentToolRowState();
}

class _AgentToolRowState extends State<_AgentToolRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final detail = tool.inputDetail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        McPressable(
          onTap: tool.streaming ? null : () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  _open ? McIcons.arrowDownS : McIcons.arrowRightS,
                  size: 12,
                  color: McTokens.textFaint,
                ),
                const SizedBox(width: 5),
                Text(
                  tool.name,
                  style: McText.caption.copyWith(
                    fontFamily: 'monospace',
                    color: const Color(0xFF9FC6E8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tool.streaming
                        ? (tool.arguments ?? '')
                        : tool.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.micro.faint.copyWith(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 6),
                if (tool.streaming || tool.output == null)
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: McTokens.textMuted,
                    ),
                  )
                else
                  Text(
                    tool.failed ? '✗' : '✓',
                    style: McText.caption.copyWith(
                      color: tool.failed ? McTokens.danger : McTokens.ok,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_open && !tool.streaming) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x28000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail != null) ...[
                  Text(
                    detail.lang == 'bash' ? '命令' : '参数 (${detail.lang})',
                    style: McText.micro.faint,
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      detail.code,
                      style: McText.micro.copyWith(
                        fontFamily: 'monospace',
                        color: McTokens.text,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
                if (tool.output != null) ...[
                  if (detail != null)
                    const Divider(height: 14, color: McTokens.line),
                  Text('输出', style: McText.micro.faint),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 176),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        tool.output!,
                        style: McText.micro.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w400,
                          color: tool.failed
                              ? McTokens.danger
                              : McTokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text('执行中…', style: McText.micro.faint),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
