import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';

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
    this.onBack,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onBack;

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
            onBack: onBack ??
                () => context.canPop() ? context.pop() : context.go('/home'),
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

enum SettingsTone { neutral, info, ok, warn, danger }

Color settingsToneColor(SettingsTone tone) => switch (tone) {
      SettingsTone.ok => McTokens.ok,
      SettingsTone.info => McTokens.info,
      SettingsTone.warn => McTokens.warning,
      SettingsTone.danger => McTokens.danger,
      SettingsTone.neutral => McTokens.textMuted,
    };

/// 语义告警/提示条（对齐 iOS `SettingsBNotice`）。
class SettingsNoticeBanner extends StatelessWidget {
  const SettingsNoticeBanner({
    super.key,
    this.text,
    this.title,
    this.message,
    this.icon,
    this.tone = SettingsTone.warn,
    this.action,
    this.trailing,
    this.margin = const EdgeInsets.symmetric(
      horizontal: McTokens.pagePadding,
      vertical: 6,
    ),
  }) : assert(
          text != null || title != null || message != null,
          'Provide text or title/message',
        );

  final String? text;
  final String? title;
  final String? message;
  final IconData? icon;
  final SettingsTone tone;
  final Widget? action;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = settingsToneColor(tone);
    final resolvedIcon = icon ??
        switch (tone) {
          SettingsTone.ok => McIcons.checkCircleFill,
          SettingsTone.danger => McIcons.alertCircle,
          SettingsTone.warn => McIcons.alert1,
          SettingsTone.info || SettingsTone.neutral => McIcons.information,
        };
    final endWidget = trailing ?? action;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: c.withValues(alpha: 0.32), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(resolvedIcon, size: 17, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(
                    title!,
                    style: McText.sub.copyWith(
                      color: McTokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (title != null &&
                    title!.isNotEmpty &&
                    ((message != null && message!.isNotEmpty) ||
                        (text != null && text!.isNotEmpty)))
                  const SizedBox(height: 4),
                if (message != null && message!.isNotEmpty)
                  Text(
                    message!,
                    style: McText.caption.copyWith(color: McTokens.textMuted),
                  )
                else if (text != null && text!.isNotEmpty)
                  Text(
                    text!,
                    style: McText.sub.copyWith(color: McTokens.text),
                  ),
              ],
            ),
          ),
          if (endWidget != null) ...[
            const SizedBox(width: 8),
            endWidget,
          ],
        ],
      ),
    );
  }
}

/// 语义胶囊徽标（对齐 iOS `SettingsBBadge`）。
class SettingsStatusBadge extends StatelessWidget {
  const SettingsStatusBadge({
    super.key,
    required this.label,
    this.tone = SettingsTone.neutral,
    this.showDot = false,
  });

  final String label;
  final SettingsTone tone;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final c = settingsToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(McTokens.pillRadius),
        border: Border.all(color: c.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(label, style: McText.micro.copyWith(color: c)),
        ],
      ),
    );
  }
}

/// 可复制的等宽值框（地址、令牌、密钥）。
class SettingsCopyBox extends StatelessWidget {
  const SettingsCopyBox({
    super.key,
    required this.value,
    this.label,
    this.copyLabel = '复制',
  });

  final String value;
  final String? label;
  final String copyLabel;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0x40000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              value,
              style: McText.caption.copyWith(
                fontFamily: 'monospace',
                color: McTokens.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          McChip(
            label: copyLabel,
            compact: true,
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              McToast.success('已复制');
            },
          ),
        ],
      ),
    );
    if (label == null || label!.isEmpty) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: McText.caption.muted),
        const SizedBox(height: 6),
        box,
      ],
    );
  }
}

/// 带语言标题与复制按钮的等宽代码块（CLI 命令、认证头）。
class SettingsCodeBlock extends StatelessWidget {
  const SettingsCodeBlock({
    super.key,
    required this.code,
    this.lang = 'BASH',
  });

  final String code;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x59000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: McTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            child: Row(
              children: [
                Text(
                  lang.toUpperCase(),
                  style: McText.micro.copyWith(
                    fontFamily: 'monospace',
                    color: McTokens.textFaint,
                    letterSpacing: 0.9,
                  ),
                ),
                const Spacer(),
                McChip(
                  label: '复制',
                  compact: true,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    McToast.success('已复制');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: McText.caption.copyWith(
                fontFamily: 'monospace',
                color: McTokens.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 安全打开外部链接。
Future<void> openExternalUrl(BuildContext context, String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    McToast.error('链接地址无效');
    return;
  }
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: rawUrl));
      McToast.info('无法打开浏览器，链接已复制到剪贴板');
    }
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: rawUrl));
    McToast.info('无法打开浏览器，链接已复制到剪贴板');
  }
}

/// 统一错误文本提取。
String settingsErrorText(Object e) =>
    e is ApiException ? e.friendlyMessage : e.toString();

/// 危险操作确认毛玻璃弹层（「注销设备」「清理存储」等）；true = 确认。
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = true,
}) async {
  final l10n = McL10n.of(context);
  final effectiveConfirm = confirmLabel ?? l10n.confirm;
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
                  label: l10n.cancel,
                  primary: false,
                  expanded: true,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: effectiveConfirm,
                  primary: !destructive,
                  tone: destructive ? McGlassTone.danger : McGlassTone.regular,
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
    final l10n = McL10n.of(context);
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
                  label: l10n.cancel,
                  primary: false,
                  expanded: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: l10n.save,
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
