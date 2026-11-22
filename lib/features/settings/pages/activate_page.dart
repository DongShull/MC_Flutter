// 设备激活页（对应安卓 ActivateScreen）：
// 新设备登录时服务端给出一串用户码，在已登录设备上输入该码，
// 查到待批准请求后由管理员批准或拒绝
//（GET /auth/devices/requests/{userCode}、POST …/approve、POST …/deny）。
// 非管理员请求（requiresAdmin）只展示请求信息，不出批准按钮。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../../../core/designsystem/state_views.dart';
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class ActivatePage extends ConsumerStatefulWidget {
  const ActivatePage({super.key});

  @override
  ConsumerState<ActivatePage> createState() => _ActivatePageState();
}

class _ActivatePageState extends ConsumerState<ActivatePage> {
  final _codeController = TextEditingController();
  core.DeviceRequestView? _request;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showSettingsToast(context, '请输入设备码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final req =
          await ref.read(settingsApiProvider).deviceRequest(code);
      if (!mounted) return;
      setState(() => _request = req);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(bool approve) async {
    final req = _request;
    if (req == null) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(settingsApiProvider);
      if (approve) {
        await api.approveDeviceRequest(req.userCode);
      } else {
        await api.denyDeviceRequest(req.userCode);
      }
      if (!mounted) return;
      showSettingsToast(context, approve ? '已批准该设备' : '已拒绝该设备');
      setState(() {
        _request = null;
        _codeController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _request;
    return SettingsScaffold(
      title: '设备激活',
      body: ListView(
        children: [
          const SettingsInfoCard(
            text: '新设备登录时会显示一串设备码；在这里输入设备码，确认是你的设备后批准，设备即可完成登录。',
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: '设备码',
                      hintText: '如 ABCD-EFGH',
                    ),
                    onSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _lookup,
                  child: const Text('查询'),
                ),
              ],
            ),
          ),
          if (_busy) const McLoadingView(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (req != null) ...[
            const SettingsGroupLabel('待批准的设备'),
            SettingsRow(
              icon: Icons.devices,
              title: req.clientName.isEmpty ? req.clientType : req.clientName,
              subtitle: [
                if (req.platform != null && req.platform!.isNotEmpty)
                  req.platform!,
                if ((req.clientVersion ?? '').isNotEmpty)
                  'v${req.clientVersion}',
                if (req.sourceIp.isNotEmpty) req.sourceIp,
                '有效期 ${req.expiresIn} 秒',
              ].join(' · '),
            ),
            if (req.requiresAdmin)
              const SettingsInfoCard(
                text: '该请求需要超级管理员批准，你的账号无权操作。',
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: (_busy || req.requiresAdmin)
                          ? null
                          : () => _decide(true),
                      child: const Text('批准登录'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_busy || req.requiresAdmin)
                          ? null
                          : () => _decide(false),
                      child: const Text('拒绝'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
