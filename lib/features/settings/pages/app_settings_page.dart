// 应用页（对应 web settings app 分区）：
// GitHub Token（更新检查用）、更新保留版本数、识别模型更新检查与应用。
// 外部地址与 Web 端口在「外部访问」分区。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class _AppSettingsData {
  const _AppSettingsData({required this.github, required this.modelCheck});

  final core.GithubToken github;
  final core.ModelUpdateCheck modelCheck;
}

class AppSettingsPage extends ConsumerStatefulWidget {
  const AppSettingsPage({super.key});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  late Future<_AppSettingsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AppSettingsData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results =
        await Future.wait([api.githubToken(), api.checkModelUpdate()]);
    return _AppSettingsData(
      github: results[0] as core.GithubToken,
      modelCheck: results[1] as core.ModelUpdateCheck,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '应用',
        body: AdminAsyncBody<_AppSettingsData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) => ListView(
            children: [
              const SettingsGroupLabel('更新'),
              SettingsRow(
                icon: Icons.system_update_outlined,
                title: data.modelCheck.updateAvailable
                    ? '识别模型有新版本 ${data.modelCheck.latestTag}'
                    : '识别模型已是最新',
                subtitle:
                    '当前 ${data.modelCheck.currentTag ?? '未知'} · 发布于 ${data.modelCheck.publishedAt}',
                trailing: data.modelCheck.updateAvailable &&
                        data.modelCheck.installable
                    ? FilledButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(settingsApiProvider)
                                .applyModelUpdate();
                            if (!context.mounted) return;
                            showSettingsToast(context, '识别模型更新已开始');
                            _reload();
                          } catch (e) {
                            if (!context.mounted) return;
                            showSettingsToast(context, '更新失败：$e');
                          }
                        },
                        child: const Text('更新'),
                      )
                    : null,
              ),
              AdminTextTile(
                title: '更新保留版本数',
                value: '',
                subtitle: '服务端保留的历史版本数（在维护页查看待更新）',
                hint: '如 3',
                keyboardType: TextInputType.number,
                onSaved: (v) async {
                  final n = int.tryParse(v);
                  if (n == null) {
                    showSettingsToast(context, '请输入数字');
                    return;
                  }
                  try {
                    await ref
                        .read(settingsApiProvider)
                        .saveUpdateRetention(n);
                    if (!context.mounted) return;
                    showSettingsToast(context, '已保存');
                  } catch (e) {
                    if (!context.mounted) return;
                    showSettingsToast(context, '保存失败：$e');
                  }
                },
              ),
              const SettingsGroupLabel('GitHub Token'),
              SettingsRow(
                icon: Icons.key,
                title: data.github.configured
                    ? '已配置（${data.github.masked}）'
                    : '未配置',
                subtitle: '用于提高 GitHub 更新检查的请求额度',
                onTap: () async {
                  final token = await textInputDialog(context,
                      title: 'GitHub Token', hint: 'ghp_…');
                  if (token == null || token.isEmpty) return;
                  try {
                    await ref
                        .read(settingsApiProvider)
                        .saveGithubToken(token);
                    if (!context.mounted) return;
                    showSettingsToast(context, '已保存');
                    _reload();
                  } catch (e) {
                    if (!context.mounted) return;
                    showSettingsToast(context, '保存失败：$e');
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
