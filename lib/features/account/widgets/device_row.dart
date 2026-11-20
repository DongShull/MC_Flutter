import 'package:flutter/material.dart';

import '../state/account_state.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 设备行（设备管理）：设备名 + 平台 + 最近活跃 + 本机标记；菜单给重命名与吊销。
class DeviceRow extends StatelessWidget {
  const DeviceRow({
    super.key,
    required this.device,
    required this.onRename,
    required this.onRevoke,
  });

  final DeviceView device;
  final void Function(String name) onRename;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            device.current ? McIcons.iphone : McIcons.device,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.name ?? '未命名设备',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (device.current) ...[
                      const SizedBox(width: 6),
                      Text(
                        '本机',
                        style: TextStyle(fontSize: 12, color: scheme.primary),
                      ),
                    ],
                  ],
                ),
                Text(
                  [
                    if (device.platform != null &&
                        device.platform!.isNotEmpty)
                      device.platform!,
                    if (device.lastSeen != null &&
                        device.lastSeen!.isNotEmpty)
                      '最近活跃：${device.lastSeen!}',
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'rename') {
                final controller =
                    TextEditingController(text: device.name ?? '');
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('重命名设备'),
                    content: TextField(controller: controller),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          onRename(controller.text.trim());
                        },
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                );
              } else if (action == 'revoke') {
                onRevoke();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(value: 'revoke', child: Text('吊销此设备')),
            ],
          ),
        ],
      ),
    );
  }
}
