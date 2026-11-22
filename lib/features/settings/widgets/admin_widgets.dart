// P4 管理页通用组件：开关行 / 文本行 / 选择行 / 通用新增编辑表单弹窗 /
// 选项弹窗 / 异步加载骨架。新增设置页一律复用这里，不各自手写弹窗与加载态。

import 'package:flutter/material.dart';

import '../../../core/designsystem/state_views.dart';
import '../state/sections.dart';
import 'settings_ui.dart';

export 'settings_ui.dart';

/// 开关行（立即生效，失败由调用方回滚并提示）。
class AdminSwitchTile extends StatelessWidget {
  const AdminSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: onChanged,
      );
}

/// 文本行：点开输入弹窗，确认后由 [onSaved] 立即保存。
class AdminTextTile extends StatelessWidget {
  const AdminTextTile({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.hint = '',
    this.obscure = false,
    this.keyboardType,
    required this.onSaved,
  });

  final String title;
  final String? value;
  final String? subtitle;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String> onSaved;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        subtitle: Text(
          subtitle ??
              (value == null || value!.isEmpty ? '未设置' : value!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final next = await textInputDialog(
            context,
            title: title,
            initial: value ?? '',
            hint: hint,
          );
          if (next != null) onSaved(next);
        },
      );
}

/// 选择行：点开选项弹窗，确认后由 [onSelected] 立即保存。
class AdminSelectTile<T> extends StatelessWidget {
  const AdminSelectTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onSelected,
    this.subtitle,
  });

  final String title;
  final T value;
  final List<({T value, String label})> options;
  final String? subtitle;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = options
        .where((o) => o.value == value)
        .map((o) => o.label)
        .firstOrNull;
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle ?? label ?? value.toString()),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final next = await showAdminOptionsDialog<T>(
          context,
          title: title,
          options: options,
          selected: value,
        );
        if (next != null) onSelected(next);
      },
    );
  }
}

/// 选项弹窗，返回选中值，取消返回 null。
Future<T?> showAdminOptionsDialog<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label})> options,
  T? selected,
}) =>
    showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final o in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(o.value),
              child: Row(
                children: [
                  Expanded(child: Text(o.label)),
                  if (o.value == selected)
                    const Icon(Icons.check, size: 18),
                ],
              ),
            ),
        ],
      ),
    );

/// 表单字段种类。
enum AdminFieldKind { text, password, number, boolean, select }

/// 通用新增/编辑表单的一个字段。
class AdminFieldSpec {
  const AdminFieldSpec({
    required this.key,
    required this.label,
    this.kind = AdminFieldKind.text,
    this.hint = '',
    this.required = false,
    this.options,
    this.initial,
  });

  final String key;
  final String label;
  final AdminFieldKind kind;
  final String hint;
  final bool required;
  final List<({String value, String label})>? options;
  final Object? initial;
}

/// 通用新增/编辑表单弹窗：按 [fields] 渲染，返回 key→value 的 map
///（text/password→String，number→int，boolean→bool，select→String），
/// 取消返回 null。必填空值时不关闭并提示。
Future<Map<String, dynamic>?> showAdminFormDialog(
  BuildContext context, {
  required String title,
  required List<AdminFieldSpec> fields,
  Map<String, dynamic>? initial,
}) async {
  final controllers = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  // select 字段用类型化 map 存当前值，避免 dynamic 扩散到 Dropdown。
  final selectValues = <String, String>{};
  for (final f in fields) {
    final init = initial?[f.key] ?? f.initial;
    if (f.kind == AdminFieldKind.boolean) {
      values[f.key] = init is bool ? init : false;
    } else if (f.kind == AdminFieldKind.select) {
      final v = init?.toString() ?? f.options?.first.value ?? '';
      selectValues[f.key] = v;
      values[f.key] = v;
    } else {
      controllers[f.key] = TextEditingController(
          text: init == null ? '' : init.toString());
    }
  }
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in fields)
                switch (f.kind) {
                  AdminFieldKind.boolean => SwitchListTile(
                      title: Text(f.label),
                      value: values[f.key] as bool? ?? false,
                      onChanged: (v) =>
                          setState(() => values[f.key] = v),
                    ),
                  AdminFieldKind.select => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectValues[f.key],
                        decoration: InputDecoration(labelText: f.label),
                        items: [
                          for (final o in f.options ??
                              const <({String value, String label})>[])
                            DropdownMenuItem(
                                value: o.value, child: Text(o.label)),
                        ],
                        onChanged: (v) => setState(() {
                          selectValues[f.key] = v ?? '';
                          values[f.key] = v;
                        }),
                      ),
                    ),
                  _ => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller: controllers[f.key],
                        obscureText: f.kind == AdminFieldKind.password,
                        keyboardType: f.kind == AdminFieldKind.number
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText:
                              f.required ? '${f.label} *' : f.label,
                          hintText: f.hint,
                        ),
                      ),
                    ),
                },
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              for (final f in fields) {
                if (f.kind == AdminFieldKind.boolean ||
                    f.kind == AdminFieldKind.select) {
                  continue;
                }
                final text = controllers[f.key]?.text.trim() ?? '';
                if (f.required && text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('${f.label}不能为空')));
                  return;
                }
                values[f.key] = f.kind == AdminFieldKind.number
                    ? int.tryParse(text)
                    : text;
              }
              Navigator.of(ctx).pop(values);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  for (final c in controllers.values) {
    c.dispose();
  }
  return result;
}

/// 异步加载骨架：加载中 / 失败（带重试）/ 成功三态。
class AdminAsyncBody<T> extends StatelessWidget {
  const AdminAsyncBody({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
  });

  final Future<T>? future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const McLoadingView();
          }
          if (snapshot.hasError) {
            return McErrorView(
              text: '加载失败：${snapshot.error}',
              onRetry: onRetry,
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return McErrorView(text: '加载失败', onRetry: onRetry);
          }
          return builder(context, data);
        },
      );
}

/// 逗号分隔文本 ↔ 列表（刮削语言优先级等字段用）。
List<String> parseCommaList(String text) => text
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

String formatCommaList(List<String> values) => values.join(', ');

/// 校验本注册表覆盖了 parity 清单的 25 个分区 id。
bool sectionsCoverParity25() {
  const parity25 = {
    'overview',
    'profile',
    'devices',
    'notifications',
    'appearance',
    'members',
    'subscription',
    'sites',
    'downloaders',
    'import-watch',
    'scrape',
    'playback',
    'drives',
    'app-push',
    'im-push',
    'webhook',
    'llm',
    'mcp',
    'ai',
    'cloud',
    'app',
    'plugins',
    'network',
    'logs',
    'external-access',
  };
  final ids = settingsSections.map((s) => s.id).toSet();
  return parity25.difference(ids).isEmpty;
}
