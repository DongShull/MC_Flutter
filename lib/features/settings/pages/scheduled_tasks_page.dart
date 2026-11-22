// 定时任务页（对应 web scheduled-tasks-section）：
// 后台定时任务列表、启用/停用、触发方式（间隔/定时表达式）与周期编辑。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class ScheduledTasksPage extends ConsumerStatefulWidget {
  const ScheduledTasksPage({super.key});

  @override
  ConsumerState<ScheduledTasksPage> createState() =>
      _ScheduledTasksPageState();
}

class _ScheduledTasksPageState extends ConsumerState<ScheduledTasksPage> {
  late Future<List<core.ScheduledTask>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<core.ScheduledTask>> _load() =>
      ref.read(settingsApiProvider).scheduledTasks();

  void _reload() => setState(() => _future = _load());

  Future<void> _save(core.ScheduledTask task, bool enabled,
      {String? triggerType, int? intervalSeconds, String? cronExpr}) async {
    try {
      await ref.read(settingsApiProvider).updateScheduledTask(
            task.key,
            core.ScheduledTaskUpdate(
              enabled: enabled,
              triggerType: triggerType ?? task.triggerType,
              intervalSeconds: intervalSeconds ?? task.intervalSeconds,
              cronExpr: cronExpr ?? task.cronExpr,
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

  Future<void> _edit(core.ScheduledTask task) async {
    final values = await showAdminFormDialog(
      context,
      title: '编辑任务',
      initial: {
        'triggerType': task.triggerType,
        'intervalSeconds': task.intervalSeconds,
        'cronExpr': task.cronExpr,
        'enabled': task.enabled,
      },
      fields: const [
        AdminFieldSpec(
          key: 'triggerType',
          label: '触发方式',
          kind: AdminFieldKind.select,
          options: [
            (value: 'interval', label: '间隔执行'),
            (value: 'cron', label: '定时表达式（cron）'),
          ],
        ),
        AdminFieldSpec(
            key: 'intervalSeconds', label: '间隔（秒）', kind: AdminFieldKind.number),
        AdminFieldSpec(key: 'cronExpr', label: 'Cron 表达式', hint: '如 0 3 * * *'),
        AdminFieldSpec(
            key: 'enabled', label: '启用', kind: AdminFieldKind.boolean),
      ],
    );
    if (values == null) return;
    await _save(
      task,
      values['enabled'] as bool? ?? task.enabled,
      triggerType: values['triggerType'] as String?,
      intervalSeconds: values['intervalSeconds'] is int
          ? values['intervalSeconds'] as int
          : int.tryParse(values['intervalSeconds']?.toString() ?? ''),
      cronExpr: (values['cronExpr'] as String?)?.trim().isEmpty == true
          ? null
          : values['cronExpr'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '定时任务',
        body: AdminAsyncBody<List<core.ScheduledTask>>(
          future: _future,
          onRetry: _reload,
          builder: (context, tasks) => ListView(
            children: [
              for (final t in tasks)
                SettingsRow(
                  icon: Icons.schedule,
                  title: t.title.isEmpty ? t.key : t.title,
                  subtitle: [
                    if (t.description.isNotEmpty) t.description,
                    t.triggerType == 'cron'
                        ? 'cron ${t.cronExpr ?? ''}'
                        : '每 ${t.intervalSeconds ?? '-'} 秒',
                    if ((t.lastRunAt ?? '').isNotEmpty)
                      '上次 ${t.lastRunAt}',
                    if ((t.nextRunAt ?? '').isNotEmpty)
                      '下次 ${t.nextRunAt}',
                  ].join(' · '),
                  trailing: Switch(
                    value: t.enabled,
                    onChanged: (v) => _save(t, v),
                  ),
                  onTap: () => _edit(t),
                ),
              if (tasks.isEmpty)
                const SettingsInfoCard(text: '当前没有定时任务。'),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
