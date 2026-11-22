// 模型接入页（对应 web settings llm 分区 / 安卓 LlmSettingsScreen）：
// LLM 供应商列表、新增/编辑/验证/删除；
// ChatGPT 计划连接：web 端的做法是在服务端执行 `mclaw llm chatgpt login`
// 再轮询供应商列表等新供应商出现——app 内同样做：展示命令、轮询等出现。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class _LlmData {
  const _LlmData({required this.providers, required this.presets});

  final List<core.LlmProviderView> providers;
  final List<core.LlmPresetView> presets;
}

class LlmPage extends ConsumerStatefulWidget {
  const LlmPage({super.key});

  @override
  ConsumerState<LlmPage> createState() => _LlmPageState();
}

class _LlmPageState extends ConsumerState<LlmPage> {
  late Future<_LlmData> _future;
  bool _waitingChatGpt = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LlmData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results =
        await Future.wait([api.llmProviders(), api.llmPresets()]);
    return _LlmData(
      providers: results[0] as List<core.LlmProviderView>,
      presets: results[1] as List<core.LlmPresetView>,
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

  Future<void> _save(_LlmData data, core.LlmProviderView? existing) async {
    final presetOptions = data.presets.isEmpty
        ? const [(value: '', label: '自定义')]
        : [
            const (value: '', label: '自定义'),
            for (final p in data.presets)
              (
                value: p.id,
                label: p.displayName.isEmpty ? p.id : p.displayName,
              ),
          ];
    final values = await showAdminFormDialog(
      context,
      title: existing == null ? '添加模型供应商' : '编辑模型供应商',
      initial: existing == null
          ? null
          : {
              'name': existing.name,
              'providerType': existing.providerType,
              'baseUrl': existing.baseUrl,
              'defaultModel': existing.defaultModel,
            },
      fields: [
        const AdminFieldSpec(key: 'name', label: '名称', required: true),
        AdminFieldSpec(
          key: 'preset',
          label: '预设',
          kind: AdminFieldKind.select,
          options: presetOptions,
        ),
        const AdminFieldSpec(key: 'providerType', label: '类型', hint: '如 openai / anthropic'),
        const AdminFieldSpec(key: 'baseUrl', label: 'Base URL'),
        const AdminFieldSpec(
            key: 'apiKey', label: 'API Key（留空不改）', kind: AdminFieldKind.password),
        const AdminFieldSpec(key: 'defaultModel', label: '默认模型'),
      ],
    );
    if (values == null) return;
    var providerType = values['providerType'] as String? ?? '';
    final presetId = values['preset'] as String? ?? '';
    if (providerType.isEmpty && presetId.isNotEmpty) {
      providerType = presetId;
    }
    final payload = core.LlmProviderPayload(
      name: values['name'] as String? ?? '',
      providerType: providerType,
      baseUrl: _nonEmpty(values['baseUrl']),
      apiKey: _nonEmpty(values['apiKey']),
      defaultModel: _nonEmpty(values['defaultModel']),
    );
    if (existing == null) {
      await _run(
          () => ref.read(settingsApiProvider).createLlmProvider(payload),
          '已添加供应商');
    } else {
      await _run(
          () => ref
              .read(settingsApiProvider)
              .updateLlmProvider(existing.id, payload),
          '已保存');
    }
  }

  /// ChatGPT 计划连接：服务端命令行登录，app 内轮询供应商列表等它出现。
  Future<void> _waitChatGpt(List<core.LlmProviderView> before) async {
    setState(() => _waitingChatGpt = true);
    final beforeIds = before.map((p) => p.id).toSet();
    final started = DateTime.now();
    try {
      while (DateTime.now().difference(started).inMinutes < 10) {
        await Future<void>.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        final providers =
            await ref.read(settingsApiProvider).llmProviders();
        final found = providers.where((p) =>
            p.providerType == 'chatgpt' && !beforeIds.contains(p.id));
        if (found.isNotEmpty) {
          final first = found.first;
          if (!mounted) return;
          if (first.status == 'failed') {
            showSettingsToast(
                context, '连接失败：${first.lastError ?? '未知错误'}');
          } else {
            showSettingsToast(context, 'ChatGPT 已连接');
            _reload();
          }
          return;
        }
      }
      if (!mounted) return;
      showSettingsToast(context, '等待超时：10 分钟内未检测到新的 ChatGPT 供应商');
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '轮询失败：$e');
    } finally {
      if (mounted) setState(() => _waitingChatGpt = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '模型接入',
        body: AdminAsyncBody<_LlmData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) => ListView(
            children: [
              if (data.providers.isEmpty)
                const SettingsInfoCard(text: '尚未接入任何模型供应商。'),
              for (final p in data.providers)
                SettingsRow(
                  icon: Icons.auto_awesome,
                  title: p.name,
                  subtitle: [
                    p.providerType,
                    if (p.defaultModel.isNotEmpty) p.defaultModel,
                    p.status,
                    if (!p.usable) '不可用',
                    if ((p.lastError ?? '').isNotEmpty) p.lastError!,
                  ].join(' · '),
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
                              _save(data, p);
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
                                    .verifyLlmProvider(p.id),
                                '验证请求已发送',
                              );
                            },
                          ),
                          if ((p.availableModels ?? []).isNotEmpty)
                            ListTile(
                              leading: const Icon(Icons.list),
                              title: Text(
                                  '可用模型：${p.availableModels!.join(', ')}'),
                            ),
                          ListTile(
                            leading: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('删除供应商',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final ok = await confirmDialog(
                                context,
                                title: '删除供应商',
                                message: '确定删除「${p.name}」吗？',
                                confirmLabel: '删除',
                              );
                              if (ok) {
                                await _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .deleteLlmProvider(p.id),
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
                  label: const Text('添加供应商'),
                  onPressed: () => _save(data, null),
                ),
              ),
              const SettingsGroupLabel('ChatGPT 计划连接'),
              const SettingsInfoCard(
                text: 'ChatGPT 计划用服务端命令行登录：在服务器上执行下面命令完成登录，本页会自动检测到新供应商。',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      'mclaw llm chatgpt login',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  icon: _waitingChatGpt
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.hourglass_top),
                  label: Text(_waitingChatGpt ? '等待连接中…' : '我已在服务器执行，开始检测'),
                  onPressed: _waitingChatGpt
                      ? null
                      : () => _waitChatGpt(data.providers),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
