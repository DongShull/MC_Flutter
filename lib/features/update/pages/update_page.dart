import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
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
        _showSheet(context, ref);
      }
    });

    final contentWidth =
        mcWindowClassOf(McFormWatch.of(context)) == McWindowClass.compact
            ? 560.0
            : 720.0;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '关于与更新',
            titleVisible: true,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: ListView(
                  padding: const EdgeInsets.only(top: 24, bottom: 32),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const McBrandMark(size: 56),
                          const SizedBox(height: 12),
                          const Text('MovieClaw', style: McText.titleLg),
                          const SizedBox(height: 4),
                          Text(
                            '版本 ${UpdatePolicy.currentDisplayVersion}',
                            style: McText.caption.muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    McInsetGroup(
                      footer: '新版本会先在官网发布，查不到时再用你的服务器兜底。',
                      children: [
                        McFocusRing(
                          borderRadius: McTokens.cardRadius,
                          child: McInsetRow(
                            icon: McIcons.dataupgradeFill,
                            iconColor: McTokens.accentStrong,
                            title: '检查更新',
                            subtitle: '检查客户端是否有新版本可用',
                            trailing: state is UpdateChecking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                            onTap: state is UpdateChecking
                                ? null
                                : () => ref
                                    .read(updateControllerProvider.notifier)
                                    .checkManually(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    final state = ref.read(updateControllerProvider);
    showMcSheet<void>(
      context: context,
      builder: (_) => _UpdateSheet(state: state),
    ).then((_) {
      if (context.mounted) {
        ref.read(updateControllerProvider.notifier).dismiss();
      }
    });
  }
}

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet({required this.state});

  final UpdateUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: switch (state) {
        UpdateIdle() => const SizedBox.shrink(),
        UpdateChecking() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const McLoadingView(),
              const SizedBox(height: 8),
              Text('正在检查新版本…', style: McText.sub.muted),
            ],
          ),
        UpdateUpToDate(:final latest) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    McIcons.checkCircleFill,
                    color: McTokens.ok,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text('已是最新版本', style: McText.titleSm),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '当前 ${UpdatePolicy.currentDisplayVersion}，最新发布 ${latest.version}。',
                style: McText.sub.muted,
              ),
              const SizedBox(height: 20),
              McActionPill(
                label: '好',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        UpdateAvailable(:final release, :final source) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '发现新版本 ${release.version}（来自${source.label}）',
                style: McText.titleSm,
              ),
              const SizedBox(height: 6),
              Text(
                '当前 ${UpdatePolicy.currentDisplayVersion} · 安装包 ${(release.size / 1048576).toStringAsFixed(1)} MB',
                style: McText.caption.muted,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Text(
                    UpdatePolicy.summary(release.changelog),
                    style: McText.sub,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: McActionPill(
                      label: '跳过此版本',
                      primary: false,
                      expanded: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref
                            .read(updateControllerProvider.notifier)
                            .skipCurrent(release.build);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: McActionPill(
                      label: '打开发布页',
                      primary: true,
                      expanded: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        final url = release.releaseUrl;
                        if (url.isNotEmpty) {
                          launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        UpdateFailed(:final message) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('检查失败', style: McText.titleSm),
              const SizedBox(height: 8),
              Text(message, style: McText.sub.muted),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: McActionPill(
                      label: '取消',
                      primary: false,
                      expanded: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: McActionPill(
                      label: '重试',
                      primary: true,
                      expanded: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref
                            .read(updateControllerProvider.notifier)
                            .checkManually();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
      },
    );
  }
}
