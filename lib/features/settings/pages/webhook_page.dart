// Webhook 页（对应 web settings webhook 分区 / 安卓 WebhookSettingsScreen）：
// 总开关、端点列表（新增/编辑/删除）、单端点测试、投递记录。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class WebhookPage extends ConsumerStatefulWidget {
  const WebhookPage({super.key});

  @override
  ConsumerState<WebhookPage> createState() => _WebhookPageState();
}

class _WebhookPageState extends ConsumerState<WebhookPage> {
  late Future<core.WebhookConfigView> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<core.WebhookConfigView> _load() =>
      ref.read(settingsApiProvider).webhookShow();

  void _reload() => setState(() => _future = _load());

  Future<void> _save(core.WebhookConfigView next) async {
    try {
      await ref.read(settingsApiProvider).webhookSet(
            core.WebhookConfigPayload(
              enabled: next.enabled,
              endpoints: next.endpoints
                  .map((e) => core.WebhookEndpointPayload(
                        id: e.id,
                        name: e.name,
                        url: e.url,
                        format: e.format,
                        enabled: e.enabled,
                        events: e.events,
                        template: e.template,
                        headers: e.headers,
                        egressScope: e.egressScope,
                      ))
                  .toList(),
            ),
          );
      if (!mounted) return;
      showSettingsToast(context, '已保存');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '保存失败：$e');
    }
  }

  Future<void> _saveEndpoint(
      core.WebhookConfigView config, core.WebhookEndpointView? existing) async {
    final values = await showAdminFormDialog(
      context,
      title: existing == null ? '添加端点' : '编辑端点',
      initial: existing == null
          ? null
          : {
              'name': existing.name,
              'url': existing.url,
              'format': existing.format,
              'events': existing.events.join(','),
              'enabled': existing.enabled,
            },
      fields: const [
        AdminFieldSpec(key: 'name', label: '名称', required: true),
        AdminFieldSpec(key: 'url', label: 'URL', required: true),
        AdminFieldSpec(
          key: 'format',
          label: '格式',
          kind: AdminFieldKind.select,
          options: [
            (value: 'movieclaw', label: 'MovieClaw'),
            (value: 'generic', label: '通用'),
          ],
        ),
        AdminFieldSpec(
            key: 'events', label: '事件（逗号分隔，留空为全部）', hint: 'downloaded,imported'),
        AdminFieldSpec(
            key: 'enabled', label: '启用', kind: AdminFieldKind.boolean,
            initial: true),
      ],
    );
    if (values == null) return;
    final endpoint = core.WebhookEndpointView(
      id: existing?.id ?? '',
      name: values['name'] as String? ?? '',
      url: values['url'] as String? ?? '',
      format: values['format'] as String? ?? 'movieclaw',
      enabled: values['enabled'] as bool? ?? true,
      events: parseCommaList(values['events'] as String? ?? ''),
      template: existing?.template ?? '',
      headers: existing?.headers ?? const {},
      egressScope: existing?.egressScope ?? 'lan',
    );
    final endpoints = [...config.endpoints];
    if (existing == null) {
      endpoints.add(endpoint);
    } else {
      final i = endpoints.indexWhere((e) => e.id == existing.id);
      if (i >= 0) endpoints[i] = endpoint;
    }
    await _save(config.copyWith(endpoints: endpoints));
  }

  Future<void> _showDeliveries(core.WebhookEndpointView e) async {
    List<core.WebhookDeliveryView>? items;
    String? error;
    try {
      items = await ref.read(settingsApiProvider).webhookDeliveries(e.id);
    } catch (err) {
      error = err.toString();
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('投递记录 · ${e.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: error != null
              ? Text('加载失败：$error')
              : (items == null || items.isEmpty)
                  ? const Text('暂无投递记录')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final d in items)
                          ListTile(
                            leading: Icon(
                              d.ok ? Icons.check_circle : Icons.error,
                              color: d.ok ? Colors.green : Colors.red,
                            ),
                            title: Text(d.event),
                            subtitle: Text(
                                '${d.at} · ${d.statusCode ?? '-'} · ${d.durationMs}ms${d.error.isNotEmpty ? ' · ${d.error}' : ''}'),
                          ),
                      ],
                    ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: 'Webhook',
        body: AdminAsyncBody<core.WebhookConfigView>(
          future: _future,
          onRetry: _reload,
          builder: (context, config) => ListView(
            children: [
              AdminSwitchTile(
                title: '启用 Webhook',
                subtitle: '关闭后不再向任何端点推送事件',
                value: config.enabled,
                onChanged: (v) =>
                    _save(config.copyWith(enabled: v)),
              ),
              const SettingsGroupLabel('端点'),
              if (config.endpoints.isEmpty)
                const SettingsInfoCard(text: '尚未配置端点。'),
              for (final e in config.endpoints)
                SettingsRow(
                  icon: Icons.webhook,
                  title: e.name,
                  subtitle: [
                    e.url,
                    e.format,
                    if (!e.enabled) '已停用',
                    if (e.events.isNotEmpty) e.events.join(', '),
                    if (e.secretMasked.isNotEmpty) '已设密钥',
                  ].join(' · '),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '测试',
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          try {
                            final result = await ref
                                .read(settingsApiProvider)
                                .webhookTest(e.id);
                            if (!context.mounted) return;
                            showSettingsToast(
                                context,
                                result.ok
                                    ? '测试成功（${result.statusCode ?? '-'}）'
                                    : '测试失败：${result.error}');
                          } catch (err) {
                            if (!context.mounted) return;
                            showSettingsToast(context, '测试失败：$err');
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.list),
                            title: const Text('查看投递记录'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showDeliveries(e);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('编辑端点'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _saveEndpoint(config, e);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('删除端点',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final ok = await confirmDialog(
                                context,
                                title: '删除端点',
                                message: '确定删除「${e.name}」吗？',
                                confirmLabel: '删除',
                              );
                              if (ok) {
                                final next = config.copyWith(
                                  endpoints: config.endpoints
                                      .where((x) => x.id != e.id)
                                      .toList(),
                                );
                                await _save(next);
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
                  label: const Text('添加端点'),
                  onPressed: () => _saveEndpoint(config, null),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
