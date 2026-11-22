// 下载器页（对应 web settings downloaders 分区 / 安卓 DownloadersScreen）：
// 下载器列表、新增/编辑、启用、设为默认、验证、删除、限速。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class _DownloadersData {
  const _DownloadersData({required this.types, required this.items});

  final List<core.DownloaderTypeInfo> types;
  final List<core.DownloaderView> items;
}

class DownloadersPage extends ConsumerStatefulWidget {
  const DownloadersPage({super.key});

  @override
  ConsumerState<DownloadersPage> createState() => _DownloadersPageState();
}

class _DownloadersPageState extends ConsumerState<DownloadersPage> {
  late Future<_DownloadersData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DownloadersData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results =
        await Future.wait([api.downloaderTypes(), api.downloaders()]);
    return _DownloadersData(
      types: results[0] as List<core.DownloaderTypeInfo>,
      items: results[1] as List<core.DownloaderView>,
    );
  }

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

  List<AdminFieldSpec> _formFields(
      _DownloadersData data, core.DownloaderView? existing) {
    final typeOptions = data.types.isEmpty
        ? const [(value: '', label: '（服务端未返回类型）')]
        : [
            for (final t in data.types)
              (value: t.type, label: t.title.isEmpty ? t.type : t.title),
          ];
    return [
      const AdminFieldSpec(key: 'name', label: '名称', required: true),
      AdminFieldSpec(
        key: 'clientType',
        label: '类型',
        kind: AdminFieldKind.select,
        options: typeOptions,
        initial: existing?.clientType,
      ),
      AdminFieldSpec(
          key: 'url',
          label: '地址',
          required: true,
          hint: '如 http://127.0.0.1:8080',
          initial: existing?.url),
      AdminFieldSpec(
          key: 'username', label: '用户名', initial: existing?.username),
      const AdminFieldSpec(
          key: 'password', label: '密码（留空不改）', kind: AdminFieldKind.password),
      AdminFieldSpec(
          key: 'savePath', label: '保存路径', initial: existing?.savePath),
      AdminFieldSpec(
        key: 'enabled',
        label: '启用',
        kind: AdminFieldKind.boolean,
        initial: existing?.enabled ?? true,
      ),
    ];
  }

  Future<void> _save(
      _DownloadersData data, core.DownloaderView? existing) async {
    final values = await showAdminFormDialog(
      context,
      title: existing == null ? '添加下载器' : '编辑下载器',
      fields: _formFields(data, existing),
    );
    if (values == null) return;
    final payload = core.DownloaderPayload(
      name: values['name'] as String? ?? '',
      clientType: values['clientType'] as String? ?? '',
      url: values['url'] as String? ?? '',
      username: _nonEmpty(values['username']),
      password: _nonEmpty(values['password']),
      savePath: _nonEmpty(values['savePath']),
      enabled: values['enabled'] as bool? ?? true,
    );
    if (existing == null) {
      await _run(
          () => ref.read(settingsApiProvider).createDownloader(payload),
          '已添加下载器');
    } else {
      await _run(
          () =>
              ref.read(settingsApiProvider).updateDownloader(existing.id, payload),
          '已保存');
    }
  }

  Future<void> _limits(core.DownloaderView d) async {
    final current = await ref.read(settingsApiProvider).downloaderLimits(d.id);
    if (!mounted) return;
    int mb(int? bytes) => bytes == null ? 0 : bytes ~/ (1024 * 1024);
    final values = await showAdminFormDialog(
      context,
      title: '限速（0 = 不限）',
      initial: {
        'downloadLimitMB': mb(current.downloadLimitBytes),
        'uploadLimitMB': mb(current.uploadLimitBytes),
        'maxActiveDownloads': current.maxActiveDownloads,
        'maxActiveUploads': current.maxActiveUploads,
      },
      fields: const [
        AdminFieldSpec(key: 'downloadLimitMB', label: '下载限速 MB/s', kind: AdminFieldKind.number),
        AdminFieldSpec(key: 'uploadLimitMB', label: '上传限速 MB/s', kind: AdminFieldKind.number),
        AdminFieldSpec(key: 'maxActiveDownloads', label: '最大同时下载数', kind: AdminFieldKind.number),
        AdminFieldSpec(key: 'maxActiveUploads', label: '最大同时上传数', kind: AdminFieldKind.number),
      ],
    );
    if (values == null) return;
    int? toBytes(Object? v) {
      final n = v is int ? v : int.tryParse(v?.toString() ?? '');
      if (n == null || n <= 0) return null;
      return n * 1024 * 1024;
    }

    await _run(
      () => ref.read(settingsApiProvider).setDownloaderLimits(
            d.id,
            core.DownloaderLimits(
              downloadLimitBytes: toBytes(values['downloadLimitMB']),
              uploadLimitBytes: toBytes(values['uploadLimitMB']),
              maxActiveDownloads: values['maxActiveDownloads'] is int
                  ? values['maxActiveDownloads'] as int
                  : int.tryParse(
                      values['maxActiveDownloads']?.toString() ?? ''),
              maxActiveUploads: values['maxActiveUploads'] is int
                  ? values['maxActiveUploads'] as int
                  : int.tryParse(
                      values['maxActiveUploads']?.toString() ?? ''),
            ),
          ),
      '限速已保存',
    );
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '下载器',
        body: AdminAsyncBody<_DownloadersData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) => ListView(
            children: [
              if (data.items.isEmpty)
                const SettingsInfoCard(text: '尚未配置下载器，订阅无法下载资源。'),
              for (final d in data.items)
                SettingsRow(
                  icon: Icons.download,
                  title: d.name,
                  subtitle: [
                    d.clientType,
                    d.url,
                    d.status,
                    if (d.isDefault) '默认',
                    if (!d.enabled) '已停用',
                    if (!d.pathsHealthy) '路径异常',
                    if ((d.lastError ?? '').isNotEmpty) d.lastError!,
                  ].join(' · '),
                  trailing: Switch(
                    value: d.enabled,
                    onChanged: (v) => _run(
                      () => ref
                          .read(settingsApiProvider)
                          .setDownloaderEnabled(d.id, v),
                      v ? '已启用' : '已停用',
                    ),
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('编辑'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _save(data, d);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.verified),
                            title: const Text('验证连接'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _run(
                                () => ref
                                    .read(settingsApiProvider)
                                    .verifyDownloader(d.id),
                                '验证请求已发送',
                              );
                            },
                          ),
                          if (!d.isDefault)
                            ListTile(
                              leading: const Icon(Icons.star),
                              title: const Text('设为默认下载器'),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .setDefaultDownloader(d.id),
                                  '已设为默认',
                                );
                              },
                            ),
                          ListTile(
                            leading: const Icon(Icons.speed),
                            title: const Text('限速'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _limits(d);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('删除下载器',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final ok = await confirmDialog(
                                context,
                                title: '删除下载器',
                                message: '确定删除「${d.name}」吗？',
                                confirmLabel: '删除',
                              );
                              if (ok) {
                                await _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .deleteDownloader(d.id),
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
                  label: const Text('添加下载器'),
                  onPressed: () => _save(data, null),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
