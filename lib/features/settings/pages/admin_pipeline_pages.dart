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
import 'member_detail_sheet.dart';

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
    final status = (_data?['status'] ?? '').toString();
    final ready = _data?['ready'] == true || status == 'ok';
    final siteCheck = _data?['site_check'] is Map
        ? Map<String, dynamic>.from(_data!['site_check'] as Map)
        : null;
    final downloaderOk = _data?['downloader_ok'] == true;
    final issues = (_data?['issues'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final libraries = (_data?['libraries'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final legacyChecks =
        (_data?['checks'] ?? _data?['steps'] ?? _data?['items'])
            as List<dynamic>?;

    final synthesizedChecks = <Map<String, dynamic>>[
      if (siteCheck != null)
        {
          'ok': siteCheck['status'] == 'ok' || siteCheck['ok'] == true,
          'title': (siteCheck['label'] ?? siteCheck['title'] ?? 'PT 资源搜索与站点连通')
              .toString(),
          'message':
              (siteCheck['detail'] ?? siteCheck['message'] ?? '').toString(),
        },
      if (_data != null && _data!.containsKey('downloader_ok'))
        {
          'ok': downloaderOk,
          'title': '默认下载客户端',
          'message': downloaderOk ? '默认下载器连接正常' : '尚未配置可用的默认下载器',
        },
      if (legacyChecks != null)
        ...legacyChecks.whereType<Map>().map(Map<String, dynamic>.from),
    ];

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
                          : '发现 ${issues.isNotEmpty ? '${issues.length} 项' : '部分'}待优化环节，补齐下方提示项即可实现全无人值守追更入库。',
                    ),
                    const SizedBox(height: 12),
                    if (issues.isNotEmpty) ...[
                      McInsetGroup(
                        header: '待处理问题 (${issues.length})',
                        children: [
                          for (final iss in issues)
                            McInsetRow(
                              icon: iss['status'] == 'error'
                                  ? McIcons.alertCircle
                                  : McIcons.alert1,
                              iconColor: iss['status'] == 'error'
                                  ? McTokens.danger
                                  : McTokens.warning,
                              title: (iss['title'] ?? '').toString(),
                              subtitle: [
                                if ((iss['detail'] ?? '').toString().isNotEmpty)
                                  iss['detail'].toString(),
                                if (iss['affected_libraries'] is List &&
                                    (iss['affected_libraries'] as List)
                                        .isNotEmpty)
                                  '受影响库：${(iss['affected_libraries'] as List).join('、')}',
                              ].join('\n'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (synthesizedChecks.isNotEmpty) ...[
                      McInsetGroup(
                        header: '全局核心环节',
                        children: [
                          for (final raw in synthesizedChecks)
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
                                  title: (raw['title'] ??
                                          raw['label'] ??
                                          raw['key'] ??
                                          '')
                                      .toString(),
                                  subtitle: (raw['message'] ??
                                          raw['detail'] ??
                                          '')
                                      .toString(),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (libraries.isNotEmpty) ...[
                      McInsetGroup(
                        header: '各媒体库入库链路 (${libraries.length})',
                        children: [
                          for (final lib in libraries)
                            Builder(
                              builder: (context) {
                                final st = (lib['status'] ?? 'ok').toString();
                                final ok = st == 'ok';
                                final err = st == 'error';
                                return McInsetRow(
                                  icon: ok
                                      ? McIcons.checkCircleFill
                                      : (err
                                          ? McIcons.alertCircle
                                          : McIcons.alert1),
                                  iconColor: ok
                                      ? McTokens.ok
                                      : (err
                                          ? McTokens.danger
                                          : McTokens.warning),
                                  title:
                                      (lib['library_name'] ?? '').toString(),
                                  subtitle: (lib['narrative'] ??
                                          lib['library_root'] ??
                                          '')
                                      .toString(),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
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
  String _search = '';
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
      _loading = _members.isEmpty;
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
          _members =
              list.whereType<Map>().map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '读取成员列表失败：${settingsErrorText(e)}';
        });
      }
    }
  }

  Future<void> _openCreateMember() async {
    final created = await showCreateMemberSheet(context, mc: _mc);
    if (created != null && mounted) {
      setState(() => _members = [..._members, created]);
    }
  }

  Future<void> _openMemberDetail(Map<String, dynamic> member) async {
    final id = (member['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberDetailSheetPage(
          mc: _mc,
          member: member,
          onChanged: (updated) {
            if (!mounted) return;
            setState(() {
              _members = [
                for (final m in _members)
                  (m['id'] as num?)?.toInt() == id ? updated : m,
              ];
            });
          },
          onDeleted: () {
            if (!mounted) return;
            setState(() {
              _members = _members
                  .where((m) => (m['id'] as num?)?.toInt() != id)
                  .toList();
            });
          },
        ),
      ),
    );
  }

  bool _isActive(Map<String, dynamic> m) =>
      (m['status'] ?? 'active').toString() == 'active';

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final matched = _members.where((m) {
      if (q.isEmpty) return true;
      final nick = (m['nickname'] ?? '').toString().toLowerCase();
      final user = (m['username'] ?? '').toString().toLowerCase();
      return nick.contains(q) || user.contains(q);
    }).toList();
    final activeList = matched.where(_isActive).toList();
    final disabledList = matched.where((m) => !_isActive(m)).toList();

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
          : _error != null && _members.isEmpty
              ? McErrorView(text: _error!, onRetry: _load)
              : _members.isEmpty
                  ? McEmptyView(
                      icon: McIcons.team,
                      title: '暂无额外成员',
                      text: '为家人创建独立账号，各自维护独立的继续观看、媒体库范围与年龄分级权限。',
                      actionLabel: '新增成员',
                      onRetry: _openCreateMember,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.only(top: 8, bottom: 36),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: McTokens.pagePadding,
                            ),
                            child: TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(McIcons.search, size: 17),
                                hintText: '搜索成员昵称或用户名…',
                              ),
                              onChanged: (v) => setState(() => _search = v),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (activeList.isNotEmpty) ...[
                            McInsetGroup(
                              header: '已启用 · ${activeList.length}',
                              children: [
                                for (final m in activeList) _buildMemberRow(m),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (disabledList.isNotEmpty)
                            McInsetGroup(
                              header: '已停用 · ${disabledList.length}',
                              children: [
                                for (final m in disabledList)
                                  _buildMemberRow(m),
                              ],
                            ),
                          if (matched.isEmpty)
                            const McEmptyView(
                              title: '没有匹配的成员',
                              text: '请尝试调整搜索关键词。',
                            ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> m) {
    final user = (m['username'] ?? '').toString();
    final nick = (m['nickname'] ?? '').toString();
    final active = _isActive(m);
    final devCount = (m['device_count'] as num?)?.toInt() ?? 0;
    final age = (m['content_age_limit'] as num?)?.toInt();

    return McInsetRow(
      icon: active ? McIcons.user : McIcons.userForbid,
      iconColor: active ? McTokens.accentStrong : McTokens.textFaint,
      title: nick.isNotEmpty && nick.toLowerCase() != user.toLowerCase()
          ? '$nick (@$user)'
          : (nick.isNotEmpty ? nick : user),
      subtitle: [
        devCount == 0 ? '暂无登录设备' : '$devCount 台设备',
        if (age != null) '$age 岁以下',
        if (!active) '已停用',
      ].join(' · '),
      showChevron: true,
      onTap: () => _openMemberDetail(m),
    );
  }
}

/// 3) 订阅策略与选种规则组 CRUD 页（完整后端 RuleSetPayload Schema）。
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

  static const _resOptions = ['2160p', '1080p', '720p'];
  static const _sourceOptions = ['remux', 'blu-ray', 'web-dl', 'rip', 'tv'];
  static const _codecOptions = ['x265', 'x264', 'av1'];
  static const _hdrOptions = ['DV', 'HDR10+', 'HDR10', 'HLG', 'SDR'];
  static const _platformOptions = [
    'netflix',
    'disney_plus',
    'apple_tv_plus',
    'amazon',
    'hbo',
    'iqiyi',
    'tencent',
    'youku',
    'bilibili',
  ];
  static const _langOptions = ['zh', 'en', 'ja', 'ko'];

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
          _rules =
              list.whereType<Map>().map(Map<String, dynamic>.from).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '读取规则组失败：${settingsErrorText(e)}';
        });
      }
    }
  }

  List<String> _strList(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is List) {
      return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _editRule({Map<String, dynamic>? existing}) async {
    final spec = existing?['spec'] is Map
        ? Map<String, dynamic>.from(existing!['spec'] as Map)
        : <String, dynamic>{};
    final matchRulesRaw = existing?['match_rules'] is List
        ? (existing!['match_rules'] as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList()
        : <Map<String, dynamic>>[];

    final nameCtrl =
        TextEditingController(text: (existing?['name'] ?? '').toString());
    final resOrder = _strList(spec, 'resolutions');
    final sourceOrder = _strList(spec, 'media_sources');
    final codecs = _strList(spec, 'video_codecs').toSet();
    final hdrAllow = _strList(spec, 'hdr_levels');
    final hdrBlock = _strList(spec, 'hdr_block').toSet();
    final platAllow = _strList(spec, 'platforms').toSet();
    final platBlock = _strList(spec, 'platforms_block').toSet();
    final subLangs = _strList(spec, 'subtitle_languages_require').toSet();
    final audLangs = _strList(spec, 'audio_languages_require').toSet();

    final groupAllowCtrl = TextEditingController(
      text: _strList(spec, 'release_groups_allow').join(', '),
    );
    final groupBlockCtrl = TextEditingController(
      text: _strList(spec, 'release_groups_block').join(', '),
    );
    final sizeMinCtrl = TextEditingController(
      text: spec['size_min_mb'] != null ? '${spec['size_min_mb']}' : '',
    );
    final sizeMaxCtrl = TextEditingController(
      text: spec['size_max_mb'] != null ? '${spec['size_max_mb']}' : '',
    );
    final minSeedersCtrl = TextEditingController(
      text: spec['min_seeders'] != null ? '${spec['min_seeders']}' : '',
    );

    var freeOnly = spec['free_only'] == true;
    var excludeHr = spec['exclude_hr'] == true;
    var hrUnknown = (spec['hr_unknown_policy'] ?? '').toString();
    var upgradeSource = (spec['upgrade_source'] ?? '').toString();
    var cutoffRes = (spec['cutoff_resolution'] ?? '').toString();

    // 适用范围 match_rules（kind + origin_countries）
    String? matchKind;
    final matchCountriesCtrl = TextEditingController();
    for (final r in matchRulesRaw) {
      final f = (r['field'] ?? '').toString();
      final vals = (r['values'] as List? ?? const []).map((e) => e.toString()).toList();
      if (f == 'kind' && vals.isNotEmpty) matchKind = vals.first;
      if (f == 'origin_countries' && vals.isNotEmpty) {
        matchCountriesCtrl.text = vals.join(', ');
      }
    }

    final ok = await showMcSheet<bool>(
      context: context,
      maxWidth: 620,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget chipOrder(
            String label,
            List<String> options,
            List<String> selected,
          ) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: McText.caption.muted),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final o in options)
                        McChip(
                          label: selected.contains(o)
                              ? '${selected.indexOf(o) + 1}. $o'
                              : o,
                          compact: true,
                          selected: selected.contains(o),
                          onTap: () => setSheet(() {
                            selected.contains(o)
                                ? selected.remove(o)
                                : selected.add(o);
                          }),
                        ),
                    ],
                  ),
                ],
              );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? '新建选种规则组' : '编辑选种规则组',
                  style: McText.titleSm,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '规则组名称 *',
                    hintText: '例如：4K 杜比视界原盘 / 1080P 剧集省空间',
                  ),
                ),
                const SizedBox(height: 14),
                chipOrder('分辨率偏好序（留空=不限）', _resOptions, resOrder),
                const SizedBox(height: 12),
                chipOrder('片源档白名单与偏好序（留空=不限）', _sourceOptions, sourceOrder),
                const SizedBox(height: 12),
                Text('视频编码白名单（video_codecs）', style: McText.caption.muted),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in _codecOptions)
                      McChip(
                        label: c,
                        compact: true,
                        selected: codecs.contains(c),
                        onTap: () => setSheet(() {
                          codecs.contains(c) ? codecs.remove(c) : codecs.add(c);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                chipOrder('HDR 偏好白名单 (hdr_levels)', _hdrOptions, hdrAllow),
                const SizedBox(height: 10),
                Text('排除 HDR 类型 (hdr_block)', style: McText.caption.muted),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final h in _hdrOptions)
                      McChip(
                        label: h,
                        compact: true,
                        selected: hdrBlock.contains(h),
                        onTap: () => setSheet(() {
                          hdrBlock.contains(h)
                              ? hdrBlock.remove(h)
                              : hdrBlock.add(h);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('流媒体平台白名单 (platforms)', style: McText.caption.muted),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in _platformOptions)
                      McChip(
                        label: p,
                        compact: true,
                        selected: platAllow.contains(p),
                        onTap: () => setSheet(() {
                          platAllow.contains(p)
                              ? platAllow.remove(p)
                              : platAllow.add(p);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('流媒体平台黑名单 (platforms_block)', style: McText.caption.muted),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in _platformOptions)
                      McChip(
                        label: p,
                        compact: true,
                        selected: platBlock.contains(p),
                        onTap: () => setSheet(() {
                          platBlock.contains(p)
                              ? platBlock.remove(p)
                              : platBlock.add(p);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('字幕语言要求 (subtitle_languages_require)',
                    style: McText.caption.muted),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final l in _langOptions)
                      McChip(
                        label: l,
                        compact: true,
                        selected: subLangs.contains(l),
                        onTap: () => setSheet(() {
                          subLangs.contains(l)
                              ? subLangs.remove(l)
                              : subLangs.add(l);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('音轨语言要求 (audio_languages_require)',
                    style: McText.caption.muted),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final l in _langOptions)
                      McChip(
                        label: l,
                        compact: true,
                        selected: audLangs.contains(l),
                        onTap: () => setSheet(() {
                          audLangs.contains(l)
                              ? audLangs.remove(l)
                              : audLangs.add(l);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sizeMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: '最小体积 (MB)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sizeMaxCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: '最大体积 (MB)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minSeedersCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '最低做种'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: groupAllowCtrl,
                  decoration: const InputDecoration(
                    labelText: '制作组白名单（逗号分隔）',
                    hintText: 'FRDS, CMCT, WiKi',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: groupBlockCtrl,
                  decoration: const InputDecoration(
                    labelText: '制作组黑名单（逗号分隔）',
                    hintText: 'CAM, HC',
                  ),
                ),
                const SizedBox(height: 12),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    McInsetRow(
                      title: '仅抓免费促销种 (free_only)',
                      trailing: Switch(
                        value: freeOnly,
                        onChanged: (v) => setSheet(() => freeOnly = v),
                      ),
                    ),
                    McInsetRow(
                      title: '排除 H&R 考核种 (exclude_hr)',
                      trailing: Switch(
                        value: excludeHr,
                        onChanged: (v) => setSheet(() => excludeHr = v),
                      ),
                    ),
                  ],
                ),
                if (excludeHr) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('H&R 未知策略：', style: McText.caption.muted),
                      const SizedBox(width: 8),
                      McChip(
                        label: '宽松放行',
                        compact: true,
                        selected: hrUnknown != 'strict',
                        onTap: () => setSheet(() => hrUnknown = 'lenient'),
                      ),
                      const SizedBox(width: 6),
                      McChip(
                        label: '严格排除',
                        compact: true,
                        selected: hrUnknown == 'strict',
                        onTap: () => setSheet(() => hrUnknown = 'strict'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: const ['', 'web-dl', 'blu-ray', 'remux']
                                .contains(upgradeSource)
                            ? upgradeSource
                            : '',
                        decoration:
                            const InputDecoration(labelText: '洗版目标片源'),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('不自动洗版')),
                          DropdownMenuItem(value: 'web-dl', child: Text('WEB-DL')),
                          DropdownMenuItem(
                              value: 'blu-ray', child: Text('Blu-ray')),
                          DropdownMenuItem(value: 'remux', child: Text('Remux')),
                        ],
                        onChanged: (v) =>
                            setSheet(() => upgradeSource = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: const ['', '2160p', '1080p', '720p']
                                .contains(cutoffRes)
                            ? cutoffRes
                            : '',
                        decoration:
                            const InputDecoration(labelText: '洗版截止分辨率'),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('跟随首选')),
                          DropdownMenuItem(value: '2160p', child: Text('2160p')),
                          DropdownMenuItem(value: '1080p', child: Text('1080p')),
                          DropdownMenuItem(value: '720p', child: Text('720p')),
                        ],
                        onChanged: (v) => setSheet(() => cutoffRes = v ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('自动适用范围 (match_rules，可选)', style: McText.caption.muted),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final (k, lbl) in const [
                      (null, '不限类型'),
                      ('movie', '仅电影'),
                      ('tv', '仅剧集'),
                    ]) ...[
                      McChip(
                        label: lbl,
                        compact: true,
                        selected: matchKind == k,
                        onTap: () => setSheet(() => matchKind = k),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: matchCountriesCtrl,
                  decoration: const InputDecoration(
                    labelText: '适用制片国家/地区码（可选，逗号分隔）',
                    hintText: 'JP, KR, US, CN',
                  ),
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
          );
        },
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

    final nextSpec = <String, dynamic>{
      if (resOrder.isNotEmpty) 'resolutions': resOrder,
      if (sourceOrder.isNotEmpty) 'media_sources': sourceOrder,
      if (codecs.isNotEmpty) 'video_codecs': codecs.toList(),
      if (hdrAllow.isNotEmpty) 'hdr_levels': hdrAllow,
      if (hdrBlock.isNotEmpty) 'hdr_block': hdrBlock.toList(),
      if (platAllow.isNotEmpty) 'platforms': platAllow.toList(),
      if (platBlock.isNotEmpty) 'platforms_block': platBlock.toList(),
      if (subLangs.isNotEmpty) 'subtitle_languages_require': subLangs.toList(),
      if (audLangs.isNotEmpty) 'audio_languages_require': audLangs.toList(),
      if (splitCsv(groupAllowCtrl.text).isNotEmpty)
        'release_groups_allow': splitCsv(groupAllowCtrl.text),
      if (splitCsv(groupBlockCtrl.text).isNotEmpty)
        'release_groups_block': splitCsv(groupBlockCtrl.text),
      if (int.tryParse(sizeMinCtrl.text.trim()) != null)
        'size_min_mb': int.parse(sizeMinCtrl.text.trim()),
      if (int.tryParse(sizeMaxCtrl.text.trim()) != null)
        'size_max_mb': int.parse(sizeMaxCtrl.text.trim()),
      if (int.tryParse(minSeedersCtrl.text.trim()) != null)
        'min_seeders': int.parse(minSeedersCtrl.text.trim()),
      if (freeOnly) 'free_only': true,
      if (excludeHr) 'exclude_hr': true,
      if (excludeHr && hrUnknown.isNotEmpty) 'hr_unknown_policy': hrUnknown,
      if (upgradeSource.isNotEmpty) 'upgrade_source': upgradeSource,
      if (cutoffRes.isNotEmpty) 'cutoff_resolution': cutoffRes,
    };

    final nextMatchRules = <Map<String, dynamic>>[
      if (matchKind != null)
        {
          'field': 'kind',
          'op': 'any_of',
          'values': [matchKind],
        },
      if (splitCsv(matchCountriesCtrl.text).isNotEmpty)
        {
          'field': 'origin_countries',
          'op': 'any_of',
          'values': splitCsv(matchCountriesCtrl.text)
              .map((e) => e.toUpperCase())
              .toList(),
        },
    ];

    final payload = <String, dynamic>{
      'name': name,
      'spec': nextSpec,
      'match_rules': nextMatchRules,
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
      if (mounted) McToast.error('保存失败：${settingsErrorText(e)}');
    }
  }

  String _describeSpec(Map<String, dynamic> r) {
    final spec = r['spec'] is Map
        ? Map<String, dynamic>.from(r['spec'] as Map)
        : const <String, dynamic>{};
    final parts = <String>[
      if (r['is_default'] == true) '默认',
      if (_strList(spec, 'resolutions').isNotEmpty)
        _strList(spec, 'resolutions').join('/'),
      if (_strList(spec, 'media_sources').isNotEmpty)
        _strList(spec, 'media_sources').join('/'),
      if (spec['free_only'] == true) '仅免费',
      if (spec['exclude_hr'] == true) '排 H&R',
      if ((spec['upgrade_source'] ?? '').toString().isNotEmpty)
        '洗版→${spec['upgrade_source']}',
    ];
    return parts.isEmpty ? '不限条件' : parts.join(' · ');
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
                      text: '默认使用智能选源策略；可新建规则精确限定分辨率、片源、HDR、字幕音轨、制作组与洗版策略。',
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
                                subtitle: _describeSpec(r),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (r['is_default'] != true)
                                      McChip(
                                        label: '设为默认',
                                        compact: true,
                                        onTap: () async {
                                          try {
                                            await _mc.unwrap<dynamic>(
                                              Channel.general,
                                              'POST',
                                              '/api/v1/rule-sets/${r['id']}/default',
                                            );
                                            await _load();
                                          } catch (e) {
                                            McToast.error(settingsErrorText(e));
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
                                        final refCount =
                                            (r['reference_count'] as num?)
                                                    ?.toInt() ??
                                                0;
                                        if (refCount > 0) {
                                          McToast.error(
                                            '该规则组正被 $refCount 个订阅引用，无法删除',
                                          );
                                          return;
                                        }
                                        try {
                                          await _mc.unwrap<dynamic>(
                                            Channel.general,
                                            'DELETE',
                                            '/api/v1/rule-sets/${r['id']}',
                                          );
                                          await _load();
                                        } catch (e) {
                                          McToast.error(settingsErrorText(e));
                                        }
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
  final Set<String> _busySiteIds = <String>{};
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
                                final siteName = (s['name'] ?? sid).toString();
                                final enabled = s['enabled'] != false;
                                final isBusy = _busySiteIds.contains(sid);
                                return McInsetRow(
                                  icon: McIcons.globe,
                                  iconColor: enabled
                                      ? McTokens.ok
                                      : McTokens.textFaint,
                                  title: siteName,
                                  subtitle: enabled ? '已启用' : '已停用',
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      McChip(
                                        label: '测速验证',
                                        compact: true,
                                        onTap: isBusy
                                            ? null
                                            : () async {
                                                try {
                                                  await _mc.unwrap<dynamic>(
                                                    Channel.general,
                                                    'POST',
                                                    '/api/v1/sites/$sid/verify',
                                                  );
                                                  if (context.mounted) {
                                                    McToast.success(
                                                      '$siteName 连通正常',
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    McToast.error(
                                                      '验证失败：${settingsErrorText(e)}',
                                                    );
                                                  }
                                                }
                                              },
                                      ),
                                      Switch(
                                        value: enabled,
                                        onChanged: isBusy
                                            ? null
                                            : (v) async {
                                                setState(
                                                  () => _busySiteIds.add(sid),
                                                );
                                                try {
                                                  await _mc.unwrap<dynamic>(
                                                    Channel.general,
                                                    'PATCH',
                                                    '/api/v1/sites/$sid/status',
                                                    body: {'enabled': v},
                                                  );
                                                  await _load();
                                                } catch (e) {
                                                  if (mounted) {
                                                    McToast.error(
                                                      '切换失败：${settingsErrorText(e)}',
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () => _busySiteIds
                                                          .remove(sid),
                                                    );
                                                  }
                                                }
                                              },
                                      ),
                                      IconButton(
                                        tooltip: '删除站点',
                                        icon: const Icon(
                                          McIcons.trash2,
                                          size: 17,
                                          color: McTokens.danger,
                                        ),
                                        onPressed: isBusy
                                            ? null
                                            : () async {
                                                final ok = await confirmDialog(
                                                  context,
                                                  title: '删除站点「$siteName」？',
                                                  message:
                                                      '删除后该 PT 索引站点将不再参与搜索和自动追更。',
                                                  confirmLabel: '删除',
                                                  destructive: true,
                                                );
                                                if (!ok || !mounted) return;
                                                setState(
                                                  () => _busySiteIds.add(sid),
                                                );
                                                try {
                                                  await _mc.unwrap<dynamic>(
                                                    Channel.general,
                                                    'DELETE',
                                                    '/api/v1/sites/$sid',
                                                  );
                                                  if (mounted) {
                                                    McToast.success('已删除站点');
                                                  }
                                                  await _load();
                                                } catch (e) {
                                                  if (mounted) {
                                                    McToast.error(
                                                      '删除失败：${settingsErrorText(e)}',
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () => _busySiteIds
                                                          .remove(sid),
                                                    );
                                                  }
                                                }
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
  const DownloadersAdminPage({super.key, this.initialSection});

  /// 深度链接定位分区，例如 `import-watch`。
  final String? initialSection;

  @override
  ConsumerState<DownloadersAdminPage> createState() =>
      _DownloadersAdminPageState();
}

class _DownloadersAdminPageState extends ConsumerState<DownloadersAdminPage> {
  List<Map<String, dynamic>> _downloaders = const [];
  List<Map<String, dynamic>> _watches = const [];
  final Set<String> _busyKeys = <String>{};
  final GlobalKey _watchSectionKey = GlobalKey();
  bool _scrolledToInitial = false;
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
        if (!_scrolledToInitial && widget.initialSection == 'import-watch') {
          _scrolledToInitial = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _watchSectionKey.currentContext;
            if (ctx != null && ctx.mounted) {
              Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
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
    try {
      if (ok != true || !mounted) return;
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
      if (mounted) McToast.error('添加失败：${settingsErrorText(e)}');
    } finally {
      nameCtrl.dispose();
      urlCtrl.dispose();
      userCtrl.dispose();
      pwdCtrl.dispose();
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
                            Builder(
                              builder: (context) {
                                final dlId = '${d['id']}';
                                final dlKey = 'dl:$dlId';
                                final dlName =
                                    (d['name'] ?? d['type'] ?? '').toString();
                                final isBusy = _busyKeys.contains(dlKey);
                                return McInsetRow(
                                  icon: McIcons.downloadCloudOut,
                                  title: dlName,
                                  subtitle:
                                      '${d['url'] ?? d['base_url'] ?? ''}${d['is_default'] == true ? ' · 默认' : ''}',
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      McChip(
                                        label: '测试',
                                        compact: true,
                                        onTap: isBusy
                                            ? null
                                            : () async {
                                                try {
                                                  await _mc.unwrap<dynamic>(
                                                    Channel.general,
                                                    'POST',
                                                    '/api/v1/downloaders/$dlId/verify',
                                                  );
                                                  if (context.mounted) {
                                                    McToast.success('下载器连接成功');
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    McToast.error(
                                                      '连接失败：${settingsErrorText(e)}',
                                                    );
                                                  }
                                                }
                                              },
                                      ),
                                      IconButton(
                                        tooltip: '删除下载器',
                                        icon: const Icon(
                                          McIcons.trash2,
                                          size: 17,
                                          color: McTokens.danger,
                                        ),
                                        onPressed: isBusy
                                            ? null
                                            : () async {
                                                final ok = await confirmDialog(
                                                  context,
                                                  title: '删除下载器「$dlName」？',
                                                  message:
                                                      '删除后将无法向该下载客户端推送新的下载任务。',
                                                  confirmLabel: '删除',
                                                  destructive: true,
                                                );
                                                if (!ok || !mounted) return;
                                                setState(
                                                  () => _busyKeys.add(dlKey),
                                                );
                                                try {
                                                  await _mc.unwrap<dynamic>(
                                                    Channel.general,
                                                    'DELETE',
                                                    '/api/v1/downloaders/$dlId',
                                                  );
                                                  if (mounted) {
                                                    McToast.success('已删除下载器');
                                                  }
                                                  await _load();
                                                } catch (e) {
                                                  if (mounted) {
                                                    McToast.error(
                                                      '删除失败：${settingsErrorText(e)}',
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () => _busyKeys
                                                          .remove(dlKey),
                                                    );
                                                  }
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    Padding(
                      key: _watchSectionKey,
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
                            Builder(
                              builder: (context) {
                                final watchId = '${w['id']}';
                                final watchKey = 'watch:$watchId';
                                final watchPath =
                                    (w['path'] ?? w['source_path'] ?? '')
                                        .toString();
                                final isBusy = _busyKeys.contains(watchKey);
                                return McInsetRow(
                                  icon: McIcons.folderOpen,
                                  title: watchPath,
                                  trailing: IconButton(
                                    tooltip: '删除监控目录',
                                    icon: const Icon(
                                      McIcons.trash2,
                                      size: 17,
                                      color: McTokens.danger,
                                    ),
                                    onPressed: isBusy
                                        ? null
                                        : () async {
                                            final ok = await confirmDialog(
                                              context,
                                              title: '删除监控目录？',
                                              message:
                                                  '将停止自动扫描与入库「$watchPath」，不会删除磁盘上的已有文件。',
                                              confirmLabel: '删除',
                                              destructive: true,
                                            );
                                            if (!ok || !mounted) return;
                                            setState(
                                              () => _busyKeys.add(watchKey),
                                            );
                                            try {
                                              await _mc.unwrap<dynamic>(
                                                Channel.general,
                                                'DELETE',
                                                '/api/v1/import-watch/$watchId',
                                              );
                                              if (mounted) {
                                                McToast.success('已删除监控目录');
                                              }
                                              await _load();
                                            } catch (e) {
                                              if (mounted) {
                                                McToast.error(
                                                  '删除失败：${settingsErrorText(e)}',
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () =>
                                                      _busyKeys.remove(watchKey),
                                                );
                                              }
                                            }
                                          },
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
