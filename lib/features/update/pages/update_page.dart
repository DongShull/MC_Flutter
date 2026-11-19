import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/theme.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../state/update_controller.dart';

/// 应用更新页（对应原 Kotlin feature/update 的 AppUpdateController + AppUpdateDialog）。
class UpdatePage extends ConsumerWidget {
  const UpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    ref.listen<UpdateUiState>(updateControllerProvider, (prev, next) {
      if (next is! UpdateChecking && next is! UpdateIdle) {
        _showDialog(context, ref);
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('关于与更新')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.system_update, color: McColors.accent),
            title: const Text('检查更新'),
            subtitle: const Text('当前版本 0.1.0'),
            trailing: state is UpdateChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: state is UpdateChecking
                ? null
                : () => ref.read(updateControllerProvider.notifier).checkManually(),
          ),
          const Divider(height: 32),
          const Text(
            '提示：新版本会先在官网发布，查不到时再用你的服务器兜底。',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(updateControllerProvider);
    showDialog<void>(
      context: context,
      barrierDismissible: state is! UpdateChecking,
      builder: (dialogContext) => _UpdateDialog(state: state),
    ).then((_) {
      // 关弹窗时清理一次性状态，避免路由切换后残留。
      if (context.mounted) {
        ref.read(updateControllerProvider.notifier).dismiss();
      }
    });
  }
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog({required this.state});

  final UpdateUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state) {
      UpdateIdle() => const SizedBox.shrink(),
      UpdateChecking() => AlertDialog(
          title: const Text('检查更新'),
          content: const Text('正在问服务器有没有新版本…'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      UpdateUpToDate(:final latest) => AlertDialog(
          title: const Text('已是最新版本'),
          content: Text(
            '当前 ${UpdatePolicy.currentDisplayVersion}，最新发布 ${latest.version}。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好', style: TextStyle(color: McColors.accent)),
            ),
          ],
        ),
      UpdateAvailable(:final release, :final source) => AlertDialog(
          title: Text('发现新版本 ${release.version}（来自${source.label}）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前 ${UpdatePolicy.currentDisplayVersion} · 安装包 ${(release.size / 1048576).toStringAsFixed(1)} MB',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(UpdatePolicy.summary(release.changelog)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(updateControllerProvider.notifier)
                    .skipCurrent(release.build);
              },
              child: const Text('跳过此版本'),
            ),
            TextButton(
              // 对齐 Kotlin 端 ACTION_VIEW 发布页；Flutter 侧 url_launcher
              // 尚未在 pubspec 中，先 TODO 占位。
              // TODO(share/update): 引入 url_launcher 后改为 launchUrl(release.releaseUrl)。
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('发布页：${release.releaseUrl}')),
                );
              },
              child: const Text('打开发布页', style: TextStyle(color: McColors.accent)),
            ),
          ],
        ),
      UpdateFailed(:final message) => AlertDialog(
          title: const Text('检查失败'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(updateControllerProvider.notifier).checkManually();
              },
              child: const Text('重试', style: TextStyle(color: McColors.accent)),
            ),
          ],
        ),
    };
  }
}
