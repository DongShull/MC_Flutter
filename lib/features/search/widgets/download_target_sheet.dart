import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../../../core/session/permissions.dart';
import '../models/search_models.dart';

/// 管理员保存位置记忆 + 下载器目录候选（对齐 iOS `DownloadTargetPrefs`）。
class DownloadTargetPrefsStore {
  Map<String, DownloadTargetPref> byCategory = {};
  Set<String>? usableDirs;

  static String trimPath(String path) {
    var p = path;
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  Future<void> refresh(McClient mc) async {
    try {
      dynamic raw;
      try {
        raw = await mc.unwrap<dynamic>(
          Channel.general,
          'GET',
          '/api/v1/downloaders/target-prefs',
        );
      } on ApiException catch (e) {
        if (e.httpStatus == 404) {
          raw = await mc.unwrap<dynamic>(
            Channel.general,
            'GET',
            '/api/v1/downloaders/target-preferences',
          );
        } else {
          rethrow;
        }
      }
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['prefs'] ?? raw['items'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      final map = <String, DownloadTargetPref>{};
      for (final el in list) {
        if (el is Map) {
          final pref =
              DownloadTargetPref.fromJson(Map<String, dynamic>.from(el));
          map[pref.category] = pref;
        }
      }
      byCategory = map;
    } catch (_) {}
  }

  Future<void> loadDirs(McClient mc) async {
    try {
      final raw = await mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/downloaders',
      );
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['downloaders'] ?? raw['items'] ?? const [])
                  as List<dynamic>
              : const <dynamic>[]);
      final dirs = <String>{};
      for (final el in list) {
        if (el is! Map) continue;
        final d = DownloaderInfo.fromJson(Map<String, dynamic>.from(el));
        if (!d.usable) continue;
        if (d.savePath != null) dirs.add(trimPath(d.savePath!));
        for (final m in d.pathMappings) {
          if (m.local.isNotEmpty) dirs.add(trimPath(m.local));
        }
      }
      usableDirs = dirs;
    } catch (_) {
      usableDirs = null;
    }
  }

  bool isStaleDir(DownloadTargetPref pref) {
    if (pref.kind != 'dir' || pref.savePath == null || usableDirs == null) {
      return false;
    }
    return !usableDirs!.contains(trimPath(pref.savePath!));
  }

  Future<void> forget(String category, McClient mc) async {
    byCategory.remove(category);
    try {
      await mc.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/downloaders/target-prefs/${Uri.encodeComponent(category)}',
      );
    } on ApiException catch (e) {
      if (e.httpStatus == 404) {
        try {
          await mc.unwrap<dynamic>(
            Channel.general,
            'DELETE',
            '/api/v1/downloaders/target-preferences/${Uri.encodeComponent(category)}',
          );
        } catch (_) {}
      }
    } catch (_) {}
  }
}

/// 按记住的目标直接提交（对齐 iOS `submitRememberedDownload`）。
/// `smart` 记忆会重跑 `resolve-target`；未收敛时返回 `null`，调用方回落完整弹窗。
Future<DownloadSubmitResult?> submitRememberedDownload(
  McClient mc,
  DownloadTargetRequest request,
  DownloadTargetPref target,
) async {
  final payload = <String, dynamic>{
    'site_id': request.siteId,
    'download_url': request.downloadUrl,
    'torrent_id': request.torrentId,
    'category': request.category,
  };
  if (target.kind == 'smart') {
    final id = request.identity;
    if (id == null) return null;
    try {
      final raw = await mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/downloaders/resolve-target',
        body: {
          'kind': id.kind,
          'title': id.title,
          'year': id.year,
          if (request.subtitle != null) 'subtitle': request.subtitle,
          if (target.downloaderId != null) 'downloader_id': target.downloaderId,
        },
      );
      final resolved = ManualDownloadTarget.fromJson(raw);
      if (!resolved.ok ||
          resolved.status != 'ready' ||
          resolved.tmdbId == null) {
        return null;
      }
      payload['auto_route'] = true;
      payload['media_kind'] = resolved.kind ?? id.kind;
      payload['tmdb_id'] = resolved.tmdbId;
      payload['title'] = resolved.title ?? id.title;
      payload['year'] = resolved.year ?? id.year;
      if (request.subtitle != null) payload['subtitle'] = request.subtitle;
    } catch (_) {
      return null;
    }
  } else if (target.kind == 'dir' && target.savePath != null) {
    payload['save_path'] = target.savePath;
  }
  if (target.downloaderId != null) {
    payload['downloader_id'] = target.downloaderId;
  }
  final res = await mc.unwrap<Map<String, dynamic>>(
    Channel.general,
    'POST',
    '/api/v1/downloaders/submit',
    body: payload,
  );
  return DownloadSubmitResult.fromJson(res);
}

