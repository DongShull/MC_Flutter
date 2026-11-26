import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/models.dart';
import '../state/offline_state.dart';

/// 下载档位选择毛玻璃弹层（1:1 对齐 Kotlin DownloadProfileSheet）：
/// 标题栏 + 范围胶囊分段 + 画质行勾选 + 容量校验底部胶囊主按钮。
Future<void> showDownloadProfileSheet(
  BuildContext context, {
  required DownloadCandidate candidate,
}) {
  return showMcSheet<void>(
    context: context,
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
    if (widget.candidate.profiles.isNotEmpty) {
      _selected.add(widget.candidate.profiles.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  candidate.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.titleSm,
                ),
              ),
              McGlassIconButton(
                icon: McIcons.close,
                size: 32,
                iconSize: 16,
                tooltip: '取消',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (candidate.scopes.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final i in candidate.scopes.indexed)
                  McChip(
                    label: i.$2,
                    selected: _scopeIndex == i.$1,
                    onTap: () => setState(() => _scopeIndex = i.$1),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          McInsetGroup(
            margin: EdgeInsets.zero,
            dividerIndent: 46,
            children: [
              for (final profile in candidate.profiles)
                McInsetRow(
                  leading: Icon(
                    _selected.contains(profile.id)
                        ? McIcons.checkCircleFill
                        : McIcons.circler,
                    size: 20,
                    color: _selected.contains(profile.id)
                        ? McTokens.accentStrong
                        : McTokens.textFaint,
                  ),
                  title: profile.label,
                  subtitle: profile.subtitle.isEmpty ? null : profile.subtitle,
                  onTap: () => setState(() {
                    if (_selected.contains(profile.id)) {
                      _selected.remove(profile.id);
                    } else {
                      _selected.add(profile.id);
                    }
                  }),
                ),
            ],
          ),
          if (!enoughSpace) ...[
            const SizedBox(height: 10),
            Text(
              '空间不够：还需要 ${mcFormatBytes(estBytes)}（已预留 2 GB 给系统）',
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ],
          const SizedBox(height: 18),
          McActionPill(
            label: '开始下载',
            icon: McIcons.fileDownload,
            primary: true,
            expanded: true,
            height: 44,
            onTap: enoughSpace && _selected.isNotEmpty
                ? () async {
                    final message = await controller.startDownload(
                      DownloadCandidate(
                        fileId: candidate.fileId,
                        title: candidate.title,
                        subtitle: candidate.subtitle,
                        scopes: candidate.scopes,
                        seasonFileIds: candidate.seasonFileIds,
                        fullSeasonSelected: _scopeIndex == 1,
                        profiles: candidate.profiles
                            .where((p) => _selected.contains(p.id))
                            .toList(),
                      ),
                    );
                    if (context.mounted) Navigator.of(context).pop();
                    McToast.info(message);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
