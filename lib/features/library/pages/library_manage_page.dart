import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../../../core/session/session_store.dart';
import '../routes.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/issue_drawer_sheet.dart';
import '../widgets/library_form_sheet.dart';
import '../widgets/library_organize_sheet.dart';
import '../widgets/library_shared.dart';
import '../widgets/manage_duplicate_files.dart';

/// 媒体库原生管控中心（5 页签完整对齐 upstream iOS `LibraryManageView`）：
/// 0) 媒体库：新建/编辑（含目录树、4 种类型、自定义封面、路由范围+重叠警告、刮削覆盖、成员权限）、
///    扫描/停止、整理文件名（4段式）、元数据刷新、待处理入口、排序、删除；
/// 1) 待处理：缺失 / 待识别 / 身份复核 / 已忽略四合一视图；
/// 2) 重复文件：扫描进度条 + 摘要/明细两层清理（`ManageDuplicateFilesTab`）；
/// 3) 回收站：搜索 + 库/原因分面 + 三态多选 + 24h 倒计时警示 + 批量恢复/彻底清理；
/// 4) 活跃分享：全站外链审计（浏览次数、最近访问、密码标记、合集部数、复制与吊销）。
class LibraryManagePage extends ConsumerStatefulWidget {
  const LibraryManagePage({
    super.key,
    this.initialTab = 0,
    this.initialItemId,
  });

  final int initialTab;
  final int? initialItemId;

  @override
  ConsumerState<LibraryManagePage> createState() => _LibraryManagePageState();
}

class _LibraryManagePageState extends ConsumerState<LibraryManagePage> {
  late int _tab = widget.initialTab.clamp(0, 4);

  bool _loadingLibs = true;
  String? _libsError;
  List<LibraryView> _libraries = const [];

  int _dupCount = 0;
  int _trashCount = 0;
  int _shareCount = 0;

