import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../../../core/navigation/external_media_link.dart';
import '../state/detail_controller.dart';

export 'subtitle_gen_sheet.dart' show showSubtitleGenSheet;

/// 1) 可配置外链分享弹层（支持 1/3/7/30 天有效期、可选密码、一键复制、系统分享与吊销）。
Future<void> showConfigurableShareSheet({
  required BuildContext context,
  required DetailController controller,
  required String itemTitle,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => _ShareSheet(controller: controller, itemTitle: itemTitle),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.controller, required this.itemTitle});

  final DetailController controller;
  final String itemTitle;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final TextEditingController _pwd = TextEditingController();
  int _days = 7;
  bool _loading = true;
  bool _submitting = false;
  String? _activeUrl;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadExisting);
  }

  @override
  void dispose() {
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final info = await widget.controller.getShareInfo();
    if (!mounted) return;
    var url = info?['url']?.toString() ?? '';
    if (url.isEmpty && info?['slug'] != null) {
      url = '/s/${info!['slug']}';
    }
    setState(() {
      _activeUrl = url.isEmpty ? null : url;
      _loading = false;
    });
  }

  Future<void> _generate() async {
    setState(() => _submitting = true);
    final err = StringBuffer();
    final url = await widget.controller.createShareLink(
      expiresInDays: _days,
      password: _pwd.text,
      err: err,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (url != null) _activeUrl = url;
    });
    if (url == null) {
      McToast.error('生成失败：${err.isEmpty ? '未知错误' : err}');
    } else {
      Clipboard.setData(ClipboardData(text: url));
      McToast.success('分享链接已生成并复制到剪贴板');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: _loading
          ? const SizedBox(height: 150, child: McLoadingView())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('分享「${widget.itemTitle}」', style: McText.titleSm),
                const SizedBox(height: 6),
                Text(
                  '接收方无需注册账号即可在浏览器或客户端直接播放。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 14),
                Text('有效期', style: McText.caption.muted),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in const [1, 3, 7, 30])
                      McChip(
                        label: '$d 天',
                        compact: true,
                        selected: _days == d,
                        onTap: () => setState(() => _days = d),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pwd,
                  style: McText.body,
                  decoration: const InputDecoration(
                    labelText: '访问密码（留空则免密直接观看）',
                    isDense: true,
                  ),
                ),
                if (_activeUrl != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: McTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: McTokens.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _activeUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.caption.copyWith(color: McTokens.ok),
                          ),
                        ),
                        const SizedBox(width: 8),
                        McChip(
                          label: '复制',
                          compact: true,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _activeUrl!));
                            McToast.success('已复制链接');
                          },
                        ),
                        const SizedBox(width: 6),
                        McChip(
                          label: '系统分享',
                          compact: true,
                          onTap: () => Share.share(
                            _activeUrl!,
                            subject: widget.itemTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (_activeUrl != null) ...[
                      Expanded(
                        child: McActionPill(
                          label: '吊销分享',
                          primary: false,
                          tone: McGlassTone.danger,
                          expanded: true,
                          onTap: () async {
                            final err = await widget.controller.revokeShare();
                            if (!context.mounted) return;
                            if (err != null) {
                              McToast.error(err);
                            } else {
                              McToast.success('外链已吊销');
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: McActionPill(
                        label: _activeUrl == null ? '生成分享链接' : '更新链接配置',
                        icon: McIcons.share,
                        primary: true,
                        expanded: true,
                        busy: _submitting,
                        onTap: _submitting ? null : _generate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// 2) 加入片单合集弹层（支持一键加入已有合集或直接新建合集）。
Future<void> showAddToCollectionSheet({
  required BuildContext context,
  required DetailController controller,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => _AddToCollectionSheet(controller: controller),
  );
}

class _AddToCollectionSheet extends StatefulWidget {
  const _AddToCollectionSheet({required this.controller});

  final DetailController controller;

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  final TextEditingController _newCtrl = TextEditingController();
  List<Map<String, dynamic>>? _cols;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final list = await widget.controller.listEditableCollections();
        if (mounted) setState(() => _cols = list);
      } catch (_) {
        if (mounted) setState(() => _cols = const []);
      }
    });
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cols = _cols;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('加入片单合集', style: McText.titleSm),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCtrl,
                  style: McText.body,
                  decoration: const InputDecoration(
                    hintText: '或直接输入名称新建合集…',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              McChip(
                label: '新建并收入',
                selected: true,
                onTap: () async {
                  final name = _newCtrl.text.trim();
                  if (name.isEmpty) return;
                  final err =
                      await widget.controller.createCollectionWithItem(name);
                  if (!context.mounted) return;
                  if (err != null) {
                    McToast.error(err);
                  } else {
                    McToast.success('已新建合集「$name」并收入此片');
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (cols == null)
            const SizedBox(height: 120, child: McLoadingView())
          else if (cols.isEmpty)
            Text('暂无已有手动合集，可在上方输入名称新建。', style: McText.caption.muted)
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final c in cols)
                      McInsetRow(
                        icon: McIcons.stack,
                        title: (c['name'] ?? '').toString(),
                        subtitle: '${c['item_count'] ?? 0} 部',
                        onTap: () async {
                          final id = (c['id'] as num? ?? 0).toInt();
                          if (id <= 0) return;
                          final err =
                              await widget.controller.addToCollection(id);
                          if (!context.mounted) return;
                          if (err != null) {
                            McToast.error(err);
                          } else {
                            McToast.success('已加入合集「${c['name']}」');
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 3) 海报 / 剧照 / 透明 Logo 候选更换弹层（1:1 对齐 iOS `ArtworkPickerSheet.swift`）：
/// - 展示手动锁定状态条 + 「恢复自动选择」解锁按钮（`file_path: null`）；
/// - 标出「当前」在用图片与「无字」剧照标识及尺寸/语言说明；
/// - 切换后静默刷新候选态而不强行关闭弹层，支持连续挑图。
Future<void> showArtworkPickerSheet({
  required BuildContext context,
  required DetailController controller,
}) {
  return showMcSheet<void>(
    context: context,
    maxWidth: 640,
    builder: (_) => _ArtworkPickerSheet(controller: controller),
  );
}

class _ArtworkPickerSheet extends StatefulWidget {
  const _ArtworkPickerSheet({required this.controller});

  final DetailController controller;

  @override
  State<_ArtworkPickerSheet> createState() => _ArtworkPickerSheetState();
}

class _ArtworkPickerSheetState extends State<_ArtworkPickerSheet> {
  String _kind = 'backdrop';
  Map<String, dynamic>? _raw;
  String? _error;
  String? _saveError;
  String? _applying;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _raw = null;
        _error = null;
      });
    }
    try {
      final d = await widget.controller.fetchArtworkCandidates();
      if (mounted) {
        setState(() {
          _raw = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '加载图片候选失败：$e');
    }
  }

  List<Map<String, dynamic>> _candidatesFor(String kind) {
    final r = _raw;
    if (r == null) return const [];
    final key = switch (kind) {
      'backdrop' => r['backdrops'] ?? r['backdrop'],
      'logo' => r['logos'] ?? r['logo'],
      _ => r['posters'] ?? r['poster'],
    };
    if (key is List) {
      return key.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return const [];
  }

  bool _isLocked(String kind) {
    final r = _raw;
    if (r == null) return false;
    return switch (kind) {
      'backdrop' => r['backdrop_locked'] == true,
      'logo' => r['logo_locked'] == true,
      _ => r['poster_locked'] == true,
    };
  }

  String? _currentPath(String kind) {
    final r = _raw;
    if (r == null) return null;
    return switch (kind) {
      'backdrop' => J.s(r, ['current_backdrop']),
      'logo' => J.s(r, ['current_logo']),
      _ => J.s(r, ['current_poster']),
    };
  }

  Future<void> _apply(String? filePath) async {
    if (_applying != null) return;
    setState(() {
      _applying = filePath ?? '__unlock__';
      _saveError = null;
    });
    final err = filePath == null
        ? await widget.controller.unlockArtwork(_kind)
        : await widget.controller.selectArtwork(
            kind: _kind,
            filePath: filePath,
          );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _applying = null;
        _saveError = err;
      });
      return;
    }
    McToast.success(filePath == null ? '已恢复自动选图' : '已更换并锁定当前图片');
    setState(() => _applying = null);
    await _load(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    final list = _candidatesFor(_kind);
    final isPoster = _kind == 'poster';
    final locked = _isLocked(_kind);
    final current = _currentPath(_kind);
    final kindTitle = switch (_kind) {
      'backdrop' => '横版剧照',
      'logo' => '透明 Logo',
      _ => '竖版海报',
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('更换海报与剧照', style: McText.titleSm)),
                McPressable(
                  onTap: _applying != null
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '完成',
                      style: McText.sub.copyWith(
                        color: McTokens.accentStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '点选任意候选图将立即落盘并加锁，此后刷新元数据不会覆盖你的选择。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (k, label) in const [
                  ('backdrop', '横版剧照'),
                  ('poster', '竖版海报'),
                  ('logo', '透明 Logo'),
                ]) ...[
                  McChip(
                    label: label,
                    compact: true,
                    selected: _kind == k,
                    onTap: () => setState(() => _kind = k),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            if (locked) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: McTokens.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: McTokens.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      McIcons.fileLock,
                      size: 15,
                      color: McTokens.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$kindTitle已手动锁定，刷新时不会自动替换',
                        style: McText.caption.copyWith(color: McTokens.info),
                      ),
                    ),
                    const SizedBox(width: 8),
                    McPressable(
                      onTap: _applying != null ? null : () => _apply(null),
                      child: Text(
                        _applying == '__unlock__' ? '恢复中…' : '恢复自动选择',
                        style: McText.caption.copyWith(
                          color: McTokens.accentStrong,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(
                _saveError!,
                style: McText.caption.copyWith(color: McTokens.danger),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _raw == null && _error == null
                  ? const McLoadingView()
                  : _error != null
                      ? McErrorView(
                          text: _error!,
                          onRetry: () => _load(reset: _raw == null),
                        )
                      : list.isEmpty
                          ? const McEmptyView(text: '上游暂无更多候选图片')
                          : GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isPoster ? 3 : 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: isPoster ? 0.67 : 1.77,
                              ),
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final c = list[i];
                                final url = (c['preview_url'] ??
                                        c['url'] ??
                                        c['file_path'] ??
                                        '')
                                    .toString();
                                final fp = (c['file_path'] ?? c['path'] ?? url)
                                    .toString();
                                final isCurrent = (current != null &&
                                        fp == current) ||
                                    c['selected'] == true;
                                final w = J.i(c, ['width']);
                                final h = J.i(c, ['height']);
                                final lang = J.s(c, ['language']);
                                final caption = [
                                  if (w != null && h != null) '$w×$h',
                                  if (lang != null && lang.isNotEmpty) lang,
                                ].join(' · ');
                                final busyThis = _applying == fp;

                                return McPressable(
                                  onTap: _applying != null
                                      ? null
                                      : () => _apply(fp),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _kind == 'logo'
                                          ? const Color(0xFF1A1E29)
                                          : McTokens.posterPlaceholder,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCurrent
                                            ? McTokens.accentStrong
                                            : McTokens.line,
                                        width: isCurrent ? 2 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Padding(
                                          padding: _kind == 'logo'
                                              ? const EdgeInsets.all(10)
                                              : EdgeInsets.zero,
                                          child: CachedNetworkImage(
                                            imageUrl: McImageUrls.resolve(
                                              url,
                                              widthPx: 480,
                                            ),
                                            httpHeaders: mcImageHeaders(),
                                            fit: _kind == 'logo'
                                                ? BoxFit.contain
                                                : BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                const ColoredBox(
                                              color: McTokens.posterPlaceholder,
                                            ),
                                          ),
                                        ),
                                        if (isCurrent)
                                          Positioned(
                                            left: 6,
                                            top: 6,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: McTokens.accentStrong,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '当前',
                                                style: McText.micro.copyWith(
                                                  color: McTokens.onAccent,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (_kind == 'backdrop' && lang == null)
                                          Positioned(
                                            right: 6,
                                            top: 6,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xB3000000),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '无字',
                                                style: McText.micro.copyWith(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (caption.isNotEmpty)
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                6,
                                                12,
                                                6,
                                                4,
                                              ),
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Color(0xCC000000),
                                                    Color(0x00000000),
                                                  ],
                                                ),
                                              ),
                                              child: Text(
                                                caption,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: McText.micro
                                                    .copyWith(
                                                      color: Colors.white
                                                          .withValues(
                                                        alpha: 0.8,
                                                      ),
                                                    )
                                                    .tabular,
                                              ),
                                            ),
                                          ),
                                        if (busyThis)
                                          const ColoredBox(
                                            color: Color(0x8C000000),
                                            child: Center(
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4) 两阶段修正词条识别弹层（1:1 对齐 iOS `ReidentifySheet.swift` + `IssueClaimPanels.swift`）：
/// - Stage 1：打开即调 `POST .../reidentification-preview` 展示当前身份、告警、分组结论；
/// - Stage 2：每组支持采用机器结论、跨 movie↔tv 关键词 / TMDB ID / TMDB URL 搜索、
///   剧集指定季号确认面板、以及逐文件勾选「标为花絮/特典 (Extras)」！
Future<void> showReidentifySheet({
  required BuildContext context,
  required DetailController controller,
  required String initialTitle,
  VoidCallback? onApplied,
}) {
  return showMcSheet<void>(
    context: context,
    maxWidth: 620,
    builder: (_) => _ReidentifySheet(
      controller: controller,
      initialTitle: initialTitle,
      onApplied: onApplied,
    ),
  );
}

class _ReidentifySheet extends StatefulWidget {
  const _ReidentifySheet({
    required this.controller,
    required this.initialTitle,
    this.onApplied,
  });

  final DetailController controller;
  final String initialTitle;
  final VoidCallback? onApplied;

  @override
  State<_ReidentifySheet> createState() => _ReidentifySheetState();
}

class _ReidentifySheetState extends State<_ReidentifySheet> {
  Map<String, dynamic>? _preview;
  String? _error;
  bool _loading = true;
  final Map<String, String> _settled = {};
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPreview);
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
      _settled.clear();
    });
    try {
      final p = await widget.controller.reidentifyPreview();
      if (!mounted) return;
      setState(() {
        _preview = p;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.friendlyMessage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '预览识别结果失败：$e';
        _loading = false;
      });
    }
  }

  void _close() {
    Navigator.of(context).pop();
    if (_dirty) {
      widget.onApplied?.call();
      unawaited(widget.controller.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final current = p == null ? const <String, dynamic>{} : J.map(p, 'current');
    final movie = p?['movie'] != false;
    final unreachable = p?['unreachable'] == true;
    final pinned = p?['pinned_identity'] == true;
    final skippedMissing = J.i(p ?? const {}, ['skipped_missing']) ?? 0;
    final searchSeed =
        J.s(p ?? const {}, ['search_seed']) ?? widget.initialTitle;
    final groups = p == null ? const <Map<String, dynamic>>[] : J.listOfMap(p, ['groups']);
    final allSettled = groups.isNotEmpty &&
        groups.every((g) => _settled.containsKey((g['key'] ?? '').toString()));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _dirty) {
          widget.onApplied?.call();
          unawaited(widget.controller.load());
        }
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('手动修正词条识别', style: McText.titleSm)),
                  McGlassIconButton(
                    icon: McIcons.close,
                    iconSize: 16,
                    onTap: _close,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '先预览识别结论，由你确认或手动搜索后再写入台账；关闭窗口不会改动任何数据。',
                style: McText.caption.muted,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _loading
                    ? const SizedBox(height: 180, child: McLoadingView())
                    : _error != null
                        ? McErrorView(text: _error!, onRetry: _loadPreview)
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCurrentCard(current, movie),
                                if (unreachable) ...[
                                  const SizedBox(height: 10),
                                  _warnBox(
                                    McTokens.warning,
                                    '部分文件因 TMDB 暂不可达未得出结论，建议网络恢复后再重试。',
                                  ),
                                ],
                                if (pinned) ...[
                                  const SizedBox(height: 10),
                                  _warnBox(
                                    McTokens.textMuted,
                                    '该条目身份由目录名 [tmdbid=…] 或本地 NFO 固定，修改后若未更新本地标记，重新扫描可能会还原。',
                                  ),
                                ],
                                const SizedBox(height: 12),
                                if (groups.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '当前条目下没有可重新识别的在位文件。',
                                        style: McText.sub.muted,
                                      ),
                                    ),
                                  )
                                else
                                  for (final g in groups) ...[
                                    _ReidentifyGroupCard(
                                      controller: widget.controller,
                                      group: g,
                                      defaultMovie: movie,
                                      searchSeed: searchSeed,
                                      settledMessage:
                                          _settled[(g['key'] ?? '').toString()],
                                      onSettled: (msg) {
                                        setState(() {
                                          _settled[(g['key'] ?? '').toString()] =
                                              msg;
                                          _dirty = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                if (skippedMissing > 0)
                                  Text(
                                    '已跳过 $skippedMissing 个磁盘缺失文件（保持原归属）。',
                                    style: McText.micro.faint,
                                  ),
                              ],
                            ),
                          ),
              ),
              const SizedBox(height: 8),
              Text(
                allSettled
                    ? '所有分组均已处理完毕，关闭窗口后详情页将自动刷新。'
                    : '提示：支持直接粘贴 TMDB 链接（如 themoviedb.org/tv/1396）或纯数字 ID。',
                style: McText.micro.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentCard(Map<String, dynamic> current, bool movie) {
    final title = J.s(current, ['title', 'name']) ?? widget.initialTitle;
    final year = J.i(current, ['year']);
    final tmdbId = J.i(current, ['tmdb_id']);
    final poster = J.s(current, ['poster_url']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 64,
            decoration: BoxDecoration(
              color: McTokens.posterPlaceholder,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: poster != null && poster.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: McImageUrls.resolve(poster, widthPx: 140),
                    httpHeaders: mcImageHeaders(),
                    fit: BoxFit.cover,
                  )
                : const Icon(McIcons.film, size: 20, color: McTokens.textFaint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前识别身份', style: McText.micro.faint),
                const SizedBox(height: 2),
                Text(
                  year != null ? '$title ($year)' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tmdbId != null && tmdbId > 0) ...[
                  const SizedBox(height: 3),
                  McPressable(
                    onTap: () => ExternalMediaLink.open(
                      'https://www.themoviedb.org/${movie ? 'movie' : 'tv'}/$tmdbId',
                    ),
                    child: Text(
                      'TMDB #$tmdbId ↗',
                      style: McText.micro.copyWith(
                        color: McTokens.accent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _warnBox(Color color, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: McText.caption.copyWith(color: color)),
      );
}

class _ReidentifyGroupCard extends StatefulWidget {
  const _ReidentifyGroupCard({
    required this.controller,
    required this.group,
    required this.defaultMovie,
    required this.searchSeed,
    required this.settledMessage,
    required this.onSettled,
  });

  final DetailController controller;
  final Map<String, dynamic> group;
  final bool defaultMovie;
  final String searchSeed;
  final String? settledMessage;
  final ValueChanged<String> onSettled;

  @override
  State<_ReidentifyGroupCard> createState() => _ReidentifyGroupCardState();
}

class _ReidentifyGroupCardState extends State<_ReidentifyGroupCard> {
  late final TextEditingController _query =
      TextEditingController(text: widget.searchSeed);
  final TextEditingController _seasonCtrl = TextEditingController();
  late String _searchKind = widget.defaultMovie ? 'movie' : 'tv';
  late Set<int> _selectedFileIds;

  bool _showSearch = false;
  bool _searching = false;
  bool _busy = false;
  bool _showFileCheckboxes = false;
  String? _error;
  List<Map<String, dynamic>>? _hits;
  Map<String, dynamic>? _confirmSeed;
  Map<String, dynamic>? _confirmDetail;

  List<int> get _groupFileIds => J.intList(widget.group, ['file_ids']);

  @override
  void initState() {
    super.initState();
    _selectedFileIds = _groupFileIds.toSet();
  }

  @override
  void dispose() {
    _query.dispose();
    _seasonCtrl.dispose();
    super.dispose();
  }

  /// 解析 TMDB 链接或纯数字 ID（如 `https://www.themoviedb.org/tv/1396-breaking-bad` 或 `1396`）。
  ({String kind, int id})? _parseTmdbInput(String raw) {
    final trimmed = raw.trim();
    if (RegExp(r'^\d{1,10}$').hasMatch(trimmed)) {
      return (kind: _searchKind, id: int.parse(trimmed));
    }
    final m = RegExp(
      r'themoviedb\.org/(movie|tv)/(\d+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (m != null) {
      return (kind: m.group(1)!.toLowerCase(), id: int.parse(m.group(2)!));
    }
    final refM = RegExp(
      r'^tmdb:(movie|tv):(\d+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (refM != null) {
      return (kind: refM.group(1)!.toLowerCase(), id: int.parse(refM.group(2)!));
    }
    return null;
  }

  Future<void> _search() async {
    final raw = _query.text.trim();
    if (raw.isEmpty || _searching) return;
    final direct = _parseTmdbInput(raw);
    if (direct != null) {
      setState(() => _searchKind = direct.kind);
      await _openConfirm({
        'tmdb_id': direct.id,
        'media_type': direct.kind,
        'title': 'TMDB #${direct.id}',
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final res = await widget.controller.searchReidentifyCandidates(
        raw,
        mediaType: _searchKind,
      );
      if (!mounted) return;
      setState(() {
        _hits = res;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '搜索失败：$e';
        _searching = false;
      });
    }
  }

  Future<void> _openConfirm(Map<String, dynamic> seed) async {
    final id = J.i(seed, ['tmdb_id', 'external_id', 'id']);
    if (id == null || id <= 0) return;
    final kind = J.s(seed, ['media_type', 'kind']) ?? _searchKind;
    setState(() {
      _confirmSeed = {...seed, 'tmdb_id': id, 'media_type': kind};
      _confirmDetail = null;
      _showSearch = false;
      _error = null;
    });
    final det =
        await widget.controller.fetchDiscoverTitleDetails('tmdb:$kind:$id');
    if (mounted && _confirmSeed?['tmdb_id'] == id) {
      setState(() => _confirmDetail = det);
    }
  }

  Future<void> _applyAssign() async {
    final seed = _confirmSeed;
    final targetIds = _selectedFileIds.toList();
    if (seed == null || targetIds.isEmpty || _busy) return;
    final kind = (seed['media_type'] ?? _searchKind).toString();
    final id = J.i(seed, ['tmdb_id']) ?? 0;
    final title = J.s(
          J.map(_confirmDetail ?? const {}, 'title'),
          ['title', 'name'],
        ) ??
        J.s(seed, ['title', 'name']) ??
        'TMDB #$id';
    final seasonNum =
        kind == 'tv' ? int.tryParse(_seasonCtrl.text.trim()) : null;

    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.controller.assignFilesToTitle(
      fileIds: targetIds,
      titleRef: 'tmdb:$kind:$id',
      seasonNumber: seasonNum,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      widget.onSettled('已将 ${targetIds.length} 个文件归属到《$title》');
    }
  }

  Future<void> _markExtras() async {
    final targetIds = _selectedFileIds.toList();
    if (targetIds.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.controller.markFilesAsExtras(targetIds);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      widget.onSettled('已将 ${targetIds.length} 个文件标为花絮/特典（未删除磁盘文件）');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settledMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: McTokens.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: McTokens.accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          '✓ ${widget.settledMessage!}',
          style: McText.sub.copyWith(color: McTokens.text),
        ),
      );
    }

    final fileCount = J.i(widget.group, ['file_count']) ?? _groupFileIds.length;
    final totalBytes = J.i(widget.group, ['total_size_bytes']) ?? 0;
    final sampleNames = J.list(widget.group, ['sample_names']);
    final outcome = J.map(widget.group, 'outcome');
    final outcomeMediaId = J.i(outcome, ['media_item_id']);
    final outcomeTmdbId = J.i(outcome, ['tmdb_id']);
    final sameAsCurrent = outcome['same_as_current'] == true;
    final candidates = J.listOfMap(outcome, ['candidates']);
    final allFiles =
        widget.controller.current.entry?.files ?? const <DetailFileInfo>[];
    final groupFiles = allFiles.where((f) => _groupFileIds.contains(f.id)).toList();

    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(
                '$fileCount 个文件 · ${mcFormatBytes(totalBytes)}',
                style: McText.sub
                    .copyWith(color: McTokens.text, fontWeight: FontWeight.w600)
                    .tabular,
              ),
              const Spacer(),
              if (groupFiles.length > 1)
                McPressable(
                  onTap: () =>
                      setState(() => _showFileCheckboxes = !_showFileCheckboxes),
                  child: Text(
                    _showFileCheckboxes
                        ? '收起文件勾选'
                        : '勾选文件 (${_selectedFileIds.length}/$fileCount)',
                    style: McText.micro.copyWith(color: McTokens.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (_showFileCheckboxes && groupFiles.isNotEmpty)
            Column(
              children: [
                for (final f in groupFiles)
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_selectedFileIds.contains(f.id)) {
                          if (_selectedFileIds.length > 1) {
                            _selectedFileIds.remove(f.id);
                          }
                        } else {
                          _selectedFileIds.add(f.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _selectedFileIds.contains(f.id)
                                ? McIcons.checkCircleFill
                                : McIcons.circler,
                            size: 16,
                            color: _selectedFileIds.contains(f.id)
                                ? McTokens.accentStrong
                                : McTokens.textFaint,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.micro.copyWith(
                                fontFamily: 'monospace',
                                color: McTokens.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else
            Text(
              sampleNames.join('、') +
                  (fileCount > sampleNames.length ? ' …' : ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: McText.micro.copyWith(
                fontFamily: 'monospace',
                color: McTokens.textFaint,
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: McTokens.line),
          ),
          if (outcomeMediaId != null)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sameAsCurrent ? '机器结论与现身份相同' : '机器识别新结论',
                        style: McText.micro.faint,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${outcome['title'] ?? ''}'
                        '${outcome['year'] != null ? ' (${outcome['year']})' : ''}',
                        style: McText.sub.copyWith(
                          color: McTokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!sameAsCurrent && outcomeTmdbId != null)
                  McChip(
                    label: '应用新结论',
                    selected: true,
                    compact: true,
                    onTap: _busy
                        ? null
                        : () => _openConfirm({
                              'tmdb_id': outcomeTmdbId,
                              'media_type': widget.defaultMovie ? 'movie' : 'tv',
                              'title': outcome['title'] ?? '',
                              'year': outcome['year'],
                              'poster_url': outcome['poster_url'],
                            }),
                  ),
              ],
            )
          else
            Text(
              '未自动命中：${outcome['reason'] ?? outcome['code'] ?? '请手动搜索正确词条'}',
              style: McText.caption.muted,
            ),
          if (candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in candidates)
                  McChip(
                    label:
                        '${c['title'] ?? ''}${c['year'] != null ? ' (${c['year']})' : ''}',
                    compact: true,
                    selected: _confirmSeed?['tmdb_id'] == J.i(c, ['tmdb_id']),
                    onTap: _busy
                        ? null
                        : () => _openConfirm({
                              ...c,
                              'media_type': widget.defaultMovie ? 'movie' : 'tv',
                            }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              McChip(
                label: _showSearch ? '收起搜索' : '手动搜索 TMDB…',
                icon: McIcons.search,
                compact: true,
                selected: _showSearch,
                onTap: _busy
                    ? null
                    : () => setState(() {
                          _showSearch = !_showSearch;
                          if (_showSearch) _confirmSeed = null;
                        }),
              ),
              const Spacer(),
              McPressable(
                onTap: _busy ? null : _markExtras,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: McTokens.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: McTokens.danger.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '标为花絮/特典 (${_selectedFileIds.length})',
                    style: McText.micro.copyWith(
                      color: const Color(0xFFFFB4B4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ],
          if (_showSearch) ...[
            const SizedBox(height: 10),
            _buildSearchPanel(),
          ],
          if (_confirmSeed != null) ...[
            const SizedBox(height: 10),
            _buildConfirmPanel(_confirmSeed!),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    final direct = _parseTmdbInput(_query.text);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              McChip(
                label: '电影',
                compact: true,
                selected: _searchKind == 'movie',
                onTap: () => setState(() => _searchKind = 'movie'),
              ),
              const SizedBox(width: 6),
              McChip(
                label: '剧集',
                compact: true,
                selected: _searchKind == 'tv',
                onTap: () => setState(() => _searchKind = 'tv'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  style: McText.sub.copyWith(color: McTokens.text),
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: '输入片名、TMDB ID 或粘贴 TMDB 链接…',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              McChip(
                label: direct != null
                    ? '直达 #${direct.id}'
                    : (_searching ? '搜索中' : '搜索'),
                selected: true,
                compact: true,
                onTap: _searching ? null : _search,
              ),
            ],
          ),
          if (_hits != null) ...[
            const SizedBox(height: 8),
            if (_hits!.isEmpty)
              Text('未找到匹配结果，可尝试更换关键词或直接粘贴 TMDB 链接/ID。', style: McText.micro.muted)
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _hits!.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: McTokens.line),
                  itemBuilder: (_, i) {
                    final h = _hits![i];
                    final title = (h['title'] ?? h['name'] ?? '').toString();
                    final year = h['release_year'] ?? h['year'];
                    final kind = (h['media_type'] ?? _searchKind).toString();
                    return InkWell(
                      onTap: () => _openConfirm({
                        ...h,
                        'tmdb_id': J.i(h, ['external_id', 'tmdb_id', 'id']),
                        'media_type': kind,
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                year != null ? '$title ($year)' : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: McText.sub.copyWith(color: McTokens.text),
                              ),
                            ),
                            Text(
                              kind == 'tv' ? '剧集' : '电影',
                              style: McText.micro.faint,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmPanel(Map<String, dynamic> seed) {
    final titleObj = J.map(_confirmDetail ?? const {}, 'title');
    final displayTitle =
        J.s(titleObj, ['title', 'name']) ?? J.s(seed, ['title', 'name']) ?? '';
    final year = J.i(titleObj, ['release_year']) ?? J.i(seed, ['year']);
    final overview = J.s(titleObj, ['overview']);
    final poster =
        J.s(titleObj, ['poster_url']) ?? J.s(seed, ['poster_url']);
    final kind = (seed['media_type'] ?? _searchKind).toString();
    final tmdbId = J.i(seed, ['tmdb_id']) ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 76,
                decoration: BoxDecoration(
                  color: McTokens.posterPlaceholder,
                  borderRadius: BorderRadius.circular(6),
                ),
                clipBehavior: Clip.antiAlias,
                child: poster != null && poster.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: McImageUrls.resolve(poster, widthPx: 160),
                        httpHeaders: mcImageHeaders(),
                        fit: BoxFit.cover,
                      )
                    : const Icon(McIcons.film, size: 20, color: McTokens.textFaint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      year != null ? '$displayTitle ($year)' : displayTitle,
                      style: McText.sub.copyWith(
                        color: McTokens.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'tmdb:$kind:$tmdbId',
                      style: McText.micro.faint,
                    ),
                    if (overview != null && overview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: McText.micro.muted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (kind == 'tv') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _seasonCtrl,
              keyboardType: TextInputType.number,
              style: McText.sub.copyWith(color: McTokens.text),
              decoration: const InputDecoration(
                labelText: '统一指定季号（可选，留空则沿用文件名解析季号；0=特别篇）',
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '取消',
                  primary: false,
                  expanded: true,
                  onTap: _busy ? null : () => setState(() => _confirmSeed = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: McActionPill(
                  label: _busy
                      ? '应用中…'
                      : '确认归属 (${_selectedFileIds.length} 个文件)',
                  primary: true,
                  expanded: true,
                  busy: _busy,
                  onTap: _busy ? null : _applyAssign,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 5) 整条目安全删除弹层（1:1 对齐 iOS `DeleteItemSheet`）：
/// 展示路径清单、硬链接共享警示（`linked_bytes`）、附加清理选项勾选（如下载器种子与源文件）、
/// 二次确认勾选、执行结果路径清单以及 `follow_ups` 后台任务实时轮询！
Future<bool?> showDeletePreviewSheet({
  required BuildContext context,
  required DetailController controller,
  required String title,
}) {
  return showMcSheet<bool>(
    context: context,
    maxWidth: 600,
    builder: (_) => _DeleteSheet(
      controller: controller,
      title: title,
      file: null,
    ),
  );
}

/// 6) 单物理文件安全删除弹层（1:1 对齐 iOS `DeleteFileSheet`）：
/// 提示最后一个文件将升级为整条目删除，展示 `delete-preview?file_id=` 的硬链接/附加选项，
/// 执行 `DELETE .../files/{fileId}` 并返回是否导致整条目被删除。
Future<({bool deleted, bool wholeItemDeleted})?> showDeleteFileSheet({
  required BuildContext context,
  required DetailController controller,
  required String title,
  required DetailFileInfo file,
}) {
  return showMcSheet<({bool deleted, bool wholeItemDeleted})>(
    context: context,
    maxWidth: 600,
    builder: (_) => _DeleteSheet(
      controller: controller,
      title: title,
      file: file,
    ),
  );
}

class _DeleteSheet extends StatefulWidget {
  const _DeleteSheet({
    required this.controller,
    required this.title,
    this.file,
  });

  final DetailController controller;
  final String title;
  final DetailFileInfo? file;

  @override
  State<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends State<_DeleteSheet> {
  Map<String, dynamic>? _preview;
  bool _loadingPreview = true;
  final Set<String> _selectedOptions = {};
  bool _acknowledged = false;
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  bool get _isSingleFile => widget.file != null;
  bool get _isLastFile =>
      _isSingleFile &&
      (widget.controller.current.entry?.files.length ?? 0) <= 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final p = await widget.controller.fetchDeletePreview(
        fileId: widget.file?.id,
      );
      if (mounted) {
        setState(() {
          _preview = p;
          _loadingPreview = false;
        });
      }
    });
  }

  Future<void> _executeDelete() async {
    if (!_acknowledged || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final optQuery = _selectedOptions.isEmpty
        ? null
        : (_selectedOptions.toList()..sort()).join(',');
    final res = _isSingleFile
        ? await widget.controller.deleteFile(widget.file!.id, options: optQuery)
        : await widget.controller.deleteItem(options: optQuery);
    if (!mounted) return;
    if (res.error != null) {
      setState(() {
        _busy = false;
        _error = res.error;
      });
      return;
    }
    setState(() {
      _busy = false;
      _result = res.result ?? const {};
    });
  }

  void _finish() {
    if (_isSingleFile) {
      final errors = J.list(_result ?? const {}, ['errors']);
      Navigator.of(context).pop((
        deleted: true,
        wholeItemDeleted: _isLastFile && errors.isEmpty,
      ));
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.controller.current.entry;
    final linkedBytes = J.i(_preview ?? const {}, ['linked_bytes']) ?? 0;
    final options = J.listOfMap(_preview ?? const {}, ['options']);
    final paths = _isSingleFile
        ? [widget.file!.filePath]
        : (entry != null && entry.entryDirs.isNotEmpty
            ? entry.entryDirs
            : (entry?.files.map((f) => f.filePath).toList() ?? const <String>[]));

    return PopScope(
      canPop: !_busy && _result == null,
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
                  const Icon(McIcons.trash2, size: 18, color: McTokens.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _result != null
                          ? '删除结果'
                          : (_isSingleFile
                              ? '删除物理文件'
                              : '永久删除「${widget.title}」'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.titleSm,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: _result != null
                      ? _buildResult(_result!)
                      : _buildConfirm(
                          entry: entry,
                          paths: paths,
                          linkedBytes: linkedBytes,
                          options: options,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (_result != null)
                McActionPill(
                  label: _isSingleFile ? '完成' : '返回媒体库',
                  primary: true,
                  expanded: true,
                  onTap: _finish,
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
                        label: _busy ? '正在删除…' : '彻底删除',
                        icon: McIcons.trash2,
                        primary: false,
                        tone: McGlassTone.danger,
                        expanded: true,
                        busy: _busy,
                        onTap: _acknowledged && !_busy ? _executeDelete : null,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirm({
    required DetailEntry? entry,
    required List<String> paths,
    required int linkedBytes,
    required List<Map<String, dynamic>> options,
  }) {
    final fileCount = entry?.fileCount ?? entry?.files.length ?? 0;
    final totalBytes = entry?.totalSizeBytes ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSingleFile
              ? '将从磁盘永久删除该媒体文件及其同名 NFO / 外挂字幕附属文件，不可撤销。'
              : '此操作将从磁盘永久删除该条目对应的 $fileCount 个媒体文件（共 ${mcFormatBytes(totalBytes)}）及关联元数据目录，不可撤销。',
          style: McText.sub.copyWith(color: Colors.white.withValues(alpha: 0.85)),
        ),
        if (_isSingleFile) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
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
                  '${widget.file!.fileName}  (${mcFormatBytes(widget.file!.sizeBytes)})',
                  style: McText.sub.copyWith(color: McTokens.text).tabular,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  widget.file!.filePath,
                  style: McText.micro.copyWith(
                    fontFamily: 'monospace',
                    color: McTokens.textFaint,
                  ),
                ),
              ],
            ),
          ),
          if (_isLastFile) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: McTokens.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: McTokens.warning.withValues(alpha: 0.3)),
              ),
              child: Text(
                '这是「${widget.title}」在库中的最后一个文件，删除后将连同整个条目目录一并移除。',
                style: McText.caption.copyWith(color: McTokens.warning),
              ),
            ),
          ],
        ] else if (paths.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in paths)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            McIcons.folder,
                            size: 13,
                            color: McTokens.textFaint,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SelectableText(
                            p,
                            style: McText.micro.copyWith(
                              fontFamily: 'monospace',
                              color: McTokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_loadingPreview)
          Row(
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
              Text('正在检查硬链接与关联清理项…', style: McText.micro.faint),
            ],
          )
        else ...[
          if (linkedBytes > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: McTokens.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: McTokens.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '硬链接共享提示：其中 ${mcFormatBytes(linkedBytes)} 与做种或其他目录共享同一份物理数据，仅删除媒体库文件不会立即释放这部分磁盘空间。',
                style: McText.caption.copyWith(color: McTokens.warning).tabular,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final opt in options) ...[
            _buildOptionRow(opt),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _busy ? null : () => setState(() => _acknowledged = !_acknowledged),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _acknowledged ? McIcons.checkCircleFill : McIcons.circler,
                  size: 19,
                  color: _acknowledged ? McTokens.danger : McTokens.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isSingleFile && !_isLastFile
                        ? '我已明白将从磁盘永久删除此文件，且不可撤销'
                        : '我已明白将从磁盘永久删除以上目录和全部文件，且不可撤销',
                    style: McText.sub.copyWith(color: McTokens.text),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: McText.caption.copyWith(color: McTokens.danger),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionRow(Map<String, dynamic> opt) {
    final key = (opt['key'] ?? '').toString();
    final label = (opt['label'] ?? key).toString();
    final help = (opt['help'] ?? '').toString();
    final available = opt['available'] != false;
    final reason = J.s(opt, ['reason']);
    final lines = J.listOfMap(opt, ['lines']);
    final isOn = _selectedOptions.contains(key) && available;

    return Opacity(
      opacity: available ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: McTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOn
                ? McTokens.danger.withValues(alpha: 0.45)
                : McTokens.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: !available || _busy
                  ? null
                  : () {
                      setState(() {
                        if (_selectedOptions.contains(key)) {
                          _selectedOptions.remove(key);
                        } else {
                          _selectedOptions.add(key);
                        }
                      });
                    },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isOn ? McIcons.checkCircleFill : McIcons.circler,
                    size: 18,
                    color: isOn ? McTokens.danger : McTokens.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: McText.sub.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (help.isNotEmpty)
                          Text(help, style: McText.micro.faint),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (available && lines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Text(
                        (line['text'] ?? '').toString(),
                        style: McText.micro.copyWith(
                          color: switch ((line['tone'] ?? '').toString()) {
                            'warn' => McTokens.warning,
                            'danger' => McTokens.danger,
                            _ => McTokens.textMuted,
                          },
                        ),
                      ),
                  ],
                ),
              )
            else if (!available)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  '不可用：${reason ?? '当前无关联清理目标'}',
                  style: McText.micro.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> r) {
    final removed = J.list(r, ['removed_paths']);
    final errors = J.list(r, ['errors']);
    final rowsDeleted = J.i(r, ['rows_deleted']) ?? 0;
    final freedBytes = J.i(r, ['freed_bytes']) ?? 0;
    final followUps = J.listOfMap(r, ['follow_ups']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          errors.isEmpty ? '已完成永久删除' : '部分路径删除时出现异常',
          style: McText.ui.copyWith(
            color: errors.isEmpty ? McTokens.ok : McTokens.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: McTokens.surfaceInset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: McTokens.line),
          ),
          child: removed.isEmpty
              ? Text('未删除任何磁盘文件。', style: McText.caption.muted)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in removed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          p,
                          style: McText.micro.copyWith(
                            fontFamily: 'monospace',
                            color: McTokens.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final err in errors)
            Text(err, style: McText.caption.copyWith(color: McTokens.danger)),
        ],
        const SizedBox(height: 8),
        Text(
          '已清理 $rowsDeleted 条台账记录，释放 ${mcFormatBytes(freedBytes)}。',
          style: McText.caption.muted.tabular,
        ),
        for (final fu in followUps) ...[
          const SizedBox(height: 10),
          _DeleteFollowUpRow(
            controller: widget.controller,
            label: (fu['label'] ?? fu['option'] ?? '后续清理任务').toString(),
            jobId: (fu['job_id'] ?? '').toString(),
          ),
        ],
      ],
    );
  }
}

class _DeleteFollowUpRow extends StatefulWidget {
  const _DeleteFollowUpRow({
    required this.controller,
    required this.label,
    required this.jobId,
  });

  final DetailController controller;
  final String label;
  final String jobId;

  @override
  State<_DeleteFollowUpRow> createState() => _DeleteFollowUpRowState();
}

class _DeleteFollowUpRowState extends State<_DeleteFollowUpRow> {
  static const _terminal = {'succeeded', 'failed', 'cancelled'};
  Map<String, dynamic>? _job;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_pollOnce);
    _timer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _pollOnce(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pollOnce() async {
    if (widget.jobId.isEmpty) return;
    final j = await widget.controller.fetchJob(widget.jobId);
    if (!mounted || j == null) return;
    setState(() => _job = j);
    if (_terminal.contains((j['status'] ?? '').toString())) {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_job?['status'] ?? '').toString();
    final message = switch (status) {
      'succeeded' => J.s(J.map(_job!, 'result'), ['message']) ?? '已完成',
      'failed' =>
        '失败：${J.s(J.map(_job!, 'error'), ['message']) ?? '未知原因（可在活动→任务中重试）'}',
      'cancelled' => '已取消',
      _ => '后台处理中…',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: McText.sub.copyWith(
              color: McTokens.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            style: McText.caption.copyWith(
              color: status == 'failed'
                  ? McTokens.danger
                  : status == 'succeeded'
                      ? McTokens.ok
                      : McTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
