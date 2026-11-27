import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../widgets/settings_ui.dart';

// ── 一次性成员凭据展示弹层（新建成员 / 重置密码共用，防误关确认）──────────

Future<void> showMemberCredentialsSheet(
  BuildContext context, {
  required String title,
  required String username,
  required String password,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xB8000000),
    constraints: const BoxConstraints(maxWidth: 540),
    builder: (ctx) => McSheetFrame(
      title: '保存成员登录凭据',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsNoticeBanner(
              text: '$title。初始/重置密码仅本次明文显示，请先复制保存后再关闭。',
              tone: SettingsTone.ok,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 14),
            Text('登录用户名', style: McText.caption.muted),
            const SizedBox(height: 6),
            SettingsCopyBox(value: username, copyLabel: '复制账号'),
            const SizedBox(height: 12),
            Text('登录密码', style: McText.caption.muted),
            const SizedBox(height: 6),
            SettingsCopyBox(value: password, copyLabel: '复制密码'),
            const SizedBox(height: 14),
            McActionPill(
              icon: McIcons.fileCopy2Fill,
              label: '一键复制账号与密码',
              primary: false,
              expanded: true,
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: '账号：$username\n密码：$password'),
                );
                McToast.success('已复制账号和密码');
              },
            ),
            const SizedBox(height: 10),
            McActionPill(
              label: '完成',
              primary: true,
              expanded: true,
              onTap: () async {
                final ok = await confirmDialog(
                  ctx,
                  title: '确认已经保存密码？',
                  message: '关闭后无法再次查看本次生成的明文密码。',
                  confirmLabel: '我已保存',
                  destructive: false,
                );
                if (ok && ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ── 新增家庭成员弹层（仅创建普通成员，自动生成 14 位强密码 + 凭据卡）──────────

Future<Map<String, dynamic>?> showCreateMemberSheet(
  BuildContext context, {
  required McClient mc,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xB8000000),
    constraints: const BoxConstraints(maxWidth: 540),
    builder: (_) => McSheetFrame(child: _CreateMemberSheet(mc: mc)),
  );
}

class _CreateMemberSheet extends StatefulWidget {
  const _CreateMemberSheet({required this.mc});

  final McClient mc;

  @override
  State<_CreateMemberSheet> createState() => _CreateMemberSheetState();
}

class _CreateMemberSheetState extends State<_CreateMemberSheet> {
  final _userCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  late String _password = _generatePassword();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _createdMember;
  String _createdUsername = '';

  static String _generatePassword() {
    const alphabet =
        'abcdefghjkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ2345679';
    final rng = Random.secure();
    return List.generate(
      14,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _userCtrl.text.trim();
    if (username.length < 3) {
      setState(() => _error = '用户名至少 3 个字符');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final member = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/members',
        body: {
          'username': username,
          'password': _password,
          'nickname': _nickCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      // 原位切换到一次性凭据展示态，避免先 pop 再使用已销毁 context 弹窗。
      setState(() {
        _createdMember = member;
        _createdUsername = (member['username'] ?? username).toString();
      });
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishCreated() async {
    final ok = await confirmDialog(
      context,
      title: '确认已经保存密码？',
      message: '关闭后无法再次查看本次生成的明文密码。',
      confirmLabel: '我已保存',
      destructive: false,
    );
    if (ok && mounted) {
      Navigator.of(context).pop(_createdMember);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = McL10n.of(context);
    final created = _createdMember;
    if (created != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _finishCreated();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('保存成员登录凭据', style: McText.titleSm),
              const SizedBox(height: 12),
              SettingsNoticeBanner(
                text:
                    '已创建家庭成员「$_createdUsername」。初始密码仅本次明文显示，请先复制保存后再关闭。',
                tone: SettingsTone.ok,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: 14),
              Text('登录用户名', style: McText.caption.muted),
              const SizedBox(height: 6),
              SettingsCopyBox(value: _createdUsername, copyLabel: '复制账号'),
              const SizedBox(height: 12),
              Text('登录密码', style: McText.caption.muted),
              const SizedBox(height: 6),
              SettingsCopyBox(value: _password, copyLabel: '复制密码'),
              const SizedBox(height: 14),
              McActionPill(
                icon: McIcons.fileCopy2Fill,
                label: '一键复制账号与密码',
                primary: false,
                expanded: true,
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: '账号：$_createdUsername\n密码：$_password',
                    ),
                  );
                  McToast.success('已复制账号和密码');
                },
              ),
              const SizedBox(height: 10),
              McActionPill(
                label: l10n.done,
                primary: true,
                expanded: true,
                onTap: _finishCreated,
              ),
            ],
          ),
        ),
      );
    }

    final canCreate = !_busy && _userCtrl.text.trim().length >= 3;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('新增家庭成员', style: McText.titleSm),
          const SizedBox(height: 6),
          Text(
            '新成员默认为普通成员身份，创建后可在成员详情中细调订阅、搜种、年龄分级与媒体库授权。',
            style: McText.caption.muted,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            SettingsNoticeBanner(
              text: _error!,
              tone: SettingsTone.danger,
              margin: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: '登录用户名 *（至少 3 位）',
              hintText: '例如：alice',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nickCtrl,
            decoration: const InputDecoration(
              labelText: '显示昵称（可选）',
              hintText: '例如：妈妈 / 客厅成员',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('自动生成初始密码（14 位）', style: McText.caption.muted),
              ),
              McChip(
                icon: McIcons.refreshS,
                label: '重新生成',
                compact: true,
                onTap: () => setState(() => _password = _generatePassword()),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SettingsCopyBox(value: _password, copyLabel: '复制'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: l10n.cancel,
                  primary: false,
                  expanded: true,
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: McActionPill(
                  label: _busy ? '创建中…' : '创建成员账号',
                  primary: true,
                  expanded: true,
                  onTap: canCreate ? _submit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 成员详情与完整权限编辑页（1:1 对齐 iOS MemberDetailView + MemberEditSheet）──

class MemberDetailSheetPage extends StatefulWidget {
  const MemberDetailSheetPage({
    super.key,
    required this.mc,
    required this.member,
    required this.onChanged,
    required this.onDeleted,
  });

  final McClient mc;
  final Map<String, dynamic> member;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDeleted;

  @override
  State<MemberDetailSheetPage> createState() => _MemberDetailSheetPageState();
}

class _MemberDetailSheetPageState extends State<MemberDetailSheetPage> {
  late Map<String, dynamic> _m = Map<String, dynamic>.from(widget.member);
  bool _busy = false;

  int get _id => (_m['id'] as num?)?.toInt() ?? 0;
  String get _username => (_m['username'] ?? '').toString();
  String get _nickname => (_m['nickname'] ?? '').toString();
  String get _displayName => _nickname.isNotEmpty ? _nickname : _username;
  bool get _isActive => (_m['status'] ?? 'active').toString() == 'active';
  bool get _allowSubscribe => _m['allow_subscribe'] == true;
  bool get _allowSearch => _m['allow_search'] == true;
  bool get _allowDirectDownload => _m['allow_direct_download'] == true;
  bool get _allowVideoDownload => _m['allow_video_download'] == true;
  int? get _ageLimit => (_m['content_age_limit'] as num?)?.toInt();
  bool get _allowUnrated => _m['allow_unrated'] != false;
  bool get _allLibraries => _m['all_libraries'] != false;
  List<int> get _libraryIds =>
      ((_m['library_ids'] ?? const []) as List<dynamic>)
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();
  bool get _allSites => _m['all_sites'] != false;
  List<String> get _siteIds => ((_m['site_ids'] ?? const []) as List<dynamic>)
      .map((e) => e.toString())
      .toList();
  int get _deviceCount => (_m['device_count'] as num?)?.toInt() ?? 0;
  String? get _lastLoginAt => _m['last_login_at']?.toString();

  void _accept(Map<String, dynamic> updated) {
    setState(() => _m = updated);
    widget.onChanged(updated);
  }

  Future<void> _putUpdate(Map<String, dynamic> body) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/members/$_id',
        body: body,
      );
      if (mounted) {
        _accept(updated);
        McToast.success('成员设置已保存');
      }
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// P0 修复：POST /api/v1/members/{id}/reset-password 不带 password body，展示后端生成的一次性凭据！
  Future<void> _resetPassword() async {
    final ok = await confirmDialog(
      context,
      title: '重置「$_displayName」的密码？',
      message: '服务器将随机生成新的临时密码，并使该成员现有密码立即失效。',
      confirmLabel: '重置密码',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/members/$_id/reset-password',
      );
      final user = (res['username'] ?? _username).toString();
      final pwd = (res['password'] ?? '').toString();
      // 刷新成员信息
      widget.mc
          .unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/members/$_id',
          )
          .then((fresh) {
        if (mounted) _accept(fresh);
      }).catchError((_) {});
      if (mounted && pwd.isNotEmpty) {
        await showMemberCredentialsSheet(
          context,
          title: '已为「$_displayName」重置登录密码',
          username: user,
          password: pwd,
        );
      }
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutAll() async {
    final ok = await confirmDialog(
      context,
      title: '强制注销「$_displayName」的全部设备？',
      message: '该成员在所有设备上的登录态都将立即失效，需重新登录。',
      confirmLabel: '全部注销',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/members/$_id/sign-out',
      );
      if (mounted) {
        _accept(updated);
        McToast.success('已强制注销该成员全部设备');
      }
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleStatus() async {
    final nextEnabled = !_isActive;
    if (!nextEnabled) {
      final ok = await confirmDialog(
        context,
        title: '停用「$_displayName」？',
        message: '停用后该成员无法登录或继续播放，可随时重新启用。',
        confirmLabel: '停用账号',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final updated = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/members/$_id/status',
        body: {'enabled': nextEnabled},
      );
      if (mounted) {
        _accept(updated);
        McToast.success(nextEnabled ? '已重新启用成员账号' : '已停用成员账号');
      }
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteMember() async {
    final ok = await confirmDialog(
      context,
      title: '删除成员「$_displayName」？',
      message: '该成员的独立观看进度与收藏将被永久移除，且无法恢复。',
      confirmLabel: '永久删除',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.mc.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/members/$_id',
      );
      if (mounted) {
        McToast.success('已删除成员「$_displayName」');
        widget.onDeleted();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 分区编辑弹层 ──

  Future<void> _editNickname() async {
    final next = await textInputDialog(
      context,
      title: '修改成员昵称',
      initial: _nickname,
      hint: '显示昵称',
    );
    if (next == null || next == _nickname) return;
    await _putUpdate({'nickname': next});
  }

  Future<void> _editPermissions() async {
    var sub = _allowSubscribe;
    var search = _allowSearch;
    var direct = _allowDirectDownload;
    var video = _allowVideoDownload;

    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('功能权限', style: McText.titleSm),
              const SizedBox(height: 12),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  McInsetRow(
                    title: '允许订阅追更',
                    subtitle: '可在发现页或详情页添加自动追更订阅',
                    trailing: Switch(
                      value: sub,
                      onChanged: (v) => setSheet(() => sub = v),
                    ),
                  ),
                  McInsetRow(
                    title: '允许搜索 PT 站点资源',
                    subtitle: '允许在发现/搜索页发起跨站种子搜索',
                    trailing: Switch(
                      value: search,
                      onChanged: (v) => setSheet(() {
                        search = v;
                        if (!v) direct = false;
                      }),
                    ),
                  ),
                  McInsetRow(
                    title: '允许直接推送下载',
                    subtitle: '搜到种子后可直接推送到下载器（需先允许搜索）',
                    trailing: Switch(
                      value: search && direct,
                      onChanged: !search
                          ? null
                          : (v) => setSheet(() => direct = v),
                    ),
                  ),
                  McInsetRow(
                    title: '允许离线下载影片到设备',
                    subtitle: '允许在手机/平板客户端缓存视频供无网播放',
                    trailing: Switch(
                      value: video,
                      onChanged: (v) => setSheet(() => video = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              McActionPill(
                label: '保存权限',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _putUpdate({
        'allow_subscribe': sub,
        'allow_search': search,
        'allow_direct_download': search && direct,
        'allow_video_download': video,
      });
    }
  }

  Future<void> _editContentRating() async {
    int? age = _ageLimit;
    var unrated = _allowUnrated;
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('内容年龄分级限制', style: McText.titleSm),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  McChip(
                    label: '不限制',
                    compact: true,
                    selected: age == null,
                    onTap: () => setSheet(() => age = null),
                  ),
                  for (final a in const [6, 12, 16, 18])
                    McChip(
                      label: '$a 岁以下',
                      compact: true,
                      selected: age == a,
                      onTap: () => setSheet(() => age = a),
                    ),
                ],
              ),
              if (age != null) ...[
                const SizedBox(height: 14),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    McInsetRow(
                      title: '允许观看未标注分级的影片',
                      trailing: Switch(
                        value: unrated,
                        onChanged: (v) => setSheet(() => unrated = v),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              McActionPill(
                label: '保存分级限制',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _putUpdate({
        'content_age_limit': age ?? -1,
        'allow_unrated': unrated,
      });
    }
  }

  Future<void> _editLibraries() async {
    List<Map<String, dynamic>> libraries = const [];
    try {
      final raw = await widget.mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/libraries',
        query: const {'scope': 'all'},
      );
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['items'] ?? const []) as List<dynamic> : const []);
      libraries =
          list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e) {
      McToast.error('读取媒体库失败：${settingsErrorText(e)}');
      return;
    }
    if (!mounted) return;

    var allLibs = _allLibraries;
    final picked = Set<int>.from(_libraryIds);

    final ok = await showMcSheet<bool>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final visible = libraries.where((l) {
            if (!allLibs) return true;
            return (l['access_mode'] ?? '').toString() == 'selected';
          }).toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('媒体库可见范围', style: McText.titleSm),
                const SizedBox(height: 12),
                Row(
                  children: [
                    McChip(
                      label: '全部共享媒体库',
                      compact: true,
                      selected: allLibs,
                      onTap: () => setSheet(() => allLibs = true),
                    ),
                    const SizedBox(width: 8),
                    McChip(
                      label: '仅指定媒体库',
                      compact: true,
                      selected: !allLibs,
                      onTap: () => setSheet(() => allLibs = false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  allLibs ? '额外授权的私密/指定媒体库' : '勾选可访问的媒体库',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 6),
                if (visible.isEmpty)
                  Text('无可单独选择的媒体库', style: McText.caption.faint)
                else
                  for (final lib in visible)
                    Builder(
                      builder: (context) {
                        final lid = (lib['id'] as num?)?.toInt() ?? 0;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: picked.contains(lid),
                          onChanged: (v) => setSheet(() {
                            v == true ? picked.add(lid) : picked.remove(lid);
                          }),
                          title: Text((lib['name'] ?? '').toString()),
                        );
                      },
                    ),
                const SizedBox(height: 16),
                McActionPill(
                  label: '保存媒体库授权',
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
    if (ok == true) {
      final filteredIds = allLibs
          ? picked.where((id) {
              for (final l in libraries) {
                if ((l['id'] as num?)?.toInt() == id) {
                  return (l['access_mode'] ?? '').toString() != 'everyone';
                }
              }
              return true;
            }).toList()
          : picked.toList();
      await _putUpdate({
        'all_libraries': allLibs,
        'library_ids': filteredIds,
      });
    }
  }

  Future<void> _editSites() async {
    List<Map<String, dynamic>> sites = const [];
    try {
      final raw = await widget.mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/sites/catalog',
      );
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['items'] ?? raw['sites'] ?? const []) as List<dynamic>
              : const []);
      sites = list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e) {
      McToast.error('读取站点目录失败：${settingsErrorText(e)}');
      return;
    }
    if (!mounted) return;

    var allSites = _allSites;
    final picked = Set<String>.from(_siteIds);
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
              const Text('可搜索 PT 站点范围', style: McText.titleSm),
              const SizedBox(height: 12),
              Row(
                children: [
                  McChip(
                    label: '全部站点',
                    compact: true,
                    selected: allSites,
                    onTap: () => setSheet(() => allSites = true),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: '仅指定站点',
                    compact: true,
                    selected: !allSites,
                    onTap: () => setSheet(() => allSites = false),
                  ),
                ],
              ),
              if (!allSites) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in sites)
                        Builder(
                          builder: (context) {
                            final sid =
                                (s['site_id'] ?? s['id'] ?? '').toString();
                            final sname =
                                (s['display_name'] ?? s['name'] ?? sid)
                                    .toString();
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: picked.contains(sid),
                              onChanged: (v) => setSheet(() {
                                v == true
                                    ? picked.add(sid)
                                    : picked.remove(sid);
                              }),
                              title: Text(sname),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              McActionPill(
                label: '保存站点授权',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _putUpdate({
        'all_sites': allSites,
        'site_ids': allSites ? const <String>[] : picked.toList(),
      });
    }
  }

  String get _permSummary {
    final list = <String>[
      if (_allowSubscribe) '订阅',
      if (_allowSearch) '搜种',
      if (_allowDirectDownload) '直接下载',
      if (_allowVideoDownload) '离线缓存',
    ];
    return list.isEmpty ? '仅浏览播放' : list.join('、');
  }

  String get _libSummary {
    if (_allLibraries) {
      return _libraryIds.isEmpty
          ? '全部共享库'
          : '全部共享库 + ${_libraryIds.length} 个私密库';
    }
    return _libraryIds.isEmpty ? '未分配' : '已授权 ${_libraryIds.length} 个媒体库';
  }

  @override
  Widget build(BuildContext context) {
    final lastDt =
        _lastLoginAt != null ? DateTime.tryParse(_lastLoginAt!) : null;

    return SettingsScaffold(
      title: _displayName,
      actions: [
        SettingsStatusBadge(
          label: _isActive ? '已启用' : '已停用',
          tone: _isActive ? SettingsTone.ok : SettingsTone.danger,
          showDot: true,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 36),
        children: [
          McInsetGroup(
            header: '基本信息',
            children: [
              McInsetRow(
                icon: McIcons.accountCircle,
                title: '登录用户名',
                valueText: '@$_username',
              ),
              McInsetRow(
                icon: McIcons.edit2,
                title: '显示昵称',
                valueText: _nickname.isNotEmpty ? _nickname : '未设置',
                showChevron: true,
                onTap: _busy ? null : _editNickname,
              ),
            ],
          ),
          const SizedBox(height: 16),
          McInsetGroup(
            header: '权限与可见范围',
            children: [
              McInsetRow(
                icon: McIcons.shieldCheck,
                title: '功能权限',
                subtitle: _permSummary,
                showChevron: true,
                onTap: _busy ? null : _editPermissions,
              ),
              McInsetRow(
                icon: McIcons.lock,
                title: '内容年龄分级',
                valueText: _ageLimit != null ? '$_ageLimit 岁以下' : '不限制',
                showChevron: true,
                onTap: _busy ? null : _editContentRating,
              ),
              McInsetRow(
                icon: McIcons.mediaLibraryFill,
                title: '媒体库访问范围',
                valueText: _libSummary,
                showChevron: true,
                onTap: _busy ? null : _editLibraries,
              ),
              if (_allowSearch)
                McInsetRow(
                  icon: McIcons.globe,
                  title: '可搜索 PT 站点',
                  valueText:
                      _allSites ? '全部站点' : '${_siteIds.length} 个站点',
                  showChevron: true,
                  onTap: _busy ? null : _editSites,
                ),
            ],
          ),
          const SizedBox(height: 16),
          McInsetGroup(
            header: '设备与安全',
            children: [
              McInsetRow(
                icon: McIcons.device,
                title: '已登录设备',
                valueText: '$_deviceCount 台',
              ),
              McInsetRow(
                icon: McIcons.clock,
                title: '最近登录',
                valueText:
                    lastDt != null ? McFormatting.relative(lastDt) : '从未登录',
              ),
              McInsetRow(
                icon: McIcons.key,
                title: '重置登录密码',
                subtitle: '由服务器生成新的一次性随机密码',
                onTap: _busy ? null : _resetPassword,
              ),
              if (_deviceCount > 0)
                McInsetRow(
                  icon: McIcons.logout,
                  title: '强制注销该成员全部设备',
                  destructive: true,
                  onTap: _busy ? null : _signOutAll,
                ),
            ],
          ),
          const SizedBox(height: 16),
          McInsetGroup(
            header: '账号状态',
            children: [
              McInsetRow(
                icon: _isActive ? McIcons.userForbid : McIcons.userFollow,
                title: _isActive ? '停用该成员账号' : '重新启用成员账号',
                destructive: _isActive,
                onTap: _busy ? null : _toggleStatus,
              ),
              McInsetRow(
                icon: McIcons.trash2,
                title: '删除成员账号',
                destructive: true,
                onTap: _busy ? null : _deleteMember,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
