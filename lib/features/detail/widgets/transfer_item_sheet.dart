import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/detail_controller.dart';

/// 跨媒体库转移弹层（1:1 对齐 iOS `TransferItemSheet.swift`）：
/// 选同类型同来源目标库 → 立即只读预检 `transfer-preview`（阻断/跨盘警示/搬运路径清单/跳过）
/// → 发起 `POST .../transfers` → 1s 轮询 `item-transfer-status` → 结论页一键「去目标库查看」。
Future<void> showTransferItemSheet({
  required BuildContext context,
  required DetailController controller,
  required String title,
  VoidCallback? onDone,
}) {
  return showMcSheet<void>(
    context: context,
    maxWidth: 600,
    builder: (_) => _TransferItemSheet(
      controller: controller,
      title: title,
      onDone: onDone,
    ),
  );
}

class _TransferItemSheet extends StatefulWidget {
  const _TransferItemSheet({
    required this.controller,
    required this.title,
    this.onDone,
  });

  final DetailController controller;
  final String title;
  final VoidCallback? onDone;

  @override
  State<_TransferItemSheet> createState() => _TransferItemSheetState();
}

class _TransferItemSheetState extends State<_TransferItemSheet> {
  List<DetailLibraryMeta>? _candidates;
  int? _targetId;
  Map<String, dynamic>? _preview;
  bool _loadingPreview = false;
  String? _error;
  Map<String, dynamic>? _status;
  bool _starting = false;
  bool _notifiedDone = false;
  Timer? _pollTimer;

  bool get _running => _status?['running'] == true;
  bool get _busy => _starting || _running;
  bool get _finished => _status != null && _status!['running'] != true;

