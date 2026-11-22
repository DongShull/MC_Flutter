// 站点页（对应 web settings sites 分区 / 安卓 SitesScreen）：
// 已配置站点列表、新增/编辑（认证方式与凭据）、启用、验证、保护、
// 加速（boost）开关；底部附浏览器扩展同步令牌管理
//（GET/POST/DELETE /extension/token）。
// 注意：浏览器扩展本身需在浏览器里安装，app 内只管同步令牌。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../state/raw_models.dart';
import '../widgets/admin_widgets.dart';

class _SitesData {
  const _SitesData({required this.catalog, required this.sites});

  final List<core.SiteCatalogItem> catalog;
  final List<core.ConfiguredSite> sites;
}

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});

  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage> {
  late Future<_SitesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SitesData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results =
        await Future.wait([api.sitesCatalog(), api.sites()]);
    return _SitesData(
      catalog: results[0] as List<core.SiteCatalogItem>,
      sites: results[1] as List<core.ConfiguredSite>,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _run(Future<void> Function() fn, String okMsg) async {
    try {
      await fn();
      if (!mounted) return;
      showSettingsToast(context, okMsg);
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '操作失败：$e');
    }
  }

  String _displayName(_SitesData data, core.ConfiguredSite s) {
    final item = data.catalog.where((c) => c.siteId == s.siteId).firstOrNull;
    return item == null || item.displayName.isEmpty
        ? s.siteId
        : item.displayName;
  }

  Future<void> _add(_SitesData data) async {
    if (data.catalog.isEmpty) {
      showSettingsToast(context, '服务端没有可用站点目录');
      return;
    }
    final values = await showAdminFormDialog(
      context,
      title: '添加站点',
      fields: [
        AdminFieldSpec(
          key: 'siteId',
          label: '站点',
          kind: AdminFieldKind.select,
          options: [
            for (final c in data.catalog)
              (
                value: c.siteId,
                label: c.displayName.isEmpty ? c.siteId : c.displayName,
              ),
          ],
        ),
        const AdminFieldSpec(
          key: 'authType',
          label: '认证方式',
          kind: AdminFieldKind.select,
          options: [
            (value: 'cookie', label: 'Cookie'),
            (value: 'apiKey', label: 'API Key'),
            (value: 'username', label: '用户名密码'),
            (value: 'none', label: '无需认证'),
          ],
        ),
        const AdminFieldSpec(
            key: 'cookie', label: 'Cookie', hint: '认证方式为 Cookie 时填写'),
        const AdminFieldSpec(
            key: 'apiKey', label: 'API Key', hint: '认证方式为 API Key 时填写'),
        const AdminFieldSpec(key: 'username', label: '用户名'),
        const AdminFieldSpec(
            key: 'password', label: '密码', kind: AdminFieldKind.password),
        const AdminFieldSpec(
            key: 'enabled', label: '启用', kind: AdminFieldKind.boolean,
            initial: true),
      ],
    );
    if (values == null) return;
    final siteId = values['siteId'] as String? ?? '';
    await _run(
      () => ref.read(settingsApiProvider).createSite(
            core.SiteConfigCreate(
              siteId: siteId,
              authType: values['authType'] as String? ?? '',
              cookie: _nonEmpty(values['cookie']),
              apiKey: _nonEmpty(values['apiKey']),
              username: _nonEmpty(values['username']),
              password: _nonEmpty(values['password']),
              enabled: values['enabled'] as bool? ?? true,
            ),
          ),
      '已添加站点',
    );
  }

  String? _nonEmpty(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  Future<void> _edit(core.ConfiguredSite s) async {
    final values = await showAdminFormDialog(
      context,
      title: '编辑站点凭据',
      initial: {'authType': s.authType, 'enabled': s.enabled},
      fields: const [
        AdminFieldSpec(
          key: 'authType',
          label: '认证方式',
          kind: AdminFieldKind.select,
          options: [
            (value: 'cookie', label: 'Cookie'),
            (value: 'apiKey', label: 'API Key'),
            (value: 'username', label: '用户名密码'),
            (value: 'none', label: '无需认证'),
          ],
        ),
        AdminFieldSpec(key: 'cookie', label: 'Cookie（留空不改）'),
        AdminFieldSpec(key: 'apiKey', label: 'API Key（留空不改）'),
        AdminFieldSpec(key: 'username', label: '用户名'),
        AdminFieldSpec(
            key: 'password', label: '密码（留空不改）', kind: AdminFieldKind.password),
        AdminFieldSpec(
            key: 'enabled', label: '启用', kind: AdminFieldKind.boolean),
      ],
    );
    if (values == null) return;
    await _run(
      () => ref.read(settingsApiProvider).updateSite(
            s.siteId,
            core.SiteConfigUpdate(
              authType: values['authType'] as String? ?? s.authType,
              cookie: _nonEmpty(values['cookie']),
              apiKey: _nonEmpty(values['apiKey']),
              username: _nonEmpty(values['username']),
              password: _nonEmpty(values['password']),
              enabled: values['enabled'] as bool? ?? s.enabled,
            ),
          ),
      '已保存',
    );
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '站点',
        body: AdminAsyncBody<_SitesData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) => ListView(
            children: [
              if (data.sites.isEmpty)
                const SettingsInfoCard(text: '尚未配置任何站点，先添加一个站点才能订阅资源。'),
              for (final s in data.sites)
                SettingsRow(
                  icon: Icons.public,
                  title: _displayName(data, s),
                  subtitle: [
                    s.status,
                    if (!s.enabled) '已停用',
                    if (s.isProtected) '受保护',
                    if (s.boostEnabled) '加速中',
                    if ((s.lastError ?? '').isNotEmpty) s.lastError!,
                  ].join(' · '),
                  trailing: Switch(
                    value: s.enabled,
                    onChanged: (v) => _run(
                      () => ref
                          .read(settingsApiProvider)
                          .setSiteEnabled(s.siteId, v),
                      v ? '已启用' : '已停用',
                    ),
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('编辑凭据'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _edit(s);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.verified),
                            title: const Text('验证连接'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _run(
                                () => ref
                                    .read(settingsApiProvider)
                                    .verifySite(s.siteId),
                                '验证请求已发送',
                              );
                            },
                          ),
                          SwitchListTile(
                            title: const Text('受保护（防误删）'),
                            value: s.isProtected,
                            onChanged: (v) {
                              Navigator.of(ctx).pop();
                              _run(
                                () => ref
                                    .read(settingsApiProvider)
                                    .setSiteProtection(s.siteId, v),
                                v ? '已设为受保护' : '已取消保护',
                              );
                            },
                          ),
                          SwitchListTile(
                            title: const Text('加速'),
                            value: s.boostEnabled,
                            onChanged: (v) {
                              Navigator.of(ctx).pop();
                              _run(
                                () => ref
                                    .read(settingsApiProvider)
                                    .setSiteBoost(s.siteId, enabled: v),
                                v ? '加速已开启' : '加速已关闭',
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('删除站点',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final ok = await confirmDialog(
                                context,
                                title: '删除站点',
                                message: '确定删除「${_displayName(data, s)}」吗？',
                                confirmLabel: '删除',
                              );
                              if (ok) {
                                await _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .deleteSite(s.siteId),
                                  '已删除',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('添加站点'),
                  onPressed: () => _add(data),
                ),
              ),
              const SettingsGroupLabel('浏览器扩展'),
              const SettingsInfoCard(
                text: '浏览器扩展用于把浏览器里的站点 Cookie 同步到服务端；扩展本身需在浏览器里安装，这里只管理同步令牌。',
              ),
              const _ExtensionTokenSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}

/// 浏览器扩展同步令牌区（独立 widget：future 在构建时才启动，
/// 避免外层加载失败时无人订阅导致未处理异常）。
class _ExtensionTokenSection extends ConsumerStatefulWidget {
  const _ExtensionTokenSection();

  @override
  ConsumerState<_ExtensionTokenSection> createState() =>
      _ExtensionTokenSectionState();
}

class _ExtensionTokenSectionState
    extends ConsumerState<_ExtensionTokenSection> {
  late Future<SyncTokenView> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _loadToken();
  }

  Future<SyncTokenView> _loadToken() =>
      ref.read(settingsApiProvider).syncToken();

  void _reloadToken() => setState(() => _tokenFuture = _loadToken());

  @override
  Widget build(BuildContext context) => AdminAsyncBody<SyncTokenView>(
        future: _tokenFuture,
        onRetry: _reloadToken,
        builder: (context, token) => Column(
          children: [
            SettingsRow(
              icon: Icons.key,
              title: token.enabled ? '同步令牌已启用' : '同步令牌未启用',
              subtitle: (token.createdAt ?? '').isEmpty
                  ? '生成令牌后填入浏览器扩展即可同步'
                  : '创建于 ${token.createdAt}',
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          final next = await ref
                              .read(settingsApiProvider)
                              .generateSyncToken();
                          if (!context.mounted) return;
                          _reloadToken();
                          if (next.token != null && next.token!.isNotEmpty) {
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('同步令牌'),
                                content: SelectableText(next.token!),
                                actions: [
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(),
                                    child: const Text('知道了'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          showSettingsToast(context, '生成失败：$e');
                        }
                      },
                      child: const Text('生成令牌'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: token.enabled
                          ? () async {
                              final ok = await confirmDialog(
                                context,
                                title: '吊销令牌',
                                message: '吊销后浏览器扩展将无法再同步 Cookie。',
                                confirmLabel: '吊销',
                              );
                              if (!ok) return;
                              try {
                                await ref
                                    .read(settingsApiProvider)
                                    .revokeSyncToken();
                                _reloadToken();
                              } catch (e) {
                                if (!context.mounted) return;
                                showSettingsToast(context, '吊销失败：$e');
                              }
                            }
                          : null,
                      child: const Text('吊销令牌'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
