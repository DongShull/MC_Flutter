// 媒体库管理页（PARITY.md 第 15 行：无 → 有）。
//
// 三区：回收站（恢复）、重复文件（扫描结论 + 重新扫描）、
// 元数据刷新（按库提交 / 停止）。清理类动作只接服务端已有的端点：
// 回收站彻底清理（purge）与重复文件批量清理在 McApi 未收录，页内如实说明，
// 不编造端点、不做假按钮。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/state_views.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/library_manage_controller.dart';

class LibraryManagePage extends ConsumerWidget {
  const LibraryManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryManageProvider);
    final notifier = ref.read(libraryManageProvider.notifier);
    ref.listen<LibraryManageState>(
      libraryManageProvider,
      (_, next) {
        if (next.notice != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.notice!)),
          );
          notifier.consumeNotice();
        }
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('媒体库管理')),
      body: state.loading && !state.trashedLoaded && !state.duplicatesLoaded
          ? const McLoadingView()
          : RefreshIndicator(
              onRefresh: notifier.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const _SectionTitle('回收站'),
                  if (!state.trashedLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                  else if (state.trashed.isEmpty)
                    const Text('回收站是空的')
                  else
                    for (final row in state.trashed)
                      _TrashedTile(
                        row: row,
                        restoring:
                            state.restoringKey != null && state.restoringKey == row.key,
                        onRestore: () => notifier.restoreTrashed(row),
                        onOpen: row.mediaItemId == null
                            ? null
                            : () => context.push(
                                  '/detail/${row.libraryId}/${row.mediaItemId}',
                                ),
                      ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '彻底清理（真删磁盘）需服务端 purge 端点，当前客户端 API 未收录，暂不提供。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('重复文件'),
                  if (!state.duplicatesLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                  else ...[
                    if (state.scanStatus != null)
                      Text(
                        [
                          '扫描状态：${state.scanStatus}',
                          if (state.scannedAt != null)
                            '上次扫描：${state.scannedAt}',
                          if (state.scanMessage != null &&
                              state.scanMessage!.isNotEmpty)
                            state.scanMessage!,
                        ].join('\n'),
                      ),
                    if (state.duplicateTotals != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '共 ${state.duplicateTotals!.items} 个条目 · '
                          '${state.duplicateTotals!.units} 组重复 · '
                          '${state.duplicateTotals!.files} 个文件 · '
                          '${mcFormatBytes(state.duplicateTotals!.bytes)}',
                        ),
                      ),
                    for (final g in state.duplicateGroups)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(g.label.isEmpty ? g.key : g.label),
                        subtitle: g.hint.isEmpty ? null : Text(g.hint),
                        trailing: Text('${g.units} 组 · ${g.files} 文件'),
                      ),
                    for (final item in state.duplicateItems)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: item.posterUrl == null
                            ? null
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: McImageUrls.resolve(
                                    item.posterUrl,
                                    widthPx: 120,
                                  ),
                                  httpHeaders: mcImageHeaders(),
                                  width: 30,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      const SizedBox(width: 30, height: 45),
                                ),
                              ),
                        title: Text(item.title),
                        subtitle: Text(
                          [
                            item.libraryName,
                            if (item.year != null) item.year.toString(),
                            if (item.seasonCount > 0)
                              '${item.seasonCount} 季',
                          ].join(' · '),
                        ),
                        onTap: () => context.push(
                          '/detail/${item.libraryId}/${item.mediaItemId}',
                        ),
                      ),
                    if (state.duplicateGroups.isEmpty &&
                        state.duplicateItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('没有发现重复文件'),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed:
                          state.scanning ? null : notifier.scanDuplicates,
                      icon: const Icon(Icons.scanner),
                      label: Text(state.scanning ? '扫描中…' : '重新扫描重复文件'),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '重复文件的批量清理需服务端清理端点，当前客户端 API 未收录，暂只展示扫描结论。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _SectionTitle('元数据刷新'),
                  if (state.libraries.isEmpty)
                    const Text('暂无媒体库')
                  else
                    for (final lib in state.libraries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(lib.name),
                        subtitle: Text(lib.kind),
                        trailing: state.refreshingLibraryId == lib.id
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => notifier
                                        .refreshLibraryMetadata(lib.id),
                                    child: const Text('刷新'),
                                  ),
                                  TextButton(
                                    onPressed: () => notifier
                                        .stopLibraryMetadataRefresh(lib.id),
                                    child: const Text('停止'),
                                  ),
                                ],
                              ),
                      ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '刮削覆盖（按库的 scrape_overrides）属库设置页的编辑口径，'
                      '不在本页做；刷新元数据会按当前刮削设置重新识别。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}

class _TrashedTile extends StatelessWidget {
  const _TrashedTile({
    required this.row,
    required this.restoring,
    required this.onRestore,
    required this.onOpen,
  });

  final TrashedRow row;
  final bool restoring;
  final VoidCallback onRestore;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          row.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            row.libraryName,
            if (row.year != null) row.year.toString(),
            '${row.fileIds.length} 个文件 · ${row.sizeLabel}',
          ].join(' · '),
        ),
        trailing: restoring
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onRestore,
                child: const Text('恢复'),
              ),
        onTap: onOpen,
      ),
    );
  }
}
