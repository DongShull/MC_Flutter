// 规则集页（对应 web settings subscription 下的规则集 / 安卓 RuleSetsScreen）：
// 规则集列表、新建/重命名、设为默认、删除；每条显示引用数与匹配规则数。
// 注意：规则明细（spec / matchRules 的逐条编辑器）在 web 端是结构化编辑器；
// 本页提供名称编辑与规则 JSON 文本编辑（解析失败会提示，不会静默丢规则），
// 完整的可视化规则编辑器仍缺失（见 P4.md）。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class RuleSetsPage extends ConsumerStatefulWidget {
  const RuleSetsPage({super.key});

  @override
  ConsumerState<RuleSetsPage> createState() => _RuleSetsPageState();
}

class _RuleSetsPageState extends ConsumerState<RuleSetsPage> {
  late Future<List<core.RuleSetView>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<core.RuleSetView>> _load() =>
      ref.read(settingsApiProvider).ruleSets();

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

  Future<void> _save(core.RuleSetView? existing) async {
    final values = await showAdminFormDialog(
      context,
      title: existing == null ? '新建规则集' : '编辑规则集',
      initial: existing == null
          ? null
          : {
              'name': existing.name,
              'matchRules': const JsonEncoder.withIndent('  ')
                  .convert(existing.matchRules),
            },
      fields: const [
        AdminFieldSpec(key: 'name', label: '名称', required: true),
        AdminFieldSpec(
          key: 'matchRules',
          label: '匹配规则（JSON 数组，留空为无规则）',
          hint: '[{"field": "resolution", "op": "gte", "value": "1080p"}]',
        ),
      ],
    );
    if (values == null) return;
    final rawRules = (values['matchRules'] as String? ?? '').trim();
    List<Map<String, dynamic>> rules = [];
    if (rawRules.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRules);
        if (decoded is! List) throw const FormatException('须为 JSON 数组');
        rules = decoded
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (e) {
        if (!mounted) return;
        showSettingsToast(context, '规则 JSON 解析失败：$e');
        return;
      }
    }
    final name = values['name'] as String? ?? '';
    if (existing == null) {
      await _run(
        () => ref.read(settingsApiProvider).createRuleSet(
              core.RuleSetPayload(
                name: name,
                spec: const {},
                matchRules: jsonEncode(rules),
              ),
            ),
        '已创建规则集',
      );
    } else {
      await _run(
        () => ref.read(settingsApiProvider).updateRuleSet(
              existing.id,
              core.RuleSetPayload(
                name: name,
                spec: existing.spec ?? const {},
                matchRules: jsonEncode(rules),
              ),
            ),
        '已保存',
      );
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '规则集',
        body: AdminAsyncBody<List<core.RuleSetView>>(
          future: _future,
          onRetry: _reload,
          builder: (context, items) => ListView(
            children: [
              const SettingsInfoCard(
                text: '规则集决定订阅抓取时接受哪些资源；订阅详情里可以切换使用的规则集。',
              ),
              for (final r in items)
                SettingsRow(
                  icon: Icons.rule,
                  title: r.name,
                  subtitle: [
                    if (r.isDefault) '默认',
                    '被 ${r.referenceCount} 个订阅引用',
                    '${r.matchRules.length} 条匹配规则',
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
                            title: const Text('编辑名称与规则'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _save(r);
                            },
                          ),
                          if (!r.isDefault)
                            ListTile(
                              leading: const Icon(Icons.star),
                              title: const Text('设为默认规则集'),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .setDefaultRuleSet(r.id),
                                  '已设为默认',
                                );
                              },
                            ),
                          ListTile(
                            leading: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('删除规则集',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final ok = await confirmDialog(
                                context,
                                title: '删除规则集',
                                message:
                                    '确定删除「${r.name}」吗？${r.referenceCount > 0 ? '仍有 ${r.referenceCount} 个订阅在引用它。' : ''}',
                                confirmLabel: '删除',
                              );
                              if (ok) {
                                await _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .deleteRuleSet(r.id),
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
                  label: const Text('新建规则集'),
                  onPressed: () => _save(null),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
