import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mc_api.dart';
import '../widgets/settings_ui.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 网页托管分区（对应安卓各 *_WEB 分区 / WebManagedSectionScreen）。
///
/// P4 之后：25 个 parity 设置分区已全部在 app 内原生实现，设置索引不再链向这里。
/// 本页只保留作未知深链（/settings/web?title=…）的兜底：说明情况并给出去
/// 浏览器打开服务器管理页的入口；不要再把已知分区接回这里。
class WebManagedPage extends ConsumerWidget {
  const WebManagedPage({super.key, this.title = '网页托管', this.description = ''});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(settingsApiProvider).origin;

    return SettingsScaffold(
      title: title,
      body: ListView(
        children: [
          SettingsInfoCard(
            icon: McIcons.globe,
            text: description.isEmpty
                ? '这一组设置已在应用内提供；如果你是从旧链接进来的，请返回设置首页重新选择。'
                    '确实只能在网页端做的操作，才会走到这里。'
                : description,
          ),
          const SettingsGroupLabel('服务器地址'),
          SettingsRow(
            icon: McIcons.link,
            title: origin.isEmpty ? '未配置服务器' : origin,
            subtitle: '在浏览器中打开服务器管理页',
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              if (origin.isEmpty) {
                showSettingsToast(context, '未配置服务器地址');
                return;
              }
              launchUrl(Uri.parse(origin), mode: LaunchMode.externalApplication);
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () => context.go('/settings'),
              child: const Text('返回设置首页'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
