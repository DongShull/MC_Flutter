// 通知与提醒页（对应 web settings notifications 分区，成员可见）：
// 每个人自己选收哪些推送事件（GET/PUT /push/me）。
// 推送通道本身（官方通道开关、测试）在「应用推送」分区管理。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class NotificationsSettingsPage extends ConsumerStatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  ConsumerState<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState
    extends ConsumerState<NotificationsSettingsPage> {
  late Future<core.MyPushView> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<core.MyPushView> _load() =>
      ref.read(settingsApiProvider).pushMe();

  void _reload() => setState(() => _future = _load());

  Future<void> _toggle(String key, bool value) async {
    final current = await _future;
    final events = {
      for (final e in current.events) e.key: e.key == key ? value : e.enabled,
    };
    try {
      await ref.read(settingsApiProvider).pushPreferences(events);
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
        title: '通知与提醒',
        body: AdminAsyncBody<core.MyPushView>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) {
            if (data.events.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('当前没有可订阅的推送事件'),
                ),
              );
            }
            final groups = <String, List<core.PushEventPref>>{};
            for (final e in data.events) {
              groups.putIfAbsent(e.group, () => []).add(e);
            }
            return ListView(
              children: [
                const SettingsInfoCard(
                  text: '只控制你自己的手机收到哪些事件；推送通道由管理员在“应用推送”里管理。',
                ),
                for (final entry in groups.entries) ...[
                  SettingsGroupLabel(
                      entry.key.isEmpty ? '事件' : entry.key),
                  for (final e in entry.value)
                    AdminSwitchTile(
                      title: e.title.isEmpty ? e.key : e.title,
                      subtitle: e.description.isEmpty ? null : e.description,
                      value: e.enabled,
                      onChanged: (v) => _toggle(e.key, v),
                    ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
