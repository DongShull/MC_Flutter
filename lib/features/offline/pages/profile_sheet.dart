
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/format.dart';
import '../state/models.dart';
import '../state/offline_state.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 下载档位选择（1:1 对齐 Kotlin DownloadProfileSheet）：
/// 取消 / 标题 / 下载 三栏；范围分段；画质行选中打勾、原画准数其余 ≈、
/// 转码档说明；空间不够 footer 禁用下载。
Future<void> showDownloadProfileSheet(
  BuildContext context, {
  required DownloadCandidate candidate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DownloadProfileSheet(candidate: candidate),
  );
}

class DownloadProfileSheet extends ConsumerStatefulWidget {
  const DownloadProfileSheet({super.key, required this.candidate});

  final DownloadCandidate candidate;

  @override
  ConsumerState<DownloadProfileSheet> createState() =>
      _DownloadProfileSheetState();
}

class _DownloadProfileSheetState extends ConsumerState<DownloadProfileSheet> {
  int _scopeIndex = 0;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    // 默认选第一个（通常是最高画质）。
    if (widget.candidate.profiles.isNotEmpty) {
      _selected.add(widget.candidate.profiles.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(offlineProvider.notifier);
    final offline = ref.watch(offlineProvider);
    final candidate = widget.candidate;
    final estBytes = candidate.profiles
        .where((p) => _selected.contains(p.id))
        .fold<int>(0, (sum, p) => sum + (p.estimatedBytes ?? 0));
    final storage = offline.storage;
    final enoughSpace = storage == null ||
        estBytes == 0 ||
        storage.availableBytes - OfflineController.reserveBytes >= estBytes;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                Expanded(
                  child: Text(
                    candidate.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: enoughSpace && _selected.isNotEmpty
                      ? () async {
                          final message = await controller.startDownload(
                            DownloadCandidate(
                              fileId: candidate.fileId,
                              title: candidate.title,
                              scopes: candidate.scopes,
                              profiles: candidate.profiles
                                  .where((p) => _selected.contains(p.id))
                                  .toList(),
                            ),
                          );
                          // POST /offline/profiles 只在候选带 profileIds 时走服务器。
                          if (context.mounted) Navigator.of(context).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          }
                        }
                      : null,
                  child: Text(
                    '下载',
                    style: TextStyle(
                      color: enoughSpace && _selected.isNotEmpty
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ],
            ),
            // 多 scope 分段（本片 / 全季…）。
            if (candidate.scopes.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: SegmentedButton<int>(
                  segments: [
                    for (final i in candidate.scopes.indexed)
                      ButtonSegment(value: i.$1, label: Text(i.$2)),
                  ],
                  selected: {_scopeIndex},
                  onSelectionChanged: (selection) =>
                      setState(() => _scopeIndex = selection.first),
                ),
              ),
            // 画质行。
            for (final profile in candidate.profiles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _selected.contains(profile.id)
                      ? McIcons.checkCircleFill
                      : McIcons.radioButtonLine,
                  color: _selected.contains(profile.id)
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                title: Text(profile.label),
                subtitle: profile.subtitle.isEmpty
                    ? null
                    : Text(profile.subtitle,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                onTap: () => setState(() {
                  if (_selected.contains(profile.id)) {
                    _selected.remove(profile.id);
                  } else {
                    _selected.add(profile.id);
                  }
                }),
              ),
            // 空间不够 footer。
            if (!enoughSpace)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '空间不够：还需要 ${mcFormatBytes(estBytes)}（已预留 2 GB 给系统）',
                  style: TextStyle(fontSize: 12, color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
