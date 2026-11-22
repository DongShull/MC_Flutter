// 外观页（对应 web settings appearance 分区）：
// 语言与主题偏好（GET/PUT /ui/preferences），成员可见。
// 注意：主题值是主题 ID（theme-sdk 主题目录），空 = 默认主题；
// 自定义主题目录本身是否移植到 app 是产品决策（见 P4.md），这里不编造主题列表，
// 只提供主题 ID 文本框与移动/桌面端主题 ID。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  late Future<core.UiPreferencesSetting> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<core.UiPreferencesSetting> _load() =>
      ref.read(settingsApiProvider).uiPreferences();

  void _reload() => setState(() => _future = _load());

  Future<void> _save(core.UiPreferencesSetting next) async {
    try {
      await ref.read(settingsApiProvider).updateUiPreferences(next);
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
        title: '外观',
        body: AdminAsyncBody<core.UiPreferencesSetting>(
          future: _future,
          onRetry: _reload,
          builder: (context, prefs) {
            final badges = prefs.posterBadges;
            return ListView(
              children: [
                const SettingsGroupLabel('语言与主题'),
                AdminSelectTile<String>(
                  title: '语言',
                  value: prefs.language,
                  options: const [
                    (value: '', label: '跟随系统'),
                    (value: 'zh-Hans', label: '简体中文'),
                    (value: 'en', label: 'English'),
                    (value: 'de', label: 'Deutsch'),
                  ],
                  onSelected: (v) => _save(prefs.copyWith(language: v)),
                ),
                AdminTextTile(
                  title: '主题',
                  value: prefs.theme,
                  subtitle: prefs.theme.isEmpty
                      ? '默认主题（主题 ID，见 P4 说明）'
                      : prefs.theme,
                  hint: '主题 ID，留空为默认',
                  onSaved: (v) => _save(prefs.copyWith(theme: v)),
                ),
                AdminTextTile(
                  title: '移动端主题',
                  value: prefs.themeMobile,
                  subtitle: (prefs.themeMobile ?? '').isEmpty
                      ? '跟随主题'
                      : prefs.themeMobile,
                  hint: '主题 ID，留空跟随',
                  onSaved: (v) =>
                      _save(prefs.copyWith(themeMobile: v.isEmpty ? null : v)),
                ),
                AdminTextTile(
                  title: '桌面端主题',
                  value: prefs.themeDesktop,
                  subtitle: (prefs.themeDesktop ?? '').isEmpty
                      ? '跟随主题'
                      : prefs.themeDesktop,
                  hint: '主题 ID，留空跟随',
                  onSaved: (v) => _save(
                      prefs.copyWith(themeDesktop: v.isEmpty ? null : v)),
                ),
                const SettingsGroupLabel('海报角标'),
                AdminSwitchTile(
                  title: '评分',
                  value: badges.rating,
                  onChanged: (v) => _save(prefs.copyWith(
                      posterBadges: badges.copyWith(rating: v))),
                ),
                AdminSwitchTile(
                  title: '年份',
                  value: badges.year,
                  onChanged: (v) => _save(prefs.copyWith(
                      posterBadges: badges.copyWith(year: v))),
                ),
                AdminSwitchTile(
                  title: '分辨率',
                  value: badges.resolution,
                  onChanged: (v) => _save(prefs.copyWith(
                      posterBadges: badges.copyWith(resolution: v))),
                ),
                AdminSwitchTile(
                  title: '播放进度',
                  value: badges.progress,
                  onChanged: (v) => _save(prefs.copyWith(
                      posterBadges: badges.copyWith(progress: v))),
                ),
                AdminSwitchTile(
                  title: '未看角标',
                  value: badges.unwatched,
                  onChanged: (v) => _save(prefs.copyWith(
                      posterBadges: badges.copyWith(unwatched: v))),
                ),
                AdminSwitchTile(
                  title: '中文字幕角标',
                  value: badges.chineseSubtitle,
                  onChanged: (v) => _save(prefs.copyWith(
                      posterBadges: badges.copyWith(chineseSubtitle: v))),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
