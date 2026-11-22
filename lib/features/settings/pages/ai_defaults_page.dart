// AI 设定页（对应 web settings ai 分区 / 安卓 AiDefaultsScreen）：
// 默认模型（Agent 对话 / 字幕生成）、联网搜索配置、站内搜索预设。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class _AiData {
  const _AiData({
    required this.defaults,
    required this.models,
    required this.webSearch,
    required this.presets,
  });

  final core.LlmDefaultsView defaults;
  final List<core.LlmModelOption> models;
  final core.WebSearchConfig webSearch;
  final core.SearchPresetsView presets;
}

class AiDefaultsPage extends ConsumerStatefulWidget {
  const AiDefaultsPage({super.key});

  @override
  ConsumerState<AiDefaultsPage> createState() => _AiDefaultsPageState();
}

class _AiDefaultsPageState extends ConsumerState<AiDefaultsPage> {
  late Future<_AiData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AiData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results = await Future.wait([
      api.llmDefaultsShow(),
      api.llmModels(),
      api.webSearchShow(),
      api.searchPresets(),
    ]);
    return _AiData(
      defaults: results[0] as core.LlmDefaultsView,
      models: results[1] as List<core.LlmModelOption>,
      webSearch: results[2] as core.WebSearchConfig,
      presets: results[3] as core.SearchPresetsView,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _saveDefaults(core.LlmDefaultsView next) async {
    try {
      await ref.read(settingsApiProvider).llmDefaultsUpdate(
            core.LlmDefaultsPayload(
              agentModel: next.agentModel,
              subtitleModel: next.subtitleModel,
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

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: 'AI 设定',
        body: AdminAsyncBody<_AiData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) {
            final modelOptions = <({String value, String label})>[
              const (value: '', label: '默认'),
              for (final m in data.models)
                (value: m.ref, label: m.label),
            ];
            return ListView(
              children: [
                const SettingsGroupLabel('默认模型'),
                AdminSelectTile<String>(
                  title: 'Agent 对话模型',
                  value: data.defaults.agentModel ?? '',
                  options: modelOptions,
                  subtitle: (data.defaults.effectiveAgentModel ?? '').isEmpty
                      ? null
                      : '当前生效：${data.defaults.effectiveAgentModel}',
                  onSelected: (v) => _saveDefaults(data.defaults.copyWith(
                      agentModel: v.isEmpty ? null : v)),
                ),
                AdminSelectTile<String>(
                  title: '字幕生成模型',
                  value: data.defaults.subtitleModel ?? '',
                  options: modelOptions,
                  subtitle:
                      (data.defaults.effectiveSubtitleModel ?? '').isEmpty
                          ? null
                          : '当前生效：${data.defaults.effectiveSubtitleModel}',
                  onSelected: (v) => _saveDefaults(data.defaults.copyWith(
                      subtitleModel: v.isEmpty ? null : v)),
                ),
                const SettingsGroupLabel('联网搜索'),
                AdminSelectTile<String>(
                  title: '搜索供应商',
                  value: data.webSearch.provider ?? '',
                  options: [
                    const (value: '', label: '未配置'),
                    for (final p in data.webSearch.providers)
                      (value: p.id, label: p.label),
                  ],
                  subtitle: data.webSearch.configured
                      ? '已配置${data.webSearch.keyHint.isNotEmpty ? ' · ${data.webSearch.keyHint}' : ''}'
                      : '未配置',
                  onSelected: (v) async {
                    if (v.isEmpty) {
                      try {
                        await ref
                            .read(settingsApiProvider)
                            .webSearchClear();
                        if (!context.mounted) return;
                        showSettingsToast(context, '已清除联网搜索配置');
                        _reload();
                      } catch (e) {
                        if (!context.mounted) return;
                        showSettingsToast(context, '清除失败：$e');
                      }
                      return;
                    }
                    final key = await textInputDialog(
                      context,
                      title: 'API Key',
                      hint: '该供应商的 API Key',
                    );
                    if (key == null) return;
                    try {
                      await ref.read(settingsApiProvider).webSearchUpdate(
                            core.WebSearchSavePayload(
                                provider: v, apiKey: key),
                          );
                      if (!context.mounted) return;
                      showSettingsToast(context, '已保存');
                      _reload();
                    } catch (e) {
                      if (!context.mounted) return;
                      showSettingsToast(context, '保存失败：$e');
                    }
                  },
                ),
                const SettingsGroupLabel('站内搜索预设'),
                if (data.presets.presets.isEmpty)
                  const SettingsInfoCard(text: '尚未配置搜索预设。'),
                for (final p in data.presets.presets)
                  SettingsRow(
                    icon: Icons.search,
                    title: (p.name ?? '').isEmpty ? p.id : p.name!,
                    subtitle: [
                      p.type,
                      if (!p.visible) '已隐藏',
                      if (p.categories.isNotEmpty)
                        p.categories.join(', '),
                      if (p.siteIds.isNotEmpty)
                        '${p.siteIds.length} 个站点',
                    ].join(' · '),
                    trailing: Switch(
                      value: p.visible,
                      onChanged: (v) async {
                        final next = data.presets.copyWith(
                          presets: [
                            for (final x in data.presets.presets)
                              x.id == p.id
                                  ? x.copyWith(visible: v)
                                  : x,
                          ],
                        );
                        try {
                          await ref
                              .read(settingsApiProvider)
                              .updateSearchPresets(
                                core.SearchPresetsPayload(
                                  presets: next.presets
                                      .map((x) => x.toJson())
                                      .toList(),
                                ),
                              );
                          if (!context.mounted) return;
                          showSettingsToast(context, '已保存');
                          _reload();
                        } catch (e) {
                          if (!context.mounted) return;
                          showSettingsToast(context, '保存失败：$e');
                        }
                      },
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
