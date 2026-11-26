import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/detail_controller.dart';

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

/// 3) 海报 / 剧照 / Logo 候选更换弹层。
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
  String _kind = 'poster';
  Map<String, dynamic>? _raw;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final d = await widget.controller.fetchArtworkCandidates();
        if (mounted) setState(() => _raw = d);
      } catch (e) {
        if (mounted) setState(() => _error = '加载图片候选失败：$e');
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final list = _candidatesFor(_kind);
    final isPoster = _kind == 'poster';
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('更换海报与剧照', style: McText.titleSm),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (k, label) in const [
                  ('poster', '竖版海报'),
                  ('backdrop', '横版剧照'),
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
            const SizedBox(height: 12),
            Expanded(
              child: _raw == null && _error == null
                  ? const McLoadingView()
                  : _error != null
                      ? McErrorView(text: _error!)
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
                                final selected = c['selected'] == true;
                                return McPressable(
                                  onTap: () async {
                                    final err = await widget.controller
                                        .selectArtwork(
                                          kind: _kind,
                                          filePath: fp,
                                        );
                                    if (!context.mounted) return;
                                    if (err != null) {
                                      McToast.error(err);
                                    } else {
                                      McToast.success('已更换图片');
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selected
                                            ? McTokens.accentStrong
                                            : McTokens.line,
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
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

/// 4) 手动重新识别 TMDB 词条弹层。
Future<void> showReidentifySheet({
  required BuildContext context,
  required DetailController controller,
  required String initialTitle,
}) {
  return showMcSheet<void>(
    context: context,
    maxWidth: 580,
    builder: (_) =>
        _ReidentifySheet(controller: controller, initialTitle: initialTitle),
  );
}

class _ReidentifySheet extends StatefulWidget {
  const _ReidentifySheet({
    required this.controller,
    required this.initialTitle,
  });

  final DetailController controller;
  final String initialTitle;

  @override
  State<_ReidentifySheet> createState() => _ReidentifySheetState();
}

class _ReidentifySheetState extends State<_ReidentifySheet> {
  late final TextEditingController _q =
      TextEditingController(text: widget.initialTitle);
  List<Map<String, dynamic>> _hits = const [];
  bool _searching = false;
  bool _applying = false;

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
    final q = _q.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final res = await widget.controller.searchReidentifyCandidates(q);
      if (mounted) {
        setState(() {
          _hits = res;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
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
            const Text('手动修正词条识别', style: McText.titleSm),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    style: McText.body,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: '输入正确片名或 TMDB 关键词…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                McGlassIconButton(icon: McIcons.search, onTap: _search),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _searching
                  ? const McLoadingView()
                  : _hits.isEmpty
                      ? const McEmptyView(text: '没有匹配的候选词条')
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
                                          label: _applying ? '识别中' : '应用',
                                          selected: true,
                                          compact: true,
                                          onTap: _applying || refStr.isEmpty
                                              ? null
                                              : () async {
                                                  setState(
                                                    () => _applying = true,
                                                  );
                                                  final err = await widget
                                                      .controller
                                                      .applyReidentify(refStr);
                                                  if (!context.mounted) return;
                                                  if (err != null) {
                                                    setState(
                                                      () => _applying = false,
                                                    );
                                                    McToast.error(err);
                                                  } else {
                                                    McToast.success(
                                                      '已重新识别并更新元数据',
                                                    );
                                                    Navigator.of(context).pop();
                                                  }
                                                },
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

/// 5) AI 字幕生成配置弹层（目标语言 / 双语副语言 / 强制重转写）。
Future<void> showSubtitleGenSheet({
  required BuildContext context,
  required DetailController controller,
  int? fileId,
  String? label,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => _SubtitleGenSheet(
      controller: controller,
      fileId: fileId,
      label: label,
    ),
  );
}

class _SubtitleGenSheet extends StatefulWidget {
  const _SubtitleGenSheet({
    required this.controller,
    this.fileId,
    this.label,
  });

  final DetailController controller;
  final int? fileId;
  final String? label;

  @override
  State<_SubtitleGenSheet> createState() => _SubtitleGenSheetState();
}

class _SubtitleGenSheetState extends State<_SubtitleGenSheet> {
  String _target = 'zh-CN';
  String _secondary = '';
  bool _retranscribe = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label != null ? 'AI 字幕 · ${widget.label}' : 'AI 生成智能字幕',
            style: McText.titleSm,
          ),
          const SizedBox(height: 6),
          Text(
            '自动提取音轨或内封外语字幕并调用大模型精准轴译。',
            style: McText.caption.muted,
          ),
          const SizedBox(height: 14),
          Text('主字幕语言', style: McText.caption.muted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, name) in const [
                ('zh-CN', '简体中文'),
                ('zh-TW', '繁體中文'),
                ('en', 'English'),
                ('ja', '日本語'),
              ])
                McChip(
                  label: name,
                  compact: true,
                  selected: _target == code,
                  onTap: () => setState(() => _target = code),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('双语对照副语言（可选）', style: McText.caption.muted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, name) in const [
                ('', '仅单语'),
                ('en', '中英双语'),
                ('ja', '中日双语'),
              ])
                McChip(
                  label: name,
                  compact: true,
                  selected: _secondary == code,
                  onTap: () => setState(() => _secondary = code),
                ),
            ],
          ),
          const SizedBox(height: 12),
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              McInsetRow(
                title: '强制从音轨重新语音识别',
                subtitle: '忽略已有外语字幕轨，直接由 Whisper 重打时间轴',
                trailing: Switch(
                  value: _retranscribe,
                  onChanged: (v) => setState(() => _retranscribe = v),
                ),
                onTap: () => setState(() => _retranscribe = !_retranscribe),
              ),
            ],
          ),
          const SizedBox(height: 18),
          McActionPill(
            label: _submitting ? '正在预检并提交…' : '开始生成字幕',
            icon: McIcons.aiStarFill,
            primary: true,
            expanded: true,
            busy: _submitting,
            onTap: _submitting
                ? null
                : () async {
                    setState(() => _submitting = true);
                    final msg = await widget.controller.startSubtitleGen(
                      fileId: widget.fileId,
                      targetLanguage: _target,
                      secondaryLanguage: _secondary.isEmpty ? null : _secondary,
                      retranscribe: _retranscribe,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    McToast.info(msg);
                  },
          ),
        ],
      ),
    );
  }
}

/// 6) 安全删除预检弹层（展示受影响文件数与磁盘总体积）。
Future<bool?> showDeletePreviewSheet({
  required BuildContext context,
  required DetailController controller,
  required String title,
}) {
  return showMcSheet<bool>(
    context: context,
    builder: (_) => _DeletePreviewSheet(controller: controller, title: title),
  );
}

class _DeletePreviewSheet extends StatefulWidget {
  const _DeletePreviewSheet({required this.controller, required this.title});

  final DetailController controller;
  final String title;

  @override
  State<_DeletePreviewSheet> createState() => _DeletePreviewSheetState();
}

class _DeletePreviewSheetState extends State<_DeletePreviewSheet> {
  Map<String, dynamic>? _preview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final p = await widget.controller.fetchDeletePreview();
      if (mounted) {
        setState(() {
          _preview = p;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fileCount = (_preview?['file_count'] as num?)?.toInt();
    final totalBytes = (_preview?['total_size_bytes'] as num?)?.toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('确认删除「${widget.title}」？', style: McText.titleSm),
          const SizedBox(height: 8),
          if (_loading)
            const SizedBox(height: 48, child: McLoadingView())
          else
            Text(
              fileCount != null && fileCount > 0
                  ? '将从媒体库移除该条目及其关联的 $fileCount 个文件（共 ${mcFormatBytes(totalBytes ?? 0)}），文件可按库策略进入回收站。'
                  : '即将从媒体库移除「${widget.title}」，该操作不可轻易撤销。',
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
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: '确认删除',
                  icon: McIcons.trash2,
                  primary: false,
                  tone: McGlassTone.danger,
                  expanded: true,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
