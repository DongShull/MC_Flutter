import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../state/controllers.dart';
import '../widgets/settings_ui.dart';

/// 播放设置页（对应安卓 PlaybackSectionScreen）：
/// 三个意愿开关 + 硬件转码能力卡。
class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key});

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(playbackProvider.notifier).load());
  }

  void _toggle(String which, bool value) {
    final notifier = ref.read(playbackProvider.notifier);
    switch (which) {
      case 'sw':
        notifier.setFlag(softwareTranscodeEnabled: value);
      case 'trick':
        notifier.setFlag(trickplayEnabled: value);
      case 'cache':
        notifier.setFlag(transcodeCacheEnabled: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackProvider);
    final policy = state.valueOrNull;

    return SettingsScaffold(
      title: '播放设置',
      body: policy == null
          ? state.isLoading
              ? const McLoadingView()
              : McErrorView(
                  text: '加载失败',
                  onRetry: () => ref.read(playbackProvider.notifier).load(),
                )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                McInsetGroup(
                  header: '转码与缓存',
                  dividerIndent: 48,
                  children: [
                    McInsetRow(
                      icon: McIcons.transcoding2,
                      title: '允许软件转码',
                      subtitle: '硬件转码不可用时，用 CPU 兜底转码',
                      trailing: Switch(
                        value: policy.softwareTranscodeEnabled,
                        onChanged: (v) => _toggle('sw', v),
                      ),
                      onTap: () =>
                          _toggle('sw', !policy.softwareTranscodeEnabled),
                    ),
                    McInsetRow(
                      icon: McIcons.fastForward,
                      title: '生成进度条预览图',
                      subtitle: '拖动进度条时显示缩略图（trickplay）',
                      trailing: Switch(
                        value: policy.trickplayEnabled,
                        onChanged: (v) => _toggle('trick', v),
                      ),
                      onTap: () => _toggle('trick', !policy.trickplayEnabled),
                    ),
                    McInsetRow(
                      icon: McIcons.save,
                      title: '保留转码产物',
                      subtitle: '转码结果缓存下来，下次播放免转',
                      trailing: Switch(
                        value: policy.transcodeCacheEnabled,
                        onChanged: (v) => _toggle('cache', v),
                      ),
                      onTap: () =>
                          _toggle('cache', !policy.transcodeCacheEnabled),
                    ),
                  ],
                ),
                const SettingsGroupLabel('硬件能力'),
                SettingsInfoCard(
                  icon: McIcons.shieldCheck,
                  text: policy.hardwareAvailable
                      ? '服务器检测到可用硬件转码后端：${policy.hwBackends.join('、')}'
                      : '服务器未检测到可用的硬件转码后端；如已允许，将回退到软件转码。',
                ),
              ],
            ),
    );
  }
}
