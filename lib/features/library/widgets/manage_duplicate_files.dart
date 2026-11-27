import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import 'library_shared.dart';

/// 媒体库管理中心第 5 页签：重复文件（完整对齐 iOS `ManageDuplicateFilesTab`）。
///
/// 两层结构：
/// - 摘要层（`limit=0`）：扫描状态条 + 搜索/库筛选 + 三档卡片（safe / suggested / review 按取舍类型分组）；
/// - 明细层（`limit=20`）：分档导航条 + 批量清理/全留 + 电影文件行 / 剧集季版本行（可展开各集）。
class ManageDuplicateFilesTab extends ConsumerStatefulWidget {
  const ManageDuplicateFilesTab({
    super.key,
    required this.libraries,
    this.initialItemId,
    this.onCountChange,
  });

  final List<LibraryView> libraries;
  final int? initialItemId;
  final ValueChanged<int>? onCountChange;

  @override
  ConsumerState<ManageDuplicateFilesTab> createState() =>
      _ManageDuplicateFilesTabState();
}

class _ManageDuplicateFilesTabState
    extends ConsumerState<ManageDuplicateFilesTab> {
  static const _pageSize = 20;
  static const _batchLimit = 500;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  Timer? _pollTimer;

  String _q = '';
  int? _libraryId;
  int? _itemId;
  String? _focusTier; // null = summary | safe | suggested | review
  String? _focusReviewKind;
  int _offset = 0;

  DuplicateFilesData? _data;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;
  int _seq = 0;
  final Set<String> _expanded = {};

  bool get _isDetail => _focusTier != null || _itemId != null;

  bool get _isScanning {
    final s = _data?.scan.status;
    return s == 'queued' || s == 'running';
  }

  bool get _filterActive =>
      _q.trim().isNotEmpty || _libraryId != null || _itemId != null;

  @override
  void initState() {
    super.initState();
    _itemId = widget.initialItemId;
    _reload();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isScanning && mounted) _reload(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant ManageDuplicateFilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialItemId != widget.initialItemId) {
      _itemId = widget.initialItemId;
      _offset = 0;
      _expanded.clear();
      _reload();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    final seq = ++_seq;
    if (!silent && _data == null) setState(() => _loading = true);
    final api = ref.read(libraryApiProvider);
    final trimmed = _q.trim();
    try {
      final next = await api.duplicateFiles(
        tier: _focusTier,
        reviewKind: _focusReviewKind,
        q: trimmed.isEmpty ? null : trimmed,
        libraryId: _libraryId,
        mediaItemId: _itemId,
        limit: _isDetail ? _pageSize : 0,
        offset: _isDetail ? _offset : 0,
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _data = next;
        _loading = false;
        _failed = false;
      });
      if (_itemId == null && _libraryId == null && trimmed.isEmpty) {
        widget.onCountChange?.call(next.totalFiles);
      }
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onSearchChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_q != raw) {
        setState(() {
          _q = raw;
          _offset = 0;
          _expanded.clear();
        });
        _reload();
      }
    });
  }

  Future<void> _startScan() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(libraryApiProvider).scanDuplicateFiles();
      McToast.success(
        res['created'] == true ? '已开始后台扫描重复文件' : '重复文件扫描已在运行中',
      );
      await _reload(silent: true);
    } catch (e) {
      McToast.error('启动扫描失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    required String confirmLabel,
    bool destructive = true,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('暂不'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? McTokens.danger : McTokens.accentStrong,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _runResolve(
    Future<TrashedBatchResultView> Function() action, {
    String? customSuccess,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await action();
      final msg = customSuccess ??
          (res.failed.isEmpty
              ? '已移入回收站 ${res.done} 个文件'
              : '完成 ${res.done} 个，失败 ${res.failed.length} 个');
      if (res.failed.isEmpty) {
        McToast.success(msg);
      } else {
        McToast.error(msg);
      }
      await _reload(silent: true);
    } catch (e) {
      McToast.error('操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keepFile(
    DuplicateItemView item,
    DuplicateUnitView unit,
    DuplicateFileView file,
  ) async {
    final gone = unit.files.where((f) => f.id != file.id).toList();
    final lines = gone
        .map((f) => '• ${f.fileName} · ${f.qualityLabel} · ${mcFormatBytes(f.sizeBytes)}')
        .join('\n');
    final ok = await _confirm(
      '保留该文件并清理其余副本？',
      '保留：${file.fileName}\n\n以下 ${gone.length} 个文件将移入回收站（7 天内可恢复）：\n$lines',
      confirmLabel: '移入回收站 (${gone.length})',
    );
    if (!ok) return;
    await _runResolve(
      () => ref.read(libraryApiProvider).resolveDuplicateFiles(
            mediaItemId: item.mediaItemId,
            seasonNumber: unit.seasonNumber,
            episodeNumber: unit.episodeNumber,
            keepFileId: file.id,
          ),
    );
  }

  Future<void> _keepVersion(
    DuplicateItemView item,
    DuplicateSeasonView season,
    DuplicateVersionView version,
  ) async {
    final goneFiles = <DuplicateFileView>[];
    for (final u in season.units) {
      final match = u.files.where((f) => f.versionKey == version.key).firstOrNull;
      final keeper = match ?? u.files.where((f) => f.suggested).firstOrNull ?? u.files.first;
      for (final f in u.files) {
        if (f.id != keeper.id) goneFiles.add(f);
      }
    }
    final bytes = goneFiles.fold<int>(0, (s, f) => s + f.sizeBytes);
    final ok = await _confirm(
      '《${item.title}》第 ${season.seasonNumber} 季保留此版本？',
      '将保留「${version.qualityLabel} · ${version.originLabel}」（覆盖 ${version.episodes.length} 集），'
          '其余 ${goneFiles.length} 个重复文件（共 ${mcFormatBytes(bytes)}）移入回收站。',
      confirmLabel: '移入回收站 (${goneFiles.length})',
    );
    if (!ok) return;
    await _runResolve(
      () => ref.read(libraryApiProvider).resolveDuplicateFiles(
            mediaItemId: item.mediaItemId,
            seasonNumber: season.seasonNumber,
            keepVersion: version.key,
          ),
    );
  }

  Future<void> _keepAll(
    DuplicateItemView item,
    DuplicateSeasonView season,
  ) async {
    final isTv = item.kind == 'tv';
    await _runResolve(
      () => ref.read(libraryApiProvider).resolveDuplicateFiles(
            mediaItemId: item.mediaItemId,
            seasonNumber: season.seasonNumber,
            episodeNumber: isTv ? null : 0,
            keepAll: true,
          ),
      customSuccess: isTv ? '已标记整季全部保留' : '已标记全部保留',
    );
  }

  Future<void> _cleanGroup(
    String tier,
    String? reviewKind,
    DuplicateGroupView group,
  ) async {
    final safe = tier == 'safe';
    final count = group.files > _batchLimit ? _batchLimit : group.files;
    final ok = await _confirm(
      safe ? '一键清理完全一致副本？' : '按建议批量清理「${group.label}」？',
      '将按系统推荐保留每组最优版本，把其余 $count 个重复文件（约 ${mcFormatBytes(group.bytes)}）移入回收站（7 天内可恢复）。'
          '${group.files > _batchLimit ? '\n单次最多批量处理 $_batchLimit 个文件，完成后可再次执行。' : ''}',
      confirmLabel: '移入回收站 ($count)',
      destructive: !safe,
    );
    if (!ok) return;
    await _runResolve(
      () => ref.read(libraryApiProvider).resolveAllDuplicateFiles(
            tier: tier,
            reviewKind: reviewKind,
            libraryId: _libraryId,
          ),
    );
  }

  Future<void> _keepGroup(
    String tier,
    String? reviewKind,
    DuplicateGroupView group,
  ) async {
    final ok = await _confirm(
      '「${group.label}」全部保留？',
      '将这 ${group.units} 组重复项标记为「都留着」，不删除任何文件。',
      confirmLabel: '全部保留 (${group.units})',
      destructive: false,
    );
    if (!ok) return;
    await _runResolve(
      () => ref.read(libraryApiProvider).resolveAllDuplicateFiles(
            tier: tier,
            reviewKind: reviewKind,
            libraryId: _libraryId,
            keepAll: true,
          ),
      customSuccess: '已标记 ${group.units} 组全部保留',
    );
  }

  Color _tierColor(String key) => switch (key) {
        'safe' => McTokens.ok,
        'suggested' => McTokens.info,
        _ => McTokens.warning,
      };

  String _scanNote(DuplicateScanStateView scan) {
    if (scan.status == 'queued') return '重复文件扫描排队中…';
    if (scan.status == 'running') {
      final pct = scan.percent != null ? ' ${scan.percent!.round()}%' : '';
      return '正在扫描重复文件$pct';
    }
    if (scan.status == 'failed') {
      return '上次扫描失败${scan.message != null && scan.message!.isNotEmpty ? '：${scan.message}' : ''}';
    }
    if (scan.scannedAt != null && scan.scannedAt!.isNotEmpty) {
      return '上次扫描：${mcFromNowIso(scan.scannedAt)}';
    }
    return '尚未扫描过重复文件';
  }

  DuplicateGroupView? _currentFocusGroup(DuplicateFilesData data) {
    if (_focusTier == null) return null;
    if (_focusReviewKind != null) {
      return data.reviewGroups
          .where((g) => g.key == _focusReviewKind)
          .firstOrNull;
    }
    return data.tiers.where((t) => t.key == _focusTier).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const McLoadingView(label: '加载重复文件记录…');
    }
    if (_failed && _data == null) {
      return McErrorView(text: '重复文件加载失败', onRetry: _reload);
    }
    final data = _data!;
    final scan = data.scan;

    // 从未扫过
    if (scan.status == null && !_isScanning) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _scanBar(scan),
          const SizedBox(height: 28),
          McEmptyView(
            icon: McIcons.copy,
            title: '扫描库内的重复影片与多版本',
            text: '扫描会找出同片或同集的多个文件，按「完全重复 / 建议清理 / 需要人工取舍」三档整理，绝不会自动删除任何文件。',
            actionLabel: '开始扫描',
            onRetry: _busy ? null : _startScan,
          ),
        ],
      );
    }

    // 扫描完且无重复
    if (data.totalUnits == 0 && !_filterActive && !_isScanning) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _scanBar(scan),
          const SizedBox(height: 28),
          const McEmptyView(
            icon: McIcons.checkCircleFill,
            title: '没有发现重复文件',
            text: '当前所有媒体库干净整洁，无需清理。',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          _scanBar(scan),
          const SizedBox(height: 12),
          // 搜索框
          TextField(
            controller: _searchCtrl,
            style: McText.body,
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索片名或文件名…',
              prefixIcon: const Icon(McIcons.search, size: 17),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 10),
          // 媒体库筛选条 + 单条目 chip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: McChip(
                    label: '全部媒体库',
                    compact: true,
                    selected: _libraryId == null,
                    onTap: () {
                      setState(() {
                        _libraryId = null;
                        _offset = 0;
                        _expanded.clear();
                      });
                      _reload();
                    },
                  ),
                ),
                for (final lib in widget.libraries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: McChip(
                      label: lib.name,
                      compact: true,
                      selected: _libraryId == lib.id,
                      onTap: () {
                        setState(() {
                          _libraryId = _libraryId == lib.id ? null : lib.id;
                          _offset = 0;
                          _expanded.clear();
                        });
                        _reload();
                      },
                    ),
                  ),
                if (_itemId != null)
                  McChip(
                    label: '仅看当前作品 ×',
                    compact: true,
                    selected: true,
                    onTap: () {
                      setState(() {
                        _itemId = null;
                        _offset = 0;
                      });
                      _reload();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!_isDetail) _buildSummaryLayer(data) else _buildDetailLayer(data),
        ],
      ),
    );
  }

  Widget _scanBar(DuplicateScanStateView scan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.line),
      ),
      child: Row(
        children: [
          if (_isScanning) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: McTokens.accent,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(_scanNote(scan), style: McText.caption.muted),
          ),
          McActionPill(
            label: _isScanning
                ? '扫描中…'
                : (scan.scannedAt != null ? '重新扫描' : '开始扫描'),
            height: 30,
            onTap: _busy || _isScanning ? null : _startScan,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLayer(DuplicateFilesData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '共发现 ${data.totalUnits} 组重复 · 多出 ${data.totalFiles} 个文件 · 可释放约 ${mcFormatBytes(data.totalBytes)}',
          style: McText.caption.muted,
        ),
        const SizedBox(height: 10),
        for (final tier in data.tiers) _tierCard(tier, data),
      ],
    );
  }

  Widget _tierCard(DuplicateGroupView tier, DuplicateFilesData data) {
    final empty = tier.units == 0;
    final tone = _tierColor(tier.key);
    final allowsBulk = tier.key == 'safe' || tier.key == 'suggested';

    return Opacity(
      opacity: empty ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: empty ? McTokens.surfaceInset : tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: empty ? McTokens.line : tone.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tier.label,
                  style: McText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  empty
                      ? '无'
                      : '${tier.units} 组 · ${tier.files} 文件 · ${mcFormatBytes(tier.bytes)}',
                  style: McText.caption.faint,
                ),
              ],
            ),
            if (tier.hint.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tier.hint, style: McText.caption.muted),
            ],
            if (!empty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  McActionPill(
                    label: '逐个看',
                    height: 32,
                    onTap: _busy
                        ? null
                        : () {
                            setState(() {
                              _focusTier = tier.key;
                              _focusReviewKind = null;
                              _offset = 0;
                              _expanded.clear();
                            });
                            _reload();
                          },
                  ),
                  if (allowsBulk)
                    McActionPill(
                      label: tier.key == 'safe'
                          ? '一键清理 · ${tier.files}'
                          : '按建议清理 · ${tier.files}',
                      primary: tier.key == 'safe',
                      height: 32,
                      onTap: _busy
                          ? null
                          : () => _cleanGroup(tier.key, null, tier),
                    ),
                ],
              ),
            ],
            if (tier.key == 'review' && data.reviewGroups.isNotEmpty) ...[
              const Divider(height: 20, color: McTokens.line),
              for (final rg in data.reviewGroups) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rg.label,
                              style: McText.sub
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${rg.units} 组 · ${mcFormatBytes(rg.bytes)}',
                            style: McText.caption.faint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          McChip(
                            label: '逐个看',
                            compact: true,
                            onTap: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _focusTier = 'review';
                                      _focusReviewKind = rg.key;
                                      _offset = 0;
                                      _expanded.clear();
                                    });
                                    _reload();
                                  },
                          ),
                          McChip(
                            label: '都留着',
                            compact: true,
                            onTap: _busy
                                ? null
                                : () => _keepGroup('review', rg.key, rg),
                          ),
                          McChip(
                            label: '按建议清理 (${rg.files})',
                            compact: true,
                            onTap: _busy
                                ? null
                                : () => _cleanGroup('review', rg.key, rg),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailLayer(DuplicateFilesData data) {
    final group = _currentFocusGroup(data);
    final pageCount = (data.totalItems / _pageSize).ceil().clamp(1, 9999);
    final curPage = (_offset ~/ _pageSize) + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_focusTier != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: McChip(
                    label: '← 摘要',
                    compact: true,
                    onTap: () {
                      setState(() {
                        _focusTier = null;
                        _focusReviewKind = null;
                        _offset = 0;
                        _expanded.clear();
                      });
                      _reload();
                    },
                  ),
                ),
                for (final t in data.tiers)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: McChip(
                      label: '${t.label}${t.units > 0 ? ' ${t.units}' : ''}',
                      compact: true,
                      selected:
                          _focusTier == t.key && _focusReviewKind == null,
                      onTap: () {
                        setState(() {
                          _focusTier = t.key;
                          _focusReviewKind = null;
                          _offset = 0;
                          _expanded.clear();
                        });
                        _reload();
                      },
                    ),
                  ),
                if (_focusReviewKind != null && group != null)
                  McChip(
                    label: '${group.label} ×',
                    compact: true,
                    selected: true,
                    onTap: () {
                      setState(() {
                        _focusReviewKind = null;
                        _offset = 0;
                      });
                      _reload();
                    },
                  ),
              ],
            ),
          ),
        if (group != null && group.files > 0) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_focusTier == 'review')
                McActionPill(
                  label: '整组都留着',
                  height: 32,
                  onTap: _busy
                      ? null
                      : () => _keepGroup(_focusTier!, _focusReviewKind, group),
                ),
              McActionPill(
                label: '按建议批量清理 · ${group.files}',
                primary: _focusTier == 'safe',
                height: 32,
                onTap: _busy
                    ? null
                    : () => _cleanGroup(_focusTier!, _focusReviewKind, group),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (data.items.isEmpty)
          McEmptyView(
            text: '当前筛选下没有待处理的重复项',
            actionLabel: _filterActive ? '清空筛选' : null,
            onRetry: _filterActive
                ? () {
                    _searchCtrl.clear();
                    setState(() {
                      _q = '';
                      _libraryId = null;
                      _itemId = null;
                      _offset = 0;
                    });
                    _reload();
                  }
                : null,
          )
        else
          for (final item in data.items)
            for (final season in item.seasons) _seasonCard(item, season),
        if (pageCount > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              McActionPill(
                label: '上一页',
                height: 32,
                onTap: _offset >= _pageSize
                    ? () {
                        setState(() {
                          _offset -= _pageSize;
                          _expanded.clear();
                        });
                        _reload();
                      }
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$curPage / $pageCount 页',
                  style: McText.caption.muted,
                ),
              ),
              McActionPill(
                label: '下一页',
                height: 32,
                onTap: _offset + _pageSize < data.totalItems
                    ? () {
                        setState(() {
                          _offset += _pageSize;
                          _expanded.clear();
                        });
                        _reload();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _seasonCard(DuplicateItemView item, DuplicateSeasonView season) {
    final blockKey = '${item.mediaItemId}:${season.seasonNumber}:${season.bucket}';
    final isTv = item.kind == 'tv';
    final isExpanded = _expanded.contains(blockKey);
    final showVersions = season.uniform && !isExpanded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 块头
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 28,
                    height: 40,
                    child: LibraryNetImage(url: item.posterUrl, widthPx: 160),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context
                        .push('/detail/${item.libraryId}/${item.mediaItemId}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.title}${item.year != null ? ' (${item.year})' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${item.libraryName}${isTv ? ' · 第 ${season.seasonNumber} 季' : ''}',
                          style: McText.caption.faint,
                        ),
                      ],
                    ),
                  ),
                ),
                if (season.uniform)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (!_expanded.remove(blockKey)) {
                          _expanded.add(blockKey);
                        }
                      });
                    },
                    child: Text(isExpanded ? '收起各集' : '展开各集'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          if (showVersions)
            for (final v in season.versions)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: v.suggested ? McTokens.ok : Colors.transparent,
                    ),
                    bottom: const BorderSide(color: McTokens.line, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  v.qualityLabel,
                                  style: McText.sub
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (v.suggested) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  '建议保留',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: McTokens.ok,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${v.episodes.length} 集 · ${mcFormatBytes(v.bytes)} · ${v.originLabel}',
                            style: McText.caption.faint,
                          ),
                        ],
                      ),
                    ),
                    McActionPill(
                      label: '整季留此版',
                      height: 30,
                      onTap: _busy ? null : () => _keepVersion(item, season, v),
                    ),
                  ],
                ),
              )
          else
            for (final u in season.units) ...[
              if (isTv && u.episodeNumber > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Text(
                    episodeCode(season.seasonNumber, u.episodeNumber),
                    style: McText.caption.muted,
                  ),
                ),
              for (final f in u.files)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        width: 3,
                        color: f.suggested ? McTokens.ok : Colors.transparent,
                      ),
                      bottom: const BorderSide(color: McTokens.line, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: McTokens.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${f.qualityLabel} · ${mcFormatBytes(f.sizeBytes)}${f.suggested ? ' · 建议保留' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: f.suggested
                                    ? McTokens.ok
                                    : McTokens.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      McActionPill(
                        label: '留这个',
                        height: 30,
                        onTap: _busy ? null : () => _keepFile(item, u, f),
                      ),
                    ],
                  ),
                ),
            ],
          Container(
            color: Colors.black.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _keepAll(item, season),
                  child: Text(isTv ? '整季都留着' : '都留着'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
