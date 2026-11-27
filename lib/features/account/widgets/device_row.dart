import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../state/account_state.dart';

/// 设备行（设备管理）：设备名 + 平台 + 最近活跃 + 本机标记；点按弹出毛玻璃菜单（重命名与吊销，吊销带确认、防连点与错误提示）。
class DeviceRow extends StatefulWidget {
  const DeviceRow({
    super.key,
    required this.device,
    required this.onRename,
    required this.onRevoke,
  });

  final DeviceView device;
  final void Function(String name) onRename;
  final FutureOr<void> Function() onRevoke;

  @override
  State<DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<DeviceRow> {
  bool _revoking = false;

  Future<void> _confirmAndRevoke() async {
    if (_revoking) return;
    final d = widget.device;
    final l10n = McL10n.of(context);
    final confirmed = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              d.current
                  ? '退出当前设备登录？'
                  : '吊销「${d.name ?? '未命名设备'}」？',
              style: McText.titleSm,
            ),
            const SizedBox(height: 8),
            Text(
              d.current
                  ? '你正在吊销当前正在使用的设备。确认后将立即退出本机登录，需要重新输入密码才能继续使用。'
                  : '吊销后该设备会立即掉线并需要重新登录才能访问服务器。',
              style: McText.sub.muted,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: l10n.cancel,
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: d.current ? '退出本机登录' : '吊销',
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
    if (confirmed != true || !mounted) return;
    setState(() => _revoking = true);
    try {
      await widget.onRevoke();
      if (mounted) McToast.success(d.current ? '已退出当前设备登录' : '已吊销该设备');
    } catch (e) {
      if (mounted) McToast.error('吊销设备失败：$e');
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  Future<void> _openActions(BuildContext context) {
    final d = widget.device;
    return showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: d.name ?? '未命名设备',
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              icon: McIcons.edit2,
              title: '重命名',
              onTap: () {
                Navigator.of(ctx).pop();
                _openRenameSheet(context);
              },
            ),
            McInsetRow(
              icon: McIcons.logout,
              title: d.current ? '退出本机登录（吊销当前设备）' : '吊销此设备',
              destructive: true,
              onTap: _revoking
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _confirmAndRevoke();
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRenameSheet(BuildContext context) async {
    final next = await showMcSheet<String>(
      context: context,
      builder: (_) => _RenameDeviceSheet(initial: widget.device.name ?? ''),
    );
    if (next != null && next.isNotEmpty) {
      widget.onRename(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final subtitle = [
      if (device.platform != null && device.platform!.isNotEmpty)
        device.platform!,
      if (device.lastSeen != null && device.lastSeen!.isNotEmpty)
        '最近活跃：${device.lastSeen!}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: McPressable(
        onTap: _revoking ? null : () => _openActions(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(McTokens.cardRadius),
            border: Border.all(color: McTokens.line, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                device.current ? McIcons.iphone : McIcons.device,
                size: 20,
                color:
                    device.current ? McTokens.accentStrong : McTokens.textMuted,
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
                            style: McText.ui.semibold,
                          ),
                        ),
                        if (device.current) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: McTokens.ok.withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(McTokens.pillRadius),
                              border: Border.all(
                                color: McTokens.ok.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '本机',
                              style: McText.micro.copyWith(color: McTokens.ok),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: McText.caption.muted),
                    ],
                  ],
                ),
              ),
              if (_revoking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: McTokens.accentStrong,
                  ),
                )
              else
                const Icon(
                  McIcons.more,
                  size: 18,
                  color: McTokens.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameDeviceSheet extends StatefulWidget {
  const _RenameDeviceSheet({required this.initial});

  final String initial;

  @override
  State<_RenameDeviceSheet> createState() => _RenameDeviceSheetState();
}

class _RenameDeviceSheetState extends State<_RenameDeviceSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('重命名设备', style: McText.titleSm),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            style: McText.body,
            decoration: const InputDecoration(hintText: '设备名称'),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '取消',
                  primary: false,
                  expanded: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: '保存',
                  primary: true,
                  expanded: true,
                  onTap: () =>
                      Navigator.of(context).pop(_controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
