import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import 'library_shared.dart';

/// 弹出完整媒体库新建 / 编辑表单（对齐 iOS `ManageFormParts` + `ManageScrapeOverrides`）。
Future<bool?> showLibraryFormSheet(
  BuildContext context, {
  LibraryView? editing,
  List<LibraryView> existingLibraries = const [],
}) {
  return showMcSheet<bool>(
    context: context,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: LibraryFormSheet(
        editing: editing,
        existingLibraries: existingLibraries,
      ),
    ),
  );
}

/// 媒体库完整表单：
/// - 支持 4 种类型（movie / tv / video / photo）；
/// - 服务端目录浏览器 + 多根目录增删；
/// - 自定义封面上传（`image_picker` -> `POST /libraries/{id}/cover`）与恢复自动封面；
/// - 扫描/监听/自动清理缺失/缩略图/章节图/排除首页/自动系列开关 + 网络挂载提示；
/// - 收录范围（`match_rules`：地区预设 + 地区 + 类型）与同类型库路由重叠检测警告；
/// - 刮削设置覆盖（`ManageScrapeOverrides`：跟随全局 vs 库级覆盖 + 一键重置）；
/// - 成员可见范围（`everyone` vs `selected` + 超管可见开关 + 空可见警示）。
class LibraryFormSheet extends ConsumerStatefulWidget {
  const LibraryFormSheet({
    super.key,
    this.editing,
    this.existingLibraries = const [],
  });

  final LibraryView? editing;
  final List<LibraryView> existingLibraries;

  @override
  ConsumerState<LibraryFormSheet> createState() => _LibraryFormSheetState();
}

class _LibraryFormSheetState extends ConsumerState<LibraryFormSheet> {
  late final TextEditingController _nameCtrl;
  late String _kind;
  late List<String> _paths;
  late bool _isDefault;
  late bool _excludeFromHome;
  late bool _generateThumbnails;
  late bool _extractChapterImages;
  late bool _autoSeriesCollections;
  late bool _autoClearMissing;
  late bool _realtimeWatch;
  late String _accessMode;
  late bool _adminVisible;
  late Set<int> _memberIds;
  late bool _hasCustomCover;
  int _coverVersion = 0;

  // Match rules (regions + genres)
  final Set<String> _selectedRegions = {};
  final Set<int> _selectedGenres = {};
  RoutingOptionsView? _routingOptions;

  // Members
  List<MemberOptionView> _members = const [];

  // Scrape overrides
  late Map<String, dynamic> _scrapeOverrides;
  Map<String, dynamic>? _globalScrapeConfig;
  bool _showScrapeOverrides = false;

  bool _saving = false;
  bool _uploadingCover = false;

  bool get _isEdit => widget.editing != null;
  bool get _isScrapedKind => _kind == 'movie' || _kind == 'tv';

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _kind = e?.kind ?? 'movie';
    _paths = [...(e?.paths ?? const [])];
    _isDefault = e?.isDefault ?? false;
    _excludeFromHome = e?.excludeFromHome ?? false;
    _generateThumbnails = e?.generateThumbnails ?? true;
    _extractChapterImages = e?.extractChapterImages ?? false;
    _autoSeriesCollections = e?.autoSeriesCollections ?? true;
    _autoClearMissing = e?.autoClearMissing ?? false;
    _realtimeWatch = e?.realtimeWatch ?? true;
    _accessMode = e?.accessMode ?? 'everyone';
    _adminVisible = e?.adminVisible ?? true;
    _memberIds = {...(e?.memberIds ?? const [])};
    _hasCustomCover = e?.customCover ?? false;
    _scrapeOverrides = Map<String, dynamic>.from(e?.scrapeOverrides ?? const {});

