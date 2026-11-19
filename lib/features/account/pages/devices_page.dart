import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account_state.dart';
import '../widgets/device_row.dart';

/// 设备管理页（对齐 Kotlin 设备管理段：auth/devices）：
/// 清单 + 重命名 / 吊销单台 / 清理其他设备。
class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountProvider.notifier).loadDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(accountProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设备管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final device in ui.devices)
            DeviceRow(
              device: device,
              onRename: (name) {
                if (name.isNotEmpty) {
                  ref.read(accountProvider.notifier).renameDevice(device.id, name);
                }
              },
              onRevoke: () =>
                  ref.read(accountProvider.notifier).revokeDevice(device.id),
            ),
          if (ui.devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '暂时没有其他登录设备',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('清理其他设备？'),
                  content: const Text('将吊销除本机外的所有登录设备。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('清理'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                ref.read(accountProvider.notifier).cleanupDevices();
              }
            },
            child: const Text('清理其他设备'),
          ),
        ],
      ),
    );
  }
}
