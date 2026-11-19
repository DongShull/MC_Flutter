import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/controllers.dart';
import '../widgets/settings_ui.dart';

/// 设置索引页（对应安卓 feature/settings 的 SettingsSectionScreen：
/// 分组「账号 / 播放 / 服务器」，超管多一组维护入口）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(profileProvider).valueOrNull;
    final isAdmin = session?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const SettingsGroupLabel('账号'),
          SettingsRow(
            icon: Icons.person_outline,
            title: '个人信息',
            subtitle: session?.displayName,
            onTap: () => context.push('/settings/profile'),
          ),
          SettingsRow(
            icon: Icons.devices_other,
            title: '我的设备',
            subtitle: '已配对的登录设备与播放器',
            onTap: () => context.push('/settings/devices'),
          ),
          SettingsRow(
            icon: Icons.notifications_none,
            title: '通知与提醒',
            subtitle: '服务器公告与告警',
            onTap: () => context.push('/notices'),
          ),
          const SettingsGroupLabel('播放'),
          SettingsRow(
            icon: Icons.play_circle_outline,
            title: '播放设置',
            subtitle: '转码 / 预览图 / 缓存',
            onTap: () => context.push('/settings/playback'),
          ),
          const SettingsGroupLabel('服务器'),
          SettingsRow(
            icon: Icons.public,
            title: '网页托管',
            subtitle: '在浏览器里打开服务器管理页',
            onTap: () => context.push('/settings/web'),
          ),
          if (isAdmin)
            SettingsRow(
              icon: Icons.build_outlined,
              title: '服务器维护',
              subtitle: '版本 / 重启 / 存储清理',
              onTap: () => context.push('/settings/maintenance'),
            ),
          SettingsRow(
            icon: Icons.system_update_outlined,
            title: '检查更新',
            subtitle: '客户端版本与升级',
            onTap: () => context.push('/update'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
