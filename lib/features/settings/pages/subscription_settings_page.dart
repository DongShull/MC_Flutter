// 订阅设置页（对应 web settings subscription 分区）：
// 智能默认（分辨率/来源/升级/等待）、智能计划（电影/剧集各一份偏好）、
// 智能记忆（语言理解与习惯）。仅管理员。
// 注意：规则集编辑器在「规则集」页（/settings/rule-sets），订阅详情里可切换规则集。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class _SubscriptionSettingsData {
  const _SubscriptionSettingsData({
    required this.defaults,
    required this.movieProfile,
    required this.tvProfile,
    required this.memory,
  });

  final core.SmartDefaultsView defaults;
  final core.SmartProfileView movieProfile;
  final core.SmartProfileView tvProfile;
  final core.SmartMemoryView memory;
}

class SubscriptionSettingsPage extends ConsumerStatefulWidget {
  const SubscriptionSettingsPage({super.key});

  @override
  ConsumerState<SubscriptionSettingsPage> createState() =>
      _SubscriptionSettingsPageState();
}

class _SubscriptionSettingsPageState
    extends ConsumerState<SubscriptionSettingsPage> {
  late Future<_SubscriptionSettingsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SubscriptionSettingsData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results = await Future.wait([
      api.smartDefaults(),
      api.smartProfile('movie'),
      api.smartProfile('tv'),
      api.smartMemory(),
    ]);
    return _SubscriptionSettingsData(
      defaults: results[0] as core.SmartDefaultsView,
      movieProfile: results[1] as core.SmartProfileView,
      tvProfile: results[2] as core.SmartProfileView,
      memory: results[3] as core.SmartMemoryView,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _saveDefaults(core.SmartDefaultsView next) async {
    try {
      await ref.read(settingsApiProvider).saveSmartDefaults(
            core.SmartDefaultsPayload(
              movieRevision: next.movieRevision,
              tvRevision: next.tvRevision,
              resolution: next.resolution,
              source: next.source,
              allowUpgrade: next.allowUpgrade,
              strictResolution: next.strictResolution,
              movieWaitSeconds: next.movieWaitSeconds,
              tvWaitSeconds: next.tvWaitSeconds,
            ),
          );
      if (!mounted) return;
      showSettingsToast(context, '已保存');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '保存失败：$e');
    }
  }

  Future<void> _saveProfile(
      String kind, core.SmartProfileView profile, core.SmartPreferences prefs) async {
    try {
      await ref.read(settingsApiProvider).saveSmartProfile(
            kind,
            core.SmartProfilePayload(
                revision: profile.revision, preferences: prefs),
          );
      if (!mounted) return;
      showSettingsToast(context, '已保存');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '保存失败：$e');
    }
  }

  Widget _profileSection(
      String kind, String label, core.SmartProfileView profile) {
    final prefs = profile.preferences ?? const core.SmartPreferences();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupLabel(label),
        AdminSelectTile<String>(
          title: '分辨率',
          value: prefs.resolution,
          options: const [
            (value: '2160p', label: '2160p'),
            (value: '1080p', label: '1080p'),
            (value: '720p', label: '720p'),
          ],
          onSelected: (v) => _saveProfile(
              kind, profile, prefs.copyWith(resolution: v)),
        ),
        AdminSelectTile<String>(
          title: '来源',
          value: prefs.source,
          options: const [
            (value: 'web-dl', label: 'WEB-DL'),
            (value: 'bluray', label: 'Blu-ray'),
            (value: 'hdtv', label: 'HDTV'),
          ],
          onSelected: (v) =>
              _saveProfile(kind, profile, prefs.copyWith(source: v)),
        ),
        AdminSwitchTile(
          title: '允许升级',
          subtitle: '有更好资源时自动升级',
          value: prefs.allowUpgrade,
          onChanged: (v) => _saveProfile(
              kind, profile, prefs.copyWith(allowUpgrade: v)),
        ),
        AdminSwitchTile(
          title: '严格分辨率',
          subtitle: '只接受所选分辨率',
          value: prefs.strictResolution,
          onChanged: (v) => _saveProfile(
              kind, profile, prefs.copyWith(strictResolution: v)),
        ),
        AdminTextTile(
          title: '等待时间（秒）',
          value: prefs.waitSeconds.toString(),
          subtitle: '找到资源后等待 ${prefs.waitSeconds} 秒再下载',
          keyboardType: TextInputType.number,
          onSaved: (v) {
            final seconds = int.tryParse(v);
            if (seconds == null) {
              showSettingsToast(context, '请输入数字');
              return;
            }
            _saveProfile(
                kind, profile, prefs.copyWith(waitSeconds: seconds));
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '订阅设置',
        body: AdminAsyncBody<_SubscriptionSettingsData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) {
            final d = data.defaults;
            return ListView(
              children: [
                const SettingsGroupLabel('智能默认'),
                SettingsRow(
                  icon: Icons.info_outline,
                  title: d.configured ? '已配置智能默认' : '未配置智能默认',
                  subtitle: '电影等待 ${d.movieWaitSeconds} 秒 · '
                      '剧集等待 ${d.tvWaitSeconds} 秒',
                ),
                AdminSelectTile<String>(
                  title: '默认分辨率',
                  value: d.resolution,
                  options: const [
                    (value: '2160p', label: '2160p'),
                    (value: '1080p', label: '1080p'),
                    (value: '720p', label: '720p'),
                  ],
                  onSelected: (v) =>
                      _saveDefaults(d.copyWith(resolution: v)),
                ),
                AdminSelectTile<String>(
                  title: '默认来源',
                  value: d.source,
                  options: const [
                    (value: 'web-dl', label: 'WEB-DL'),
                    (value: 'bluray', label: 'Blu-ray'),
                    (value: 'hdtv', label: 'HDTV'),
                  ],
                  onSelected: (v) => _saveDefaults(d.copyWith(source: v)),
                ),
                AdminSwitchTile(
                  title: '允许升级',
                  value: d.allowUpgrade,
                  onChanged: (v) =>
                      _saveDefaults(d.copyWith(allowUpgrade: v)),
                ),
                AdminSwitchTile(
                  title: '严格分辨率',
                  value: d.strictResolution,
                  onChanged: (v) =>
                      _saveDefaults(d.copyWith(strictResolution: v)),
                ),
                _profileSection('movie', '智能计划 · 电影', data.movieProfile),
                _profileSection('tv', '智能计划 · 剧集', data.tvProfile),
                const SettingsGroupLabel('智能记忆'),
                if (data.memory.languages.isEmpty &&
                    data.memory.habits.isEmpty)
                  const SettingsInfoCard(text: '暂无语言记忆与习惯记录。'),
                for (final lang in data.memory.languages)
                  SettingsRow(
                    icon: Icons.language,
                    title: lang.label.isEmpty ? lang.key : lang.label,
                    subtitle: lang.sourceTitle,
                  ),
                for (final habit in data.memory.habits)
                  SettingsRow(
                    icon: Icons.psychology,
                    title: habit.label.isEmpty ? habit.key : habit.label,
                    subtitle: [
                      if (habit.qualityLabel.isNotEmpty)
                        habit.qualityLabel,
                      if ((habit.sourceTitle ?? '').isNotEmpty)
                        habit.sourceTitle!,
                    ].join(' · '),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
