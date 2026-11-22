// 云页（对应 web settings cloud 分区 / 安卓 CloudSettingsScreen）：
// MovieClaw Cloud 连接状态、续期、统计上报开关、断开连接。
// 注意：首次配对（pairing）流程在 web 端走配对码；本页只做已连接状态的管理，
// 未连接时提示去服务端执行配对（见 P4.md）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class CloudPage extends ConsumerStatefulWidget {
  const CloudPage({super.key});

  @override
  ConsumerState<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends ConsumerState<CloudPage> {
  late Future<core.CloudStatusView> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<core.CloudStatusView> _load() =>
      ref.read(settingsApiProvider).cloudStatus();

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '云',
        body: AdminAsyncBody<core.CloudStatusView>(
          future: _future,
          onRetry: _reload,
          builder: (context, status) => ListView(
            children: [
              const SettingsGroupLabel('连接状态'),
              SettingsRow(
                icon: Icons.cloud,
                title: '状态：${status.state}',
                subtitle: [
                  if (status.cloudUrl.isNotEmpty) status.cloudUrl,
                  if (status.serverName.isNotEmpty) status.serverName,
                  if ((status.healthMessage ?? '').isNotEmpty)
                    status.healthMessage!,
                  if ((status.lastReportAt ?? '').isNotEmpty)
                    '上次上报 ${status.lastReportAt}',
                ].join(' · '),
              ),
              if (status.state == 'disconnected')
                const SettingsInfoCard(
                  text: '尚未连接 MovieClaw Cloud。首次连接需在服务端执行配对流程，配对成功后这里会显示连接状态。',
                ),
              AdminSwitchTile(
                title: '上报使用统计',
                subtitle: '帮助改进产品，可随时关闭',
                value: status.reportStats,
                onChanged: (v) async {
                  try {
                    await ref
                        .read(settingsApiProvider)
                        .cloudSettingsSet(
                            core.CloudSettingsRequest(reportStats: v));
                    if (!context.mounted) return;
                    showSettingsToast(context, '已保存');
                    _reload();
                  } catch (e) {
                    if (!context.mounted) return;
                    showSettingsToast(context, '保存失败：$e');
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(settingsApiProvider)
                                .cloudRenew();
                            if (!context.mounted) return;
                            showSettingsToast(context, '云连接已续期');
                            _reload();
                          } catch (e) {
                            if (!context.mounted) return;
                            showSettingsToast(context, '续期失败：$e');
                          }
                        },
                        child: const Text('续期'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.error,
                        ),
                        onPressed: status.state == 'disconnected'
                            ? null
                            : () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: '断开云连接',
                                  message: '断开后远程访问与云推送将不可用。',
                                  confirmLabel: '断开',
                                );
                                if (!ok) return;
                                try {
                                  await ref
                                      .read(settingsApiProvider)
                                      .cloudDisconnect();
                                  if (!context.mounted) return;
                                  showSettingsToast(context, '已断开云连接');
                                  _reload();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  showSettingsToast(context, '断开失败：$e');
                                }
                              },
                        child: const Text('断开连接'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
