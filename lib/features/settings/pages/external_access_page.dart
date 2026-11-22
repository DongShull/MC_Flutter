// 外部访问页（对应 web 外部访问 / 安卓 ExternalAccessScreen）：
// 外部地址（external_url）与 Web 端口（web_port），以及服务端监听地址一览。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class _ExternalAccessData {
  const _ExternalAccessData({required this.config, required this.addresses});

  final core.AppConfig config;
  final core.ServerAddressesView addresses;
}

class ExternalAccessPage extends ConsumerStatefulWidget {
  const ExternalAccessPage({super.key});

  @override
  ConsumerState<ExternalAccessPage> createState() =>
      _ExternalAccessPageState();
}

class _ExternalAccessPageState extends ConsumerState<ExternalAccessPage> {
  late Future<_ExternalAccessData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExternalAccessData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results = await Future.wait([
      api.appConfigShow(),
      api.serverAddresses(),
    ]);
    return _ExternalAccessData(
      config: results[0] as core.AppConfig,
      addresses: results[1] as core.ServerAddressesView,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '外部访问',
        body: AdminAsyncBody<_ExternalAccessData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) {
            final c = data.config;
            return ListView(
              children: [
                const SettingsInfoCard(
                  text: '外部地址是别人从外网访问这台服务器用的地址；Web 端口改动后需重启服务端生效。',
                ),
                AdminTextTile(
                  title: '外部地址',
                  value: c.externalUrl,
                  subtitle: c.externalUrl.isEmpty
                      ? '未配置（留空则用自动检测）'
                      : c.externalUrl,
                  hint: '如 https://mc.example.com',
                  onSaved: (v) async {
                    try {
                      await ref.read(settingsApiProvider).appConfigSave(
                          core.AppConfigPayload(externalUrl: v));
                      if (!context.mounted) return;
                      showSettingsToast(context, '已保存');
                      _reload();
                    } catch (e) {
                      if (!context.mounted) return;
                      showSettingsToast(context, '保存失败：$e');
                    }
                  },
                ),
                AdminTextTile(
                  title: 'Web 端口',
                  value: c.webPort == 0 ? '' : c.webPort.toString(),
                  subtitle: c.webPortConfigurable
                      ? '当前 ${c.webPort}（默认 ${c.webPortDefault}，来源 ${c.webPortSource}）'
                      : '当前 ${c.webPort}（不可改：来源 ${c.webPortSource}）',
                  hint: '如 8080',
                  keyboardType: TextInputType.number,
                  onSaved: (v) async {
                    if (!c.webPortConfigurable) {
                      showSettingsToast(context, '当前端口不可改（来源 ${c.webPortSource}）');
                      return;
                    }
                    final port = v.isEmpty ? null : int.tryParse(v);
                    if (v.isNotEmpty && port == null) {
                      showSettingsToast(context, '请输入数字端口');
                      return;
                    }
                    try {
                      await ref
                          .read(settingsApiProvider)
                          .appPortSave(port);
                      if (!context.mounted) return;
                      showSettingsToast(context, '已保存，重启服务端后生效');
                      _reload();
                    } catch (e) {
                      if (!context.mounted) return;
                      showSettingsToast(context, '保存失败：$e');
                    }
                  },
                ),
                if (c.webPortRejected != null)
                  SettingsRow(
                    icon: Icons.warning_amber,
                    title: '端口 ${c.webPortRejected} 被拒绝',
                    subtitle: '该端口已被占用或不可用',
                  ),
                const SettingsGroupLabel('服务端监听地址'),
                for (final a in data.addresses.addresses)
                  SettingsRow(
                    icon: Icons.lan,
                    title: a.url,
                    subtitle: [a.kind, a.source].join(' · '),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