    for (final rule in (e?.matchRules ?? const [])) {
      final field = rule['field']?.toString() ?? '';
      final values = (rule['values'] as List<dynamic>? ?? const []);
      if (field == 'origin_country' || field == 'origin_countries') {
        for (final v in values) {
          _selectedRegions.add(v.toString());
        }
      } else if (field == 'genre' || field == 'genres') {
        for (final v in values) {
          final id = int.tryParse(v.toString());
          if (id != null) _selectedGenres.add(id);
        }
      }
    }
    _loadAuxData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAuxData() async {
    final api = ref.read(libraryApiProvider);
    final results = await Future.wait([
      api.libraryRoutingOptions().catchError((_) => const RoutingOptionsView()),
      api.membersList().catchError((_) => <MemberOptionView>[]),
      api.scrapeConfig().catchError((_) => <String, dynamic>{}),
    ]);
    if (!mounted) return;
    setState(() {
      _routingOptions = results[0] as RoutingOptionsView;
      _members = results[1] as List<MemberOptionView>;
      _globalScrapeConfig = results[2] as Map<String, dynamic>;
    });
  }

  List<Map<String, dynamic>> _buildMatchRules() => [
        if (_selectedRegions.isNotEmpty)
          {
            'field': 'origin_country',
            'op': 'any_of',
            'values': _selectedRegions.toList()..sort(),
          },
        if (_selectedGenres.isNotEmpty)
          {
            'field': 'genre',
            'op': 'any_of',
            'values': _selectedGenres.toList()..sort(),
          },
      ];

  /// 与同类型已有库检测收录范围重叠，给出友好警示。
  List<String> _overlapWarnings() {
    if (!_isScrapedKind) return const [];
    final myRules = _buildMatchRules();
    if (myRules.isEmpty) return const [];
    final warnings = <String>[];
    for (final other in widget.existingLibraries) {
      if (other.id == widget.editing?.id || other.kind != _kind) continue;
      if (other.matchRules.isEmpty) continue;
      final otherRegions = <String>{};
      final otherGenres = <int>{};
      for (final r in other.matchRules) {
        final f = r['field']?.toString() ?? '';
        final vs = (r['values'] as List<dynamic>? ?? const []);
        if (f == 'origin_country' || f == 'origin_countries') {
          otherRegions.addAll(vs.map((e) => e.toString()));
        } else if (f == 'genre' || f == 'genres') {
          for (final v in vs) {
            final id = int.tryParse(v.toString());
            if (id != null) otherGenres.add(id);
          }
        }
      }
      final regionHit = _selectedRegions.isEmpty ||
          otherRegions.isEmpty ||
          _selectedRegions.intersection(otherRegions).isNotEmpty;
      final genreHit = _selectedGenres.isEmpty ||
          otherGenres.isEmpty ||
          _selectedGenres.intersection(otherGenres).isNotEmpty;
      if (regionHit && genreHit) {
        warnings.add('与「${other.name}」的收录范围存在重叠，订阅入库路由可能会同时命中。');
      }
    }
    return warnings;
  }

  Future<void> _pickServerDir() async {
    final picked = await showMcSheet<String>(
      context: context,
      builder: (_) => const _ServerDirBrowserSheet(),
    );
    if (picked != null && picked.isNotEmpty && !_paths.contains(picked)) {
      setState(() => _paths.add(picked));
    }
  }

