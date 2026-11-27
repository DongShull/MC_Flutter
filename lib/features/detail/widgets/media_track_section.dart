import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/llm_capability_probe.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/permissions.dart';
import '../state/detail_controller.dart';
import 'detail_admin_sheets.dart';

/// 详情页多版本选择器 + 交互式音轨 / 字幕行（1:1 对齐 iOS `MediaTrackSection.swift` & `TrackSubtitlePreview.swift`）。
class MediaTrackSection extends ConsumerStatefulWidget {
  const MediaTrackSection({
    super.key,
    required this.files,
    required this.selectedFileId,
    required this.onSelectFile,
    required this.controller,
  });

  final List<DetailFileInfo> files;
  final int? selectedFileId;
  final ValueChanged<int> onSelectFile;
  final DetailController controller;

  @override
  ConsumerState<MediaTrackSection> createState() => _MediaTrackSectionState();
}

class _MediaTrackSectionState extends ConsumerState<MediaTrackSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final client = ref.read(mcClientProvider);
      unawaited(ref.read(llmCapabilityProbeProvider).ensure(client));
    });
  }

  List<DetailFileInfo> get _availableFiles =>
      widget.files.where((f) => f.state == 'in_place').toList();

  DetailFileInfo? get _selectedFile {
    final avail = _availableFiles;
    if (avail.isEmpty) return null;
    if (widget.selectedFileId != null) {
      for (final f in avail) {
        if (f.id == widget.selectedFileId) return f;
      }
    }
    return avail.first;
  }

  void _openTrackList({
    required _TrackKind kind,
    required String focusLanguage,
    required DetailFileInfo file,
    required bool canManage,
  }) {
    showMcSheet<void>(
      context: context,
      maxWidth: 620,
      builder: (_) => _TrackListSheet(
        kind: kind,
        focusLanguage: focusLanguage,
        initialFile: file,
        canManage: canManage,
        controller: widget.controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avail = _availableFiles;
    final file = _selectedFile;
    if (file == null) return const SizedBox.shrink();

    final perms = ref.watch(permissionsProvider);
    final probe = ref.watch(llmCapabilityProbeProvider);
    final defaults = file.playbackDefaults;
    final audioGroups = _TrackModel.groupByLanguage(
      _TrackModel.audioEntries(file.audioStreams ?? const [], defaults: defaults),
    );
    final subtitleGroups = _TrackModel.groupByLanguage(
      _TrackModel.subtitleEntries(
        file.subtitleStreams,
        videoStem: _TrackModel.videoStem(file.fileName),
        defaults: defaults,
      ),
    );
    final audioSpec = _TrackModel.topAudioSpec(file.audioStreams ?? const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avail.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < avail.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  McChip(
                    label: avail[i].displayVersionLabel,
                    compact: true,
                    selected: avail[i].id == file.id,
                    onTap: () => widget.onSelectFile(avail[i].id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        _TrackSummaryRow(
          label: '音轨',
          groups: audioGroups,
          emptyText: file.audioStreams == null ? '未探测' : '无音轨',
          marksDefault: defaults != null,
          onOpen: (lang) => _openTrackList(
            kind: _TrackKind.audio,
            focusLanguage: lang,
            file: file,
            canManage: perms.canManageLibraries,
          ),
          trailing: audioSpec == null
              ? null
              : Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0x24FFFFFF)),
                  ),
                  child: Text(
                    audioSpec,
                    style: McText.caption
                        .copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w600,
                        )
                        .tabular,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _TrackSummaryRow(
          label: '字幕',
          groups: subtitleGroups,
          emptyText: '无字幕',
          marksDefault: defaults != null,
          onOpen: (lang) => _openTrackList(
            kind: _TrackKind.subtitle,
            focusLanguage: lang,
            file: file,
            canManage: perms.canManageLibraries,
          ),
          trailing: perms.isAdmin && !file.missing
              ? ListenableBuilder(
                  listenable: probe,
                  builder: (context, _) {
                    if (probe.state == LlmCapabilityState.checking) {
                      return const SizedBox.shrink();
                    }
                    if (probe.state == LlmCapabilityState.missing) {
                      return McPressable(
                        onTap: () => context.push('/settings/ai?section=llm'),
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: McTokens.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: McTokens.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '接入模型解锁 AI 字幕 ',
                                style: McText.micro.copyWith(
                                  color: McTokens.warning,
                                ),
                              ),
                              Text(
                                '去接入',
                                style: McText.micro.copyWith(
                                  color: McTokens.accentStrong,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return McPressable(
                      onTap: () => showSubtitleGenSheet(
                        context: context,
                        controller: widget.controller,
                        fileId: file.id,
                        file: file,
                      ),
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              McIcons.aiStarFill,
                              size: 13,
                              color: McTokens.accentStrong,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'AI 生成字幕',
                              style: McText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      ],
    );
  }
}

class _TrackSummaryRow extends StatelessWidget {
  const _TrackSummaryRow({
    required this.label,
    required this.groups,
    required this.emptyText,
    required this.marksDefault,
    required this.onOpen,
    this.trailing,
  });

  final String label;
  final List<_TrackLanguageGroup> groups;
  final String emptyText;
  final bool marksDefault;
  final ValueChanged<String> onOpen;
  final Widget? trailing;

  static const int _maxChips = 2;

  @override
  Widget build(BuildContext context) {
    final shown = groups.take(_maxChips).toList();
    final hiddenCount = groups.length - shown.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SizedBox(
            width: 44,
            child: Text(label, style: McText.caption.faint),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (groups.isEmpty)
                Container(
                  height: 30,
                  alignment: Alignment.centerLeft,
                  child: Text(emptyText, style: McText.caption.muted),
                )
              else ...[
                for (final g in shown)
                  _langChip(
                    group: g,
                    playing: marksDefault && g.hasDefault,
                    onTap: () => onOpen(g.language),
                  ),
                if (hiddenCount > 0)
                  McPressable(
                    onTap: () => onOpen(groups[_maxChips].language),
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x0BFFFFFF),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0x10FFFFFF)),
                      ),
                      child: Text(
                        '+$hiddenCount 种',
                        style: McText.caption.muted.tabular,
                      ),
                    ),
                  ),
              ],
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }

  Widget _langChip({
    required _TrackLanguageGroup group,
    required bool playing,
    required VoidCallback onTap,
  }) {
    return McPressable(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0x10FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playing) ...[
              const Icon(
                McIcons.play2Fill,
                size: 10,
                color: McTokens.accentStrong,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              group.language,
              style: McText.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              group.entries.length == 1
                  ? group.entries.first.format
                  : '×${group.entries.length}',
              style: McText.micro
                  .copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  )
                  .tabular,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 完整轨道列表弹层（内嵌切换至字幕预览页，对齐 iOS NavigationStack 弹层内推进） ──

class _TrackListSheet extends ConsumerStatefulWidget {
  const _TrackListSheet({
    required this.kind,
    required this.focusLanguage,
    required this.initialFile,
    required this.canManage,
    required this.controller,
  });

  final _TrackKind kind;
  final String focusLanguage;
  final DetailFileInfo initialFile;
  final bool canManage;
  final DetailController controller;

  @override
  ConsumerState<_TrackListSheet> createState() => _TrackListSheetState();
}

class _TrackListSheetState extends ConsumerState<_TrackListSheet> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _groupKeys = {};
  _TrackPreviewInfo? _activePreview;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _groupKeys[widget.focusLanguage];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 260),
          alignment: 0.08,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DetailFileInfo _resolveFile() {
    final key = '${widget.controller.libraryId}:${widget.controller.itemId}';
    final st = ref.watch(detailControllerProvider(key));
    for (final f in st.currentUnitFiles) {
      if (f.id == widget.initialFile.id) return f;
    }
    return widget.initialFile;
  }

  Future<void> _confirmDelete(_TrackEntry entry, DetailFileInfo file) async {
    final filename = entry.deletable;
    if (filename == null || _deleting) return;
    final fullPath = _TrackModel.siblingPath(file.filePath, filename);
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('删除这条外挂字幕？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '将直接从磁盘移除以下文件，不进回收站且无法撤销：',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: McTokens.line),
              ),
              child: SelectableText(
                fullPath,
                style: McText.micro.copyWith(
                  fontFamily: 'monospace',
                  color: McTokens.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 18),
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
                    label: '删除字幕',
                    icon: McIcons.trash2,
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
    setState(() => _deleting = true);
    final err = await widget.controller.deleteExternalSubtitle(file.id, filename);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (err != null) {
      McToast.error(err);
    } else {
      McToast.success('已删除 $filename');
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _resolveFile();
    if (_activePreview != null) {
      return _TrackSubtitlePreviewBody(
        file: file,
        preview: _activePreview!,
        controller: widget.controller,
        onBack: () => setState(() => _activePreview = null),
      );
    }

    final defaults = file.playbackDefaults;
    final groups = widget.kind == _TrackKind.audio
        ? _TrackModel.groupByLanguage(
            _TrackModel.audioEntries(
              file.audioStreams ?? const [],
              defaults: defaults,
            ),
          )
        : _TrackModel.groupByLanguage(
            _TrackModel.subtitleEntries(
              file.subtitleStreams,
              videoStem: _TrackModel.videoStem(file.fileName),
              defaults: defaults,
            ),
          );
    final allEntries = [for (final g in groups) ...g.entries];
    final extCount = allEntries.where((e) => e.external == true).length;
    final subtitleSummary = widget.kind == _TrackKind.subtitle
        ? '共 ${allEntries.length} 条 · 内封 ${allEntries.length - extCount} / 外挂 $extCount'
        : '共 ${allEntries.length} 条音轨';
    final defaultNote = defaults == null
        ? null
        : _TrackModel.defaultNote(defaults, widget.kind);
    final footerHint = widget.kind == _TrackKind.subtitle
        ? (widget.canManage
            ? '点击任意字幕可预览对白与校准时间轴；外挂字幕支持左滑或点垃圾桶删除。'
            : '点击任意字幕可预览对白时间轴。')
        : null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.kind == _TrackKind.audio ? '音轨规格' : '字幕轨道',
                          style: McText.titleSm,
                        ),
                        const SizedBox(height: 2),
                        Text(subtitleSummary, style: McText.caption.faint),
                      ],
                    ),
                  ),
                  McGlassIconButton(
                    icon: McIcons.close,
                    iconSize: 16,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                controller: _scroll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            widget.kind == _TrackKind.audio
                                ? '暂无音轨信息'
                                : '暂无字幕轨道',
                            style: McText.sub.muted,
                          ),
                        ),
                      ),
                    for (var gi = 0; gi < groups.length; gi++) ...[
                      if (gi > 0) const SizedBox(height: 14),
                      Builder(
                        builder: (context) {
                          final g = groups[gi];
                          final isFocus = g.language == widget.focusLanguage;
                          final groupKey = _groupKeys.putIfAbsent(
                            g.language,
                            GlobalKey.new,
                          );
                          final notes = <String>[
                            if (gi == 0 && defaultNote != null) defaultNote,
                            if (gi == groups.length - 1 && footerHint != null)
                              footerHint,
                          ];
                          return Column(
                            key: groupKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                                child: Row(
                                  children: [
                                    Text(
                                      g.language,
                                      style: McText.caption.copyWith(
                                        color: isFocus
                                            ? McTokens.accentStrong
                                            : McTokens.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '· ${g.entries.length}',
                                      style: McText.caption.faint.tabular,
                                    ),
                                  ],
                                ),
                              ),
                              McInsetGroup(
                                margin: EdgeInsets.zero,
                                dividerIndent: 16,
                                footer:
                                    notes.isEmpty ? null : notes.join('\n'),
                                children: [
                                  for (final entry in g.entries)
                                    _buildTrackRow(entry, file),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackRow(_TrackEntry entry, DetailFileInfo file) {
    final canPreview =
        widget.kind == _TrackKind.subtitle && entry.preview != null;
    final canDelete = widget.canManage && entry.deletable != null;

    Widget rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: entry.tone.background,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              entry.format,
              style: McText.micro.copyWith(
                color: entry.tone.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.primary,
                  maxLines: widget.kind == _TrackKind.subtitle ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(color: McTokens.text),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(entry.secondary, style: McText.caption.muted),
                    for (final flag in entry.flags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          flag,
                          style: McText.micro.copyWith(
                            color: flag == '默认'
                                ? McTokens.accentStrong
                                : McTokens.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canDelete) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: '删除外挂字幕',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                McIcons.trash2,
                size: 16,
                color: McTokens.textFaint,
              ),
              onPressed: () => _confirmDelete(entry, file),
            ),
          ],
          if (canPreview)
            const Icon(
              McIcons.chevronRight,
              size: 16,
              color: McTokens.textFaint,
            ),
        ],
      ),
    );

    if (canPreview) {
      rowContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _activePreview = entry.preview),
          child: rowContent,
        ),
      );
    }

    if (canDelete) {
      rowContent = Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await _confirmDelete(entry, file);
          return false;
        },
        background: Container(
          color: McTokens.danger.withValues(alpha: 0.22),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          child: const Icon(McIcons.trash2, color: McTokens.danger, size: 18),
        ),
        child: rowContent,
      );
    }

    return rowContent;
  }
}

