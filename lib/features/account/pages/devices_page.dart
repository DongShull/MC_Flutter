import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
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

  Future<void> _confirmCleanup() async {
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('清理其他设备？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text('将吊销除本机外的所有登录设备。', style: McText.sub.muted),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '清理',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      ref.read(accountProvider.notifier).cleanupDevices();
    }
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
                const SizedBox(height: 14),
                Center(
                  child: McActionPill(
                    label: '清理其他设备',
                    icon: McIcons.eraser,
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: _confirmCleanup,
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
