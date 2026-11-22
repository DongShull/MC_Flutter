// 设置总览页（对应 web settings overview 分区）：
// 管理员进设置的落地页——开局清单（必要件配齐情况）+ 链路体检 + 更新提示。
// 数据：GET /health、GET /automation/readiness、GET /app/update/pending、
// GET /app/update/status、GET /app/storage。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/admin_widgets.dart';

class _OverviewData {
  const _OverviewData({
    required this.health,
    required this.readiness,
    required this.pending,
    required this.status,
    required this.storage,
  });

  final core.HealthView health;
  final core.PipelineHealth readiness;
  final PendingUpdate? pending;
  final core.UpdateStatus status;
  final StorageState storage;
}

class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage> {
  late Future<_OverviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OverviewData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results = await Future.wait([
      api.health(),
      api.automationReadiness(),
      api.pendingUpdate(),
      api.updateStatus(),
      api.storage(),
    ]);
    return _OverviewData(
      health: results[0] as core.HealthView,
      readiness: results[1] as core.PipelineHealth,
      pending: results[2] as PendingUpdate?,
      status: results[3] as core.UpdateStatus,
      storage: results[4] as StorageState,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '总览',
        body: AdminAsyncBody<_OverviewData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) {
            final r = data.readiness;
            final checklist = <(String, bool, String)>[
              (
                '站点已配置',
                r.sitesConfigured,
                r.sitesConfigured ? '至少配置了一个资源站点' : '未配置站点，订阅无法抓取资源',
              ),
              (
                '下载器已配置',
                r.downloadersConfigured,
                r.downloadersConfigured ? '下载器可用' : '未配置下载器，订阅无法下载',
              ),
              (
                '下载器连通',
                r.downloaderOk,
                r.downloaderOk ? '下载器连接正常' : '下载器未连通或未配置',
              ),
            ];
            return ListView(
              children: [
                const SettingsGroupLabel('服务健康'),
                SettingsRow(
                  icon: McIcons.globe,
                  title: '服务状态：${data.health.status ?? '未知'}',
                  subtitle: [
                    if ((data.health.service ?? '').isNotEmpty)
                      data.health.service!,
                    if ((data.health.environment ?? '').isNotEmpty)
                      data.health.environment!,
                    '版本 ${data.status.currentVersion}',
                  ].join(' · '),
                ),
                if (data.pending?.hasUpdate == true)
                  SettingsRow(
                    icon: Icons.system_update_outlined,
                    title: data.pending!.label ?? '有可用更新',
                    subtitle: '前往“检查更新”查看详情',
                  ),
                const SettingsGroupLabel('开局清单'),
                for (final (title, ok, subtitle) in checklist)
                  SettingsRow(
                    icon: ok ? Icons.check_circle : Icons.warning_amber,
                    title: title,
                    subtitle: subtitle,
                  ),
                const SettingsGroupLabel('链路体检'),
                SettingsRow(
                  icon: Icons.tune,
                  title: '错误 ${r.errorCount} · 警告 ${r.warnCount}',
                  subtitle: '状态：${r.status}',
                ),
                const SettingsGroupLabel('存储'),
                SettingsRow(
                  icon: Icons.storage,
                  title:
                      '已用 ${mcFormatBytes(data.storage.diskUsed)} / 共 ${mcFormatBytes(data.storage.diskTotal)}',
                  subtitle: '缓存 ${mcFormatBytes(data.storage.cacheBytes)}'
                      ' · 数据 ${mcFormatBytes(data.storage.dataBytes)}',
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