enum _TargetOptKind { smart, dir, library, fallback }

class _TargetOption {
  const _TargetOption({
    required this.id,
    required this.kind,
    required this.label,
    this.savePath,
    this.libraryId,
    this.detail,
  });

  final String id;
  final _TargetOptKind kind;
  final String label;
  final String? savePath;
  final int? libraryId;
  final String? detail;
}

/// 完整的「选择保存位置」弹层（1:1 对齐 iOS `DownloadTargetSheet`）：
/// - 管理员：智能入库预检 (`POST /downloaders/resolve-target`) + 「这是哪部作品？」TMDB 候选纠偏 +
///   可展开「其他保存位置」（下载器选择 + 路径映射双视角）+ 「记住本次选择」开关；
/// - 成员（`!perms.isAdmin`）：拉取可见非图片媒体库供选目标库或下载器默认目录，绝不越权调用超管接口。
class DownloadTargetSheet extends ConsumerStatefulWidget {
  const DownloadTargetSheet({
    super.key,
    required this.request,
    this.remembered,
    required this.onSubmitted,
  });

  final DownloadTargetRequest request;
  final DownloadTargetPref? remembered;
  final ValueChanged<DownloadSubmitResult> onSubmitted;

  static Future<void> show(
    BuildContext context, {
    required DownloadTargetRequest request,
    DownloadTargetPref? remembered,
    required ValueChanged<DownloadSubmitResult> onSubmitted,
  }) =>
      showMcSheet<void>(
        context: context,
        builder: (_) => DownloadTargetSheet(
          request: request,
          remembered: remembered,
          onSubmitted: onSubmitted,
        ),
      );

  @override
  ConsumerState<DownloadTargetSheet> createState() =>
      _DownloadTargetSheetState();
}

class _DownloadTargetSheetState extends ConsumerState<DownloadTargetSheet> {
  late final McClient _mc = McClient(session: ref.read(sessionStoreProvider));
  final TextEditingController _hintCtrl = TextEditingController();

  List<DownloaderInfo> _downloaders = const [];
  List<MemberLibraryOption>? _memberLibraries;
  int? _downloaderId;
  ManualDownloadTarget? _manualTarget;
  bool _picking = false;
  List<ManualDownloadCandidate> _candidates = const [];
  ManualDownloadCandidate? _selectedCandidate;
  String? _hint;
  bool _showOther = false;
  bool _downloadersLoaded = false;
  bool _loadingDownloaders = false;
  bool _loadingTarget = false;
  String? _selected;
  bool _remember = false;
  bool _busy = false;
  String? _error;
  int _targetSeq = 0;

  bool get _isAdmin => ref.read(permissionsProvider).isAdmin;
  bool get _canResolve =>
      widget.request.identity != null || widget.request.hint != null;