  bool get _canRun {
    final p = _preview;
    if (p == null || _busy) return false;
    final blocked = J.list(p, ['blocked']);
    final moves = J.listOfMap(p, ['moves']);
    return blocked.isEmpty && moves.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCandidates);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    try {
      final list = await widget.controller.listTransferCandidateLibraries();
      if (!mounted) return;
      setState(() => _candidates = list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _candidates = const [];
        _error = '读取候选媒体库失败：$e';
      });
    }
  }

  Future<void> _selectTarget(int libId) async {
    if (_busy) return;
    setState(() {
      _targetId = libId;
      _loadingPreview = true;
      _preview = null;
      _error = null;
    });
    try {
      final p = await widget.controller.transferPreview(libId);
      if (!mounted || _targetId != libId) return;
      setState(() {
        _preview = p;
        _loadingPreview = false;
      });
    } on ApiException catch (e) {
      if (!mounted || _targetId != libId) return;
      setState(() {
        _error = e.friendlyMessage;
        _loadingPreview = false;
      });
    } catch (e) {
      if (!mounted || _targetId != libId) return;
      setState(() {
        _error = '转移预检失败：$e';
        _loadingPreview = false;
      });
    }
  }

  Future<void> _run() async {
    final targetId = _targetId;
    if (targetId == null || !_canRun) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await widget.controller.startTransfer(targetId);
      final st = await widget.controller.transferStatus();
      if (!mounted) return;
      _applyStatus(st);
      setState(() => _starting = false);
      if (_running) {
        _startPolling();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.friendlyMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = '发起转移失败：$e';
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final next = await widget.controller.transferStatus();
        if (!mounted) return;
        _applyStatus(next);
        if (next['running'] != true) {
          _pollTimer?.cancel();
        }
      } catch (_) {}
    });
  }

  void _applyStatus(Map<String, dynamic> next) {
    setState(() => _status = next);
    final running = next['running'] == true;
    final errors = J.list(next, ['errors']);
    final targetLib = J.i(next, ['target_library_id']);
    if (!running && errors.isEmpty && targetLib != null && !_notifiedDone) {
      _notifiedDone = true;
      widget.onDone?.call();
    }
  }

  void _goToTarget(int targetLibraryId) {
    final itemId = widget.controller.itemId;
    Navigator.of(context).pop();
    context.pushReplacement('/detail/$targetLibraryId/$itemId');
  }

  @override
  Widget build(BuildContext context) {
    final srcLib = widget.controller.current.libraryMeta;
    final fileEntries = srcLib != null && !srcLib.scraped;
    final kindLabel =
        switch (srcLib?.kind ?? widget.controller.current.entry?.kind) {
      'movie' => '电影',
      'tv' => '剧集',
      'video' => '其他视频',
      'photo' => '图片',
      _ => '同类型',
    };

    return PopScope(
      canPop: !_busy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    McIcons.folder,
                    size: 18,
                    color: McTokens.accentStrong,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '转移「${widget.title}」',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.titleSm,
                    ),
                  ),
                  if (!_busy)
                    McGlassIconButton(
                      icon: McIcons.close,
                      iconSize: 16,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: _finished && _status != null
                      ? _buildResult(_status!)
                      : _buildPlanStep(
                          fileEntries: fileEntries,
                          kindLabel: kindLabel,
                          sourceName: srcLib?.name,
                        ),
                ),
              ),
              const SizedBox(height: 14),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanStep({
    required bool fileEntries,
    required String kindLabel,
    String? sourceName,
  }) {
    final candidates = _candidates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fileEntries
              ? '将把磁盘上的实际媒体文件连同台账记录一起移动到目标媒体库主根目录下。'
              : '将把磁盘上的整个条目目录连同台账记录、海报与字幕一起移动到目标媒体库主根目录下。',
          style: McText.caption.muted,
        ),
        const SizedBox(height: 16),
        Text(
          '选择目标媒体库',
          style: McText.micro.copyWith(
            color: McTokens.textFaint,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (candidates == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: McLoadingView(),
          )
        else if (candidates.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: McTokens.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: McTokens.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '没有其他同来源的$kindLabel媒体库可供转移。',
              style: McText.sub.copyWith(color: McTokens.warning),
            ),
          )
        else
          Column(
            children: [
              for (final lib in candidates) ...[
                _candidateRow(lib),
                const SizedBox(height: 8),
              ],
            ],
          ),
        if (_loadingPreview)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: McTokens.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text('正在计算转移路径与磁盘空间…', style: McText.caption.muted),
              ],
            ),
          ),
        if (_preview != null) ...[
          const SizedBox(height: 12),
          _buildPreview(_preview!, sourceName),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: McText.caption.copyWith(color: McTokens.danger),
          ),
        ],
      ],
    );
  }

  Widget _candidateRow(DetailLibraryMeta lib) {
    final selected = _targetId == lib.id;
    return Opacity(
      opacity: _busy ? 0.5 : 1.0,
      child: McPressable(
        onTap: _busy ? null : () => _selectTarget(lib.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? McTokens.accent.withValues(alpha: 0.12)
                : McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? McTokens.accent.withValues(alpha: 0.65)
                  : McTokens.line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? McIcons.checkCircleFill : McIcons.circler,
                size: 18,
                color: selected ? McTokens.accentStrong : McTokens.textFaint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lib.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.ui.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (lib.isDefault) ...[
                          const SizedBox(width: 6),
                          Text('默认库', style: McText.micro.faint),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lib.primaryRoot ?? '未配置主根路径',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.micro.copyWith(
                        fontFamily: 'monospace',
                        color: McTokens.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(Map<String, dynamic> p, String? sourceName) {
    final blocked = J.list(p, ['blocked']);
    final crossDevice = J.b(p, ['cross_device']);
    final moves = J.listOfMap(p, ['moves']);
    final skips = J.listOfMap(p, ['skips']);
    final totalBytes = J.i(p, ['total_bytes']) ?? 0;
    final missingCount = J.i(p, ['missing_count']) ?? 0;
    final targetName = J.s(p, ['target_library_name']) ?? '目标库';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocked.isNotEmpty)
          _noticeBox(
            McTokens.danger,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final msg in blocked)
                  Text(
                    msg,
                    style: McText.caption.copyWith(color: McTokens.danger),
                  ),
              ],
            ),
          ),
        if (crossDevice && moves.isNotEmpty) ...[
          if (blocked.isNotEmpty) const SizedBox(height: 10),
          _noticeBox(
            McTokens.warning,
            Text(
              '目标库与源路径不在同一块磁盘：将执行完整文件复制（共 ${mcFormatBytes(totalBytes)}），'
              '耗时较长且会断开与做种目录的硬链接（磁盘占用翻倍）。',
              style: McText.caption.copyWith(color: McTokens.warning),
            ),
          ),
        ],
        if (moves.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '将移动 ${moves.length} 处路径 · 共 ${mcFormatBytes(totalBytes)}'
                  '${missingCount > 0 ? '（另有 $missingCount 条缺失台账随迁）' : ''}',
                  style: McText.caption.faint.tabular,
                ),
                const SizedBox(height: 8),
                for (final m in moves) ...[
                  Text(
                    '${sourceName != null ? '$sourceName · ' : ''}${m['source_path'] ?? ''}',
                    style: McText.micro.copyWith(
                      fontFamily: 'monospace',
                      color: McTokens.textFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '↳ $targetName · ${m['target_path'] ?? ''}',
                    style: McText.micro.copyWith(
                      fontFamily: 'monospace',
                      color: McTokens.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
        if (skips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('以下路径将被跳过：', style: McText.micro.faint),
                const SizedBox(height: 4),
                for (final s in skips)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${s['file_path'] ?? ''}：${s['reason'] ?? ''}',
                      style: McText.micro.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(Map<String, dynamic> st) {
    final errors = J.list(st, ['errors']);
    final movedPaths = J.list(st, ['moved_paths']);
    final filesRelocated = J.i(st, ['files_relocated']) ?? 0;
    final bytesMoved = J.i(st, ['bytes_moved']) ?? 0;
    final removedDirs = J.i(st, ['removed_dirs']) ?? 0;
    final subMoved = J.b(st, ['subscription_moved']);
    final targetName = J.s(st, ['target_library_name']) ?? '目标库';
    final failed = errors.isNotEmpty;

    final summary = StringBuffer(
      '已随迁 $filesRelocated 条台账记录，共 ${mcFormatBytes(bytesMoved)}',
    );
    if (removedDirs > 0) summary.write('，清理 $removedDirs 个空目录');
    summary.write('。');
    if (subMoved) summary.write(' 关联订阅已自动改挂到新媒体库。');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              failed ? McIcons.alert1 : McIcons.checkCircleFill,
              size: 18,
              color: failed ? McTokens.warning : McTokens.ok,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                failed ? '部分路径转移失败' : '已转移至「$targetName」',
                style: McText.ui.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: McTokens.surfaceInset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: McTokens.line),
          ),
          child: movedPaths.isEmpty
              ? Text('未发生物理路径移动。', style: McText.caption.muted)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final path in movedPaths)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          path,
                          style: McText.micro.copyWith(
                            fontFamily: 'monospace',
                            color: McTokens.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (failed) ...[
          const SizedBox(height: 10),
          _noticeBox(
            McTokens.danger,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final err in errors)
                  Text(
                    err,
                    style: McText.caption.copyWith(color: McTokens.danger),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(summary.toString(), style: McText.caption.muted),
      ],
    );
  }

  Widget _buildBottomBar() {
    final processed = J.i(_status ?? const {}, ['processed']) ?? 0;
    final total = J.i(_status ?? const {}, ['total']) ?? 0;
    final suffix = total > 0 ? ' · $processed/$total' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_running) ...[
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: McTokens.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '正在搬运文件与台账（跨盘复制可能耗时较长）$suffix',
                  style: McText.caption.copyWith(color: McTokens.info),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_finished && _status != null)
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '留在本页',
                  primary: false,
                  expanded: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              if (J.list(_status!, ['errors']).isEmpty &&
                  J.i(_status!, ['target_library_id']) != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '去目标库查看',
                    icon: McIcons.arrowRightS,
                    primary: true,
                    expanded: true,
                    onTap: () => _goToTarget(
                      J.i(_status!, ['target_library_id'])!,
                    ),
                  ),
                ),
              ],
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '取消',
                  primary: false,
                  expanded: true,
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: _starting ? '正在启动…' : '确认转移',
                  primary: true,
                  expanded: true,
                  busy: _starting,
                  onTap: _canRun ? _run : null,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _noticeBox(Color tint, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.32)),
      ),
      child: child,
    );
  }
}
