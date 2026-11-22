// 网盘页（对应 web settings drives 分区）：
// 网盘后端一览、账号列表（刷新/删除）、扫码登录、导入设置。
// 注意：Cookie 粘贴与填表登录两种方式由后端插件能力决定，
// 本页只做扫码登录；Cookie/表单登录未实现（见 P4.md）。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/raw_models.dart';
import '../widgets/admin_widgets.dart';

class _DrivesData {
  const _DrivesData({
    required this.status,
    required this.backends,
    required this.accounts,
    required this.settings,
  });

  final DriveStatus status;
  final List<DriveBackend> backends;
  final List<DriveAccount> accounts;
  final DriveSettings settings;
}

class DrivesPage extends ConsumerStatefulWidget {
  const DrivesPage({super.key});

  @override
  ConsumerState<DrivesPage> createState() => _DrivesPageState();
}

class _DrivesPageState extends ConsumerState<DrivesPage> {
  late Future<_DrivesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DrivesData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results = await Future.wait([
      api.driveStatus(),
      api.driveBackends(),
      api.driveAccounts(),
      api.driveSettings(),
    ]);
    return _DrivesData(
      status: results[0] as DriveStatus,
      backends: results[1] as List<DriveBackend>,
      accounts: results[2] as List<DriveAccount>,
      settings: results[3] as DriveSettings,
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

  /// 扫码登录：发起后展示二维码，轮询等确认。
  Future<void> _scanLogin(DriveBackend backend) async {
    DriveLogin login;
    try {
      login = await ref.read(settingsApiProvider).startDriveLogin(backend.type);
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '发起登录失败：$e');
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DriveLoginDialog(
        backendTitle:
            backend.title.isEmpty ? backend.type : backend.title,
        login: login,
        poll: (loginId) =>
            ref.read(settingsApiProvider).driveLoginStatus(loginId),
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      showSettingsToast(context, '网盘登录成功');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '网盘',
        body: AdminAsyncBody<_DrivesData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) => ListView(
            children: [
              if (!data.status.awake)
                SettingsInfoCard(
                  text: '网盘功能未唤醒${data.status.message.isEmpty ? '' : '：${data.status.message}'}。需要有插件提供网盘后端。',
                ),
              const SettingsGroupLabel('已登录账号'),
              if (data.accounts.isEmpty)
                const SettingsInfoCard(text: '尚未登录任何网盘账号。'),
              for (final a in data.accounts)
                SettingsRow(
                  icon: Icons.cloud,
                  title: a.name,
                  subtitle: [
                    a.backendTitle,
                    a.statusLabel,
                    if ((a.statusMessage ?? '').isNotEmpty)
                      a.statusMessage!,
                    if ((a.vip ?? '').isNotEmpty) a.vip!,
                    '今日已用 ${a.usedToday} 次',
                    if (a.quotaTotal != null)
                      '容量 ${mcFormatBytes(a.quotaUsed ?? 0)} / ${mcFormatBytes(a.quotaTotal!)}',
                  ].join(' · '),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.refresh),
                            title: const Text('刷新状态'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _run(
                                () => ref
                                    .read(settingsApiProvider)
                                    .refreshDriveAccount(a.id),
                                '已刷新',
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('删除账号',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final ok = await confirmDialog(
                                context,
                                title: '删除网盘账号',
                                message: '确定删除「${a.name}」吗？',
                                confirmLabel: '删除',
                              );
                              if (ok) {
                                await _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .deleteDriveAccount(a.id),
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
              const SettingsGroupLabel('添加账号（扫码登录）'),
              if (data.backends.isEmpty)
                const SettingsInfoCard(text: '没有可用的网盘后端。'),
              for (final b in data.backends)
                SettingsRow(
                  icon: Icons.add_to_drive,
                  title: b.title.isEmpty ? b.type : b.title,
                  subtitle: b.description.isEmpty ? null : b.description,
                  onTap: b.scanLogin
                      ? () => _scanLogin(b)
                      : () => showSettingsToast(
                          context, '该后端不支持扫码登录（仅支持 Cookie/表单登录，暂未实现）'),
                ),
              const SettingsGroupLabel('导入设置'),
              AdminSwitchTile(
                title: '本地腾空后删除下载任务',
                subtitle: '本地文件腾空到网盘后，删除对应的下载任务',
                value: data.settings.removeDownloadTasks,
                onChanged: (v) async {
                  try {
                    await ref
                        .read(settingsApiProvider)
                        .updateDriveSettings(
                            DriveSettings(removeDownloadTasks: v));
                    if (!context.mounted) return;
                    showSettingsToast(context, '已保存');
                    _reload();
                  } catch (e) {
                    if (!context.mounted) return;
                    showSettingsToast(context, '保存失败：$e');
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}

/// 扫码登录弹窗：展示二维码，轮询等确认/过期。
class _DriveLoginDialog extends StatefulWidget {
  const _DriveLoginDialog({
    required this.backendTitle,
    required this.login,
    required this.poll,
  });

  final String backendTitle;
  final DriveLogin login;
  final Future<DriveLogin> Function(String loginId) poll;

  @override
  State<_DriveLoginDialog> createState() => _DriveLoginDialogState();
}

class _DriveLoginDialogState extends State<_DriveLoginDialog> {
  Timer? _timer;
  String _status = 'pending';
  String _message = '';

  @override
  void initState() {
    super.initState();
    _message = widget.login.message;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final next = await widget.poll(widget.login.loginId);
        if (!mounted) return;
        if (next.confirmed) {
          _timer?.cancel();
          Navigator.of(context).pop(true);
        } else if (next.expired) {
          _timer?.cancel();
          setState(() {
            _status = next.status;
            _message = next.message.isEmpty ? '二维码已过期' : next.message;
          });
        } else {
          setState(() => _message = next.message);
        }
      } catch (_) {
        // 轮询失败继续等，不打断扫码。
      }
    });
    // 5 分钟未确认自动停。
    Future<void>.delayed(const Duration(minutes: 5), () {
      if (mounted && _status == 'pending') {
        _timer?.cancel();
        Navigator.of(context).pop(false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qr = widget.login.qrImage;
    final bytes = qr.contains(',')
        ? base64Decode(qr.split(',').last)
        : base64Decode(qr);
    return AlertDialog(
      title: Text('扫码登录 · ${widget.backendTitle}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qr.isNotEmpty) Image.memory(bytes, width: 220, height: 220),
          const SizedBox(height: 12),
          Text(_status == 'pending'
              ? (_message.isEmpty ? '请用网盘 App 扫码' : _message)
              : _message),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