  DownloaderInfo? get _downloader {
    for (final d in _downloaders) {
      if (d.id == _downloaderId) return d;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!_isAdmin) {
      try {
        final raw = await _mc.unwrap<dynamic>(
          Channel.general,
          'GET',
          '/api/v1/libraries',
          query: {'scope': 'all'},
        );
        final list = raw is List
            ? raw
            : (raw is Map
                ? (raw['libraries'] ?? raw['items'] ?? const [])
                    as List<dynamic>
                : const <dynamic>[]);
        final libs = [
          for (final el in list)
            if (el is Map)
              MemberLibraryOption.fromJson(Map<String, dynamic>.from(el)),
        ];
        if (!mounted) return;
        setState(() => _memberLibraries = libs);
        _autoSelect();
      } catch (_) {
        if (!mounted) return;
        setState(() => _memberLibraries = const []);
        _autoSelect();
      }
      return;
    }

    final rem = widget.remembered;
    setState(() {
      _remember = rem != null;
      _hint = widget.request.hint;
      _hintCtrl.text = widget.request.hint ?? '';
      _picking = widget.request.identity == null;
      _showOther = !_canResolve || (rem != null && rem.kind != 'smart');
      if (rem?.kind == 'smart') _downloaderId = rem?.downloaderId;
    });

    if (_showOther) {
      _loadDownloaders();
    }
    if (_canResolve) {
      final remDlId = rem?.kind == 'smart' ? rem?.downloaderId : null;
      await _runPreflight(
        downloaderId: remDlId,
        candidate: null,
        hint: widget.request.hint,
        initial: true,
      );
    }
    _autoSelect();
  }

  List<_TargetOption> get _options {
    if (!_isAdmin) return _memberOptions;
    final out = <_TargetOption>[];
    final t = _manualTarget;
    if (t != null &&
        t.status == 'ready' &&
        t.tmdbId != null &&
        t.libraryId != null &&
        t.ok) {
      final entryDir = t.entryDir ?? t.path ?? '';
      final reason = t.routeReason ?? '';
      String? detail;
      if (t.mode == 'watch') {
        detail = t.stagingPath != null
            ? '$reason · 投递至 ${t.path ?? ''}，整理到 ${t.stagingPath}'
            : '$reason · 监听投递至 ${t.path ?? ''}';
      } else if (t.mode == 'inplace') {
        detail = '$reason · 直接下载至 ${DownloadTargetPrefsStore.trimPath(entryDir)}';
      } else if (entryDir.isNotEmpty) {
        detail = reason.isNotEmpty ? '$reason · $entryDir' : entryDir;
      }
      out.add(
        _TargetOption(
          id: 'smart',
          kind: _TargetOptKind.smart,
          label: '自动入库 · ${t.libraryName ?? ''}',
          detail: detail,
        ),
      );
    }
    if (_showOther) {
      final dl = _downloader;
      final seen = <String>{};
      final dirs = <({String path, String source})>[];
      if (dl?.savePath != null) {
        dirs.add((path: dl!.savePath!, source: '下载器默认目录'));
        seen.add(dl.savePath!);
      }
      for (final m in dl?.pathMappings ?? const <PathMappingInfo>[]) {
        if (m.local.isNotEmpty && seen.add(m.local)) {
          dirs.add((path: m.local, source: '路径映射目录'));
        }
      }
      for (final d in dirs) {
        final remote = _remoteView(d.path, dl?.pathMappings);
        out.add(
          _TargetOption(
            id: 'dir:${d.path}',
            kind: _TargetOptKind.dir,
            savePath: d.path,
            label: d.path,
            detail: remote != d.path
                ? '下载器视角：$remote · ${d.source}'
                : d.source,
          ),
        );
      }
      out.add(
        const _TargetOption(
          id: 'default',
          kind: _TargetOptKind.fallback,
          label: '下载器默认目录',
          detail: '不指定保存路径，由下载器自行决定',
        ),
      );
    }
    return out;
  }

  List<_TargetOption> get _memberOptions {
    final libs = _memberLibraries;
    if (libs == null) return const [];
    final kind = widget.request.identity?.kind;
    final fit = libs.where((l) => l.kind != 'photo').toList();
    final ordered = [
      ...fit.where((l) => l.kind == kind),
      ...fit.where((l) => l.kind != kind),
    ];
    return [
      for (final l in ordered)
        _TargetOption(
          id: 'library:${l.id}',
          kind: _TargetOptKind.library,
          libraryId: l.id,
          label: '下载到「${l.name}」',
          detail: '${l.kindLabel} · 自动推导目录并入库',
        ),
      const _TargetOption(
        id: 'default',
        kind: _TargetOptKind.fallback,
        label: '下载器默认目录',
        detail: '由服务器默认下载器决定保存位置',
      ),
    ];
  }

