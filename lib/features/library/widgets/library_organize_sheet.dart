import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/models.dart';

/// 弹出 4 段式整理文件名确认单（对齐 iOS `LibraryOrganizeSheet`）。
Future<void> showLibraryOrganizeSheet(
  BuildContext context, {
  required int libraryId,
  VoidCallback? onStarted,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => LibraryOrganizeSheet(
      libraryId: libraryId,
      onStarted: onStarted,
    ),
  );
}

enum _OrganizePhase { loading, preview, running, done, failed }

class _RenameGroup {
  _RenameGroup({
    required this.id,
    required this.title,
    this.year,
    required this.actions,
  });

  final int id;
  final String title;
  final int? year;
  final List<OrganizeRenameView> actions;
}

/// 整理文件名 4 段式弹层：加载预览 → 风险核对与清单 → 轮询执行进度 → 整理结论与错误明细。
class LibraryOrganizeSheet extends ConsumerStatefulWidget {
  const LibraryOrganizeSheet({
    super.key,
    required this.libraryId,
    this.onStarted,
  });

  final int libraryId;
  final VoidCallback? onStarted;

  @override
  ConsumerState<LibraryOrganizeSheet> createState() =>
      _LibraryOrganizeSheetState();
}

class _LibraryOrganizeSheetState extends ConsumerState<LibraryOrganizeSheet> {
  _OrganizePhase _phase = _OrganizePhase.loading;
  LibraryView? _library;
  OrganizePreviewView? _preview;
  LastOrganizeView? _result;
  ScanProgress? _progress;
  String? _error;
  bool _agreed = false;
  bool _showSkips = false;
  bool _sawRunning = false;
  String? _baselineFinished;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    final api = ref.read(libraryApiProvider);
    try {
      final lib = await api.libraryGet(widget.libraryId);
      if (!mounted) return;
      _library = lib;
      _baselineFinished = lib.lastOrganize?.finishedAt;
      if (lib.organizing) {
        setState(() {
          _phase = _OrganizePhase.running;
          _progress = lib.organizeProgress;
          _sawRunning = true;
        });
        _startPolling();
        return;
      }
      final prev = await api.organizePreview(widget.libraryId);
      if (!mounted) return;
      setState(() {
        _preview = prev;
        _phase = _OrganizePhase.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _phase = _OrganizePhase.failed;
      });
    }
  }

  Future<void> _startOrganize() async {
    setState(() {
      _error = null;
      _sawRunning = false;
      _baselineFinished = _library?.lastOrganize?.finishedAt;
      _phase = _OrganizePhase.running;
    });
    try {
      await ref.read(libraryApiProvider).organizeLibrary(widget.libraryId);
      widget.onStarted?.call();
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _phase = _OrganizePhase.preview;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollRunning();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _pollRunning(),
    );
  }

  Future<void> _pollRunning() async {
    if (!mounted || _phase != _OrganizePhase.running) return;
    try {
      final lib = await ref.read(libraryApiProvider).libraryGet(widget.libraryId);
      if (!mounted || _phase != _OrganizePhase.running) return;
      _library = lib;
      if (lib.organizing) {
        setState(() {
          _sawRunning = true;
          _progress = lib.organizeProgress;
        });
        return;
      }
      final finished = lib.lastOrganize?.finishedAt;
      if (_sawRunning || finished != _baselineFinished) {
        _pollTimer?.cancel();
        setState(() {
          _progress = lib.organizeProgress;
          _result = lib.lastOrganize;
          _phase = _OrganizePhase.done;
        });
      }
    } catch (_) {}
  }

  List<_RenameGroup> _groupRenames(OrganizePreviewView p) {
    final map = <int, _RenameGroup>{};
    for (final a in p.renames) {
      map
          .putIfAbsent(
            a.mediaItemId,
            () => _RenameGroup(
              id: a.mediaItemId,
              title: a.title,
              year: a.year,
              actions: [],
            ),
          )
          .actions
          .add(a);
    }
    return map.values.toList()..sort((a, b) => a.title.compareTo(b.title));
  }

  Widget _statChip(String text, Color tone) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tone,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.84,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('整理文件名', style: McText.titleSm),
                      if (_library != null)
                        Text(_library!.name, style: McText.caption.muted),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: switch (_phase) {
              _OrganizePhase.loading => const McLoadingView(
                  label: '正在扫描并生成改名预览（只读不改动磁盘）…',
                ),
              _OrganizePhase.failed => McErrorView(
                  text: _error ?? '生成整理预览失败',
                  onRetry: () {
                    setState(() => _phase = _OrganizePhase.loading);
                    _open();
                  },
                ),
              _OrganizePhase.preview => _buildPreview(_preview!),
              _OrganizePhase.running => _buildRunning(),
              _OrganizePhase.done => _buildDone(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(OrganizePreviewView preview) {
    final renameCount = preview.renames.length;
    final sidecarCount = preview.renames.fold<int>(
      0,
      (s, r) => s + r.sidecars.length,
    );
    final entryAssetCount = preview.entryAssets.length;
    final groups = _groupRenames(preview);
    final seasonPart = _library?.kind == 'tv' ? '/Season NN' : '';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Text(
                '按当前命名模板归位到「片名 (年份)$seasonPart」目录结构。以下预览仅读取不改动磁盘。',
                style: McText.sub.muted,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _statChip(
                    '将改名 $renameCount 个文件',
                    renameCount > 0 ? McTokens.text : McTokens.textMuted,
                  ),
                  if (sidecarCount > 0)
                    _statChip('附属字幕/NFO $sidecarCount 个', McTokens.textMuted),
                  if (entryAssetCount > 0)
                    _statChip('条目目录素材 $entryAssetCount 个', McTokens.textMuted),
                  _statChip('已规范 ${preview.alreadyOk} 个', McTokens.ok),
                  if (preview.skips.isNotEmpty)
                    _statChip('跳过 ${preview.skips.length} 个', McTokens.warning),
                ],
              ),
              const SizedBox(height: 14),
              if (renameCount == 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: McTokens.surfaceInset,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        McIcons.checkCircleFill,
                        size: 28,
                        color: McTokens.ok,
                      ),
                      const SizedBox(height: 8),
                      const Text('所有可整理文件均已符合规范', style: McText.body),
                      if (preview.skips.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '另有 ${preview.skips.length} 个文件被跳过，可在下方展开查看原因。',
                          style: McText.caption.faint,
                        ),
                      ],
                    ],
                  ),
                )
              else ...[
                // 3 条风险告知
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: McTokens.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: McTokens.warning.withValues(alpha: 0.32),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '开始前请确认以下风险',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: McTokens.warning,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• 批量重命名直接修改磁盘路径，无法一键撤销；',
                        style: TextStyle(fontSize: 12, color: McTokens.warning),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '• 正在 PT/BT 做种的硬链接原文件若与媒体库同路径，改名会导致做种报错；',
                        style: TextStyle(fontSize: 12, color: McTokens.warning),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '• 第三方播放器（如 Infuse / Plex）下次同步会按新路径重新识别。',
                        style: TextStyle(fontSize: 12, color: McTokens.warning),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                    child: Text(
                      '${g.title}${g.year != null ? ' (${g.year})' : ''} · ${g.actions.length} 个文件',
                      style: McText.sub.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  McInsetGroup(
                    margin: const EdgeInsets.only(bottom: 10),
                    children: [
                      for (final a in g.actions)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.sourceRel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: McTokens.textFaint,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    McIcons.chevronRight,
                                    size: 12,
                                    color: McTokens.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      a.targetRel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: McTokens.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    mcFormatBytes(a.sizeBytes),
                                    style: McText.caption.faint,
                                  ),
                                ],
                              ),
                              if (a.sidecars.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    top: 2,
                                  ),
                                  child: Text(
                                    '同步移动 ${a.sidecars.length} 个字幕/附属文件',
                                    style: McText.caption.faint,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
              if (preview.skips.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _showSkips = !_showSkips),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _showSkips
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: McTokens.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '查看被跳过的 ${preview.skips.length} 个文件',
                          style: McText.sub.muted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showSkips)
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      for (final s in preview.skips)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.filePath,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: McTokens.textFaint,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.reason,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: McTokens.warning,
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
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: McTokens.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: McTokens.danger,
                    ),
                  ),
                ),
              if (renameCount > 0) ...[
                CheckboxListTile(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v == true),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: const Text(
                    '我已核对清单并了解上述风险',
                    style: TextStyle(fontSize: 13, color: McTokens.textMuted),
                  ),
                ),
                const SizedBox(height: 6),
                McActionPill(
                  label: '开始整理（$renameCount 个文件）',
                  primary: true,
                  expanded: true,
                  onTap: _agreed ? _startOrganize : null,
                ),
              ] else
                McActionPill(
                  label: '关闭',
                  expanded: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRunning() {
    final p = _progress;
    final fraction = (p != null && p.total > 0)
        ? (p.processed / p.total).clamp(0.0, 1.0)
        : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: McTokens.surfaceInset,
                color: McTokens.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              p != null && p.total > 0
                  ? '正在整理文件名 · ${p.processed} / ${p.total}'
                  : '正在后台整理文件名…',
              style: McText.body,
            ),
            const SizedBox(height: 6),
            Text(
              '任务在服务端后台执行，关闭此面板不会中断整理。',
              textAlign: TextAlign.center,
              style: McText.caption.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone() {
    final r = _result;
    final parts = [
      '已重命名 ${r?.renamed ?? 0} 个媒体文件',
      if ((r?.sidecarsRenamed ?? 0) > 0) '移动 ${r!.sidecarsRenamed} 个附属文件',
      if ((r?.entryAssetsMoved ?? 0) > 0) '迁移 ${r!.entryAssetsMoved} 个条目素材',
      if ((r?.removedDirs ?? 0) > 0) '清理 ${r!.removedDirs} 个空目录',
      if ((r?.skipped ?? 0) > 0) '跳过 ${r!.skipped} 个',
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        const Center(
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Color(0x264ADE80),
            child: Icon(Icons.check_rounded, color: McTokens.ok, size: 28),
          ),
        ),
        const SizedBox(height: 14),
        const Center(child: Text('文件整理已完成', style: McText.titleSm)),
        const SizedBox(height: 8),
        Text(
          parts.join('，'),
          textAlign: TextAlign.center,
          style: McText.sub.muted,
        ),
        if (r != null && r.errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: McTokens.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: McTokens.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 ${r.errors.length} 条错误',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: McTokens.warning,
                  ),
                ),
                const SizedBox(height: 6),
                for (final err in r.errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText(
                      err,
                      style: const TextStyle(
                        fontSize: 11,
                        color: McTokens.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        McActionPill(
          label: '完成',
          primary: true,
          expanded: true,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