// ── 字幕预览与音频对齐校准页（1:1 对齐 iOS `TrackSubtitlePreview.swift`） ──

class _TrackSubtitlePreviewBody extends ConsumerStatefulWidget {
  const _TrackSubtitlePreviewBody({
    required this.file,
    required this.preview,
    required this.controller,
    required this.onBack,
  });

  final DetailFileInfo file;
  final _TrackPreviewInfo preview;
  final DetailController controller;
  final VoidCallback onBack;

  @override
  ConsumerState<_TrackSubtitlePreviewBody> createState() =>
      _TrackSubtitlePreviewBodyState();
}

class _TrackSubtitlePreviewBodyState
    extends ConsumerState<_TrackSubtitlePreviewBody> {
  Map<String, dynamic>? _data;
  String? _pendingMessage;
  String? _error;
  bool _calibrating = false;
  String? _calibrationNotice;
  bool _calibrationOk = false;
  Timer? _retryTimer;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _retryTimer?.cancel();
    final seq = ++_loadSeq;
    setState(() {
      _data = null;
      _error = null;
      _pendingMessage = null;
    });

    try {
      final res = await widget.controller.fetchSubtitlePreview(
        widget.file.id,
        widget.preview.track,
      );
      if (!mounted || seq != _loadSeq) return;
      final pending = J.s(res, ['pending']);
      if (pending != null && pending.isNotEmpty) {
        final retryMs = (J.i(res, ['retry_after_ms']) ?? 2000).clamp(1000, 15000);
        setState(() => _pendingMessage = pending);
        _retryTimer = Timer(Duration(milliseconds: retryMs), _load);
        return;
      }
      setState(() {
        _pendingMessage = null;
        _data = res;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _pendingMessage = null;
        _error = e.friendlyMessage;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _pendingMessage = null;
        _error = '读取字幕失败：$e';
      });
    }
  }

  Future<void> _calibrate() async {
    final filename = widget.preview.stream.fileName;
    if (!widget.preview.stream.external || filename == null || _calibrating) {
      return;
    }
    setState(() {
      _calibrating = true;
      _calibrationNotice = null;
    });
    try {
      final res = await widget.controller.calibrateSubtitle(
        widget.file.id,
        filename,
      );
      if (!mounted) return;
      final ok = res['ok'] == true;
      final msg = J.s(res, ['message']) ?? (ok ? '已完成音频时间轴对齐校准' : '校准未生效');
      setState(() {
        _calibrating = false;
        _calibrationOk = ok;
        _calibrationNotice = msg;
      });
      if (ok) {
        unawaited(_load());
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _calibrating = false;
        _calibrationOk = false;
        _calibrationNotice = e.friendlyMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calibrating = false;
        _calibrationOk = false;
        _calibrationNotice = '校准失败：$e';
      });
    }
  }

  static String _formatTs(int ms) {
    final safe = ms < 0 ? 0 : ms;
    final totalSec = safe ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    final rem = safe % 1000;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.'
        '${rem.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final stream = widget.preview.stream;
    final calibratable =
        perms.isAdmin && stream.external && stream.fileName != null;
    final cues = _data == null
        ? const <Map<String, dynamic>>[]
        : J.listOfMap(_data!, ['cues']);
    final eventCount = _data == null
        ? null
        : (J.i(_data!, ['event_count']) ?? cues.length);
    final format = _data == null ? null : J.s(_data!, ['format']);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.84,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                McGlassIconButton(
                  icon: McIcons.arrowLeftS,
                  iconSize: 18,
                  tooltip: '返回轨道列表',
                  onTap: widget.onBack,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.preview.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.ui.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (eventCount != null)
                        Text(
                          '共 $eventCount 条对白',
                          style: McText.micro.faint.tabular,
                        ),
                    ],
                  ),
                ),
                if (calibratable && _data != null) ...[
                  const SizedBox(width: 8),
                  McActionPill(
                    label: _calibrating ? '校准中…' : '一键音频对齐校准',
                    icon: McIcons.equalizer,
                    primary: false,
                    tone: McGlassTone.strong,
                    busy: _calibrating,
                    height: 34,
                    onTap: _calibrating ? null : _calibrate,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: McTokens.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: McTokens.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _badge(stream.external ? '外挂' : '内封'),
                      if (format != null && format.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _badge(format.toUpperCase()),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stream.fileName ?? widget.file.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                ],
              ),
            ),
            if (_calibrationNotice != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: (_calibrationOk ? McTokens.info : McTokens.warning)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_calibrationOk ? McTokens.info : McTokens.warning)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _calibrationNotice!,
                  style: McText.caption.copyWith(
                    color: _calibrationOk ? McTokens.info : McTokens.warning,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(child: _buildBody(cues, stream.external)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> cues, bool external) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '无法预览字幕：$_error',
              textAlign: TextAlign.center,
              style: McText.sub.copyWith(color: McTokens.danger),
            ),
            const SizedBox(height: 12),
            McChip(label: '重试', selected: true, onTap: _load),
          ],
        ),
      );
    }
    if (_data == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: McTokens.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: McTokens.accent,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pendingMessage ??
                          (external ? '正在读取外挂字幕…' : '正在后台抽取内封字幕…'),
                      style: McText.sub.copyWith(color: McTokens.text),
                    ),
                    if (_pendingMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '首次预览内封字幕需通读视频容器，完成后会落盘缓存，下次打开秒开。',
                        style: McText.caption.muted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (cues.isEmpty) {
      return Center(
        child: Text('该字幕轨道没有可展示的对白文本。', style: McText.sub.muted),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: cues.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 14,
          color: McTokens.line,
        ),
        itemBuilder: (_, i) {
          final cue = cues[i];
          final startMs = J.i(cue, ['start_ms']) ?? 0;
          final endMs = J.i(cue, ['end_ms']) ?? 0;
          final text = (cue['text'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 98,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTs(startMs),
                        style: McText.micro.muted.tabular,
                      ),
                      Text(
                        '→ ${_formatTs(endMs)}',
                        style: McText.micro.faint.tabular,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    text,
                    style: McText.sub.copyWith(
                      color: McTokens.text,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: McText.micro.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      );
}

// ── 中性轨道模型（1:1 对齐 iOS `TrackModel`） ──

enum _TrackKind { audio, subtitle }

enum _TrackTone {
  srt,
  ass,
  pgs,
  vobsub,
  text,
  ai,
  other;

  Color get background => switch (this) {
        _TrackTone.srt => const Color(0x1A7DD3FC),
        _TrackTone.ass => const Color(0x1AC4B5FD),
        _TrackTone.pgs => const Color(0x1AFCD34D),
        _TrackTone.vobsub => const Color(0x1AFDBA74),
        _TrackTone.text => const Color(0x1A67E8F9),
        _TrackTone.ai => McTokens.accent.withValues(alpha: 0.14),
        _TrackTone.other => const Color(0x12FFFFFF),
      };

  Color get foreground => switch (this) {
        _TrackTone.srt => const Color(0xE6E0F2FE),
        _TrackTone.ass => const Color(0xE6EDE9FE),
        _TrackTone.pgs => const Color(0xE6FEF3C7),
        _TrackTone.vobsub => const Color(0xE6FFEDD5),
        _TrackTone.text => const Color(0xE6CFFAFE),
        _TrackTone.ai => McTokens.accentStrong,
        _TrackTone.other => const Color(0xBFFFFFFF),
      };
}

class _TrackPreviewInfo {
  const _TrackPreviewInfo({
    required this.stream,
    required this.track,
    required this.label,
  });

  final DetailSubtitleStream stream;
  final String track;
  final String label;
}

class _TrackEntry {
  const _TrackEntry({
    required this.id,
    required this.language,
    required this.rank,
    required this.format,
    required this.tone,
    required this.primary,
    required this.secondary,
    required this.flags,
    required this.external,
    required this.order,
    this.deletable,
    this.preview,
  });

  final String id;
  final String language;
  final int rank;
  final String format;
  final _TrackTone tone;
  final String primary;
  final String secondary;
  final List<String> flags;
  final bool? external;
  final int order;
  final String? deletable;
  final _TrackPreviewInfo? preview;
}

class _TrackLanguageGroup {
  const _TrackLanguageGroup({
    required this.language,
    required this.entries,
    required this.rank,
    required this.hasDefault,
  });

  final String language;
  final List<_TrackEntry> entries;
  final int rank;
  final bool hasDefault;
}

abstract final class _TrackModel {
  static const _audioCodecLabels = {
    'aac': 'AAC',
    'ac3': 'Dolby Digital',
    'eac3': 'Dolby Digital+',
    'truehd': 'Dolby TrueHD',
    'dts': 'DTS',
    'flac': 'FLAC',
    'opus': 'Opus',
    'mp3': 'MP3',
    'vorbis': 'Vorbis',
  };

  static const _audioFormatTokens = {
    'aac': 'AAC',
    'ac3': 'AC3',
    'eac3': 'EAC3',
    'truehd': 'TrueHD',
    'dts': 'DTS',
    'flac': 'FLAC',
    'opus': 'Opus',
    'mp3': 'MP3',
    'vorbis': 'Vorbis',
  };

  static const _subtitleCodecLabels = {
    'subrip': 'SRT',
    'srt': 'SRT',
    'ass': 'ASS',
    'ssa': 'SSA',
    'hdmv_pgs_subtitle': 'PGS',
    'dvd_subtitle': 'VobSub',
    'mov_text': 'Text',
    'webvtt': 'VTT',
    'vtt': 'VTT',
    'sub': 'VobSub',
    'sup': 'PGS',
  };

  static const _languageLabels = <(String, String)>[
    ('chs', '简体中文'),
    ('cht', '繁体中文'),
    ('chi', '中文'),
    ('zho', '中文'),
    ('cmn', '中文'),
    ('yue', '粤语'),
    ('eng', '英语'),
    ('jpn', '日语'),
    ('kor', '韩语'),
    ('fre', '法语'),
    ('fra', '法语'),
    ('ger', '德语'),
    ('deu', '德语'),
    ('spa', '西班牙语'),
    ('rus', '俄语'),
    ('ita', '意大利语'),
    ('por', '葡萄牙语'),
    ('tha', '泰语'),
    ('hin', '印地语'),
  ];

  static const _languageRanks = {
    'chs': 1,
    'cht': 2,
    'chi': 3,
    'zho': 3,
    'cmn': 3,
    'yue': 4,
    'eng': 5,
    'jpn': 6,
    'kor': 7,
  };

  static const _otherRank = 40;
  static const _bilingualRank = 80;
  static const _unknownRank = 90;
  static const _unknownLanguage = '未知语言';
  static const _genericProfiles = {'lc', 'main', 'high', 'baseline', 'main 10'};
  static const _audioTier = {
    'truehd': 5,
    'dts': 4,
    'eac3': 3,
    'flac': 3,
    'ac3': 2,
    'opus': 1,
    'aac': 1,
    'vorbis': 0,
    'mp3': 0,
  };

  static String? languageLabel(String? code) {
    if (code == null || code.isEmpty || code.toLowerCase() == 'und') return null;
    final lower = code.toLowerCase();
    for (final (k, v) in _languageLabels) {
      if (k == lower) return v;
    }
    return code;
  }

  static int languageRank(String? code) {
    if (code == null || code.isEmpty || code.toLowerCase() == 'und') {
      return _unknownRank;
    }
    return _languageRanks[code.toLowerCase()] ?? _otherRank;
  }

  static String? channelsLabel(DetailAudioStream stream) {
    final layout = stream.channelLayout;
    if (layout != null && layout.isNotEmpty) {
      final cleaned = layout.split('(').first.trim();
      if (cleaned.isNotEmpty && RegExp(r'^\d').hasMatch(cleaned)) {
        return cleaned;
      }
    }
    final ch = stream.channels;
    if (ch == null) return null;
    return switch (ch) {
      1 => '单声道',
      2 => '2.0',
      6 => '5.1',
      7 => '6.1',
      8 => '7.1',
      _ => '$ch 声道',
    };
  }

  static String? informativeProfile(DetailAudioStream stream) {
    final p = stream.profile;
    if (p == null || p.isEmpty) return null;
    return _genericProfiles.contains(p.toLowerCase()) ? null : p;
  }

  static String? audioCodecName(DetailAudioStream stream) {
    final c = stream.codec;
    if (c == null || c.isEmpty) return null;
    return _audioCodecLabels[c.toLowerCase()] ?? c.toUpperCase();
  }

  static String audioSpecLabel(DetailAudioStream stream) {
    final codec = informativeProfile(stream) ?? audioCodecName(stream) ?? '未知格式';
    final ch = channelsLabel(stream);
    return ch == null ? codec : '$codec · $ch';
  }

  static String? topAudioSpec(List<DetailAudioStream> streams) {
    if (streams.length < 2) return null;
    DetailAudioStream? best;
    var bestScore = -1;
    for (final s in streams) {
      final tier = _audioTier[s.codec?.toLowerCase() ?? ''] ?? 0;
      final score = tier * 100 + (s.channels ?? 0);
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    if (best == null) return null;
    final codec = informativeProfile(best) ?? audioCodecName(best);
    final parts = [
      if (codec != null && codec.isNotEmpty) codec,
      if (channelsLabel(best) != null) channelsLabel(best)!,
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  static String? generatedSubtitleLabel(DetailSubtitleStream stream) {
    final title = stream.title?.toLowerCase() ?? '';
    if (title.isEmpty) return null;
    if (title.startsWith('ai-bilingual-')) {
      final langs = title.substring('ai-bilingual-'.length).split('-');
      if (langs.length == 2) {
        return '${languageLabel(langs[0]) ?? langs[0]} + '
            '${languageLabel(langs[1]) ?? langs[1]}';
      }
    }
    if (title == 'ai-chs') return '简体中文';
    if (title == 'ai-cht') return '繁体中文';
    return null;
  }

  static String subtitleLanguageName(DetailSubtitleStream stream) {
    return generatedSubtitleLabel(stream) ??
        languageLabel(stream.language) ??
        _unknownLanguage;
  }

  static String subtitleFormatToken(DetailSubtitleStream stream) {
    final c = stream.codec;
    if (c == null || c.isEmpty) return '字幕';
    return _subtitleCodecLabels[c.toLowerCase()] ?? c.toUpperCase();
  }

  static List<String> fileTokens(DetailSubtitleStream stream) =>
      stream.fileName?.toLowerCase().split('.') ?? const [];

  static bool isAiSubtitle(DetailSubtitleStream stream) {
    final title = stream.title?.toLowerCase() ?? '';
    return title.startsWith('ai-') ||
        fileTokens(stream).any((t) => t == 'ai' || t.startsWith('ai-'));
  }

  static _TrackTone subtitleTone(DetailSubtitleStream stream) {
    if (isAiSubtitle(stream)) return _TrackTone.ai;
    return switch (stream.codec?.toLowerCase()) {
      'subrip' || 'srt' => _TrackTone.srt,
      'ass' || 'ssa' => _TrackTone.ass,
      'hdmv_pgs_subtitle' || 'sup' => _TrackTone.pgs,
      'dvd_subtitle' || 'sub' => _TrackTone.vobsub,
      'mov_text' || 'webvtt' || 'vtt' => _TrackTone.text,
      _ => _TrackTone.other,
    };
  }

  static _TrackTone audioTone(DetailAudioStream stream) {
    return switch (stream.codec?.toLowerCase()) {
      'aac' || 'mp3' => _TrackTone.srt,
      'truehd' => _TrackTone.ass,
      'ac3' || 'eac3' => _TrackTone.pgs,
      'dts' => _TrackTone.vobsub,
      'flac' || 'opus' || 'vorbis' => _TrackTone.text,
      _ => _TrackTone.other,
    };
  }

  static String externalSubtitleSuffix(DetailSubtitleStream stream) {
    final tokens = fileTokens(stream);
    if (tokens.any((t) => t == 'ai' || t.startsWith('ai-'))) return 'AI 外挂';
    if (tokens.contains('pgs-ocr')) return 'PGS 转换';
    return '外挂';
  }

  static String videoStem(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot >= fileName.length - 1) return fileName;
    return fileName.substring(0, dot);
  }

  static String externalSubtitleLabel(String? fileName, String videoStem) {
    if (fileName == null || fileName.isEmpty) return '外挂字幕';
    if (videoStem.isNotEmpty &&
        fileName.toLowerCase().startsWith(videoStem.toLowerCase())) {
      var rest = fileName.substring(videoStem.length);
      if (rest.startsWith('.')) rest = rest.substring(1);
      if (rest.isNotEmpty) return rest;
    }
    return fileName;
  }

  static String siblingPath(String videoPath, String filename) {
    final cut = videoPath.lastIndexOf(RegExp(r'[/\\]'));
    if (cut < 0) return filename;
    return '${videoPath.substring(0, cut + 1)}$filename';
  }

  static String? subtitleTrackRef(DetailSubtitleStream stream, int index) {
    if (!stream.external) return 'embedded:$index';
    if (stream.fileName == null || stream.fileName!.isEmpty) return null;
    return 'external:${stream.fileName}';
  }

  static List<_TrackEntry> audioEntries(
    List<DetailAudioStream> streams, {
    TrackDefaults? defaults,
  }) {
    final result = <_TrackEntry>[];
    for (var i = 0; i < streams.length; i++) {
      final s = streams[i];
      final isDefault = defaults != null
          ? defaults.audioTrack == 'embedded:$i'
          : s.isDefault;
      final spec = audioSpecLabel(s);
      final title = s.title?.trim() ?? '';
      final fmt = (s.codec == null || s.codec!.isEmpty)
          ? '音轨'
          : (_audioFormatTokens[s.codec!.toLowerCase()] ?? s.codec!.toUpperCase());
      result.add(
        _TrackEntry(
          id: 'audio:$i',
          language: languageLabel(s.language) ?? _unknownLanguage,
          rank: languageRank(s.language),
          format: fmt,
          tone: audioTone(s),
          primary: title.isEmpty ? spec : '$spec · $title',
          secondary: '轨 ${i + 1}',
          flags: isDefault ? const ['默认'] : const [],
          external: null,
          order: isDefault ? 0 : 1,
        ),
      );
    }
    return result;
  }

  static List<_TrackEntry> subtitleEntries(
    List<DetailSubtitleStream> streams, {
    required String videoStem,
    TrackDefaults? defaults,
  }) {
    var embeddedOrdinal = 0;
    final result = <_TrackEntry>[];
    for (var i = 0; i < streams.length; i++) {
      final s = streams[i];
      final lang = subtitleLanguageName(s);
      final fmt = subtitleFormatToken(s);
      if (!s.external) embeddedOrdinal++;
      final track = subtitleTrackRef(s, i);
      final isDefault = defaults != null
          ? (track != null && defaults.subtitleTrack == track)
          : s.isDefault;
      final title = s.title?.trim() ?? '';
      final primary = s.external
          ? externalSubtitleLabel(s.fileName, videoStem)
          : (title.isNotEmpty ? title : '内封轨 #$embeddedOrdinal');
      final flags = <String>[
        if (isDefault) '默认',
        if (s.forced) '强制',
      ];
      result.add(
        _TrackEntry(
          id: 'subtitle:${track ?? 'unknown:$i'}',
          language: lang,
          rank: _subtitleRank(s, lang),
          format: fmt,
          tone: subtitleTone(s),
          primary: primary,
          secondary: s.external
              ? externalSubtitleSuffix(s)
              : (title.isNotEmpty ? '内封轨 #$embeddedOrdinal' : '内封'),
          flags: flags,
          external: s.external,
          order: isDefault
              ? 0
              : isAiSubtitle(s)
                  ? 3
                  : s.external
                      ? 2
                      : 1,
          deletable: s.external ? s.fileName : null,
          preview: track == null
              ? null
              : _TrackPreviewInfo(
                  stream: s,
                  track: track,
                  label: '$primary · $lang · $fmt',
                ),
        ),
      );
    }
    return result;
  }

  static int _subtitleRank(DetailSubtitleStream s, String language) {
    if (language.contains(' + ')) return _bilingualRank;
    if (language == _unknownLanguage) return _unknownRank;
    final byCode = languageRank(s.language);
    if (byCode != _unknownRank) return byCode;
    for (final (code, label) in _languageLabels) {
      if (label == language) return languageRank(code);
    }
    return _otherRank;
  }

  static String? defaultNote(TrackDefaults defaults, _TrackKind kind) {
    if (kind == _TrackKind.audio) {
      if (defaults.audioTrack == null || defaults.audioNote.isEmpty) return null;
      return '默认音轨：${defaults.audioNote}';
    }
    if (defaults.subtitleNote.isEmpty) return null;
    return defaults.subtitleTrack != null
        ? '默认字幕：${defaults.subtitleNote}'
        : defaults.subtitleNote;
  }

  static List<_TrackLanguageGroup> groupByLanguage(List<_TrackEntry> entries) {
    final buckets = <String, List<_TrackEntry>>{};
    for (final e in entries) {
      buckets.putIfAbsent(e.language, () => []).add(e);
    }
    final groups = <_TrackLanguageGroup>[];
    for (final entry in buckets.entries) {
      final list = List<_TrackEntry>.from(entry.value)
        ..sort((a, b) => a.order.compareTo(b.order));
      var minRank = _otherRank;
      for (final e in list) {
        if (e.rank < minRank) minRank = e.rank;
      }
      groups.add(
        _TrackLanguageGroup(
          language: entry.key,
          entries: list,
          rank: minRank,
          hasDefault: list.any((e) => e.order == 0),
        ),
      );
    }
    groups.sort((a, b) {
      if (a.hasDefault != b.hasDefault) return a.hasDefault ? -1 : 1;
      if (a.rank != b.rank) return a.rank.compareTo(b.rank);
      if (a.entries.length != b.entries.length) {
        return b.entries.length.compareTo(a.entries.length);
      }
      return a.language.compareTo(b.language);
    });
    return groups;
  }
}
