// 导入监听页（对应 web settings import-watch 分区 / 安卓 ImportWatchScreen）：
// 监听目录列表、新增/编辑、删除；点进一条可看最近的入库条目，
// 对失败条目可忽略 / 恢复。认领（claim）需指定 TMDB，入口在条目详情里，
// 本页只做忽略/恢复；认领走媒体库的重新识别流程（见 P4.md）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class ImportWatchPage extends ConsumerStatefulWidget {
  const ImportWatchPage({super.key});

  @override
  ConsumerState<ImportWatchPage> createState() => _ImportWatchPageState();
}

class _ImportWatchPageState extends ConsumerState<ImportWatchPage> {
  late Future<List<core.ImportWatchView>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<core.ImportWatchView>> _load() =>
      ref.read(settingsApiProvider).importWatch();

  void _reload() => setState(() => _future = _load());

  Future<void> _run(Future<void> Function() fn, String okMsg) async {
    try {
      await fn();
      if (!mounted) return;
      showSettingsToast(context, okMsg);
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '操作失败：$e');
    }
  }

  String? _nonEmpty(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  Future<void> _save(core.ImportWatchView? existing) async {
    final values = await showAdminFormDialog(
      context,
      title: existing == null ? '添加导入监听' : '编辑导入监听',
      initial: existing == null
          ? null
          : {
              'sourcePath': existing.sourcePath,
              'strategy': existing.strategy,
              'libraryId': existing.libraryId,
              'targetPath': existing.targetPath,
              'processExisting': existing.processExisting,
            },
      fields: const [
        AdminFieldSpec(key: 'sourcePath', label: '来源目录', required: true),
        AdminFieldSpec(
            key: 'strategy', label: '入库方式', hint: '如 hardlink（硬链接）'),
        AdminFieldSpec(
            key: 'libraryId', label: '目标媒体库 ID', kind: AdminFieldKind.number),
        AdminFieldSpec(key: 'targetPath', label: '目标子目录'),
        AdminFieldSpec(
            key: 'processExisting',
            label: '处理已有文件',
            kind: AdminFieldKind.boolean,
            initial: true),
      ],
    );
    if (values == null) return;
    final payload = core.ImportWatchPayload(
      sourcePath: values['sourcePath'] as String? ?? '',
      strategy: values['strategy'] as String? ?? 'hardlink',
      libraryId: values['libraryId'] is int
          ? values['libraryId'] as int
          : int.tryParse(values['libraryId']?.toString() ?? ''),
      targetPath: _nonEmpty(values['targetPath']),
      processExisting: values['processExisting'] as bool? ?? true,
    );
    if (existing == null) {
      await _run(
          () => ref.read(settingsApiProvider).createImportWatch(payload),
          '已添加导入监听');
    } else {
      await _run(
          () => ref
              .read(settingsApiProvider)
              .updateImportWatch(existing.id, payload),
          '已保存');
    }
  }

  Future<void> _showEntries(core.ImportWatchView w) async {
    core.IngestEntriesView? entries;
    String? error;
    try {
      entries = await ref.read(settingsApiProvider).importWatchEntries(w.id);
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('入库条目 · ${w.sourcePath}',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('加载失败：$error'),
                ),
              if (entries != null && entries.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无入库条目'),
                ),
              if (entries != null)
                Expanded(
                  child: ListView(
                    children: [
                      for (final e in entries.entries)
                        ListTile(
                          title: Text(e.name),
                          subtitle: Text(
                              '${e.status}${(e.message ?? '').isNotEmpty ? ' · ${e.message}' : ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (e.status == 'ignored')
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(settingsApiProvider)
                                          .restoreIngestEntry(e.id);
                                      if (!mounted || !ctx.mounted) {
                                        return;
                                      }
                                      Navigator.of(ctx).pop();
                                      showSettingsToast(context, '已恢复');
                                    } catch (err) {
                                      if (!mounted) return;
                                      showSettingsToast(
                                          context, '恢复失败：$err');
                                    }
                                  },
                                  child: const Text('恢复'),
                                )
                              else
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(settingsApiProvider)
                                          .ignoreIngestEntry(e.id);
                                      if (!mounted || !ctx.mounted) {
                                        return;
                                      }
                                      Navigator.of(ctx).pop();
                                      showSettingsToast(context, '已忽略');
                                    } catch (err) {
                                      if (!mounted) return;
                                      showSettingsToast(
                                          context, '忽略失败：$err');
                                    }
                                  },
                                  child: const Text('忽略'),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '导入监听',
        body: AdminAsyncBody<List<core.ImportWatchView>>(
          future: _future,
          onRetry: _reload,
          builder: (context, items) => ListView(
            children: [
              if (items.isEmpty)
                const SettingsInfoCard(
                    text: '监听目录里的新文件会自动入库到媒体库。'),
              for (final w in items)
                SettingsRow(
                  icon: Icons.folder,
                  title: w.sourcePath,
                  subtitle: [
                    w.strategy,
                    if ((w.libraryName ?? '').isNotEmpty) w.libraryName!,
                    if (w.targetLabel.isNotEmpty) w.targetLabel,
                    '已导入 ${w.importedFiles} 个文件',
                  ].join(' · '),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.list),
                            title: const Text('查看入库条目'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showEntries(w);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('编辑'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _save(w);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('删除监听',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final ok = await confirmDialog(
                                context,
                                title: '删除导入监听',
                                message: '确定删除对「${w.sourcePath}」的监听吗？',
                                confirmLabel: '删除',
                              );
                              if (ok) {
                                await _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .deleteImportWatch(w.id),
                                  '已删除',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('添加导入监听'),
                  onPressed: () => _save(null),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
