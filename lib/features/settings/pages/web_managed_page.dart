import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mc_api.dart';
import '../widgets/settings_ui.dart';

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
            icon: Icons.public,
            text: description.isEmpty
                ? '这一组设置由服务器网页端托管，客户端内不提供编辑。'
                : description,
          ),
          const SettingsGroupLabel('服务器地址'),
          SettingsRow(
            icon: Icons.link,
            title: origin.isEmpty ? '未配置服务器' : origin,
            subtitle: '在浏览器中打开服务器管理页',
            trailing: const Icon(Icons.open_in_new),
            // TODO(browser): 引入 url_launcher 后改为真实拉起浏览器。
            onTap: () => showSettingsToast(context, '请在浏览器中打开 $origin'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