  LibraryApi get _api => ref.read(libraryApiProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadLibraries);
  }

  Future<void> _loadLibraries() async {
    setState(() {
      _loadingLibs = true;
      _libsError = null;
    });
    try {
      final libs = await _api.libraries(scope: 'all');
      if (!mounted) return;
      setState(() {
        _libraries = libs;
        _loadingLibs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLibs = false;
        _libsError = '加载媒体库失败：$e';
      });
    }
  }

  Future<void> _openEditor({LibraryView? existing}) async {
    final saved = await showLibraryFormSheet(
      context,
      editing: existing,
      existingLibraries: _libraries,
    );
    if (saved == true && mounted) {
      await _loadLibraries();
    }
  }

  Future<void> _moveLibrary(int index, int delta) async {
    final nextIdx = index + delta;
    if (nextIdx < 0 || nextIdx >= _libraries.length) return;
    final list = [..._libraries];
    final moved = list.removeAt(index);
    list.insert(nextIdx, moved);
    setState(() => _libraries = list);
    try {
      await _api.reorderLibraries([for (final l in list) l.id]);
    } catch (e) {
      if (mounted) McToast.error('排序保存失败：$e');
      await _loadLibraries();
    }
  }

  Future<void> _deleteLibrary(LibraryView lib) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        title: Text('删除媒体库「${lib.name}」？'),
        content: const Text('仅移除媒体库索引记录，不会删除磁盘上的任何视频和照片文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: McTokens.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteLibrary(lib.id);
      McToast.success('已删除媒体库「${lib.name}」');
      await _loadLibraries();
    } catch (e) {
      if (mounted) McToast.error('删除失败：$e');
    }
  }

  List<String> _globalOverlapWarnings() {
    final warnings = <String>[];
    for (var i = 0; i < _libraries.length; i++) {
      final a = _libraries[i];
      if (a.matchRules.isEmpty) continue;
      for (var j = i + 1; j < _libraries.length; j++) {
        final b = _libraries[j];
        if (b.kind != a.kind || b.matchRules.isEmpty) continue;
        final ar = _extractRuleSet(a.matchRules, 'origin_country');
        final br = _extractRuleSet(b.matchRules, 'origin_country');
        final ag = _extractRuleSet(a.matchRules, 'genre');
        final bg = _extractRuleSet(b.matchRules, 'genre');
        final regionHit =
            ar.isEmpty || br.isEmpty || ar.intersection(br).isNotEmpty;
        final genreHit =
            ag.isEmpty || bg.isEmpty || ag.intersection(bg).isNotEmpty;
        if (regionHit && genreHit) {
          warnings.add('「${a.name}」与「${b.name}」的收录范围存在重叠，建议微调地区/类型条件避免路由歧义。');
        }
      }
    }
    return warnings;
  }

  Set<String> _extractRuleSet(List<Map<String, dynamic>> rules, String prefix) {
    final out = <String>{};
    for (final r in rules) {
      final f = r['field']?.toString() ?? '';
      if (f == prefix || f == '${prefix}s' || f == 'origin_countries' && prefix == 'origin_country') {
        for (final v in (r['values'] as List<dynamic>? ?? const [])) {
          out.add(v.toString());
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final totalIssues = _libraries.fold<int>(
      0,
      (s, l) => s + l.missingCount + l.unidentifiedCount + l.reviewCount,
    );
    final tabs = <(int, String, int)>[
      (0, '媒体库', _libraries.length),
      (1, '待处理', totalIssues),
      (2, '重复文件', _dupCount),
      (3, '回收站', _trashCount),
      (4, '活跃分享', _shareCount),
    ];

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '媒体库管控中心',
            titleVisible: true,
            trailing: [
              if (_tab == 0)
                McGlassIconButton(
                  icon: McIcons.addS,
                  tooltip: '新建媒体库',
                  onTap: () => _openEditor(),
                ),
            ],
          ),
          // 5 页签横滚条
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
                vertical: 4,
              ),
              children: [
                for (final (idx, label, count) in tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: McChip(
                      label: count > 0 ? '$label $count' : label,
                      compact: true,
                      selected: _tab == idx,
                      onTap: () => setState(() => _tab = idx),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: switch (_tab) {
              0 => _buildLibrariesTab(),
              1 => IssueDrawerView(onChanged: _loadLibraries),
              2 => ManageDuplicateFilesTab(
                  libraries: _libraries,
                  initialItemId: widget.initialItemId,
                  onCountChange: (c) {
                    if (_dupCount != c && mounted) {
                      setState(() => _dupCount = c);
                    }
                  },
                ),
              3 => _ManageRecycleBinTab(
                  onCountChange: (c) {
                    if (_trashCount != c && mounted) {
                      setState(() => _trashCount = c);
                    }
                  },
                ),
              _ => _ManageSharesTab(
                  onCountChange: (c) {
                    if (_shareCount != c && mounted) {
                      setState(() => _shareCount = c);
                    }
                  },
                ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLibrariesTab() {
    if (_loadingLibs && _libraries.isEmpty) {
      return const McLoadingView();
    }
    if (_libsError != null && _libraries.isEmpty) {
      return McErrorView(text: _libsError!, onRetry: _loadLibraries);
    }
    if (_libraries.isEmpty) {
      return McEmptyView(
        icon: McIcons.mediaLibraryFill,
        title: '还没有媒体库',
        text: '点击右上角 + 创建电影、剧集、视频或照片媒体库。',
        actionLabel: '新建媒体库',
        onRetry: () => _openEditor(),
      );
    }

    final overlaps = _globalOverlapWarnings();

    return RefreshIndicator(
      onRefresh: _loadLibraries,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          if (overlaps.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                  for (final w in overlaps)
                    Text(
                      '⚠ $w',
                      style: const TextStyle(
                        fontSize: 12,
                        color: McTokens.warning,
                      ),
                    ),
                ],
              ),
            ),
          for (var i = 0; i < _libraries.length; i++)
            _libraryManageCard(_libraries[i], i),
        ],
      ),
    );
  }

  Widget _libraryManageCard(LibraryView lib, int index) {
    final issues = lib.missingCount + lib.unidentifiedCount + lib.reviewCount;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Icon(libraryKindIcon(lib.kind), size: 18, color: McTokens.accent),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push(routeLibraryDetail(lib.id)),
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
                              style: McText.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (lib.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: McTokens.accentSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '默认',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: McTokens.accent,
                                ),
                              ),
                            ),
                          ],
                          if (lib.excludeFromHome) ...[
                            const SizedBox(width: 6),
                            const Text(
                              '不显示在首页',
                              style: TextStyle(
                                fontSize: 10,
                                color: McTokens.textFaint,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${libraryKindLabel(lib.kind)} · ${lib.stats.itemCount} 部 · ${mcFormatBytes(lib.stats.totalSizeBytes)}'
                        '${lib.lastScanAt != null ? ' · ${mcFromNowIso(lib.lastScanAt)}扫描' : ''}',
                        style: McText.caption.muted,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: '上移',
                icon: const Icon(Icons.arrow_upward_rounded, size: 17),
                onPressed: index > 0 ? () => _moveLibrary(index, -1) : null,
              ),
              IconButton(
                tooltip: '下移',
                icon: const Icon(Icons.arrow_downward_rounded, size: 17),
                onPressed: index < _libraries.length - 1
                    ? () => _moveLibrary(index, 1)
                    : null,
              ),
            ],
          ),
          if (lib.paths.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              lib.paths.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: McTokens.textFaint,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              McChip(
                label: lib.scanning ? '停止扫描' : '扫描',
                icon: lib.scanning ? McIcons.stop : McIcons.refresh,
                compact: true,
                selected: lib.scanning,
                onTap: () async {
                  try {
                    if (lib.scanning) {
                      await _api.stopLibraryScan(lib.id);
                      McToast.info('已请求停止扫描');
                    } else {
                      await _api.scanLibrary(lib.id);
                      McToast.success('已启动扫描');
                    }
                    await _loadLibraries();
                  } catch (e) {
                    McToast.error('操作失败：$e');
                  }
                },
              ),
              if (lib.capabilities.naming)
                McChip(
                  label: '整理文件名',
                  icon: McIcons.folderSettings,
                  compact: true,
                  onTap: () => showLibraryOrganizeSheet(
                    context,
                    libraryId: lib.id,
                    onStarted: _loadLibraries,
                  ),
                ),
              if (lib.capabilities.scraped)
                McChip(
                  label: '刷新元数据',
                  icon: McIcons.refresh,
                  compact: true,
                  onTap: () async {
                    try {
                      await _api.libraryMetadataRefresh(lib.id, mode: 'all');
                      McToast.success('已启动元数据刷新');
                    } catch (e) {
                      McToast.error('刷新失败：$e');
                    }
                  },
                ),
              if (issues > 0)
                McChip(
                  label: '待处理 ($issues)',
                  icon: McIcons.alert1,
                  compact: true,
                  selected: true,
                  onTap: () => showIssueDrawerSheet(
                    context,
                    libraryId: lib.id,
                    onChanged: _loadLibraries,
                  ),
                ),
              McChip(
                label: '编辑',
                icon: McIcons.edit,
                compact: true,
                onTap: () => _openEditor(existing: lib),
              ),
              McChip(
                label: '删除',
                icon: McIcons.trash2,
                compact: true,
                onTap: () => _deleteLibrary(lib),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ────────────────────── 页签 3：回收站（完整对齐 ManageRecycleBin.swift） ────────────────────── */

class _ManageRecycleBinTab extends ConsumerStatefulWidget {
  const _ManageRecycleBinTab({required this.onCountChange});
  final ValueChanged<int> onCountChange;

  @override
  ConsumerState<_ManageRecycleBinTab> createState() =>
      _ManageRecycleBinTabState();
}

class _ManageRecycleBinTabState extends ConsumerState<_ManageRecycleBinTab> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _q = '';
  int? _libraryId;
  String? _reason;
  int _offset = 0;

  TrashedFilesData? _data;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;
  int _seq = 0;
  final Set<String> _expanded = {};
  final Set<int> _selected = {};

  bool get _filterActive =>
      _q.trim().isNotEmpty || _libraryId != null || _reason != null;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    final seq = ++_seq;
    if (!silent && _data == null) setState(() => _loading = true);
    try {
      final next = await ref.read(libraryApiProvider).trashedFilesData(
            q: _q.trim().isEmpty ? null : _q.trim(),
            libraryId: _libraryId,
            reason: _reason,
            limit: _pageSize,
            offset: _offset,
          );
      if (!mounted || seq != _seq) return;
      setState(() {
        _data = next;
        _loading = false;
        _failed = false;
      });
      widget.onCountChange(next.totalFiles);
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
      if (!mounted || _q == raw) return;
      setState(() {
        _q = raw;
        _offset = 0;
        _selected.clear();
        _expanded.clear();
      });
      _reload();
    });
  }

  String _reasonLabel(String r) => switch (r) {
        'duplicate' => '重复清理',
        'manual' => '手动删除',
        'replace' => '版本替换',
        _ => r.isEmpty ? '其他' : r,
      };

  bool _isUrgent24h(String? expiresAt) {
    if (expiresAt == null || expiresAt.isEmpty) return false;
    final dt = DateTime.tryParse(expiresAt);
    if (dt == null) return false;
    return dt.difference(DateTime.now()).inHours < 24;
  }

  Future<void> _restoreIds(List<int> ids) async {
    if (ids.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final res =
          await ref.read(libraryApiProvider).restoreTrashedFiles(ids);
      McToast.success('已恢复 ${res.done} 个文件');
      _selected.removeAll(ids);
      await _reload(silent: true);
    } catch (e) {
      McToast.error('恢复失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purge({
    List<int>? ids,
    Map<String, dynamic>? filter,
    required String title,
    required int fileCount,
    required int bytes,
  }) async {
    if (fileCount <= 0 || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        title: Text(title),
        content: Text(
          '将永久删除 $fileCount 个磁盘文件（预计释放 ${mcFormatBytes(bytes)}），删除后无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('暂不'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '永久删除 ($fileCount)',
              style: const TextStyle(color: McTokens.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(libraryApiProvider)
          .purgeTrashedFiles(ids, filter: filter);
      McToast.success('已彻底清理 ${res.done} 个文件');
      _selected.clear();
      await _reload(silent: true);
    } catch (e) {
      McToast.error('清理失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const McLoadingView();
    if (_failed && _data == null) {
      return McErrorView(text: '回收站加载失败', onRetry: _reload);
    }
    final data = _data!;
    if (data.totalFiles == 0 && !_filterActive) {
      return const McEmptyView(
        icon: McIcons.trash2,
        title: '回收站是空的',
        text: '删除或清理重复文件后会暂存在这里 7 天，随时可恢复。',
      );
    }

    final pageFileIds = [
      for (final item in data.items)
        for (final f in item.files) f.id,
    ];
    final selectedOnPage =
        pageFileIds.where(_selected.contains).length;
    final pageSelectVal = selectedOnPage == 0
        ? false
        : (selectedOnPage == pageFileIds.length ? true : null);
    final selectedBytes = [
      for (final item in data.items)
        for (final f in item.files)
          if (_selected.contains(f.id)) f.sizeBytes,
    ].fold<int>(0, (a, b) => a + b);

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          // 摘要头 + 立即清理全部
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.totalFiles} 个文件 · 共 ${mcFormatBytes(data.totalBytes)}',
                      style: McText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (data.dueWithin24h > 0)
                      Text(
                        '其中 ${data.dueWithin24h} 个将在 24 小时内自动彻底清除',
                        style: const TextStyle(
                          fontSize: 12,
                          color: McTokens.warning,
                        ),
                      ),
                  ],
                ),
              ),
              McActionPill(
                label: '立即清理全部',
                height: 32,
                onTap: _busy || data.totalFiles == 0
                    ? null
                    : () => _purge(
                          filter: {
                            if (_q.trim().isNotEmpty) 'q': _q.trim(),
                            if (_libraryId != null) 'library_id': _libraryId,
                            if (_reason != null) 'reason': _reason,
                          },
                          title: _filterActive ? '清理当前筛选的全部文件？' : '清空整个回收站？',
                          fileCount: data.totalFiles,
                          bytes: data.totalBytes,
                        ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 8),
          // 库分面
          if (data.byLibrary.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: McChip(
                      label: '全部库',
                      compact: true,
                      selected: _libraryId == null,
                      onTap: () {
                        setState(() {
                          _libraryId = null;
                          _offset = 0;
                          _selected.clear();
                        });
                        _reload();
                      },
                    ),
                  ),
                  for (final bl in data.byLibrary)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: McChip(
                        label: '${bl.name} ${bl.count}',
                        compact: true,
                        selected: _libraryId == bl.libraryId,
                        onTap: () {
                          setState(() {
                            _libraryId =
                                _libraryId == bl.libraryId ? null : bl.libraryId;
                            _offset = 0;
                            _selected.clear();
                          });
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
          // 原因分面
          if (data.byReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: McChip(
                      label: '全部原因',
                      compact: true,
                      selected: _reason == null,
                      onTap: () {
                        setState(() {
                          _reason = null;
                          _offset = 0;
                          _selected.clear();
                        });
                        _reload();
                      },
                    ),
                  ),
                  for (final br in data.byReason)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: McChip(
                        label: '${_reasonLabel(br.reason)} ${br.count}',
                        compact: true,
                        selected: _reason == br.reason,
                        onTap: () {
                          setState(() {
                            _reason = _reason == br.reason ? null : br.reason;
                            _offset = 0;
                            _selected.clear();
                          });
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // 三态全选 + 批量恢复 / 彻底清理操作条
          if (data.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: McTokens.line),
              ),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: pageSelectVal,
                    onChanged: (_) {
                      setState(() {
                        if (pageSelectVal == true) {
                          _selected.removeAll(pageFileIds);
                        } else {
                          _selected.addAll(pageFileIds);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? '全选本页'
                          : '已选 ${_selected.length} 个 (${mcFormatBytes(selectedBytes)})',
                      style: McText.caption.muted,
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    McActionPill(
                      label: '恢复',
                      height: 30,
                      onTap:
                          _busy ? null : () => _restoreIds(_selected.toList()),
                    ),
                    const SizedBox(width: 6),
                    McActionPill(
                      label: '彻底清理',
                      height: 30,
                      onTap: _busy
                          ? null
                          : () => _purge(
                                ids: _selected.toList(),
                                title: '永久删除选中的 ${_selected.length} 个文件？',
                                fileCount: _selected.length,
                                bytes: selectedBytes,
                              ),
                    ),
                  ],
                ],
              ),
            ),
          if (data.items.isEmpty)
            const McEmptyView(text: '当前筛选下没有回收站文件')
          else
            for (final item in data.items) _trashItemCard(item),
        ],
      ),
    );
  }

  Widget _trashItemCard(TrashedItemView item) {
    final key = '${item.libraryId}:${item.mediaItemId ?? item.title}';
    final expanded = _expanded.contains(key);
    final fileIds = item.files.map((f) => f.id).toList();
    final selCount = fileIds.where(_selected.contains).length;
    final triVal = selCount == 0
        ? false
        : (selCount == fileIds.length ? true : null);
    final urgent = _isUrgent24h(item.earliestPurgeAfter);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent
              ? McTokens.warning.withValues(alpha: 0.45)
              : McTokens.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                tristate: true,
                value: triVal,
                onChanged: (_) {
                  setState(() {
                    if (triVal == true) {
                      _selected.removeAll(fileIds);
                    } else {
                      _selected.addAll(fileIds);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.body
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (urgent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: McTokens.warning.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '24h 内过期',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: McTokens.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${item.libraryName} · ${item.fileCount} 文件 · ${mcFormatBytes(item.totalBytes)}',
                      style: McText.caption.faint,
                    ),
                  ],
                ),
              ),
              if (item.files.length > 1)
                IconButton(
                  icon: Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: McTokens.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      if (!_expanded.remove(key)) _expanded.add(key);
                    });
                  },
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 4),
            child: Row(
              children: [
                McActionPill(
                  label: '恢复',
                  height: 28,
                  onTap: _busy ? null : () => _restoreIds(fileIds),
                ),
                const SizedBox(width: 8),
                McActionPill(
                  label: '彻底清理',
                  height: 28,
                  onTap: _busy
                      ? null
                      : () => _purge(
                            ids: fileIds,
                            title: '永久删除「${item.title}」的 ${fileIds.length} 个文件？',
                            fileCount: fileIds.length,
                            bytes: item.totalBytes,
                          ),
                ),
              ],
            ),
          ),
          if (expanded || item.files.length == 1) ...[
            const Divider(height: 14, color: McTokens.line),
            for (final f in item.files)
              Row(
                children: [
                  if (item.files.length > 1)
                    Checkbox(
                      value: _selected.contains(f.id),
                      onChanged: (_) {
                        setState(() {
                          if (!_selected.remove(f.id)) _selected.add(f.id);
                        });
                      },
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: McTokens.textMuted,
                          ),
                        ),
                        Text(
                          '${_reasonLabel(f.reason ?? '')} · ${mcFormatBytes(f.sizeBytes)}',
                          style: McText.caption.faint,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/* ────────────────────── 页签 4：活跃分享（完整对齐 ManageSharesTab.swift） ────────────────────── */

class _ManageSharesTab extends ConsumerStatefulWidget {
  const _ManageSharesTab({required this.onCountChange});
  final ValueChanged<int> onCountChange;

  @override
  ConsumerState<_ManageSharesTab> createState() => _ManageSharesTabState();
}

class _ManageSharesTabState extends ConsumerState<_ManageSharesTab> {
  List<LibraryShareView>? _shares;
  bool _failed = false;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await ref.read(libraryApiProvider).activeSharesTyped();
      if (!mounted) return;
      setState(() {
        _shares = list;
        _failed = false;
      });
      widget.onCountChange(list.length);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _fullUrl(LibraryShareView s) {
    final u = s.url;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final origin = (appSession.baseUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    return origin.isEmpty ? u : '$origin$u';
  }

  Future<void> _copy(LibraryShareView s) async {
    final link = _fullUrl(s);
    final hasPwd = s.password != null && s.password!.isNotEmpty;
    final text = hasPwd
        ? 'MovieClaw · 《${s.title}》\n$link\n访问密码：${s.password}'
        : 'MovieClaw · 《${s.title}》\n$link';
    await Clipboard.setData(ClipboardData(text: text));
    McToast.success(hasPwd ? '已复制分享链接与密码' : '已复制分享链接');
  }

  Future<void> _revoke(LibraryShareView s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        title: Text('取消「${s.title}」的外链分享？'),
        content: const Text('取消后原链接立即失效，访客无法再打开或播放。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('先不'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('取消分享', style: TextStyle(color: McTokens.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = s.id);
    try {
      await ref.read(libraryApiProvider).revokeShare(
            s.id > 0 ? '${s.id}' : s.slug,
          );
      McToast.success('已取消分享');
      await _reload();
    } catch (e) {
      McToast.error('取消失败：$e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shares == null && !_failed) return const McLoadingView();
    if (_failed && _shares == null) {
      return McErrorView(text: '加载活跃分享失败', onRetry: _reload);
    }
    final list = _shares ?? const [];
    if (list.isEmpty) {
      return const McEmptyView(
        icon: McIcons.share,
        title: '暂无活跃分享',
        text: '在作品或合集详情页创建外链分享后，可在这里统一审计与吊销。',
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final s = list[i];
          final hasPwd = s.password != null && s.password!.isNotEmpty;
          final meta = [
            if (s.collectionId != null)
              '合集 · ${s.itemCount ?? 0} 部'
            else if (s.kind != null)
              libraryKindLabel(s.kind!),
            if (s.year != null) '${s.year}',
            if (s.expiresAt.isNotEmpty) '到期 ${s.expiresAt.split('T').first}',
          ];
          final views = s.viewCount > 0
              ? '已访问 ${s.viewCount} 次${s.lastAccessedAt != null ? ' · 最近 ${mcFromNowIso(s.lastAccessedAt)}' : ''}'
              : '尚无访问记录';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
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
                    GestureDetector(
                      onTap: () {
                        if (s.libraryId != null && s.mediaItemId != null) {
                          context.push(
                            '/detail/${s.libraryId}/${s.mediaItemId}',
                          );
                        } else if (s.collectionId != null) {
                          context.push(routeLibraryCollection(s.collectionId!));
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 66,
                          child: LibraryNetImage(
                            url: s.posterUrl,
                            widthPx: 160,
                          ),
                        ),
                      ),
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
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: McText.body
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (hasPwd) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  McIcons.lock,
                                  size: 13,
                                  color: McTokens.textFaint,
                                ),
                                const SizedBox(width: 2),
                                Text('密码', style: McText.caption.faint),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(meta.join(' · '), style: McText.caption.muted),
                          const SizedBox(height: 2),
                          Text(views, style: McText.caption.faint),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    McActionPill(
                      label: '复制链接',
                      icon: McIcons.copy,
                      height: 30,
                      onTap: () => _copy(s),
                    ),
                    const SizedBox(width: 8),
                    McActionPill(
                      label: '取消分享',
                      height: 30,
                      onTap: _busyId == s.id ? null : () => _revoke(s),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
