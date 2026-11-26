import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';

/// 标记二级设置页当前是否内嵌在平板/TV 的右栏 master-detail 中（内嵌时隐藏重复返回按钮）。
class SettingsEmbeddedScope extends InheritedWidget {
  const SettingsEmbeddedScope({
    super.key,
    this.embedded = true,
    required super.child,
  });

  final bool embedded;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SettingsEmbeddedScope>()
          ?.embedded ??
      false;

  @override
  bool updateShouldNotify(SettingsEmbeddedScope oldWidget) =>
      oldWidget.embedded != embedded;
}

/// 二级设置页脚手架：独立路由下使用纯黑底 + 悬浮液态玻璃返回顶栏；
/// 平板/TV 右栏内嵌模式下展示干净的分区内联标题。
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final embedded = SettingsEmbeddedScope.of(context);
    if (embedded) {
      return ColoredBox(
        color: McTokens.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: McText.title)),
                  if (actions.isNotEmpty) ...actions,
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: title,
            titleVisible: true,
            trailing: actions,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// 分组标题（如「账号」「播放」「服务器」）。
class SettingsGroupLabel extends StatelessWidget {
  const SettingsGroupLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          label,
          style: McText.caption.copyWith(
            color: McTokens.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

/// 一行设置项（统一对齐 `McInsetRow` 银玻璃列表行）。
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return McInsetRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      destructive: destructive,
      showChevron: trailing == null && !destructive && onTap != null,
      onTap: onTap,
    );
  }
}

/// 通用信息说明卡（银玻璃内凹面 + 1px 细描边）。
class SettingsInfoCard extends StatelessWidget {
  const SettingsInfoCard({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(
          horizontal: McTokens.pagePadding,
          vertical: 6,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(McTokens.cardRadius),
          border: Border.all(color: McTokens.line, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: McTokens.textMuted),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(text, style: McText.sub.muted),
            ),
          ],
        ),
      );
}

/// 危险操作确认毛玻璃弹层（「注销设备」「清理存储」等）；true = 确认。
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认',
}) async {
  final ok = await showMcSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: McText.titleSm),
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
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: confirmLabel,
                  primary: false,
                  tone: McGlassTone.danger,
                  expanded: true,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// 单输入毛玻璃弹层（改名 / 改昵称 / 改密码）；返回输入内容，取消返回 null。
Future<String?> textInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  bool obscureText = false,
}) {
  return showMcSheet<String>(
    context: context,
    builder: (_) => _TextInputSheet(
      title: title,
      initial: initial,
      hint: hint,
      obscureText: obscureText,
    ),
  );
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    required this.initial,
    required this.hint,
    required this.obscureText,
  });

  final String title;
  final String initial;
  final String hint;
  final bool obscureText;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: McText.titleSm),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: widget.obscureText,
            style: McText.body,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: 18),
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
                  label: '保存',
                  primary: true,
                  expanded: true,
                  onTap: () =>
                      Navigator.of(context).pop(_controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 统一底部液态玻璃胶囊轻提示。
void showSettingsToast(BuildContext context, String message) {
  McToast.info(message);
}
