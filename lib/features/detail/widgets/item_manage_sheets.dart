// 详情页管理弹层（P2；对齐安卓 `ItemActionSheets.kt` 的 ArtworkPicker /
// TransferItem）：更换图片、转移到其他库。调用方是详情页的 ⋯ 菜单。
import 'package:flutter/material.dart';

import '../../../core/api/models.dart';
import '../state/detail_controller.dart';

/// 更换图片：海报 / 背景 / Logo 三组候选，点一张即锁定（POST …/artwork/select）。
/// 成功后调 [onChanged]（详情页重拉）。失败在弹层内展示错误，不静默吞掉。
Future<void> showArtworkPickerSheet(
  BuildContext context, {
  required DetailController controller,
  required VoidCallback onChanged,
}) async {
  ArtworkCandidatesView? candidates;
  String? error;
  try {
    candidates = await controller.artworkCandidates();
  } catch (e) {
    error = e.toString();
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ArtworkSheet(
      candidates: candidates,
      error: error,
      controller: controller,
      onChanged: onChanged,
    ),
  );
}

class _ArtworkSheet extends StatefulWidget {
  const _ArtworkSheet({
    required this.candidates,
    required this.error,
    required this.controller,
    required this.onChanged,
  });

  final ArtworkCandidatesView? candidates;
  final String? error;
  final DetailController controller;
  final VoidCallback onChanged;

  @override
  State<_ArtworkSheet> createState() => _ArtworkSheetState();
}

class _ArtworkSheetState extends State<_ArtworkSheet> {
  String _kind = 'poster';
  String? _busy;
  String? _error;

  List<ArtworkCandidateView> get _list {
    final c = widget.candidates;
    if (c == null) return const [];
    return switch (_kind) {
      'backdrop' => c.backdrops,
      'logo' => c.logos,
      _ => c.posters,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candidates;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('更换图片',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (widget.error != null)
              Text('加载候选失败：${widget.error}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            if (c == null && widget.error == null)
              const Text('没有可用的候选图片'),
            if (c != null) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'poster', label: Text('海报')),
                  ButtonSegment(value: 'backdrop', label: Text('背景')),
                  ButtonSegment(value: 'logo', label: Text('标志')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) =>
                    setState(() => _kind = s.first),
              ),
              const SizedBox(height: 12),
              if (_list.isEmpty)
                const Text('这一组没有候选图片')
              else
                SizedBox(
                  height: 220,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: _list.length,
                    itemBuilder: (context, i) {
                      final cand = _list[i];
                      final busy = _busy == cand.filePath;
                      return InkWell(
                        onTap: busy
                            ? null
                            : () async {
                                setState(() {
                                  _busy = cand.filePath;
                                  _error = null;
                                });
                                final err = await widget.controller
                                    .selectArtwork(
                                        kind: _kind,
                                        filePath: cand.filePath);
                                if (!context.mounted) return;
                                setState(() => _busy = null);
                                if (err != null) {
                                  setState(() => _error = err);
                                  return;
                                }
                                widget.onChanged();
                                Navigator.of(context).pop();
                              },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (cand.previewUrl.isNotEmpty)
                              Image.network(cand.previewUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                      Icons.broken_image)),
                            if (cand.previewUrl.isEmpty)
                              const Icon(Icons.image_not_supported),
                            if (busy)
                              const Center(
                                  child: CircularProgressIndicator()),
                            Positioned(
                              left: 4,
                              right: 4,
                              bottom: 4,
                              child: Text(
                                [
                                  if (cand.width != null &&
                                      cand.height != null)
                                    '${cand.width}×${cand.height}',
                                  if (cand.language != null)
                                    cand.language!,
                                  cand.source,
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black)
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 转移到其他库：选目标库 → 预检（搬移 / 跳过 / 阻断）→ 确认转移。
/// 成功后调 [onTransferred]（详情页应重拉或返回上级）。
Future<void> showTransferSheet(
  BuildContext context, {
  required DetailController controller,
  required int currentLibraryId,
  required VoidCallback onTransferred,
}) async {
  List<LibraryView> libraries = const [];
  String? error;
  try {
    libraries = await controller.librariesList();
  } catch (e) {
    error = e.toString();
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _TransferSheet(
      libraries: libraries,
      error: error,
      currentLibraryId: currentLibraryId,
      controller: controller,
      onTransferred: onTransferred,
    ),
  );
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({
    required this.libraries,
    required this.error,
    required this.currentLibraryId,
    required this.controller,
    required this.onTransferred,
  });

  final List<LibraryView> libraries;
  final String? error;
  final int currentLibraryId;
  final DetailController controller;
  final VoidCallback onTransferred;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  int? _targetId;
  TransferPreviewView? _preview;
  String? _error;
  bool _loadingPreview = false;
  bool _submitting = false;

  List<LibraryView> get _targets => widget.libraries
      .where((l) => l.id != widget.currentLibraryId)
      .toList();

  Future<void> _loadPreview(int targetId) async {
    setState(() {
      _targetId = targetId;
      _loadingPreview = true;
      _preview = null;
      _error = null;
    });
    try {
      final p =
          await widget.controller.transferPreview(targetLibraryId: targetId);
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _targets.where((l) => l.id == _targetId).firstOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('转移到其他库',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (widget.error != null)
              Text('加载媒体库失败：${widget.error}',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_targets.isEmpty && widget.error == null)
              const Text('没有其他媒体库可转移'),
            for (final lib in _targets)
              RadioListTile<int>(
                title: Text(lib.name),
                subtitle: Text(lib.kind.isEmpty ? '媒体库' : lib.kind),
                value: lib.id,
                groupValue: _targetId,
                onChanged: (v) {
                  if (v != null) _loadPreview(v);
                },
              ),
            if (_loadingPreview)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (_preview != null && target != null) ...[
              Text('目标：${target.name}（${_preview!.targetRoot}）'),
              Text(
                  '将搬移 ${_preview!.moves.length} 个文件，跳过 ${_preview!.skips.length} 个'
                  '${_preview!.missingCount > 0 ? '，缺失 ${_preview!.missingCount} 个' : ''}'),
              if (_preview!.crossDevice)
                const Text('注意：跨设备转移，文件将被复制而非移动'),
              if (_preview!.blocked.isNotEmpty)
                Text('无法转移：${_preview!.blocked.join('；')}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _preview!.blocked.isNotEmpty || _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        final err = await widget.controller
                            .transferItem(_targetId!);
                        if (!context.mounted) return;
                        setState(() => _submitting = false);
                        if (err != null) {
                          setState(() => _error = err);
                          return;
                        }
                        widget.onTransferred();
                        Navigator.of(context).pop();
                      },
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('确认转移'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
