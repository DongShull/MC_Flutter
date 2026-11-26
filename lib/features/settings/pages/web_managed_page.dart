import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
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
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          SettingsInfoCard(
            icon: McIcons.globe,
            text: description.isEmpty
                ? '这一组设置由服务器网页端托管，客户端内不提供编辑。'
                : description,
          ),
          const SizedBox(height: 14),
          McInsetGroup(
            header: '服务器地址',
            children: [
              McInsetRow(
                icon: McIcons.link,
                title: origin.isEmpty ? '未配置服务器' : origin,
                subtitle: '在浏览器中打开服务器管理页',
                trailing: const Icon(McIcons.windowOpen1, size: 18),
                onTap: () {
                  if (origin.isEmpty) {
                    showSettingsToast(context, '未配置服务器地址');
                    return;
                  }
                  launchUrl(
                    Uri.parse(origin),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