  Future<void> _addManualPath() async {
    final ctrl = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        title: const Text('手动输入目录路径'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '/media/movies'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (path != null && path.isNotEmpty && !_paths.contains(path)) {
      setState(() => _paths.add(path));
    }
  }

  Future<void> _uploadCover() async {
    final id = widget.editing?.id;
    if (id == null || _uploadingCover) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingCover = true);
    try {
      await ref.read(libraryApiProvider).uploadLibraryCover(id, picked.path);
      if (!mounted) return;
      setState(() {
        _uploadingCover = false;
        _hasCustomCover = true;
        _coverVersion = DateTime.now().millisecondsSinceEpoch;
      });
      McToast.success('自定义封面已上传');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingCover = false);
      McToast.error('上传封面失败：$e');
    }
  }

  Future<void> _deleteCover() async {
    final id = widget.editing?.id;
    if (id == null || _uploadingCover) return;
    setState(() => _uploadingCover = true);
    try {
      await ref.read(libraryApiProvider).deleteLibraryCover(id);
      if (!mounted) return;
      setState(() {
        _uploadingCover = false;
        _hasCustomCover = false;
        _coverVersion = DateTime.now().millisecondsSinceEpoch;
      });
      McToast.success('已恢复自动封面');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingCover = false);
      McToast.error('恢复失败：$e');
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      McToast.error('请输入媒体库名称');
      return;
    }
    if (_paths.isEmpty) {
      McToast.error('请至少添加一个目录路径');
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(libraryApiProvider);
    try {
      if (_isEdit) {
        await api.updateLibrary(
          widget.editing!.id,
          name: name,
          paths: _paths,
          isDefault: _isDefault,
          excludeFromHome: _excludeFromHome,
          generateThumbnails: _generateThumbnails,
          extractChapterImages: _extractChapterImages,
          autoSeriesCollections: _autoSeriesCollections,
          autoClearMissing: _autoClearMissing,
          realtimeWatch: _realtimeWatch,
          accessMode: _accessMode,
          adminVisible: _adminVisible,
          memberIds: _accessMode == 'selected' ? _memberIds.toList() : const [],
          matchRules: _isScrapedKind ? _buildMatchRules() : const [],
          scrapeOverrides: _isScrapedKind ? _scrapeOverrides : const {},
        );
        if (mounted) {
          McToast.success('媒体库已更新');
          Navigator.of(context).pop(true);
        }
      } else {
        await api.createLibrary(
          name: name,
          kind: _kind,
          paths: _paths,
          isDefault: _isDefault,
          excludeFromHome: _excludeFromHome,
          generateThumbnails: _generateThumbnails,
          extractChapterImages: _extractChapterImages,
          autoSeriesCollections: _autoSeriesCollections,
          autoClearMissing: _autoClearMissing,
          realtimeWatch: _realtimeWatch,
          accessMode: _accessMode,
          adminVisible: _adminVisible,
          memberIds: _accessMode == 'selected' ? _memberIds.toList() : const [],
          matchRules: _isScrapedKind ? _buildMatchRules() : const [],
          scrapeOverrides: _isScrapedKind ? _scrapeOverrides : const {},
        );
        if (mounted) {
          McToast.success('已创建媒体库「$name」');
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      McToast.error('保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlaps = _overlapWarnings();
    final noVisibleMember =
        _accessMode == 'selected' && !_adminVisible && _memberIds.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEdit ? '编辑媒体库' : '新建媒体库',
                  style: McText.titleSm,
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 4),
              McActionPill(
                label: _saving ? '保存中…' : '保存',
                primary: true,
                height: 34,
                onTap: _saving ? null : _submit,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: McTokens.line),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            children: [
              // 名称与类型
              const Text('基本信息', style: McText.titleSm),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: McText.body,
                decoration: const InputDecoration(
                  labelText: '媒体库名称',
                  hintText: '例如：4K 电影、日漫番剧、家庭相册',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isEdit ? '媒体库类型（创建后不可更改）' : '媒体库类型',
                style: McText.caption.muted,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (k, label) in const [
                    ('movie', '电影'),
                    ('tv', '剧集'),
                    ('video', '其他视频'),
                    ('photo', '照片'),
                  ])
                    McChip(
                      label: label,
                      icon: libraryKindIcon(k),
                      compact: true,
                      selected: _kind == k,
                      onTap: _isEdit ? null : () => setState(() => _kind = k),
                    ),
                ],
              ),

              // 编辑模式自定义封面
              if (_isEdit) ...[
                const SizedBox(height: 18),
                const Text('自定义封面', style: McText.titleSm),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 112,
                        height: 63,
                        child: LibraryNetImage(
                          url:
                              '/libraries/${widget.editing!.id}/cover${_coverVersion > 0 ? '?v=$_coverVersion' : ''}',
                          widthPx: 360,
                          placeholderIcon: libraryKindIcon(_kind),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          McActionPill(
                            label: _uploadingCover ? '处理中…' : '上传封面',
                            icon: McIcons.imageAdd,
                            height: 34,
                            onTap: _uploadingCover ? null : _uploadCover,
                          ),
                          if (_hasCustomCover)
                            McActionPill(
                              label: '恢复自动封面',
                              height: 34,
                              onTap: _uploadingCover ? null : _deleteCover,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              // 文件夹路径
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Text('目录路径', style: McText.titleSm)),
                  TextButton.icon(
                    onPressed: _pickServerDir,
                    icon: const Icon(McIcons.folderOpen, size: 16),
                    label: const Text('浏览服务器'),
                  ),
                  TextButton(
                    onPressed: _addManualPath,
                    child: const Text('手填'),
                  ),
                ],
              ),
              if (_paths.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: McTokens.surfaceInset,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Text('暂未添加目录，请点击右上角浏览服务器文件夹。',
                      style: McText.caption.muted),
                )
              else
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < _paths.length; i++)
                      ListTile(
                        dense: true,
                        title: Text(
                          _paths[i],
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: McTokens.text,
                          ),
                        ),
                        subtitle: i == 0 && _paths.length > 1
                            ? const Text(
                                '主目录（订阅新片优先落盘于此）',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: McTokens.accent,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i > 0)
                              IconButton(
                                tooltip: '设为主目录',
                                icon: const Icon(
                                  Icons.vertical_align_top_rounded,
                                  size: 18,
                                  color: McTokens.textMuted,
                                ),
                                onPressed: () => setState(() {
                                  final p = _paths.removeAt(i);
                                  _paths.insert(0, p);
                                }),
                              ),
                            IconButton(
                              tooltip: '移除路径',
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: McTokens.danger,
                              ),
                              onPressed: () => setState(() => _paths.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (widget.editing?.networkMount == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: McTokens.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '检测到网络挂载目录（SMB/NFS/WebDAV）：部分网络文件系统不支持实时 inotify 变更事件，建议开启定时扫描。',
                    style: TextStyle(fontSize: 12, color: McTokens.warning),
                  ),
                ),
              ],

              // 行为开关
              const SizedBox(height: 18),
              const Text('扫描与行为', style: McText.titleSm),
              const SizedBox(height: 8),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  SwitchListTile(
                    dense: true,
                    value: _realtimeWatch,
                    onChanged: (v) => setState(() => _realtimeWatch = v),
                    title: const Text('实时监听目录变动'),
                    subtitle: const Text('新增或删除文件时自动触发增量入库'),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: _autoClearMissing,
                    onChanged: (v) => setState(() => _autoClearMissing = v),
                    title: const Text('自动清理缺失文件记录'),
                    subtitle: const Text('扫描发现文件已移除时直接清理，不留在待处理中'),
                  ),
                  SwitchListTile(
                    dense: true,
                    value: !_excludeFromHome,
                    onChanged: (v) => setState(() => _excludeFromHome = !v),
                    title: const Text('在媒体库首页展示'),
                    subtitle: const Text('关闭后此库不会混入首页默认行与全部跨库墙'),
                  ),
                  if (_kind != 'photo') ...[
                    SwitchListTile(
                      dense: true,
                      value: _generateThumbnails,
                      onChanged: (v) => setState(() => _generateThumbnails = v),
                      title: const Text('生成进度条预览缩略图'),
                    ),
                    SwitchListTile(
                      dense: true,
                      value: _extractChapterImages,
                      onChanged: (v) =>
                          setState(() => _extractChapterImages = v),
                      title: const Text('提取章节关键帧图'),
                      subtitle: const Text('用于详情页章节条与图床浏览'),
                    ),
                  ],
                  if (_kind == 'movie')
                    SwitchListTile(
                      dense: true,
                      value: _autoSeriesCollections,
                      onChanged: (v) =>
                          setState(() => _autoSeriesCollections = v),
                      title: const Text('自动生成电影系列合集'),
                    ),
                  if (_isScrapedKind)
                    SwitchListTile(
                      dense: true,
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      title: const Text('设为该类型默认入库库'),
                      subtitle: const Text('订阅未命中特定范围规则时自动落盘至此库'),
                    ),
                ],
              ),

              // 收录范围（仅 movie / tv）
              if (_isScrapedKind && _routingOptions != null) ...[
                const SizedBox(height: 18),
                const Text('订阅入库收录范围（可选）', style: McText.titleSm),
                const SizedBox(height: 4),
                Text(
                  '限定地区或类型后，订阅下载的影片会自动路由到最匹配的库（留空表示不限）。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 8),
                if (_routingOptions!.regionPresets.isNotEmpty) ...[
                  Text('快捷地区组合', style: McText.caption.faint),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in _routingOptions!.regionPresets)
                        McChip(
                          label: p.label,
                          compact: true,
                          selected: p.countries.isNotEmpty &&
                              p.countries.every(_selectedRegions.contains),
                          onTap: () => setState(() {
                            if (p.countries.every(_selectedRegions.contains)) {
                              _selectedRegions.removeAll(p.countries);
                            } else {
                              _selectedRegions.addAll(p.countries);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_routingOptions!.genresFor(_kind).isNotEmpty) ...[
                  Text('题材类型', style: McText.caption.faint),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final g in _routingOptions!.genresFor(_kind))
                        McChip(
                          label: g.label,
                          compact: true,
                          selected: _selectedGenres.contains(g.id),
                          onTap: () => setState(() {
                            if (!_selectedGenres.remove(g.id)) {
                              _selectedGenres.add(g.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                if (overlaps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: McTokens.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
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
                ],
              ],

              // 刮削设置覆盖（ManageScrapeOverrides）
              if (_isScrapedKind) ...[
                const SizedBox(height: 18),
                InkWell(
                  onTap: () => setState(
                    () => _showScrapeOverrides = !_showScrapeOverrides,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('刮削设置覆盖', style: McText.titleSm),
                        ),
                        if (_scrapeOverrides.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: McTokens.accentSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '已覆盖 ${_scrapeOverrides.length} 项',
                              style: const TextStyle(
                                fontSize: 11,
                                color: McTokens.accent,
                              ),
                            ),
                          ),
                        Icon(
                          _showScrapeOverrides
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: McTokens.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showScrapeOverrides)
                  _ScrapeOverridesEditor(
                    overrides: _scrapeOverrides,
                    globalConfig: _globalScrapeConfig,
                    onChanged: (next) =>
                        setState(() => _scrapeOverrides = next),
                  ),
              ],

              // 成员可见范围
              const SizedBox(height: 18),
              const Text('成员可见范围', style: McText.titleSm),
              const SizedBox(height: 8),
              Row(
                children: [
                  McChip(
                    label: '所有成员可见',
                    icon: McIcons.team,
                    compact: true,
                    selected: _accessMode == 'everyone',
                    onTap: () => setState(() => _accessMode = 'everyone'),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: '仅指定成员可见',
                    icon: McIcons.lock,
                    compact: true,
                    selected: _accessMode == 'selected',
                    onTap: () => setState(() => _accessMode = 'selected'),
                  ),
                ],
              ),
              if (_accessMode == 'selected') ...[
                const SizedBox(height: 10),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    CheckboxListTile(
                      dense: true,
                      value: _adminVisible,
                      onChanged: (v) =>
                          setState(() => _adminVisible = v == true),
                      title: const Text('超级管理员（我自己）'),
                      subtitle: const Text('取消勾选后自己也会在浏览视图中隐藏此库'),
                    ),
                    for (final m in _members.where((m) => m.role != 'admin'))
                      CheckboxListTile(
                        dense: true,
                        value: _memberIds.contains(m.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _memberIds.add(m.id);
                          } else {
                            _memberIds.remove(m.id);
                          }
                        }),
                        title: Text(m.displayName),
                        subtitle: Text('@${m.username}'),
                      ),
                  ],
                ),
                if (noVisibleMember) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: McTokens.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '当前没有任何成员（含超管）可见此库，保存后只能通过管理中心访问。',
                      style: TextStyle(fontSize: 12, color: McTokens.warning),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/* ── 刮削覆盖编辑器（对齐 ManageScrapeOverrides.swift） ── */

class _ScrapeOverridesEditor extends StatelessWidget {
  const _ScrapeOverridesEditor({
    required this.overrides,
    required this.globalConfig,
    required this.onChanged,
  });

  final Map<String, dynamic> overrides;
  final Map<String, dynamic>? globalConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;

  static const _commonLangs = <(String, String)>[
    ('zh-CN', '简体中文'),
    ('zh-TW', '繁体中文'),
    ('zh-HK', '香港中文'),
    ('en-US', '英语'),
    ('ja-JP', '日语'),
    ('ko-KR', '韩语'),
  ];

  static const _commonCerts = <(String, String)>[
    ('CN', '中国大陆'),
    ('HK', '香港'),
    ('TW', '台湾'),
    ('US', '美国'),
    ('JP', '日本'),
    ('GB', '英国'),
  ];

  static const _namingFields = <(String, String, String)>[
    ('naming_entry_dir', '作品目录模板', '{title} ({year})'),
    ('naming_movie_file', '电影文件模板', '{title} ({year})'),
    ('naming_season_dir', '季目录模板', 'Season {season:02d}'),
    ('naming_episode_file', '剧集文件模板', '{title} ({year}) - S{season:02d}E{episode:02d}'),
  ];

  static const _mirrorFields = <(String, String)>[
    ('mirror_images', '向媒体目录写入海报/背景图'),
    ('mirror_nfo', '向媒体目录写入 NFO 元数据'),
    ('mirror_episode_thumbs', '向媒体目录写入分集剧照'),
  ];

  Map<String, dynamic> get _globalSetting {
    final s = globalConfig?['setting'];
    return s is Map ? Map<String, dynamic>.from(s) : const {};
  }

  void _setKey(String key, dynamic val) {
    final next = Map<String, dynamic>.from(overrides);
    if (val == null) {
      next.remove(key);
    } else {
      next[key] = val;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final global = _globalSetting;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '仅保存本库显式修改的字段，其余全部跟随全局刮削设置。',
                  style: TextStyle(fontSize: 12, color: McTokens.textMuted),
                ),
              ),
              if (overrides.isNotEmpty)
                TextButton(
                  onPressed: () => onChanged(const {}),
                  child: const Text('一键重置'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _multiChoiceCard(
            title: '元数据语言优先序',
            keyName: 'language_priority',
            options: _commonLangs,
            globalDefault: (global['language_priority'] as List<dynamic>? ??
                    const ['zh-CN', 'en-US'])
                .map((e) => e.toString())
                .toList(),
          ),
          const SizedBox(height: 10),
          _multiChoiceCard(
            title: '分级国家优先序',
            keyName: 'cert_country_priority',
            options: _commonCerts,
            globalDefault: (global['cert_country_priority'] as List<dynamic>? ??
                    const ['CN', 'US'])
                .map((e) => e.toString())
                .toList(),
          ),
          const SizedBox(height: 10),
          _multiChoiceCard(
            title: '海报图语言优先序',
            keyName: 'poster_language_priority',
            options: _commonLangs,
            globalDefault:
                (global['poster_language_priority'] as List<dynamic>? ??
                        const ['zh-CN', 'en-US'])
                    .map((e) => e.toString())
                    .toList(),
          ),
          const SizedBox(height: 10),
          _multiChoiceCard(
            title: '背景图语言优先序',
            keyName: 'backdrop_language_priority',
            options: _commonLangs,
            globalDefault:
                (global['backdrop_language_priority'] as List<dynamic>? ??
                        const ['zh-CN', 'en-US'])
                    .map((e) => e.toString())
                    .toList(),
          ),
          const SizedBox(height: 12),
          const Text('命名模板（留空跟随全局）', style: McText.caption),
          const SizedBox(height: 6),
          for (final (k, label, fallback) in _namingFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                initialValue: overrides[k]?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: McTokens.text,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: label,
                  hintText:
                      '跟随全局：${(global[k]?.toString().isNotEmpty == true) ? global[k] : fallback}',
                ),
                onChanged: (v) =>
                    _setKey(k, v.trim().isEmpty ? null : v.trim()),
              ),
            ),
          const SizedBox(height: 6),
          const Text('媒体目录本地写入（三态）', style: McText.caption),
          const SizedBox(height: 6),
          for (final (k, label) in _mirrorFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: McText.caption.muted),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final (val, text) in <(bool?, String)>[
                        (
                          null,
                          '跟随全局(${global[k] == false ? '关' : '开'})',
                        ),
                        (true, '开'),
                        (false, '关'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: McChip(
                            label: text,
                            compact: true,
                            selected: overrides[k] == val,
                            onTap: () => _setKey(k, val),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _multiChoiceCard({
    required String title,
    required String keyName,
    required List<(String, String)> options,
    required List<String> globalDefault,
  }) {
    final isCustom = overrides.containsKey(keyName);
    final current = isCustom
        ? (overrides[keyName] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList()
        : globalDefault;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$title（${isCustom ? '自定义' : '跟随全局'}）',
                style: McText.caption.copyWith(
                  color: isCustom ? McTokens.accent : McTokens.textMuted,
                ),
              ),
            ),
            McChip(
              label: isCustom ? '切回跟随全局' : '自定义',
              compact: true,
              selected: isCustom,
              onTap: () {
                if (isCustom) {
                  _setKey(keyName, null);
                } else {
                  _setKey(keyName, [...globalDefault]);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: isCustom ? 1 : 0.45,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (code, label) in options)
                McChip(
                  label: current.contains(code)
                      ? '${current.indexOf(code) + 1}. $label'
                      : label,
                  compact: true,
                  selected: current.contains(code),
                  onTap: !isCustom
                      ? null
                      : () {
                          final next = [...current];
                          if (!next.remove(code)) next.add(code);
                          _setKey(keyName, next);
                        },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ── 服务端文件夹浏览器 ── */

class _ServerDirBrowserSheet extends ConsumerStatefulWidget {
  const _ServerDirBrowserSheet();

  @override
  ConsumerState<_ServerDirBrowserSheet> createState() =>
      _ServerDirBrowserSheetState();
}

class _ServerDirBrowserSheetState
    extends ConsumerState<_ServerDirBrowserSheet> {
  String? _current;
  String? _parent;
  List<Map<String, dynamic>> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _browse(null);
  }

  Future<void> _browse(String? path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(libraryApiProvider).browseServerFs(path: path);
      if (!mounted) return;
      final list = (res['entries'] ?? res['dirs'] ?? const []) as List<dynamic>;
      setState(() {
        _loading = false;
        _current = res['current']?.toString() ?? path ?? '/';
        _parent = res['parent']?.toString();
        _entries = list
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .where((e) => e['is_dir'] != false)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
            child: Row(
              children: [
                if (_parent != null && _parent!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    tooltip: '上一级目录',
                    onPressed: () => _browse(_parent),
                  ),
                Expanded(
                  child: Text(
                    _current ?? '/',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: McTokens.text,
                    ),
                  ),
                ),
                McActionPill(
                  label: '选择此目录',
                  primary: true,
                  height: 32,
                  onTap: _current == null
                      ? null
                      : () => Navigator.of(context).pop(_current),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: _loading
                ? const McLoadingView()
                : _error != null
                    ? McErrorView(
                        text: _error!,
                        onRetry: () => _browse(_current),
                      )
                    : _entries.isEmpty
                        ? const McEmptyView(text: '此目录下没有子文件夹')
                        : ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (_, i) {
                              final e = _entries[i];
                              final name = e['name']?.toString() ?? '';
                              final path = e['path']?.toString() ?? '';
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  McIcons.folderOpen,
                                  size: 18,
                                  color: McTokens.accent,
                                ),
                                title: Text(name, style: McText.body),
                                trailing: const Icon(
                                  McIcons.chevronRight,
                                  size: 16,
                                  color: McTokens.textFaint,
                                ),
                                onTap: () => _browse(path),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