  static String _remoteView(String path, List<PathMappingInfo>? mappings) {
    if (mappings == null || mappings.isEmpty) return path;
    PathMappingInfo? best;
    var bestLen = -1;
    for (final m in mappings) {
      final local = DownloadTargetPrefsStore.trimPath(m.local);
      if ((path == local || path.startsWith('$local/')) &&
          local.length > bestLen) {
        best = m;
        bestLen = local.length;
      }
    }
    if (best == null) return path;
    final local = DownloadTargetPrefsStore.trimPath(best.local);
    final remote = DownloadTargetPrefsStore.trimPath(best.remote);
    return '$remote${path.substring(local.length)}';
  }

  Future<void> _runPreflight({
    int? downloaderId,
    ManualDownloadCandidate? candidate,
    String? hint,
    bool initial = false,
  }) async {
    final seq = ++_targetSeq;
    setState(() {
      _loadingTarget = true;
      if (!initial) _manualTarget = null;
    });
    ManualDownloadTarget? target;
    try {
      final id = widget.request.identity;
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/downloaders/resolve-target',
        body: {
          if (id != null) 'kind': id.kind,
          if (id != null) 'title': id.title,
          if (id != null) 'year': id.year,
          if (widget.request.subtitle != null)
            'subtitle': widget.request.subtitle,
          if (hint != null && hint.isNotEmpty) 'hint': hint,
          if (downloaderId != null) 'downloader_id': downloaderId,
          if (candidate != null) 'selected_tmdb_id': candidate.tmdbId,
          if (candidate != null) 'selected_kind': candidate.kind,
        },
      );
      target = ManualDownloadTarget.fromJson(raw);
    } catch (_) {
      target = null;
    }
    if (!mounted || seq != _targetSeq) return;
    setState(() {
      _manualTarget = target;
      _loadingTarget = false;
      if (target != null) _candidates = target.candidates;
      if (initial && target != null && target.status != 'ready') {
        _picking = true;
      }
      if (target == null ||
          target.status == 'not_found' ||
          (target.status == 'ready' && !target.ok)) {
        if (!_showOther) {
          _showOther = true;
          _loadDownloaders();
        }
      }
      if (candidate != null && target?.status == 'ready' && target?.ok == true) {
        _selected = 'smart';
      }
    });
    _autoSelect();
  }

  Future<void> _loadDownloaders() async {
    if (_downloadersLoaded || _loadingDownloaders) return;
    setState(() => _loadingDownloaders = true);
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/downloaders',
      );
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['downloaders'] ?? raw['items'] ?? const [])
                  as List<dynamic>
              : const <dynamic>[]);
      final usable = [
        for (final el in list)
          if (el is Map) DownloaderInfo.fromJson(Map<String, dynamic>.from(el)),
      ].where((d) => d.usable).toList();
      final prev = _downloaderId;
      final current = usable.where((d) => d.id == _downloaderId).firstOrNull;
      final remDl = widget.remembered?.downloaderId != null
          ? usable
              .where((d) => d.id == widget.remembered!.downloaderId)
              .firstOrNull
          : null;
      final chosen = current ??
          remDl ??
          usable.where((d) => d.isDefault).firstOrNull ??
          usable.firstOrNull;
      final preflightId = chosen != null && !chosen.isDefault ? chosen.id : null;
      if (!mounted) return;
      setState(() {
        _downloaders = usable;
        _downloaderId = chosen?.id;
        _downloadersLoaded = true;
        _loadingDownloaders = false;
      });
      if (_canResolve && preflightId != prev) {
        _runPreflight(
          downloaderId: preflightId,
          candidate: _selectedCandidate,
          hint: _hint,
        );
      }
      _autoSelect();
    } catch (_) {
      if (mounted) {
        setState(() {
          _downloadersLoaded = true;
          _loadingDownloaders = false;
        });
      }
    }
  }

  void _autoSelect() {
    final opts = _options;
    if (opts.isEmpty) return;
    if (_selected != null && opts.any((o) => o.id == _selected)) return;

    final rem = widget.remembered;
    if (_isAdmin && rem != null) {
      final match = opts.where((o) {
        if (rem.kind == 'dir') {
          return o.kind == _TargetOptKind.dir && o.savePath == rem.savePath;
        }
        if (rem.kind == 'smart') return o.kind == _TargetOptKind.smart;
        return o.kind == _TargetOptKind.fallback;
      }).firstOrNull;
      if (match != null) {
        setState(() => _selected = match.id);
        return;
      }
    }

    if (!_isAdmin) {
      final kind = widget.request.identity?.kind;
      final fit =
          (_memberLibraries ?? const []).where((l) => l.kind == kind).toList();
      final lib =
          fit.where((l) => l.isDefault).firstOrNull ?? fit.firstOrNull;
      setState(() => _selected = lib != null ? 'library:${lib.id}' : 'default');
      return;
    }

    if (_loadingTarget || (_showOther && !_downloadersLoaded)) return;
    final best = opts.where((o) => o.kind == _TargetOptKind.smart).firstOrNull ??
        opts.first;
    setState(() => _selected = best.id);
  }

  void _searchHint() {
    final q = _hintCtrl.text.trim();
    if (q.isEmpty || _loadingTarget) return;
    setState(() {
      _hint = q;
      _selectedCandidate = null;
    });
    _runPreflight(downloaderId: _downloaderId, candidate: null, hint: q);
  }

  Future<void> _submit() async {
    final opt = _options.where((o) => o.id == _selected).firstOrNull;
    if (opt == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'site_id': widget.request.siteId,
      'download_url': widget.request.downloadUrl,
      'torrent_id': widget.request.torrentId,
    };

    if (!_isAdmin) {
      if (opt.kind == _TargetOptKind.library && opt.libraryId != null) {
        payload['library_id'] = opt.libraryId;
        if (widget.request.identity != null) {
          payload['title'] = widget.request.identity!.title;
          payload['year'] = widget.request.identity!.year;
        }
        if (widget.request.subtitle != null) {
          payload['subtitle'] = widget.request.subtitle;
        }
      }
    } else {
      final dl = _downloader;
      final pickedDlId =
          dl != null ? (dl.isDefault ? null : dl.id) : _downloaderId;
      if (_remember) payload['category'] = widget.request.category;
      final t = _manualTarget;
      if (opt.kind == _TargetOptKind.smart &&
          t != null &&
          t.tmdbId != null &&
          t.kind != null &&
          t.title != null) {
        payload['auto_route'] = true;
        payload['media_kind'] = t.kind;
        payload['tmdb_id'] = t.tmdbId;
        payload['title'] = t.title;
        if (t.year != null) payload['year'] = t.year;
        if (widget.request.subtitle != null) {
          payload['subtitle'] = widget.request.subtitle;
        }
      }
      if (opt.kind == _TargetOptKind.dir && opt.savePath != null) {
        payload['save_path'] = opt.savePath;
      }
      if (pickedDlId != null) payload['downloader_id'] = pickedDlId;
    }

    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/downloaders/submit',
        body: payload,
      );
      final result = DownloadSubmitResult.fromJson(raw);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSubmitted(result);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '提交下载失败，请稍后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final opts = _options;
    final confirmLabel = _busy
        ? '提交中…'
        : (_selected == 'smart' && _manualTarget?.libraryName != null
            ? '下载到「${_manualTarget!.libraryName}」'
            : '确认下载');

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('选择保存位置', style: McText.titleSm),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.request.reason != null) ...[
                    _notice(widget.request.reason!, McTokens.warning),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) ...[
                    _notice(_error!, McTokens.danger),
                    const SizedBox(height: 12),
                  ],
                  if (_isAdmin) _buildSmartSection(),
                  if ((_showOther && _loadingDownloaders) ||
                      (!_isAdmin && _memberLibraries == null)) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ],
                  for (final opt in opts) ...[
                    _buildOptionRow(opt),
                    const SizedBox(height: 10),
                  ],
                  if (_isAdmin && !_showOther) ...[
                    McGlassButton(
                      onTap: () {
                        setState(() => _showOther = true);
                        _loadDownloaders();
                      },
                      tone: McGlassTone.secondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          const Icon(McIcons.folder, size: 17),
                          const SizedBox(width: 8),
                          Text('其他保存位置', style: McText.sub.semibold),
                          const Spacer(),
                          const Icon(
                            McIcons.arrowDownS,
                            size: 16,
                            color: McTokens.textFaint,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isAdmin && _showOther && _downloaders.length >= 2) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: McTokens.surfaceInset,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: McTokens.line),
                      ),
                      child: Row(
                        children: [
                          Text('下载器', style: McText.sub.muted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _downloaderId,
                                isExpanded: true,
                                dropdownColor: McTokens.surfaceSolid,
                                items: [
                                  for (final d in _downloaders)
                                    DropdownMenuItem(
                                      value: d.id,
                                      child: Text(
                                        d.name + (d.isDefault ? '（默认）' : ''),
                                        style: McText.sub.copyWith(
                                          color: McTokens.text,
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: (id) {
                                  if (id == null) return;
                                  setState(() => _downloaderId = id);
                                  if (_canResolve) {
                                    _runPreflight(
                                      downloaderId: id,
                                      candidate: _selectedCandidate,
                                      hint: _hint,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isAdmin) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: McTokens.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: McTokens.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '记住本次选择（${TorrentCategories.label(widget.request.category)}）',
                                  style: McText.sub.copyWith(
                                    color: McTokens.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _remember
                                      ? '下次下载同分类资源时优先弹出快捷确认条'
                                      : '仅本次生效，不修改已保存偏好',
                                  style: McText.caption.faint,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _remember,
                            onChanged: (v) => setState(() => _remember = v),
                          ),
                        ],
                      ),
                    ),
                    if (_showOther) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/settings/downloaders');
                        },
                        child: Text(
                          '路径映射与默认目录可在「设置 → 下载器」中维护 ↗',
                          style: McText.caption.faint.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  McActionPill(
                    label: confirmLabel,
                    icon: McIcons.download,
                    primary: true,
                    expanded: true,
                    busy: _busy,
                    height: 44,
                    onTap: _busy || _selected == null ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSection() {
    final t = _manualTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_picking) ...[
          _buildCandidatePicker(),
          const SizedBox(height: 12),
        ],
        if (_loadingTarget) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: McTokens.line),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  _selectedCandidate != null
                      ? '正在预演入库路由与保存目录…'
                      : '正在识别作品身份并预演入库目录…',
                  style: McText.caption.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (t != null && t.status == 'ready' && !t.ok) ...[
          _notice(
            t.warning ?? '当前下载器或媒体库配置暂不支持自动入库，请检查路径映射',
            McTokens.warning,
          ),
          const SizedBox(height: 12),
        ] else if (t == null && _canResolve) ...[
          _notice('智能入库预检暂不可用，可选择下方保存目录直接下载', McTokens.warning),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildCandidatePicker() {
    final caption = (!_loadingTarget && _manualTarget?.status == 'not_found')
        ? (_hint != null
            ? '未找到与「$_hint」匹配的 TMDB 作品，换个片名试试'
            : '输入片名搜索 TMDB 以启用智能入库')
        : (_candidates.isEmpty
            ? '未能从种子名自动识别作品，可输入片名检索 TMDB'
            : '点选对应的作品，系统将自动匹配目标媒体库与目录');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '这是哪部作品？',
            style: McText.sub.copyWith(
              color: McTokens.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(caption, style: McText.caption.faint),
          if (_candidates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _candidates)
                  McChip(
                    compact: true,
                    selected: _selectedCandidate?.tmdbId == c.tmdbId &&
                        _selectedCandidate?.kind == c.kind,
                    label: '${c.title}'
                        '${c.year != null ? ' (${c.year})' : ''}'
                        ' · ${c.kind == 'tv' ? '剧集' : '电影'}'
                        '${c.episodeCount != null ? ' · ${c.episodeCount} 集' : ''}',
                    onTap: () {
                      setState(() => _selectedCandidate = c);
                      _runPreflight(
                        downloaderId: _downloaderId,
                        candidate: c,
                        hint: _hint,
                      );
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hintCtrl,
                  style: McText.sub.copyWith(color: McTokens.text),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchHint(),
                  decoration: InputDecoration(
                    hintText: _candidates.isEmpty ? '输入片名搜 TMDB…' : '都不对？换个词搜…',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              McGlassButton(
                onTap: _loadingTarget ? null : _searchHint,
                tone: McGlassTone.secondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text('搜索', style: McText.caption.semibold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(_TargetOption opt) {
    final active = _selected == opt.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = opt.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? const Color(0x14FFFFFF) : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0x40FFFFFF) : McTokens.line,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              active ? McIcons.checkCircleFill : McIcons.circler,
              size: 18,
              color: active ? McTokens.accentStrong : McTokens.textFaint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        opt.kind == _TargetOptKind.smart
                            ? McIcons.aiStarFill
                            : McIcons.folder,
                        size: 14,
                        color: McTokens.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          opt.label,
                          style: McText.sub.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (opt.detail != null && opt.detail!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(opt.detail!, style: McText.caption.faint),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String text, Color tone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: McText.caption.copyWith(color: tone),
      ),
    );
  }
}

/// 保存位置快捷确认条（命中记忆时弹出，对齐 iOS `DownloadConfirmSheet`）。
class DownloadConfirmSheet extends ConsumerStatefulWidget {
  const DownloadConfirmSheet({
    super.key,
    required this.request,
    required this.target,
    required this.onConfirm,
    required this.onChange,
    required this.onForget,
  });

  final DownloadTargetRequest request;
  final DownloadTargetPref target;
  final VoidCallback onConfirm;
  final VoidCallback onChange;
  final VoidCallback onForget;

  static Future<void> show(
    BuildContext context, {
    required DownloadTargetRequest request,
    required DownloadTargetPref target,
    required VoidCallback onConfirm,
    required VoidCallback onChange,
    required VoidCallback onForget,
  }) =>
      showMcSheet<void>(
        context: context,
        builder: (_) => DownloadConfirmSheet(
          request: request,
          target: target,
          onConfirm: onConfirm,
          onChange: onChange,
          onForget: onForget,
        ),
      );

  @override
  ConsumerState<DownloadConfirmSheet> createState() =>
      _DownloadConfirmSheetState();
}

class _DownloadConfirmSheetState extends ConsumerState<DownloadConfirmSheet> {
  late final McClient _mc = McClient(session: ref.read(sessionStoreProvider));
  String? _resolvedPath;
  bool _preflighting = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.target.kind == 'smart' && widget.request.identity != null) {
      Future.microtask(_preflight);
    }
  }

  Future<void> _preflight() async {
    final id = widget.request.identity!;
    setState(() => _preflighting = true);
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/downloaders/resolve-target',
        body: {
          'kind': id.kind,
          'title': id.title,
          'year': id.year,
          if (widget.request.subtitle != null)
            'subtitle': widget.request.subtitle,
          if (widget.target.downloaderId != null)
            'downloader_id': widget.target.downloaderId,
        },
      );
      final t = ManualDownloadTarget.fromJson(raw);
      if (mounted) {
        setState(() {
          _resolvedPath = t.entryDir ?? t.path;
          _preflighting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _preflighting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    final headline = switch (t.kind) {
      'dir' => t.savePath ?? '指定目录',
      'default' => '下载器默认保存目录',
      _ => _resolvedPath ?? '由智能入库自动路由',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: McTokens.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  McIcons.folder,
                  size: 18,
                  color: McTokens.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('保存到', style: McText.micro.faint),
                    const SizedBox(height: 2),
                    Text(
                      '${TorrentCategories.label(widget.request.category)} · ${t.kind == 'smart' ? '智能入库' : (t.downloaderName ?? '默认下载器')}',
                      style: McText.titleSm,
                    ),
                    const SizedBox(height: 4),
                    if (_preflighting)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else
                      Text(
                        headline,
                        style: McText.caption.copyWith(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (t.updatedAt.isNotEmpty) ...[
                Text(
                  '上次使用于 ${mcFromNowIso(t.updatedAt)} · ',
                  style: McText.caption.faint,
                ),
              ],
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onForget();
                },
                child: Text(
                  '不再记住',
                  style: McText.caption.faint.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '更改',
                  primary: false,
                  expanded: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onChange();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: McActionPill(
                  label: _busy ? '提交中…' : '确认下载',
                  primary: true,
                  expanded: true,
                  busy: _busy,
                  onTap: _busy || _preflighting
                      ? null
                      : () {
                          setState(() => _busy = true);
                          Navigator.of(context).pop();
                          widget.onConfirm();
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
