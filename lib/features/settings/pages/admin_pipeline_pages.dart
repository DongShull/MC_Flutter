import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../widgets/settings_ui.dart';

/// 1) 自动化流水线总览巡检页（GET /api/v1/subscriptions/automation-readiness）。
class AutomationOverviewPage extends ConsumerStatefulWidget {
  const AutomationOverviewPage({super.key});

  @override
  ConsumerState<AutomationOverviewPage> createState() =>
      _AutomationOverviewPageState();
}

class _AutomationOverviewPageState
    extends ConsumerState<AutomationOverviewPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref.read(mcClientProvider).unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/subscriptions/automation-readiness',
          );
      if (mounted) {
        setState(() {
          _data = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '读取巡检状态失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final checks = (_data?['checks'] ?? _data?['steps'] ?? _data?['items'])
        as List<dynamic>?;
    final ready = _data?['ready'] == true;
    return SettingsScaffold(
      title: '自动化流水线巡检',
      actions: [
        McChip(label: '刷新', compact: true, onTap: _load),
      ],
      body: _loading
          ? const McLoadingView()
          : _error != null
              ? McErrorView(text: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 36),
                  children: [
                    SettingsInfoCard(
                      icon: ready
                          ? McIcons.checkCircleFill
                          : McIcons.alertCircle,
                      text: ready
                          ? '全链路就绪：PT 索引站点 → 下载器 → 自动硬链入库 → 刮削流水线运转正常。'
                          : '部分环节待完善，补齐下方标黄项即可实现全无人值守追更入库。',
                    ),
                    const SizedBox(height: 12),
                    if (checks != null && checks.isNotEmpty)
                      McInsetGroup(
                        header: '核心环节自检',
                        children: [
                          for (final raw in checks.whereType<Map>())
                            Builder(
                              builder: (context) {
                                final ok = raw['ok'] == true ||
                                    raw['ready'] == true ||
                                    raw['status'] == 'ok';
                                return McInsetRow(
                                  icon: ok
                                      ? McIcons.checkCircleFill
                                      : McIcons.alert1,
                                  iconColor:
                                      ok ? McTokens.ok : McTokens.warning,
                                  title: (raw['title'] ?? raw['label'] ?? raw['key'] ?? '')
                                      .toString(),
                                  subtitle: (raw['message'] ?? raw['detail'] ?? '')
                                      .toString(),
                                );
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    McInsetGroup(
                      header: '快捷配置入口',
                      children: [
                        McInsetRow(
                          icon: McIcons.mediaLibraryFill,
                          title: '媒体库与服务端目录',
                          onTap: () => context.push('/library/manage'),
                        ),
                        McInsetRow(
                          icon: McIcons.globe,
                          title: 'PT 索引站点配置',
                          onTap: () => context.push('/settings/sites'),
                        ),
                        McInsetRow(
                          icon: McIcons.downloadCloudOut,
                          title: '下载器与监控目录',
                          onTap: () => context.push('/settings/downloaders'),
                        ),
                        McInsetRow(
                          icon: McIcons.listSettings2,
                          title: '选种规则组管理',
                          onTap: () => context.push('/settings/rules'),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}

/// 2) 家庭成员与权限管理页（GET / POST / PUT / DELETE /api/v1/members）。
class MembersAdminPage extends ConsumerStatefulWidget {
  const MembersAdminPage({super.key});

  @override
  ConsumerState<MembersAdminPage> createState() => _MembersAdminPageState();
}

class _MembersAdminPageState extends ConsumerState<MembersAdminPage> {
  List<Map<String, dynamic>> _members = const [];
  bool _loading = true;
  String? _error;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/members',
      );
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['items'] ?? raw['members'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      if (mounted) {
        setState(() {
          _members = list.whereType<Map>().map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '读取成员列表失败：$e';
        });
      }
    }
  }

  Future<void> _openCreateMember() async {
    final userCtrl = TextEditingController();
    final nickCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    var role = 'member';
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('新增家庭成员', style: McText.titleSm),
              const SizedBox(height: 12),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: '登录用户名'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nickCtrl,
                decoration: const InputDecoration(labelText: '显示昵称（可选）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '初始登录密码'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  McChip(
                    label: '普通成员',
                    compact: true,
                    selected: role == 'member',
                    onTap: () => setSheet(() => role = 'member'),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: '管理员',
                    compact: true,
                    selected: role == 'admin',
                    onTap: () => setSheet(() => role = 'admin'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              McActionPill(
                label: '创建成员账号',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final username = userCtrl.text.trim();
    final password = pwdCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      McToast.error('请填写用户名与初始密码');
      return;
    }
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/members',
        body: {
          'username': username,
          'nickname': nickCtrl.text.trim(),
          'password': password,
          'role': role,
        },
      );
      if (mounted) McToast.success('已创建成员「$username」');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('创建失败：$e');
    }
  }

  Future<void> _manageMember(Map<String, dynamic> m) async {
    final id = (m['id'] as num? ?? 0).toInt();
    if (id <= 0) return;
    final name = (m['nickname'] ?? m['username'] ?? '').toString();
    final enabled = m['enabled'] != false;
    final act = await showMcSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: name,
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              icon: McIcons.key,
              title: '重置登录密码…',
              onTap: () => Navigator.of(ctx).pop('pwd'),
            ),
            McInsetRow(
              icon: enabled ? McIcons.userForbid : McIcons.userFollow,
              title: enabled ? '停用该账号' : '重新启用账号',
              onTap: () => Navigator.of(ctx).pop('toggle'),
            ),
            McInsetRow(
              icon: McIcons.trash2,
              title: '删除成员账号',
              destructive: true,
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (act == null || !mounted) return;
    try {
      if (act == 'pwd') {
        final pw = await textInputDialog(
          context,
          title: '为「$name」设置新密码',
          hint: '输入新密码',
          obscureText: true,
        );
        if (pw == null || pw.isEmpty) return;
        await _mc.unwrap<dynamic>(
          Channel.general,
          'POST',
          '/api/v1/members/$id/reset-password',
          body: {'password': pw, 'new_password': pw},
        );
        if (mounted) McToast.success('密码已重置');
      } else if (act == 'toggle') {
        await _mc.unwrap<dynamic>(
          Channel.general,
          'PUT',
          '/api/v1/members/$id/status',
          body: {'enabled': !enabled},
        );
        await _load();
      } else if (act == 'delete') {
        final ok = await confirmDialog(
          context,
          title: '删除成员「$name」？',
          message: '该成员的独立观看进度与收藏将被一并移除。',
          confirmLabel: '删除',
        );
        if (!ok) return;
        await _mc.unwrap<dynamic>(
          Channel.general,
          'DELETE',
          '/api/v1/members/$id',
        );
        if (mounted) McToast.success('成员已删除');
        await _load();
      }
    } catch (e) {
      if (mounted) McToast.error('操作失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '家庭成员管理',
      actions: [
        McChip(
          icon: McIcons.userAdd,
          label: '新增成员',
          selected: true,
          compact: true,
          onTap: _openCreateMember,
        ),
      ],
      body: _loading
          ? const McLoadingView()
          : _error != null
              ? McErrorView(text: _error!, onRetry: _load)
              : _members.isEmpty
                  ? McEmptyView(
                      icon: McIcons.team,
                      title: '暂无额外成员',
                      text: '为家人创建独立账号，各自维护独立的继续观看与年龄分级权限。',
                      actionLabel: '新增成员',
                      onRetry: _openCreateMember,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 36),
                      children: [
                        McInsetGroup(
                          children: [
                            for (final m in _members)
                              McInsetRow(
                                icon: m['role'] == 'admin'
                                    ? McIcons.adminFill
                                    : McIcons.user,
                                iconColor: m['role'] == 'admin'
                                    ? McTokens.accentStrong
                                    : McTokens.textMuted,
                                title: (m['nickname']?.toString().isNotEmpty ==
                                        true)
                                    ? '${m['nickname']} (@${m['username']})'
                                    : (m['username'] ?? '').toString(),
                                subtitle: [
                                  m['role'] == 'admin' ? '管理员' : '家庭成员',
                                  if (m['enabled'] == false) '已停用',
                                ].join(' · '),
                                onTap: () => _manageMember(m),
                              ),
                          ],
                        ),
                      ],
                    ),
    );
  }
}

/// 3) 订阅策略与选种规则组 CRUD 页（GET / POST / PUT / DELETE /api/v1/rule-sets）。
class RuleSetsAdminPage extends ConsumerStatefulWidget {
  const RuleSetsAdminPage({super.key});

  @override
  ConsumerState<RuleSetsAdminPage> createState() => _RuleSetsAdminPageState();
}

class _RuleSetsAdminPageState extends ConsumerState<RuleSetsAdminPage> {
  List<Map<String, dynamic>> _rules = const [];
  bool _loading = true;
  String? _error;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/rule-sets',
      );
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['items'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      if (mounted) {
        setState(() {
          _rules = list.whereType<Map>().map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '读取规则组失败：$e';
        });
      }
    }
  }

  Future<void> _editRule({Map<String, dynamic>? existing}) async {
    final spec = existing?['spec'] is Map
        ? Map<String, dynamic>.from(existing!['spec'] as Map)
        : <String, dynamic>{};
    final nameCtrl =
        TextEditingController(text: (existing?['name'] ?? '').toString());
    final incCtrl = TextEditingController(
      text: ((spec['include_keywords'] as List?) ?? const []).join(', '),
    );
    final excCtrl = TextEditingController(
      text: ((spec['exclude_keywords'] as List?) ?? const []).join(', '),
    );
    final resSet = <String>{
      for (final r in ((spec['resolutions'] as List?) ?? const ['2160p', '1080p']))
        r.toString(),
    };
    var freeOnly = spec['free_only'] == true;

    final ok = await showMcSheet<bool>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? '新建选种规则组' : '编辑规则组',
                style: McText.titleSm,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '规则组名称',
                  hintText: '例如：4K 杜比视界优先 / 1080P 省空间',
                ),
              ),
              const SizedBox(height: 14),
              Text('允许分辨率', style: McText.caption.muted),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in const ['2160p', '1080p', '720p'])
                    McChip(
                      label: r,
                      compact: true,
                      selected: resSet.contains(r),
                      onTap: () => setSheet(() {
                        resSet.contains(r) ? resSet.remove(r) : resSet.add(r);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: incCtrl,
                decoration: const InputDecoration(
                  labelText: '必含关键词（逗号分隔，可选）',
                  hintText: 'DoVi, HDR, BluRay',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: excCtrl,
                decoration: const InputDecoration(
                  labelText: '排除关键词（逗号分隔，可选）',
                  hintText: 'CAM, TS, HC',
                ),
              ),
              const SizedBox(height: 12),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  McInsetRow(
                    title: '仅抓免费促销种 (FREE / 2XFREE)',
                    trailing: Switch(
                      value: freeOnly,
                      onChanged: (v) => setSheet(() => freeOnly = v),
                    ),
                    onTap: () => setSheet(() => freeOnly = !freeOnly),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              McActionPill(
                label: '保存规则组',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    List<String> splitCsv(String s) => s
        .split(RegExp(r'[,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final payload = {
      'name': name,
      'spec': {
        ...spec,
        'resolutions': resSet.toList(),
        'include_keywords': splitCsv(incCtrl.text),
        'exclude_keywords': splitCsv(excCtrl.text),
        'free_only': freeOnly,
      },
    };
    try {
      if (existing == null) {
        await _mc.unwrap<dynamic>(
          Channel.general,
          'POST',
          '/api/v1/rule-sets',
          body: payload,
        );
      } else {
        await _mc.unwrap<dynamic>(
          Channel.general,
          'PUT',
          '/api/v1/rule-sets/${existing['id']}',
          body: payload,
        );
      }
      if (mounted) McToast.success('规则组已保存');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '订阅与规则组',
      actions: [
        McChip(
          icon: McIcons.addS,
          label: '新建规则',
          selected: true,
          compact: true,
          onTap: () => _editRule(),
        ),
      ],
      body: _loading
          ? const McLoadingView()
          : _error != null
              ? McErrorView(text: _error!, onRetry: _load)
              : _rules.isEmpty
                  ? McEmptyView(
                      icon: McIcons.listSettings2,
                      title: '暂无自定义规则组',
                      text: '默认使用智能选源策略；可新建规则精确限定 4K/HDR/字幕组与促销要求。',
                      actionLabel: '新建规则组',
                      onRetry: () => _editRule(),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 36),
                      children: [
                        McInsetGroup(
                          children: [
                            for (final r in _rules)
                              McInsetRow(
                                icon: McIcons.listSettings2,
                                title: (r['name'] ?? '').toString(),
                                subtitle:
                                    r['is_default'] == true ? '默认规则组' : '自定义规则',
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (r['is_default'] != true)
                                      McChip(
                                        label: '设为默认',
                                        compact: true,
                                        onTap: () async {
                                          await _mc.unwrap<dynamic>(
                                            Channel.general,
                                            'POST',
                                            '/api/v1/rule-sets/${r['id']}/default',
                                          );
                                          await _load();
                                        },
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        McIcons.trash2,
                                        size: 17,
                                        color: McTokens.danger,
                                      ),
                                      onPressed: () async {
                                        await _mc.unwrap<dynamic>(
                                          Channel.general,
                                          'DELETE',
                                          '/api/v1/rule-sets/${r['id']}',
                                        );
                                        await _load();
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => _editRule(existing: r),
                              ),
                          ],
                        ),
                      ],
                    ),
    );
  }
}

/// 4) PT 索引站点与浏览器插件同步页（GET / POST / PUT / DELETE /api/v1/sites）。
class SitesAdminPage extends ConsumerStatefulWidget {
  const SitesAdminPage({super.key});

  @override
  ConsumerState<SitesAdminPage> createState() => _SitesAdminPageState();
}

class _SitesAdminPageState extends ConsumerState<SitesAdminPage> {
  List<Map<String, dynamic>> _sites = const [];
  List<Map<String, dynamic>> _catalog = const [];
  String? _extToken;
  bool _loading = true;
  String? _error;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rawSites = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/sites',
      );
      final rawCat = await _mc
          .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/sites/catalog')
          .catchError((_) => const <dynamic>[]);
      final rawTok = await _mc
          .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/extension/token')
          .catchError((_) => null);
      List<Map<String, dynamic>> asMaps(dynamic v) {
        final l = v is List
            ? v
            : (v is Map
                ? (v['items'] ?? v['sites'] ?? const []) as List<dynamic>
                : const <dynamic>[]);
        return l.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }

      if (mounted) {
        setState(() {
          _sites = asMaps(rawSites);
          _catalog = asMaps(rawCat);
          _extToken = rawTok is Map ? rawTok['token']?.toString() : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载索引站点失败：$e';
        });
      }
    }
  }

  Future<void> _openAddSite() async {
    var siteKey = _catalog.isNotEmpty
        ? (_catalog.first['site_id'] ?? _catalog.first['id'] ?? '').toString()
        : '';
    final idCtrl = TextEditingController(text: siteKey);
    final urlCtrl = TextEditingController();
    final cookieCtrl = TextEditingController();
    final apiKeyCtrl = TextEditingController();

    final ok = await showMcSheet<bool>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('添加 PT 索引站点', style: McText.titleSm),
              if (_catalog.isNotEmpty) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 110),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in _catalog.take(24))
                          Builder(
                            builder: (context) {
                              final cid =
                                  (c['site_id'] ?? c['id'] ?? '').toString();
                              final cname =
                                  (c['name'] ?? cid).toString();
                              return McChip(
                                label: cname,
                                compact: true,
                                selected: siteKey == cid,
                                onTap: () => setSheet(() {
                                  siteKey = cid;
                                  idCtrl.text = cid;
                                  if (c['base_url'] != null) {
                                    urlCtrl.text = c['base_url'].toString();
                                  }
                                }),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: '站点标识 (site_id)',
                  hintText: '例如：mteam / hdsky / pter',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: '站点地址（可选覆盖）',
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Key / Passkey（若站点支持）',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cookieCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '登录 Cookie（与 API Key 二选一）',
                ),
              ),
              const SizedBox(height: 18),
              McActionPill(
                label: '保存并接入站点',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final sid = idCtrl.text.trim();
    if (sid.isEmpty) return;
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/sites',
        body: {
          'site_id': sid,
          if (urlCtrl.text.trim().isNotEmpty) 'base_url': urlCtrl.text.trim(),
          if (apiKeyCtrl.text.trim().isNotEmpty)
            'api_key': apiKeyCtrl.text.trim(),
          if (cookieCtrl.text.trim().isNotEmpty)
            'cookie': cookieCtrl.text.trim(),
          'enabled': true,
        },
      );
      if (mounted) McToast.success('已添加站点 $sid');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('添加失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'PT 索引站点',
      actions: [
        McChip(
          icon: McIcons.addS,
          label: '添加站点',
          selected: true,
          compact: true,
          onTap: _openAddSite,
        ),
      ],
      body: _loading
          ? const McLoadingView()
          : _error != null
              ? McErrorView(text: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 36),
                  children: [
                    McInsetGroup(
                      header: 'CookieCloud / 浏览器插件同步令牌',
                      children: [
                        McInsetRow(
                          icon: McIcons.key,
                          title: _extToken != null && _extToken!.isNotEmpty
                              ? '同步令牌已启用'
                              : '生成浏览器插件同步令牌',
                          subtitle: _extToken ?? '一键从桌面浏览器自动同步各 PT 站点 Cookie',
                          trailing: McChip(
                            label: _extToken != null ? '复制' : '生成',
                            compact: true,
                            onTap: () async {
                              if (_extToken != null && _extToken!.isNotEmpty) {
                                Clipboard.setData(
                                  ClipboardData(text: _extToken!),
                                );
                                McToast.success('已复制插件令牌');
                              } else {
                                final r = await _mc.unwrap<Map<String, dynamic>>(
                                  Channel.general,
                                  'POST',
                                  '/api/v1/extension/token',
                                );
                                final t = r['token']?.toString();
                                if (t != null) {
                                  Clipboard.setData(ClipboardData(text: t));
                                  McToast.success('已生成并复制同步令牌');
                                }
                                await _load();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_sites.isEmpty)
                      McEmptyView(
                        icon: McIcons.globe,
                        title: '尚未配置索引站点',
                        text: '添加 PT 站点后即可使用跨站搜种与全自动追更选种。',
                        actionLabel: '添加站点',
                        onRetry: _openAddSite,
                      )
                    else
                      McInsetGroup(
                        header: '已接入站点 (${_sites.length})',
                        children: [
                          for (final s in _sites)
                            Builder(
                              builder: (context) {
                                final sid =
                                    (s['site_id'] ?? s['id'] ?? '').toString();
                                final enabled = s['enabled'] != false;
                                return McInsetRow(
                                  icon: McIcons.globe,
                                  iconColor: enabled
                                      ? McTokens.ok
                                      : McTokens.textFaint,
                                  title: (s['name'] ?? sid).toString(),
                                  subtitle: enabled ? '已启用' : '已停用',
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      McChip(
                                        label: '测速验证',
                                        compact: true,
                                        onTap: () async {
                                          try {
                                            await _mc.unwrap<dynamic>(
                                              Channel.general,
                                              'POST',
                                              '/api/v1/sites/$sid/verify',
                                            );
                                            if (context.mounted) {
                                              McToast.success('$sid 连通正常');
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              McToast.error('验证失败：$e');
                                            }
                                          }
                                        },
                                      ),
                                      Switch(
                                        value: enabled,
                                        onChanged: (v) async {
                                          await _mc.unwrap<dynamic>(
                                            Channel.general,
                                            'PATCH',
                                            '/api/v1/sites/$sid/status',
                                            body: {'enabled': v},
                                          );
                                          await _load();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          McIcons.trash2,
                                          size: 17,
                                          color: McTokens.danger,
                                        ),
                                        onPressed: () async {
                                          await _mc.unwrap<dynamic>(
                                            Channel.general,
                                            'DELETE',
                                            '/api/v1/sites/$sid',
                                          );
                                          await _load();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                  ],
                ),
    );
  }
}

/// 5) 下载器与监控目录入库规则页（/api/v1/downloaders + /api/v1/import-watch）。
class DownloadersAdminPage extends ConsumerStatefulWidget {
  const DownloadersAdminPage({super.key});

  @override
  ConsumerState<DownloadersAdminPage> createState() =>
      _DownloadersAdminPageState();
}

class _DownloadersAdminPageState extends ConsumerState<DownloadersAdminPage> {
  List<Map<String, dynamic>> _downloaders = const [];
  List<Map<String, dynamic>> _watches = const [];
  bool _loading = true;
  String? _error;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dRaw = await _mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/downloaders',
      );
      final wRaw = await _mc
          .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/import-watch')
          .catchError((_) => const <dynamic>[]);
      List<Map<String, dynamic>> asMaps(dynamic v) {
        final l = v is List
            ? v
            : (v is Map
                ? (v['items'] ?? const []) as List<dynamic>
                : const <dynamic>[]);
        return l.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }

      if (mounted) {
        setState(() {
          _downloaders = asMaps(dRaw);
          _watches = asMaps(wRaw);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '读取下载器失败：$e';
        });
      }
    }
  }

  Future<void> _openAddDownloader() async {
    var type = 'qbittorrent';
    final nameCtrl = TextEditingController(text: 'qBittorrent');
    final urlCtrl = TextEditingController(text: 'http://127.0.0.1:8080');
    final userCtrl = TextEditingController(text: 'admin');
    final pwdCtrl = TextEditingController();

    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('添加 BT/PT 下载器', style: McText.titleSm),
              const SizedBox(height: 12),
              Row(
                children: [
                  McChip(
                    label: 'qBittorrent',
                    compact: true,
                    selected: type == 'qbittorrent',
                    onTap: () => setSheet(() {
                      type = 'qbittorrent';
                      nameCtrl.text = 'qBittorrent';
                    }),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: 'Transmission',
                    compact: true,
                    selected: type == 'transmission',
                    onTap: () => setSheet(() {
                      type = 'transmission';
                      nameCtrl.text = 'Transmission';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '显示名称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'WebUI 地址'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: '用户名'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
              ),
              const SizedBox(height: 18),
              McActionPill(
                label: '保存下载器',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/downloaders',
        body: {
          'name': nameCtrl.text.trim(),
          'type': type,
          'url': urlCtrl.text.trim(),
          'base_url': urlCtrl.text.trim(),
          'username': userCtrl.text.trim(),
          'password': pwdCtrl.text,
        },
      );
      if (mounted) McToast.success('已添加下载器');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('添加失败：$e');
    }
  }

  Future<void> _openAddWatchDir() async {
    final path = await textInputDialog(
      context,
      title: '添加自动入库监控目录',
      hint: '/downloads/complete',
    );
    if (path == null || path.isEmpty || !mounted) return;
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/import-watch',
        body: {'path': path, 'source_path': path, 'enabled': true},
      );
      if (mounted) McToast.success('已添加监控目录');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('添加失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '下载器与入库目录',
      actions: [
        McChip(
          icon: McIcons.addS,
          label: '添加下载器',
          selected: true,
          compact: true,
          onTap: _openAddDownloader,
        ),
      ],
      body: _loading
          ? const McLoadingView()
          : _error != null
              ? McErrorView(text: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 36),
                  children: [
                    if (_downloaders.isEmpty)
                      McEmptyView(
                        icon: McIcons.downloadCloudOut,
                        title: '尚未配置下载器',
                        text: '接入 qBittorrent 或 Transmission 后即可一键推送种子并监控完成入库。',
                        actionLabel: '添加下载器',
                        onRetry: _openAddDownloader,
                      )
                    else
                      McInsetGroup(
                        header: '下载客户端',
                        children: [
                          for (final d in _downloaders)
                            McInsetRow(
                              icon: McIcons.downloadCloudOut,
                              title: (d['name'] ?? d['type'] ?? '').toString(),
                              subtitle:
                                  '${d['url'] ?? d['base_url'] ?? ''}${d['is_default'] == true ? ' · 默认' : ''}',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  McChip(
                                    label: '测试',
                                    compact: true,
                                    onTap: () async {
                                      try {
                                        await _mc.unwrap<dynamic>(
                                          Channel.general,
                                          'POST',
                                          '/api/v1/downloaders/${d['id']}/verify',
                                        );
                                        if (context.mounted) {
                                          McToast.success('下载器连接成功');
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          McToast.error('连接失败：$e');
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      McIcons.trash2,
                                      size: 17,
                                      color: McTokens.danger,
                                    ),
                                    onPressed: () async {
                                      await _mc.unwrap<dynamic>(
                                        Channel.general,
                                        'DELETE',
                                        '/api/v1/downloaders/${d['id']}',
                                      );
                                      await _load();
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: McTokens.pagePadding,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('目录监控自动入库', style: McText.sub.semibold),
                          ),
                          McChip(
                            icon: McIcons.folderPlus,
                            label: '新增监控目录',
                            compact: true,
                            onTap: _openAddWatchDir,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_watches.isEmpty)
                      const SettingsInfoCard(
                        icon: McIcons.folderSmart,
                        text: '配置监控目录后，外部手动拷贝或第三方工具下完的视频也会自动硬链刮削入库。',
                      )
                    else
                      McInsetGroup(
                        children: [
                          for (final w in _watches)
                            McInsetRow(
                              icon: McIcons.folderOpen,
                              title:
                                  (w['path'] ?? w['source_path'] ?? '').toString(),
                              trailing: IconButton(
                                icon: const Icon(
                                  McIcons.trash2,
                                  size: 17,
                                  color: McTokens.danger,
                                ),
                                onPressed: () async {
                                  await _mc.unwrap<dynamic>(
                                    Channel.general,
                                    'DELETE',
                                    '/api/v1/import-watch/${w['id']}',
                                  );
                                  await _load();
                                },
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
    );
  }
}
