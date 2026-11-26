import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/library_shared.dart';

/// 媒体库原生管控中心（对齐并整合 Web `/library/manage` 四大核心面板）：
/// 0) `媒体库`：创建/编辑（内置服务端目录树浏览器 `/api/v1/fs/browse`）、扫描、整理、刷新元数据、排序、删除；
/// 1) `待识别`：盘点未识别媒体文件，内置 TMDB 搜索一键认领绑定；
/// 2) `回收站`：已移除文件一键恢复或彻底清理释放磁盘；
/// 3) `活跃分享`：全站外链分享统一审计、复制与一键吊销。
class LibraryManagePage extends ConsumerStatefulWidget {
  const LibraryManagePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<LibraryManagePage> createState() => _LibraryManagePageState();
}

class _LibraryManagePageState extends ConsumerState<LibraryManagePage> {
  late int _tab = widget.initialTab.clamp(0, 3);
  bool _loading = true;
  String? _error;
  List<LibraryView> _libraries = const [];
  List<Map<String, dynamic>> _unidentified = const [];
  List<Map<String, dynamic>> _trashed = const [];
  List<Map<String, dynamic>> _shares = const [];

  LibraryApi get _api => ref.read(libraryApiProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (_tab) {
        case 0:
          _libraries = await _api.libraries();
        case 1:
          _unidentified = await _api.unidentifiedFiles();
        case 2:
          _trashed = await _api.trashedFiles();
        case 3:
          _shares = await _api.activeShares();
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败：$e';
        });
      }
    }
  }

  void _switchTab(int idx) {
    if (_tab == idx) return;
    setState(() => _tab = idx);
    _reload();
  }

  Future<void> _openLibraryEditor({LibraryView? existing}) async {
    final saved = await showMcSheet<bool>(
      context: context,
      maxWidth: 600,
      builder: (_) => _LibraryEditorSheet(existing: existing),
    );
    if (saved == true && mounted) {
      await _reload();
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
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => _openLibraryEditor(),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              4,
              McTokens.pagePadding,
              10,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  McChip(
                    label: '媒体库',
                    icon: McIcons.mediaLibraryFill,
                    selected: _tab == 0,
                    onTap: () => _switchTab(0),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: '待识别文件',
                    icon: McIcons.fileSearch,
                    selected: _tab == 1,
                    onTap: () => _switchTab(1),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: '回收站',
                    icon: McIcons.trash2,
                    selected: _tab == 2,
                    onTap: () => _switchTab(2),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: '活跃分享',
                    icon: McIcons.share,
                    selected: _tab == 3,
                    onTap: () => _switchTab(3),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: _loading
                  ? const McLoadingView()
                  : _error != null
                      ? McErrorView(text: _error!, onRetry: _reload)
                      : switch (_tab) {
                          0 => _buildLibrariesTab(),
                          1 => _buildUnidentifiedTab(),
                          2 => _buildTrashTab(),
                          _ => _buildSharesTab(),
                        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibrariesTab() {
    if (_libraries.isEmpty) {
      return McEmptyView(
        icon: McIcons.folderPlus,
        title: '尚未创建任何媒体库',
        text: '点击下方按钮选择服务器上的影视目录，MovieClaw 将自动刮削海报与演职员。',
        actionLabel: '新建媒体库',
        onRetry: () => _openLibraryEditor(),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        14,
        McTokens.pagePadding,
        40,
      ),
      itemCount: _libraries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final lib = _libraries[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(McTokens.cardRadius),
            border: Border.all(color: McTokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    libraryKindIcon(lib.kind),
                    size: 20,
                    color: McTokens.accentStrong,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(lib.name, style: McText.titleSm),
                  ),
                  if (lib.isDefault)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: McChip(label: '默认', compact: true),
                    ),
                  IconButton(
                    tooltip: '上移',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(McIcons.arrowUpS, size: 18),
                    onPressed: i > 0 ? () => _moveLibrary(i, -1) : null,
                  ),
                  IconButton(
                    tooltip: '下移',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(McIcons.arrowDownS, size: 18),
                    onPressed: i < _libraries.length - 1
                        ? () => _moveLibrary(i, 1)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${lib.stats.itemCount} 部作品 · ${lib.stats.fileCount} 个文件 · ${mcFormatBytes(lib.stats.totalSizeBytes)}'
                '${lib.stats.unidentifiedCount > 0 ? ' · ${lib.stats.unidentifiedCount} 待识别' : ''}',
                style: McText.caption.muted.tabular,
              ),
              if (lib.paths.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  lib.paths.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.micro.faint,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  McChip(
                    icon: lib.scanning ? McIcons.stop : McIcons.scan,
                    label: lib.scanning ? '停止扫描' : '立即扫描',
                    compact: true,
                    selected: lib.scanning,
                    onTap: () async {
                      try {
                        if (lib.scanning) {
                          await _api.stopLibraryScan(lib.id);
                          if (mounted) McToast.info('已请求停止扫描');
                        } else {
                          await _api.scanLibrary(lib.id);
                          if (mounted) McToast.success('已启动扫描「${lib.name}」');
                        }
                        await _reload();
                      } catch (e) {
                        if (mounted) McToast.error('操作失败：$e');
                      }
                    },
                  ),
                  McChip(
                    icon: McIcons.folderSmart,
                    label: '整理命名',
                    compact: true,
                    onTap: () async {
                      try {
                        await _api.organizeLibrary(lib.id);
                        if (mounted) McToast.success('已提交文件整理任务');
                        await _reload();
                      } catch (e) {
                        if (mounted) McToast.error('整理失败：$e');
                      }
                    },
                  ),
                  McChip(
                    icon: McIcons.refreshS,
                    label: '刷元数据',
                    compact: true,
                    onTap: () async {
                      try {
                        await _api.refreshLibraryMetadata(lib.id);
                        if (mounted) McToast.success('已提交整库元数据刷新');
                        await _reload();
                      } catch (e) {
                        if (mounted) McToast.error('刷新失败：$e');
                      }
                    },
                  ),
                  McChip(
                    icon: McIcons.edit,
                    label: '编辑目录',
                    compact: true,
                    onTap: () => _openLibraryEditor(existing: lib),
                  ),
                  McChip(
                    icon: McIcons.trash2,
                    label: '移除库',
                    compact: true,
                    onTap: () => _confirmDeleteLibrary(lib),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteLibrary(LibraryView lib) async {
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('移除媒体库「${lib.name}」？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '仅从 MovieClaw 台账移除索引记录，不会删除硬盘上的任何原始音视频文件。',
              style: McText.sub.muted,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '确认移除',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteLibrary(lib.id);
      if (mounted) McToast.success('媒体库已移除');
      await _reload();
    } catch (e) {
      if (mounted) McToast.error('移除失败：$e');
    }
  }

  Widget _buildUnidentifiedTab() {
    if (_unidentified.isEmpty) {
      return const McEmptyView(
        icon: McIcons.checkCircleFill,
        title: '全部文件均已成功识别',
        text: '没有待人工干预的异常视频文件。',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        14,
        McTokens.pagePadding,
        40,
      ),
      itemCount: _unidentified.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final f = _unidentified[i];
        final id = (f['id'] as num? ?? f['file_id'] as num? ?? 0).toInt();
        final path = (f['path'] ?? f['rel_path'] ?? f['filename'] ?? '')
            .toString();
        final size = (f['size_bytes'] as num? ?? 0).toInt();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(McTokens.cardRadius),
            border: Border.all(color: McTokens.line),
          ),
          child: Row(
            children: [
              const Icon(
                McIcons.fileWarning,
                size: 20,
                color: McTokens.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.ui.semibold,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (size > 0) mcFormatBytes(size),
                        path,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: McText.micro.faint,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              McChip(
                label: '手动认领',
                selected: true,
                compact: true,
                onTap: id <= 0
                    ? null
                    : () => _openClaimSheet(id, path.split('/').last),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openClaimSheet(int fileId, String fileName) async {
    final claimed = await showMcSheet<bool>(
      context: context,
      maxWidth: 580,
      builder: (_) => _ClaimFileSheet(fileId: fileId, fileName: fileName),
    );
    if (claimed == true && mounted) {
      await _reload();
    }
  }

  Widget _buildTrashTab() {
    if (_trashed.isEmpty) {
      return const McEmptyView(
        icon: McIcons.trash2,
        title: '回收站为空',
        text: '被移除的媒体文件会暂存于此，方便随时恢复或彻底清理。',
      );
    }
    final allIds = [
      for (final f in _trashed)
        (f['id'] as num? ?? f['file_id'] as num? ?? 0).toInt(),
    ].where((id) => id > 0).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        14,
        McTokens.pagePadding,
        40,
      ),
      children: [
        if (allIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '全部恢复 (${allIds.length})',
                    icon: McIcons.arrowGoBack,
                    primary: false,
                    expanded: true,
                    onTap: () async {
                      await _api.restoreTrashedFiles(allIds);
                      if (mounted) McToast.success('已全部恢复');
                      await _reload();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '清空回收站',
                    icon: McIcons.trash2,
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () async {
                      await _api.purgeTrashedFiles(allIds);
                      if (mounted) McToast.success('回收站已彻底清空');
                      await _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
        McInsetGroup(
          margin: EdgeInsets.zero,
          children: [
            for (final f in _trashed)
              Builder(
                builder: (context) {
                  final id =
                      (f['id'] as num? ?? f['file_id'] as num? ?? 0).toInt();
                  final path =
                      (f['path'] ?? f['filename'] ?? '未知文件').toString();
                  final size = (f['size_bytes'] as num? ?? 0).toInt();
                  return McInsetRow(
                    icon: McIcons.fileVideo1,
                    title: path.split('/').last,
                    subtitle: size > 0 ? '${mcFormatBytes(size)} · $path' : path,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        McChip(
                          label: '恢复',
                          compact: true,
                          onTap: id <= 0
                              ? null
                              : () async {
                                  await _api.restoreTrashedFiles([id]);
                                  if (mounted) McToast.success('已恢复文件');
                                  await _reload();
                                },
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: '彻底删除',
                          icon: const Icon(
                            McIcons.trash2,
                            size: 17,
                            color: McTokens.danger,
                          ),
                          onPressed: id <= 0
                              ? null
                              : () async {
                                  await _api.purgeTrashedFiles([id]);
                                  if (mounted) McToast.success('已彻底删除');
                                  await _reload();
                                },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSharesTab() {
    if (_shares.isEmpty) {
      return const McEmptyView(
        icon: McIcons.share,
        title: '当前没有活跃的外链分享',
        text: '在任意影片详情页点击「⋯ → 分享观看链接」即可生成受密码和有效期保护的客态链接。',
      );
    }
    final base = _api.client.baseUrl;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      children: [
        McInsetGroup(
          children: [
            for (final s in _shares)
              Builder(
                builder: (context) {
                  final id = (s['id'] ?? s['slug'] ?? '').toString();
                  final slug = (s['slug'] ?? '').toString();
                  final title =
                      (s['title'] ?? s['item_title'] ?? slug).toString();
                  final expires =
                      (s['expires_at'] ?? '').toString();
                  var url = (s['url'] ?? '').toString();
                  if (url.isEmpty && slug.isNotEmpty) url = '/s/$slug';
                  if (url.startsWith('/') && base.isNotEmpty) url = base + url;
                  return McInsetRow(
                    icon: McIcons.link,
                    title: title,
                    subtitle: [
                      if (s['has_password'] == true) '密码保护',
                      if (expires.isNotEmpty)
                        '到期：${mcFromNowIso(expires, empty: expires)}',
                    ].join(' · '),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (url.isNotEmpty)
                          McChip(
                            label: '复制',
                            compact: true,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: url));
                              McToast.success('已复制分享链接');
                            },
                          ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: '吊销分享',
                          icon: const Icon(
                            McIcons.trash2,
                            size: 17,
                            color: McTokens.danger,
                          ),
                          onPressed: id.isEmpty
                              ? null
                              : () async {
                                  await _api.revokeShare(id);
                                  if (mounted) McToast.success('已吊销外链分享');
                                  await _reload();
                                },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// 新建 / 编辑媒体库弹层（内置可视化服务端目录选择器 `GET /api/v1/fs/browse`）。
class _LibraryEditorSheet extends ConsumerStatefulWidget {
  const _LibraryEditorSheet({this.existing});

  final LibraryView? existing;

  @override
  ConsumerState<_LibraryEditorSheet> createState() =>
      _LibraryEditorSheetState();
}

class _LibraryEditorSheetState extends ConsumerState<_LibraryEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _kind = widget.existing?.kind ?? 'movie';
  late final List<String> _paths = [...(widget.existing?.paths ?? const [])];
  late bool _isDefault = widget.existing?.isDefault ?? false;
  late bool _excludeFromHome = widget.existing?.excludeFromHome ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickServerDir() async {
    final picked = await showMcSheet<String>(
      context: context,
      maxWidth: 580,
      builder: (_) => const _ServerDirPickerSheet(),
    );
    if (picked != null && picked.isNotEmpty && !_paths.contains(picked)) {
      setState(() => _paths.add(picked));
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _paths.isEmpty) {
      McToast.error('请填写媒体库名称并至少添加一个目录');
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(libraryApiProvider);
      if (widget.existing == null) {
        await api.createLibrary(
          name: name,
          kind: _kind,
          paths: _paths,
          isDefault: _isDefault,
          excludeFromHome: _excludeFromHome,
        );
      } else {
        await api.updateLibrary(
          widget.existing!.id,
          name: name,
          paths: _paths,
          isDefault: _isDefault,
          excludeFromHome: _excludeFromHome,
        );
      }
      if (mounted) {
        McToast.success(widget.existing == null ? '已创建媒体库' : '已更新媒体库');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        McToast.error('保存失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isEdit ? '编辑媒体库' : '新建媒体库', style: McText.titleSm),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            style: McText.body,
            decoration: const InputDecoration(
              labelText: '媒体库名称',
              hintText: '例如：4K 蓝光电影 / 追更剧集',
            ),
          ),
          if (!isEdit) ...[
            const SizedBox(height: 14),
            Text('内容类型', style: McText.caption.muted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                McChip(
                  label: '电影',
                  icon: McIcons.movie,
                  selected: _kind == 'movie',
                  onTap: () => setState(() => _kind = 'movie'),
                ),
                McChip(
                  label: '剧集',
                  icon: McIcons.tv,
                  selected: _kind == 'tv',
                  onTap: () => setState(() => _kind = 'tv'),
                ),
                McChip(
                  label: '其他视频',
                  icon: McIcons.film,
                  selected: _kind == 'video',
                  onTap: () => setState(() => _kind = 'video'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('服务端媒体目录', style: McText.caption.muted)),
              McChip(
                icon: McIcons.folderOpen,
                label: '浏览服务器目录',
                selected: true,
                compact: true,
                onTap: _pickServerDir,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_paths.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: McTokens.line),
              ),
              child: Text(
                '尚未选择目录，点击右上角「浏览服务器目录」挑选挂载盘路径。',
                style: McText.caption.faint,
              ),
            )
          else
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final p in _paths)
                  McInsetRow(
                    icon: McIcons.folder,
                    title: p,
                    trailing: IconButton(
                      icon: const Icon(
                        McIcons.close2,
                        size: 16,
                        color: McTokens.textMuted,
                      ),
                      onPressed: () => setState(() => _paths.remove(p)),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              McInsetRow(
                title: '设为该类型的默认入库目标',
                trailing: Switch(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
                onTap: () => setState(() => _isDefault = !_isDefault),
              ),
              McInsetRow(
                title: '不在首页瀑布流展示',
                trailing: Switch(
                  value: _excludeFromHome,
                  onChanged: (v) => setState(() => _excludeFromHome = v),
                ),
                onTap: () =>
                    setState(() => _excludeFromHome = !_excludeFromHome),
              ),
            ],
          ),
          const SizedBox(height: 18),
          McActionPill(
            label: _saving ? '保存中…' : '保存媒体库',
            primary: true,
            expanded: true,
            busy: _saving,
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// 可复用的服务端目录浏览器（`GET /api/v1/fs/browse`）。
class _ServerDirPickerSheet extends ConsumerStatefulWidget {
  const _ServerDirPickerSheet();

  @override
  ConsumerState<_ServerDirPickerSheet> createState() =>
      _ServerDirPickerSheetState();
}

class _ServerDirPickerSheetState extends ConsumerState<_ServerDirPickerSheet> {
  String _currentPath = '/';
  String? _parentPath;
  List<Map<String, dynamic>> _entries = const [];
  bool _loading = true;
  late final TextEditingController _manual = TextEditingController(text: '/');

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _browse(null));
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _browse(String? path) async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(libraryApiProvider).browseServerFs(path: path);
      final cur = (res['current_path'] ?? res['path'] ?? path ?? '/').toString();
      final entries = (res['entries'] ?? res['dirs'] ?? const []) as List<dynamic>;
      if (mounted) {
        setState(() {
          _currentPath = cur;
          _manual.text = cur;
          _parentPath = res['parent_path']?.toString();
          _entries =
              entries.whereType<Map>().map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        McToast.error('读取目录失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('选择服务器目录', style: McText.titleSm),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_parentPath != null && _parentPath!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: McGlassIconButton(
                      icon: McIcons.arrowUp,
                      size: 34,
                      tooltip: '上一级',
                      onTap: () => _browse(_parentPath),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _manual,
                    style: McText.sub,
                    onSubmitted: _browse,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '/media/movies',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const McLoadingView()
                  : _entries.isEmpty
                      ? const McEmptyView(text: '当前目录下没有子文件夹')
                      : ListView(
                          children: [
                            McInsetGroup(
                              margin: EdgeInsets.zero,
                              children: [
                                for (final e in _entries)
                                  McInsetRow(
                                    icon: McIcons.folder,
                                    title: (e['name'] ?? '').toString(),
                                    subtitle: e['writable'] == false
                                        ? '只读'
                                        : null,
                                    onTap: () =>
                                        _browse(e['path']?.toString()),
                                  ),
                              ],
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: 12),
            McActionPill(
              label: '选定「$_currentPath」',
              icon: McIcons.check,
              primary: true,
              expanded: true,
              onTap: () => Navigator.of(context).pop(_manual.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}

/// 待识别文件手动认领弹层（搜索 TMDB 词条并绑定 `file-title-assignments`）。
class _ClaimFileSheet extends ConsumerStatefulWidget {
  const _ClaimFileSheet({required this.fileId, required this.fileName});

  final int fileId;
  final String fileName;

  @override
  ConsumerState<_ClaimFileSheet> createState() => _ClaimFileSheetState();
}

class _ClaimFileSheetState extends ConsumerState<_ClaimFileSheet> {
  late final TextEditingController _q = TextEditingController(
    text: widget.fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]{2,4}$'), ''),
  );
  List<Map<String, dynamic>> _hits = const [];
  bool _searching = false;
  bool _binding = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_search);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _q.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final client = ref.read(libraryApiProvider).client;
      final movies = await client.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/search/titles',
        body: {'query': query, 'provider': 'tmdb', 'media_type': 'movie'},
      );
      final tvs = await client
          .unwrap<dynamic>(
            Channel.general,
            'POST',
            '/api/v1/search/titles',
            body: {'query': query, 'provider': 'tmdb', 'media_type': 'tv'},
          )
          .catchError((_) => const <dynamic>[]);
      List<Map<String, dynamic>> parse(dynamic raw) {
        final l = raw is List
            ? raw
            : (raw is Map
                ? (raw['titles'] ?? raw['items'] ?? const []) as List<dynamic>
                : const <dynamic>[]);
        return l.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }

      if (mounted) {
        setState(() {
          _hits = [...parse(movies), ...parse(tvs)];
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _bind(String titleRef) async {
    setState(() => _binding = true);
    try {
      await ref.read(libraryApiProvider).assignFileTitle(
            fileIds: [widget.fileId],
            titleRef: titleRef,
          );
      if (mounted) {
        McToast.success('已手动绑定词条并入库');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _binding = false);
        McToast.error('绑定失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.76,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('手动认领词条', style: McText.titleSm),
            const SizedBox(height: 4),
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.muted,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    style: McText.body,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '输入片名检索 TMDB…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                McGlassIconButton(
                  icon: McIcons.search,
                  onTap: _search,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _searching
                  ? const McLoadingView()
                  : _hits.isEmpty
                      ? const McEmptyView(text: '没有匹配的影视词条')
                      : ListView(
                          children: [
                            McInsetGroup(
                              margin: EdgeInsets.zero,
                              children: [
                                for (final h in _hits)
                                  Builder(
                                    builder: (context) {
                                      final refStr =
                                          (h['title_ref'] ?? '').toString();
                                      final title =
                                          (h['title'] ?? h['name'] ?? '')
                                              .toString();
                                      final year = h['release_year'] ?? h['year'];
                                      return McInsetRow(
                                        title: title,
                                        subtitle: [
                                          if (year != null) '$year',
                                          refStr,
                                        ].join(' · '),
                                        trailing: McChip(
                                          label: _binding ? '绑定中' : '认领',
                                          selected: true,
                                          compact: true,
                                          onTap: _binding || refStr.isEmpty
                                              ? null
                                              : () => _bind(refStr),
                                        ),
                                      );
                                    },
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
  }
}
