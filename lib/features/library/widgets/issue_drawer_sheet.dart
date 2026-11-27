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
import 'library_shared.dart';

/// 弹出单库待处理抽屉（对齐 iOS `IssueDrawerView`）。
Future<void> showIssueDrawerSheet(
  BuildContext context, {
  required int libraryId,
  String? initialTab,
  VoidCallback? onChanged,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: IssueDrawerView(
        libraryId: libraryId,
        initialTab: initialTab,
        asSheet: true,
        onChanged: onChanged,
      ),
    ),
  );
}

/// 待处理四页签视图（缺失 / 待识别 / 身份复核 / 已忽略）。
/// 支持单库模式（`libraryId != null`）以及全库管理模式（`libraryId == null`，自动汇总所有库）。
class IssueDrawerView extends ConsumerStatefulWidget {
  const IssueDrawerView({
    super.key,
    this.libraryId,
    this.initialTab,
    this.asSheet = false,
    this.onChanged,
  });

  final int? libraryId;
  final String? initialTab; // missing | unidentified | review | ignored
  final bool asSheet;
  final VoidCallback? onChanged;

  @override
  ConsumerState<IssueDrawerView> createState() => _IssueDrawerViewState();
}

class _IssueDrawerViewState extends ConsumerState<IssueDrawerView> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _isMovieLib = true;
  Map<int, LibraryView> _libById = {};
  List<MissingItemView> _missing = const [];
  List<UnidentifiedGroupView> _unidentified = const [];
  List<ReviewGroupView> _review = const [];
  List<UnidentifiedGroupView> _ignored = const [];
  String _tab = 'unidentified';
  bool _tabInitialized = false;
  String _query = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final api = ref.read(libraryApiProvider);
    try {
      final libId = widget.libraryId;
      LibraryView? singleLib;
      List<LibraryView> allLibs = const [];
      if (libId != null) {
        singleLib = await api.libraryGet(libId);
      } else {
        allLibs = await api.libraries(scope: 'all');
      }

      final futures = await Future.wait([
        if (libId != null)
          api.missingItems(libId).catchError((_) => <MissingItemView>[])
        else
          Future.wait(
            allLibs
                .where((l) => l.missingCount > 0)
                .map((l) => api.missingItems(l.id).catchError((_) => <MissingItemView>[])),
          ).then((lists) => lists.expand((e) => e).toList()),
        api.unidentifiedGroups(libraryId: libId).catchError((_) => <UnidentifiedGroupView>[]),
        api.reviewGroups(libraryId: libId).catchError((_) => <ReviewGroupView>[]),
        api.ignoredGroups(libraryId: libId).catchError((_) => <UnidentifiedGroupView>[]),
      ]);

      if (!mounted) return;
      final missing = futures[0] as List<MissingItemView>;
      final unidentified = futures[1] as List<UnidentifiedGroupView>;
      final review = futures[2] as List<ReviewGroupView>;
      final ignored = futures[3] as List<UnidentifiedGroupView>;

      if (!_tabInitialized) {
        _tabInitialized = true;
        if (widget.initialTab != null &&
            const {'missing', 'unidentified', 'review', 'ignored'}
                .contains(widget.initialTab)) {
          _tab = widget.initialTab!;
        } else if (missing.isNotEmpty) {
          _tab = 'missing';
        } else if (unidentified.isNotEmpty) {
          _tab = 'unidentified';
        } else if (review.isNotEmpty) {
          _tab = 'review';
        } else if (ignored.isNotEmpty) {
          _tab = 'ignored';
        } else {
          _tab = 'unidentified';
        }
      }

      setState(() {
        _loading = false;
        _isMovieLib = singleLib == null ? true : singleLib.kind == 'movie';
        _libById = {
          if (singleLib != null) singleLib.id: singleLib,
          for (final l in allLibs) l.id: l,
        };
        _missing = missing;
        _unidentified = unidentified;
        _review = review;
        _ignored = ignored;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _afterChange() async {
    await _load(silent: true);
    widget.onChanged?.call();
  }

  int get _missingFileTotal =>
      _missing.fold(0, (s, item) => s + item.files.length);

  int get _unidentifiedFileTotal =>
      _unidentified.fold(0, (s, g) => s + g.fileCount);

  int get _ignoredFileTotal =>
      _ignored.fold(0, (s, g) => s + g.fileCount);

  int get _kindMismatchFiles => _unidentified.fold(
        0,
        (s, g) => s + (g.code == 'kind_mismatch' ? g.fileCount : 0),
      );

  bool _isMovieForLib(int libraryId) {
    final lib = _libById[libraryId];
    if (lib != null) return lib.kind == 'movie';
    return _isMovieLib;
  }

  Future<void> _clearAllMissing() async {
    final libId = widget.libraryId;
    if (libId == null) return;
    final ok = await _confirm(
      '清空全部 $_missingFileTotal 条缺失记录？',
      '仅清理数据库中的失效记录，不会删除磁盘文件。',
      confirmLabel: '全部清理',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(libraryApiProvider).clearMissingRecords(libraryId: libId);
      McToast.success('已清理缺失记录');
      await _afterChange();
    } catch (e) {
      McToast.error('操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ignoreAllUnidentified() async {
    final libId = widget.libraryId;
    if (libId == null) return;
    final ok = await _confirm(
      '忽略全部 $_unidentifiedFileTotal 个待识别文件？',
      '忽略后的文件会移入「已忽略」归档，不再出现在待识别列表中，可随时恢复。',
      confirmLabel: '全部忽略',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(libraryApiProvider).ignoreAllUnidentified(libId);
      McToast.success('已全部忽略');
      await _afterChange();
    } catch (e) {
      McToast.error('操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = '确定',
    bool destructive = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
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
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, String, int)>[
      ('missing', '缺失', _missing.length),
      ('unidentified', '待识别', _unidentifiedFileTotal),
      ('review', '身份复核', _review.length),
      if (_ignoredFileTotal > 0 || _tab == 'ignored')
        ('ignored', '已忽略', _ignoredFileTotal),
    ];

    final explanation = switch (_tab) {
      'missing' => '磁盘上找不到的媒体记录，可一键重新下载或直接清理失效记录。',
      'unidentified' => '自动刮削未匹配到确切条目的文件，按目录分组认领或忽略。',
      'review' => '新识别链给出的高置信度候选与当前身份不一致，请人工拍板确认。',
      _ => '已手动忽略的文件归档，不会阻塞扫描，随时可恢复重新识别。',
    };

    final kw = _query.trim().toLowerCase();

    return Column(
      children: [
        if (widget.asSheet) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
            child: Row(
              children: [
                const Expanded(child: Text('待处理中心', style: McText.titleSm)),
                if (widget.libraryId != null &&
                    _tab == 'missing' &&
                    _missing.isNotEmpty)
                  TextButton(
                    onPressed: _busy ? null : _clearAllMissing,
                    child: const Text(
                      '全部清理',
                      style: TextStyle(color: McTokens.danger),
                    ),
                  )
                else if (widget.libraryId != null &&
                    _tab == 'unidentified' &&
                    _unidentified.isNotEmpty)
                  TextButton(
                    onPressed: _busy ? null : _ignoreAllUnidentified,
                    child: const Text('全部忽略'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
        ],
        // 搜索框
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: McText.body,
            decoration: InputDecoration(
              isDense: true,
              hintText: _tab == 'missing' ? '筛选作品名…' : '筛选文件名或路径…',
              prefixIcon: const Icon(McIcons.search, size: 17),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // 页签
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (key, label, count) in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: McChip(
                    label: count > 0 ? '$label $count' : label,
                    compact: true,
                    selected: _tab == key,
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() {
                        _tab = key;
                        _query = '';
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const McLoadingView()
              : _error != null
                  ? McErrorView(text: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        children: [
                          Text(explanation, style: McText.caption.muted),
                          const SizedBox(height: 10),
                          if (_tab == 'unidentified' &&
                              _kindMismatchFiles > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: McTokens.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _isMovieLib
                                    ? '有 $_kindMismatchFiles 个文件疑似是剧集却放在电影库中，无法直接在此认领，请将其移动至剧集库目录后重新扫描。'
                                    : '有 $_kindMismatchFiles 个文件疑似是电影却放在剧集库中，无法直接在此认领，请将其移动至电影库目录后重新扫描。',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: McTokens.warning,
                                ),
                              ),
                            ),
                          ],
                          ..._buildTabRows(kw),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  List<Widget> _buildTabRows(String kw) {
    switch (_tab) {
      case 'missing':
        final list = kw.isEmpty
            ? _missing
            : _missing
                .where((m) => m.title.toLowerCase().contains(kw))
                .toList();
        if (list.isEmpty) {
          return [_emptyBox(kw.isEmpty ? '没有缺失文件' : '没有匹配的作品')];
        }
        return [
          for (final item in list)
            _MissingIssueCard(
              libraryId: widget.libraryId ?? _libById.keys.firstOrNull ?? 0,
              item: item,
              onChanged: _afterChange,
            ),
        ];

      case 'unidentified':
        final list = kw.isEmpty
            ? _unidentified
            : _unidentified
                .where(
                  (g) =>
                      g.label.toLowerCase().contains(kw) ||
                      g.files.any((f) => f.filePath.toLowerCase().contains(kw)),
                )
                .toList();
        if (list.isEmpty) {
          return [_emptyBox(kw.isEmpty ? '全部待识别文件已处理完毕' : '没有匹配的文件')];
        }
        return [
          for (final g in list)
            _UnidentifiedIssueCard(
              group: g,
              isMovie: _isMovieForLib(g.libraryId),
              onChanged: _afterChange,
            ),
        ];

      case 'review':
        final list = kw.isEmpty
            ? _review
            : _review
                .where(
                  (g) =>
                      g.label.toLowerCase().contains(kw) ||
                      g.current.title.toLowerCase().contains(kw) ||
                      g.suggestion.title.toLowerCase().contains(kw),
                )
                .toList();
        if (list.isEmpty) {
          return [_emptyBox(kw.isEmpty ? '没有待复核的身份冲突' : '没有匹配的复核项')];
        }
        return [
          for (final g in list)
            _ReviewIssueCard(
              group: g,
              isMovie: _isMovieForLib(g.libraryId),
              onChanged: _afterChange,
            ),
        ];

      default:
        final list = kw.isEmpty
            ? _ignored
            : _ignored
                .where(
                  (g) =>
                      g.label.toLowerCase().contains(kw) ||
                      g.files.any((f) => f.filePath.toLowerCase().contains(kw)),
                )
                .toList();
        if (list.isEmpty) {
          return [_emptyBox(kw.isEmpty ? '没有已忽略的文件' : '没有匹配的文件')];
        }
        return [
          for (final g in list)
            _IgnoredIssueCard(group: g, onChanged: _afterChange),
        ];
    }
  }

  Widget _emptyBox(String text) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: McEmptyView(text: text),
      );
}

/* ── 缺失行 ── */

class _MissingIssueCard extends ConsumerStatefulWidget {
  const _MissingIssueCard({
    required this.libraryId,
    required this.item,
    required this.onChanged,
  });

  final int libraryId;
  final MissingItemView item;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_MissingIssueCard> createState() => _MissingIssueCardState();
}

class _MissingIssueCardState extends ConsumerState<_MissingIssueCard> {
  bool _busy = false;
  String? _doneMsg;
  String? _error;

  String get _summary {
    final item = widget.item;
    if (item.kind != 'tv') return '${item.files.length} 个文件缺失';
    final bySeason = <int, int>{};
    for (final f in item.files) {
      final s = f.seasonNumber;
      bySeason[s] = (bySeason[s] ?? 0) + 1;
    }
    final keys = bySeason.keys.toList()..sort();
    return keys
        .map((s) => s == 0 ? '特别篇缺 ${bySeason[s]} 集' : '第 $s 季缺 ${bySeason[s]} 集')
        .join('、');
  }

  Future<void> _redownload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final requeued = await ref.read(libraryApiProvider).redownloadMissing(
            libraryId: widget.libraryId,
            mediaItemId: widget.item.mediaItemId,
          );
      setState(() => _doneMsg = '已提交重新下载（入队 $requeued 项）');
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearRecords() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: McTokens.surfaceSolid,
        title: Text('清理「${widget.item.title}」的 ${widget.item.files.length} 条缺失记录？'),
        content: Text(
          widget.item.subscriptionId != null
              ? '该作品正在订阅追踪中，清理记录后下次订阅巡检可能会自动重新下载。'
              : '仅清理数据库中的缺失文件记录，不影响磁盘文件。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清理记录', style: TextStyle(color: McTokens.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(libraryApiProvider).clearMissingRecords(
            libraryId: widget.libraryId,
            mediaItemId: widget.item.mediaItemId,
          );
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            '${it.title}${it.year != null ? ' (${it.year})' : ''}',
            style: McText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(_summary, style: McText.caption.muted),
          if (it.subscriptionId != null && _doneMsg == null) ...[
            const SizedBox(height: 4),
            const Text(
              '已关联订阅追踪',
              style: TextStyle(fontSize: 11, color: McTokens.warning),
            ),
          ],
          const SizedBox(height: 8),
          if (_doneMsg != null)
            Text(
              _doneMsg!,
              style: const TextStyle(fontSize: 12, color: McTokens.ok),
            )
          else
            Row(
              children: [
                McActionPill(
                  label: '重新下载',
                  primary: true,
                  height: 32,
                  onTap: _busy ? null : _redownload,
                ),
                const SizedBox(width: 8),
                McActionPill(
                  label: '清理记录',
                  height: 32,
                  onTap: _busy ? null : _clearRecords,
                ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(fontSize: 11, color: McTokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/* ── 待识别组（候选芯片 + TMDB 搜索 + 剧集选季确认 + 忽略） ── */

class _UnidentifiedIssueCard extends ConsumerStatefulWidget {
  const _UnidentifiedIssueCard({
    required this.group,
    required this.isMovie,
    required this.onChanged,
  });

  final UnidentifiedGroupView group;
  final bool isMovie;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_UnidentifiedIssueCard> createState() =>
      _UnidentifiedIssueCardState();
}

class _UnidentifiedIssueCardState
    extends ConsumerState<_UnidentifiedIssueCard> {
  bool _busy = false;
  bool _expandedFiles = false;
  bool _showSearch = false;
  int? _selectedTmdbId;
  String? _selectedTitle;
  int? _selectedYear;
  int? _seasonNumber;
  Map<String, dynamic>? _previewDetail;
  List<Map<String, dynamic>> _searchResults = const [];
  bool _searching = false;
  String? _error;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    final cleaned = widget.group.label
        .replaceAll(RegExp(r'[\[{][^\]}]*[\]}]'), ' ')
        .replaceAll(RegExp(r'\((?:18|19|20)\d{2}\)\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    _searchCtrl = TextEditingController(text: cleaned);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  (String label, bool warn) get _badgeMeta => switch (widget.group.code) {
        'tmdb_unreachable' => ('TMDB 不可达', true),
        'kind_mismatch' => ('放错库了', true),
        'ambiguous' => ('${widget.group.candidates.length} 个候选', false),
        'no_match' => ('TMDB 无匹配', false),
        'unparsable' => ('无法解析片名', false),
        _ => widget.group.candidates.isEmpty
            ? ('未匹配', false)
            : ('${widget.group.candidates.length} 个候选', false),
      };

  Future<void> _selectCandidate(int tmdbId, String title, int? year) async {
    if (_selectedTmdbId == tmdbId) {
      setState(() {
        _selectedTmdbId = null;
        _previewDetail = null;
      });
      return;
    }
    setState(() {
      _showSearch = false;
      _selectedTmdbId = tmdbId;
      _selectedTitle = title;
      _selectedYear = year;
      _seasonNumber = null;
      _previewDetail = null;
      _error = null;
    });
    final titleRef = 'tmdb:${widget.isMovie ? 'movie' : 'tv'}:$tmdbId';
    try {
      final d = await ref.read(libraryApiProvider).discoverTitleDetails(titleRef);
      if (!mounted || _selectedTmdbId != tmdbId) return;
      setState(() => _previewDetail = d);
    } catch (_) {}
  }

  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty || _searching) return;
    // 直接输入纯数字视为 TMDB ID
    if (RegExp(r'^\d{1,10}$').hasMatch(q)) {
      final id = int.tryParse(q);
      if (id != null) {
        await _selectCandidate(id, 'TMDB #$id', null);
      }
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final res = await ref.read(libraryApiProvider).searchTmdbTitles(
            q,
            mediaType: widget.isMovie ? 'movie' : 'tv',
          );
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchResults = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _confirmClaim() async {
    final tmdbId = _selectedTmdbId;
    if (tmdbId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final titleRef = 'tmdb:${widget.isMovie ? 'movie' : 'tv'}:$tmdbId';
      await ref.read(libraryApiProvider).assignFileTitle(
            fileIds: widget.group.files.map((f) => f.id).toList(),
            titleRef: titleRef,
            seasonNumber: widget.isMovie ? null : _seasonNumber,
          );
      McToast.success('认领成功');
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ignoreGroup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(libraryApiProvider);
      for (final f in widget.group.files) {
        await api.ignoreIssue(f.id);
      }
      McToast.success('已忽略该组文件');
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final (badgeLabel, warn) = _badgeMeta;
    final detailTitle = _previewDetail?['title'] is Map
        ? Map<String, dynamic>.from(_previewDetail!['title'] as Map)
        : const <String, dynamic>{};
    final seasonCount =
        (detailTitle['season_count'] is num)
            ? (detailTitle['season_count'] as num).toInt()
            : 0;
    final seasons = <int>[
      for (var s = 1; s <= seasonCount.clamp(0, 30); s++) s,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Text(
                  g.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  McIcons.more,
                  size: 18,
                  color: McTokens.textMuted,
                ),
                onSelected: (v) {
                  if (v == 'files') {
                    setState(() => _expandedFiles = !_expandedFiles);
                  } else if (v == 'ignore') {
                    _ignoreGroup();
                  }
                },
                itemBuilder: (_) => [
                  if (g.fileCount > 1)
                    PopupMenuItem(
                      value: 'files',
                      child: Text(_expandedFiles ? '收起文件清单' : '查看文件清单'),
                    ),
                  const PopupMenuItem(value: 'ignore', child: Text('忽略此组')),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: warn
                      ? McTokens.warning.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: warn ? McTokens.warning : McTokens.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${g.fileCount} 个文件 · ${mcFormatBytes(g.totalSizeBytes)}',
                style: McText.caption.faint,
              ),
              const Spacer(),
              McChip(
                label: _showSearch ? '收起搜索' : '搜索 TMDB',
                icon: McIcons.search,
                compact: true,
                selected: _showSearch,
                onTap: _busy
                    ? null
                    : () => setState(() {
                          _showSearch = !_showSearch;
                          if (_showSearch) _selectedTmdbId = null;
                        }),
              ),
            ],
          ),
          if (g.candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in g.candidates)
                  McChip(
                    label:
                        '${c.title}${c.year != null ? ' (${c.year})' : ''}${(c.episodeCount ?? 0) > 0 ? ' · ${c.episodeCount}集' : ''}',
                    compact: true,
                    selected: _selectedTmdbId == c.tmdbId,
                    onTap: _busy
                        ? null
                        : () => _selectCandidate(c.tmdbId, c.title, c.year),
                  ),
              ],
            ),
          ],
          if (_showSearch) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: McText.body,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '输入片名或直接粘贴 TMDB ID',
                    ),
                    onSubmitted: (_) => _doSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                McActionPill(
                  label: _searching ? '搜索中…' : '搜索',
                  height: 36,
                  onTap: _searching ? null : _doSearch,
                ),
              ],
            ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final r in _searchResults.take(8))
                InkWell(
                  onTap: () {
                    final id = int.tryParse(r['external_id']?.toString() ?? '');
                    if (id == null) return;
                    _selectCandidate(
                      id,
                      r['title']?.toString() ?? '',
                      r['release_year'] is num
                          ? (r['release_year'] as num).toInt()
                          : null,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 28,
                            height: 42,
                            child: LibraryNetImage(
                              url: r['poster_url']?.toString(),
                              widthPx: 160,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${r['title'] ?? ''}${r['release_year'] != null ? ' (${r['release_year']})' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.body.copyWith(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
          if (_selectedTmdbId != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: McTokens.lineStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 48,
                          height: 72,
                          child: LibraryNetImage(
                            url: detailTitle['poster_url']?.toString(),
                            widthPx: 160,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${detailTitle['title'] ?? _selectedTitle ?? ''}${_selectedYear != null ? ' ($_selectedYear)' : ''}',
                              style: McText.body
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'TMDB #$_selectedTmdbId',
                              style: McText.caption.faint,
                            ),
                            if ((detailTitle['overview']?.toString() ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                detailTitle['overview'].toString(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: McText.caption.muted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 剧集认领可选指定季数
                  if (!widget.isMovie) ...[
                    const SizedBox(height: 8),
                    Text('指定归属季（可选，留空由文件名自动解析）：',
                        style: McText.caption.muted),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: McChip(
                              label: '自动解析',
                              compact: true,
                              selected: _seasonNumber == null,
                              onTap: () => setState(() => _seasonNumber = null),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: McChip(
                              label: '特别篇 (S00)',
                              compact: true,
                              selected: _seasonNumber == 0,
                              onTap: () => setState(() => _seasonNumber = 0),
                            ),
                          ),
                          for (final s in (seasons.isEmpty ? [1, 2, 3, 4, 5] : seasons))
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: McChip(
                                label: '第 $s 季',
                                compact: true,
                                selected: _seasonNumber == s,
                                onTap: () => setState(() => _seasonNumber = s),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      McActionPill(
                        label: '取消',
                        height: 32,
                        onTap: _busy
                            ? null
                            : () => setState(() => _selectedTmdbId = null),
                      ),
                      const SizedBox(width: 8),
                      McActionPill(
                        label: g.fileCount > 1
                            ? '认领全部 ${g.fileCount} 个文件'
                            : '确认认领',
                        primary: true,
                        height: 32,
                        onTap: _busy ? null : _confirmClaim,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_expandedFiles) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: McTokens.line),
            const SizedBox(height: 6),
            for (final f in g.files)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: SelectableText(
                  f.filePath,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: McTokens.textFaint,
                  ),
                ),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(fontSize: 11, color: McTokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/* ── 身份复核组（并排对比当前 vs 建议 + 采纳/维持） ── */

class _ReviewIssueCard extends ConsumerStatefulWidget {
  const _ReviewIssueCard({
    required this.group,
    required this.isMovie,
    required this.onChanged,
  });

  final ReviewGroupView group;
  final bool isMovie;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_ReviewIssueCard> createState() => _ReviewIssueCardState();
}

class _ReviewIssueCardState extends ConsumerState<_ReviewIssueCard> {
  bool _busy = false;
  String? _error;

  Future<void> _decide(String decision) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(libraryApiProvider).confirmReview(
            fileIds: widget.group.fileIds,
            decision: decision,
          );
      McToast.success(
        decision == 'accept_suggestion' ? '已采纳新身份' : '已维持当前身份',
      );
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _side(ReviewItemView info, {required bool suggestion}) {
    const tint = Color(0xFFC4B5FD);
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36,
              height: 54,
              child: LibraryNetImage(url: info.posterUrl, widthPx: 160),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion ? '建议新身份' : '当前身份',
                  style: McText.caption.faint,
                ),
                Text(
                  '${info.title}${info.year != null ? ' (${info.year})' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: suggestion ? tint : McTokens.text,
                  ),
                ),
                if (info.tmdbId != null)
                  Text('tmdb ${info.tmdbId}', style: McText.caption.faint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            g.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: McText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            '${g.fileCount} 个文件 · ${mcFormatBytes(g.totalSizeBytes)}',
            style: McText.caption.faint,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _side(g.current, suggestion: false),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('→', style: TextStyle(color: McTokens.textFaint)),
              ),
              _side(g.suggestion, suggestion: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              McActionPill(
                label: '采纳新身份',
                primary: true,
                height: 32,
                onTap: _busy ? null : () => _decide('accept_suggestion'),
              ),
              const SizedBox(width: 8),
              McActionPill(
                label: '维持现状',
                height: 32,
                onTap: _busy ? null : () => _decide('keep_current'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(fontSize: 11, color: McTokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/* ── 已忽略组（恢复） ── */

class _IgnoredIssueCard extends ConsumerStatefulWidget {
  const _IgnoredIssueCard({
    required this.group,
    required this.onChanged,
  });

  final UnidentifiedGroupView group;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_IgnoredIssueCard> createState() => _IgnoredIssueCardState();
}

class _IgnoredIssueCardState extends ConsumerState<_IgnoredIssueCard> {
  bool _busy = false;
  bool _expanded = false;
  String? _error;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(libraryApiProvider).unignoreIssue(
            widget.group.files.map((f) => f.id).toList(),
          );
      McToast.success('已恢复至待识别列表');
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            g.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: McText.body.muted,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${g.fileCount} 个文件 · ${mcFormatBytes(g.totalSizeBytes)}',
                style: McText.caption.faint,
              ),
              const Spacer(),
              if (g.fileCount > 1)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? '收起文件' : '查看文件'),
                ),
              McActionPill(
                label: '恢复',
                height: 30,
                onTap: _busy ? null : _restore,
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(height: 12, color: McTokens.line),
            for (final f in g.files)
              Text(
                f.filePath,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: McTokens.textFaint,
                ),
              ),
          ],
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(fontSize: 11, color: McTokens.danger),
            ),
        ],
      ),
    );
  }
}
