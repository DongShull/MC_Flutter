import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/theme.dart';
import '../state/account_state.dart';
import '../widgets/device_row.dart';

/// 设备管理页（auth/devices）：支持查看已登录设备、重命名与逐台吊销。
/// 已移除危险的 `inactive_days: 0` 一键吊销全部设备按钮，避免误踢所有活跃终端。
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
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/account'),
            title: '设备管理',
            titleVisible: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                McTokens.pagePadding,
                12,
                McTokens.pagePadding,
                36,
              ),
              children: [
                for (final device in ui.devices)
                  DeviceRow(
                    device: device,
                    onRename: (name) {
                      if (name.isNotEmpty) {
                        ref
                            .read(accountProvider.notifier)
                            .renameDevice(device.id, name);
                      }
                    },
                    onRevoke: () => ref
                        .read(accountProvider.notifier)
                        .revokeDevice(device.id),
                  ),
                if (ui.devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text('暂时没有其他登录设备', style: McText.sub.muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
