// IM 推送页（对应 web settings im-push 分区）：
// 两个开关：下载完成推送、导入完成推送（GET/PUT /channels/im-push/config）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class ImPushPage extends ConsumerStatefulWidget {
  const ImPushPage({super.key});

  @override
  ConsumerState<ImPushPage> createState() => _ImPushPageState();
}

class _ImPushPageState extends ConsumerState<ImPushPage> {
  late Future<core.ChannelPushConfigView> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<core.ChannelPushConfigView> _load() =>
      ref.read(settingsApiProvider).imPushConfigGet();

  void _reload() => setState(() => _future = _load());

  Future<void> _save(core.ChannelPushConfigView next) async {
    try {
      await ref.read(settingsApiProvider).imPushConfigUpdate(next);
      if (!mounted) return;
      showSettingsToast(context, '已保存');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: 'IM 推送',
        body: AdminAsyncBody<core.ChannelPushConfigView>(
          future: _future,
          onRetry: _reload,
          builder: (context, config) => ListView(
            children: [
              const SettingsInfoCard(
                text: '把下载与导入完成的消息推到你绑定的即时通讯工具；绑定方式与通道在服务端配置。',
              ),
              AdminSwitchTile(
                title: '下载完成推送',
                subtitle: '下载任务完成时推送消息',
                value: config.pushDispatch,
                onChanged: (v) => _save(config.copyWith(pushDispatch: v)),
              ),
              AdminSwitchTile(
                title: '导入完成推送',
                subtitle: '文件入库完成时推送消息',
                value: config.pushImported,
                onChanged: (v) => _save(config.copyWith(pushImported: v)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
