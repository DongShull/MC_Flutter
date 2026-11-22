// 应用推送页（对应 web settings app-push 分区 / 安卓 PushSettingsScreen）：
// 推送通道列表、官方通道开关、发送测试推送；
// 「我的事件偏好」在「通知与提醒」里改，这里只读展示。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class _AppPushData {
  const _AppPushData({required this.channels, required this.me});

  final core.PushChannelsView channels;
  final core.MyPushView me;
}

class AppPushPage extends ConsumerStatefulWidget {
  const AppPushPage({super.key});

  @override
  ConsumerState<AppPushPage> createState() => _AppPushPageState();
}

class _AppPushPageState extends ConsumerState<AppPushPage> {
  late Future<_AppPushData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AppPushData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results = await Future.wait([api.pushChannelsList(), api.pushMe()]);
    return _AppPushData(
      channels: results[0] as core.PushChannelsView,
      me: results[1] as core.MyPushView,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '应用推送',
        body: AdminAsyncBody<_AppPushData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) {
            final channels = data.channels.channels;
            final official = channels.where((c) => c.kind == 'official').firstOrNull;
            return ListView(
              children: [
                const SettingsGroupLabel('云连接'),
                SettingsRow(
                  icon: Icons.cloud,
                  title: 'MovieClaw Cloud：${data.channels.cloudState}',
                  subtitle: '官方推送通道依赖云连接；断开时只走本机通道',
                ),
                if (official != null)
                  AdminSwitchTile(
                    title: '官方推送通道',
                    subtitle: official.statusText.isEmpty
                        ? null
                        : official.statusText,
                    value: official.enabled,
                    onChanged: (v) async {
                      try {
                        await ref
                            .read(settingsApiProvider)
                            .pushChannelsOfficialSet(v);
                        if (!context.mounted) return;
                        showSettingsToast(
                            context, v ? '官方通道已开启' : '官方通道已关闭');
                        _reload();
                      } catch (e) {
                        if (!context.mounted) return;
                        showSettingsToast(context, '操作失败：$e');
                      }
                    },
                  ),
                const SettingsGroupLabel('推送通道'),
                if (channels.isEmpty)
                  const SettingsInfoCard(text: '当前没有可用的推送通道。'),
                for (final c in channels)
                  SettingsRow(
                    icon: Icons.notifications,
                    title: c.name.isEmpty ? c.id : c.name,
                    subtitle: [
                      c.kind,
                      c.state,
                      if (c.statusText.isNotEmpty) c.statusText,
                      if (!c.enabled) '已停用',
                    ].join(' · '),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('发送测试推送'),
                    onPressed: () async {
                      try {
                        await ref.read(settingsApiProvider).pushTest();
                        if (!context.mounted) return;
                        showSettingsToast(context, '测试推送已发送');
                      } catch (e) {
                        if (!context.mounted) return;
                        showSettingsToast(context, '测试失败：$e');
                      }
                    },
                  ),
                ),
                const SettingsGroupLabel('我的事件偏好（只读）'),
                if (data.me.events.isEmpty)
                  const SettingsInfoCard(text: '当前没有可订阅的推送事件。'),
                for (final e in data.me.events)
                  SettingsRow(
                    icon: e.enabled
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    title: e.title.isEmpty ? e.key : e.title,
                    subtitle: e.enabled ? '接收' : '不接收',
                  ),
                const SettingsInfoCard(
                  text: '改偏好请去“通知与提醒”，那里改的是你自己的接收选择。',
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
