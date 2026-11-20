import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mc_api.dart';
import '../widgets/settings_ui.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 网页托管分区（对应安卓各 *_WEB 分区 / WebManagedSectionScreen）：
/// 这些设置只在服务器 Web UI 里管理，这里只展示说明与服务器地址。
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
                ? '这一组设置由服务器网页端托管，客户端内不提供编辑。'
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
