// 详情页下载面板宿主（对照安卓 `feature/detail/ItemDownloadHost.kt`）。
//
// 两档目标：
// - [DownloadSheetTarget.file]：单个文件（电影、分集长按「下载这一集」）→
//   直接走 offline 域的选档面板；
// - [DownloadSheetTarget.series]：剧集按范围 → 按当前选中的季，取本季在库的集，
//   勾选后逐集进 offline 域下载（每集一个 fileId 候选）。
// 本文件只做宿主与范围选择，字节搬运仍在 offline 域完成。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../offline/pages/profile_sheet.dart';
import '../../offline/state/models.dart';
import '../../offline/state/offline_state.dart';
import '../state/detail_controller.dart';

/// 要打开的选档面板：单个文件 / 剧集按范围。
sealed class DownloadSheetTarget {
  const DownloadSheetTarget();
}

class FileDownloadTarget extends DownloadSheetTarget {
  const FileDownloadTarget({required this.fileId, required this.title});

  final int fileId;
  final String title;
}

class SeriesDownloadTarget extends DownloadSheetTarget {
  const SeriesDownloadTarget({required this.title});

  final String title;
}

/// 打开详情下载面板（File 直接选档；Series 先选范围再逐集下载）。
Future<void> showItemDownloadSheet(
  BuildContext context, {
  required DetailEntry? detail,
  required Map<int, List<EpisodeEntry>> episodes,
  required int? selectedSeason,
  EpisodeEntry? selectedEpisode,
  required DownloadSheetTarget target,
}) async {
  if (detail == null) return;
  switch (target) {
    case FileDownloadTarget(:final fileId, :final title):
      await showDownloadProfileSheet(
        context,
        candidate: DownloadCandidate(
          fileId: fileId.toString(),
          title: title,
          scopes: const ['本片'],
          profiles: _offlineProfiles,
        ),
      );
    case SeriesDownloadTarget(:final title):
      // 目标季：当前选中的季 → 选中集所在季 → 第一个有在库文件的季。
      final ownedSeasons = {
        for (final e in episodes.values.expand((l) => l))
          if (e.owned) e.seasonNumber,
      };
      final targetSeason = selectedSeason ??
          selectedEpisode?.seasonNumber ??
          detail.seasons
              .map((s) => s.number)
              .firstWhere(
                (n) => ownedSeasons.contains(n),
                orElse: () => detail.seasons.firstOrNull?.number ?? 1,
              );
      final seasonEpisodes = (episodes[targetSeason] ?? const <EpisodeEntry>[])
          .where((e) => e.owned && e.fileIds.isNotEmpty)
          .toList()
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      if (seasonEpisodes.isEmpty || !context.mounted) return;
      final picked = await showModalBottomSheet<Set<int>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => _SeriesPickerSheet(
          title: title,
          season: targetSeason,
          episodes: seasonEpisodes,
          initiallySelected: selectedEpisode != null &&
                  selectedEpisode.seasonNumber == targetSeason
              ? {selectedEpisode.episodeNumber}
              : {seasonEpisodes.first.episodeNumber},
        ),
      );
      if (picked == null || picked.isEmpty || !context.mounted) return;
      // 逐集进 offline 域：每集一个 fileId 候选（原画直下）。
      final offline = ProviderScope.containerOf(context, listen: false)
          .read(offlineProvider.notifier);
      var started = 0;
      for (final e in seasonEpisodes) {
        if (!picked.contains(e.episodeNumber)) continue;
        await offline.startDownload(
          DownloadCandidate(
            fileId: e.fileIds.first.toString(),
            title: '第 $targetSeason 季第 ${e.episodeNumber} 集 ${e.name}',
            scopes: const ['本片'],
            profiles: _offlineProfiles,
          ),
        );
        started++;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已开始下载 $started 集')),
        );
      }
  }
}

/// 离线下载档位（与详情页电影下载共用同一组：原画直下，其余服务端转码导出）。
const _offlineProfiles = [
  DownloadProfile(id: 'original', label: '原画', isOriginal: true),
  DownloadProfile(id: '1080p', label: '1080P', isOriginal: false, transcode: true),
  DownloadProfile(id: '720p', label: '720P', isOriginal: false, transcode: true),
  DownloadProfile(id: '480p', label: '480P', isOriginal: false, transcode: true),
];

/// 剧集范围选择：本季在库集列表（勾选，默认选中当前集）+ 全选 / 全不选。
class _SeriesPickerSheet extends StatefulWidget {
  const _SeriesPickerSheet({
    required this.title,
    required this.season,
    required this.episodes,
    required this.initiallySelected,
  });

  final String title;
  final int season;
  final List<EpisodeEntry> episodes;
  final Set<int> initiallySelected;

  @override
  State<_SeriesPickerSheet> createState() => _SeriesPickerSheetState();
}

class _SeriesPickerSheetState extends State<_SeriesPickerSheet> {
  late Set<int> _selected = Set<int>.from(widget.initiallySelected);

  @override
  Widget build(BuildContext context) {
    final allPicked = _selected.length == widget.episodes.length;
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
                    '${widget.title} · 第 ${widget.season} 季',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  child: Text('下载（${_selected.length}）'),
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _selected = {
                        for (final e in widget.episodes) e.episodeNumber,
                      }),
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: allPicked
                      ? () => setState(() => _selected = {})
                      : null,
                  child: const Text('全不选'),
                ),
              ],
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in widget.episodes)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '第 ${e.episodeNumber} 集 ${e.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: e.played ? const Text('已看过') : null,
                      value: _selected.contains(e.episodeNumber),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(e.episodeNumber);
                        } else {
                          _selected.remove(e.episodeNumber);
                        }
                      }),
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
