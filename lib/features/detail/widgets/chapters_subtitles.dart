// 详情页「章节 / 字幕」区（对照安卓 ItemDetailScreen 的字幕轨行与
// web 的章节预览图 trickplay）。
//
// - 字幕：条目已有的字幕轨列表 + 「生成字幕（AI）」入口（进字幕生成页）；
// - 章节预览图：`GET /playback/files/{fileId}/trickplay` 的 sprite
//   sheet 列表（每 N 秒一帧）+ 「重新生成章节图」
//   （`POST /libraries/{id}/items/{id}/chapter-images` → 任务）。
// trickplay 未就绪 / 无文件时该区只显示字幕部分，不编造预览图。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/api/models.dart';
import '../../../core/image/image_urls.dart';

class ChaptersSubtitlesSection extends StatelessWidget {
  const ChaptersSubtitlesSection({
    super.key,
    required this.subtitleTracks,
    required this.trickplay,
    required this.trickplayLoading,
    required this.regeneratingChapters,
    required this.onGenerateSubtitle,
    required this.onRegenerateChapters,
  });

  final List<String> subtitleTracks;
  final TrickplayView? trickplay;
  final bool trickplayLoading;
  final bool regeneratingChapters;
  final VoidCallback onGenerateSubtitle;
  final VoidCallback onRegenerateChapters;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '章节 / 字幕',
            style: textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text('字幕', style: muted),
              ),
              Expanded(
                child: Text(
                  subtitleTracks.isEmpty
                      ? '暂无内嵌字幕轨'
                      : subtitleTracks.join(' / '),
                  style: textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: onGenerateSubtitle,
                child: const Text('生成字幕'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text('章节图', style: muted),
              ),
              Expanded(
                child: trickplayLoading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : trickplay == null
                        ? Text('暂无章节预览图', style: muted)
                        : Text(
                            '预览图已就绪 · ${trickplay!.count} 帧 · '
                            '每 ${(trickplay!.intervalMs / 1000).toStringAsFixed(0)} 秒一帧',
                            style: textTheme.bodySmall,
                          ),
              ),
              TextButton(
                onPressed:
                    regeneratingChapters ? null : onRegenerateChapters,
                child: Text(regeneratingChapters ? '生成中…' : '重新生成'),
              ),
            ],
          ),
          if (trickplay != null && trickplay!.sheets.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: trickplay!.sheets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final url = trickplay!.sheets[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: McImageUrls.resolve(url),
                      httpHeaders: mcImageHeaders(),
                      width: 128,
                      height: 72,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 128,
                        height: 72,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.broken_image, size: 20),
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
}
