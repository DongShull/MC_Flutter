import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../widgets/settings_ui.dart';

// ── IM 推送通道数据模型（对齐 GET /api/v1/channels & /channels/bindings）───

class _ChannelField {
  const _ChannelField({
    required this.key,
    required this.label,
    this.placeholder = '',
    this.help = '',
    this.required = true,
    this.secret = false,
  });

  factory _ChannelField.fromJson(Map<String, dynamic> j) => _ChannelField(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? j['key'] ?? '').toString(),
        placeholder: (j['placeholder'] ?? '').toString(),
        help: (j['help'] ?? '').toString(),
        required: j['required'] != false,
        secret: j['secret'] == true,
      );

  final String key;
  final String label;
  final String placeholder;
  final String help;
  final bool required;
  final bool secret;
}

class _ChannelBindingSpec {
  const _ChannelBindingSpec({
    this.kind = 'form',
    this.pairing = '',
    this.hint = '',
    this.fields = const [],
  });

  factory _ChannelBindingSpec.fromJson(Map<String, dynamic> j) =>
      _ChannelBindingSpec(
        kind: (j['kind'] ?? 'form').toString(),
        pairing: (j['pairing'] ?? '').toString(),
        hint: (j['hint'] ?? '').toString(),
        fields: ((j['fields'] ?? const []) as List<dynamic>)
            .whereType<Map>()
            .map((e) => _ChannelField.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  final String kind; // 'flow' | 'form'
  final String pairing; // 'code' | ''
  final String hint;
  final List<_ChannelField> fields;
}

class _ChannelSpec {
  const _ChannelSpec({
    required this.id,
    required this.title,
    this.description = '',
    this.receive = false,
    this.binding = const _ChannelBindingSpec(),
  });

  factory _ChannelSpec.fromJson(Map<String, dynamic> j) => _ChannelSpec(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? j['id'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        receive: j['receive'] == true,
        binding: j['binding'] is Map
            ? _ChannelBindingSpec.fromJson(
                Map<String, dynamic>.from(j['binding'] as Map),
              )
            : const _ChannelBindingSpec(),
      );

  final String id;
  final String title;
  final String description;
  final bool receive;
  final _ChannelBindingSpec binding;
}

class _ChannelAccount {
  const _ChannelAccount({
    required this.channelId,
    required this.accountId,
    this.displayName = '',
    this.boundUserId,
    this.boundAt,
    this.status = '',
    this.running = false,
    this.channelAvailable = true,
    this.lastError,
  });

  factory _ChannelAccount.fromJson(Map<String, dynamic> j) => _ChannelAccount(
        channelId: (j['channel_id'] ?? j['channelId'] ?? '').toString(),
        accountId: (j['account_id'] ?? j['accountId'] ?? '').toString(),
        displayName: (j['display_name'] ?? j['displayName'] ?? '').toString(),
        boundUserId: (j['bound_user_id'] ?? j['boundUserId'])?.toString(),
        boundAt: (j['bound_at'] ?? j['boundAt'])?.toString(),
        status: (j['status'] ?? '').toString(),
        running: j['running'] == true,
        channelAvailable: j['channel_available'] != false &&
            j['channelAvailable'] != false,
        lastError: (j['last_error'] ?? j['lastError'])?.toString(),
      );

  final String channelId;
  final String accountId;
  final String displayName;
  final String? boundUserId;
  final String? boundAt;
  final String status;
  final bool running;
  final bool channelAvailable;
  final String? lastError;
}

class _BindingSnapshot {
  const _BindingSnapshot({
    required this.bindingId,
    required this.status,
    this.message = '',
    this.qr = '',
    this.qrImage = '',
    this.pairCode = '',
    this.inputLabel,
  });

  factory _BindingSnapshot.fromJson(Map<String, dynamic> j) => _BindingSnapshot(
        bindingId: (j['binding_id'] ?? j['bindingId'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        qr: (j['qr'] ?? '').toString(),
        qrImage: (j['qr_image'] ?? j['qrImage'] ?? '').toString(),
        pairCode: (j['pair_code'] ?? j['pairCode'] ?? '').toString(),
        inputLabel: (j['input_label'] ?? j['inputLabel'])?.toString(),
      );

  final String bindingId;
  final String status;
  final String message;
  final String qr;
  final String qrImage;
  final String pairCode;
  final String? inputLabel;
}

const _doneBindingStatuses = {'confirmed', 'already_bound'};
const _failedBindingStatuses = {'expired', 'failed'};

/// 设置 → IM 推送通道（管理员，1:1 对齐 iOS `PushSettingsView` + `SettingsBPushChannels` + `SettingsBPushBindSheet`）。
class PushChannelsPage extends ConsumerStatefulWidget {
  const PushChannelsPage({super.key});

  @override
  ConsumerState<PushChannelsPage> createState() => _PushChannelsPageState();
}

class _PushChannelsPageState extends ConsumerState<PushChannelsPage> {
  List<_ChannelSpec> _channels = const [];
  List<_ChannelAccount>? _accounts;
  bool _llmMissing = false;
  bool _busy = false;
  bool _testing = false;
  String? _error;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/channels',
        ),
        _mc
            .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/llm/models')
            .catchError((_) => null),
      ]);
      final raw = results[0] as Map<String, dynamic>;
      final models = results[1];
      final channels = ((raw['channels'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => _ChannelSpec.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final accounts = ((raw['accounts'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => _ChannelAccount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final hasModels = models is List
          ? models.isNotEmpty
          : (models is Map &&
              ((models['items'] ?? models['models']) as List?)?.isNotEmpty ==
                  true);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _accounts = accounts;
        _llmMissing = models != null && !hasModels;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.httpStatus == 404
            ? '当前服务器版本较旧，尚未支持插件化 IM 推送通道接口。'
            : e.friendlyMessage;
        _accounts = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = settingsErrorText(e);
        _accounts = const [];
      });
    }
  }

  List<_ChannelSpec> get _addable =>
      _channels.where((c) => !_llmMissing || !c.receive).toList();

  String _channelTitle(String channelId) {
    for (final c in _channels) {
      if (c.id == channelId) return c.title;
    }
    return channelId;
  }

  Future<void> _openAddMenu() async {
    final list = _addable;
    if (list.isEmpty) {
      McToast.info('当前没有可新增的通道');
      return;
    }
    final picked = await showMcSheet<_ChannelSpec>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '选择要接入的 IM 通道',
          margin: EdgeInsets.zero,
          children: [
            for (final c in list)
              McInsetRow(
                icon: McIcons.chat,
                title: '接入 ${c.title}',
                subtitle: c.description.isNotEmpty ? c.description : null,
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final bound = await showMcSheet<bool>(
      context: context,
      maxWidth: 560,
      builder: (_) => _ChannelBindSheet(channel: picked, mc: _mc),
    );
    if (bound == true && mounted) {
      McToast.success(
        picked.receive
            ? '已接入 ${picked.title}（支持对话与推送）'
            : '已接入 ${picked.title} 推送通道',
      );
      await _load();
    }
  }

  Future<void> _unbind(_ChannelAccount row) async {
    final title = _channelTitle(row.channelId);
    final ok = await confirmDialog(
      context,
      title: '解绑 $title？',
      message: '解绑后将停止向该账号推送消息，并断开对话连接。',
      confirmLabel: '解绑',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _mc.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/channels/${Uri.encodeComponent(row.channelId)}/accounts/${Uri.encodeComponent(row.accountId)}',
      );
      McToast.success('已解绑 $title');
      await _load();
    } catch (e) {
      setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testPush() async {
    setState(() => _testing = true);
    try {
      final res = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/channels/im/push-test',
        body: const {'text': ''},
      );
      final sent = (res['sent'] as num?)?.toInt() ?? 0;
      McToast.success('测试消息已发送至 $sent 个 IM 通道');
    } catch (e) {
      McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    return SettingsScaffold(
      title: 'IM 推送通道',
      actions: [
        if (_addable.isNotEmpty)
          McChip(
            icon: McIcons.addS,
            label: '新增通道',
            selected: true,
            compact: true,
            onTap: accounts == null ? null : _openAddMenu,
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 36),
          children: [
            const SettingsInfoCard(
              icon: McIcons.chat,
              text:
                  '接入微信、Telegram、Discord、飞书等通道后，既可接收新片入库提醒，也可直接发送 /reset 重置会话或 /stop 中断回复。',
            ),
            if (_llmMissing) ...[
              const SizedBox(height: 6),
              SettingsNoticeBanner(
                text: '尚未接入大模型：支持对话的 IM 通道需先配置大模型供应商；纯推送通道可直接接入。',
                tone: SettingsTone.info,
                action: McChip(
                  label: '去接入模型',
                  compact: true,
                  onTap: () => context.push('/settings/ai'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            McInsetGroup(
              children: [
                McInsetRow(
                  icon: McIcons.bellOn,
                  title: '选择推送哪些通知事件',
                  subtitle: 'IM 通道与手机 App 共用「通知偏好」中的事件开关',
                  onTap: () => context.push('/settings/notifications'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              SettingsNoticeBanner(text: _error!, tone: SettingsTone.danger),
            ],
            const SizedBox(height: 16),
            if (accounts == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: McLoadingView(),
              )
            else if (accounts.isEmpty)
              McEmptyView(
                icon: McIcons.chat,
                title: '尚未接入任何 IM 账号',
                text: _channels.isEmpty
                    ? '当前没有可用的通道插件，请在「系统 → 扩展插件」中启用 IM 通道插件。'
                    : '支持 ${_channels.map((c) => c.title).join('、')}，点击下方按钮立即接入。',
                actionLabel: _addable.isNotEmpty ? '新增通道' : null,
                onRetry: _addable.isNotEmpty ? _openAddMenu : null,
              )
            else ...[
              McInsetGroup(
                header: '已接入账号 (${accounts.length})',
                children: [
                  for (final row in accounts) _buildAccountRow(row),
                ],
              ),
              const SizedBox(height: 16),
              McInsetGroup(
                header: '连通性验证',
                children: [
                  McInsetRow(
                    icon: McIcons.sendPlane,
                    title: '发送测试推送',
                    subtitle: '向所有已接入的 IM 通道发送一条测试消息',
                    trailing: McChip(
                      label: _testing ? '发送中…' : '发送测试',
                      selected: true,
                      compact: true,
                      onTap: _testing ? null : _testPush,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow(_ChannelAccount row) {
    final (badgeLabel, tone) = !row.channelAvailable
        ? ('插件未启用', SettingsTone.neutral)
        : row.status == 'stale'
            ? ('连接已失效', SettingsTone.danger)
            : row.running
                ? ('运行中', SettingsTone.ok)
                : ('已停止', SettingsTone.neutral);

    final boundAtDt =
        row.boundAt != null ? DateTime.tryParse(row.boundAt!) : null;
    final boundAtText =
        boundAtDt != null ? McFormatting.relative(boundAtDt) : '';
    final userLabel =
        (row.boundUserId != null && row.boundUserId!.isNotEmpty)
            ? row.boundUserId!
            : row.displayName;
    final detail = !row.channelAvailable
        ? '提供此通道的插件已关闭或卸载，重新启用插件即可恢复。'
        : row.status == 'stale'
            ? (row.lastError?.isNotEmpty == true
                ? row.lastError!
                : '登录凭证已过期，请解绑后重新接入。')
            : [
                if (userLabel.isNotEmpty) userLabel,
                if (boundAtText.isNotEmpty) '绑定于 $boundAtText',
              ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(McIcons.chat, size: 19, color: McTokens.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _channelTitle(row.channelId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.ui.semibold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SettingsStatusBadge(
                      label: badgeLabel,
                      tone: tone,
                      showDot: true,
                    ),
                  ],
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.faint,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          McChip(
            label: '解绑',
            compact: true,
            onTap: _busy ? null : () => _unbind(row),
          ),
        ],
      ),
    );
  }
}

// ── 通用通道绑定弹层（支持 flow 二维码 + need_input 与 form 动态表单 + 6 位配对码）──

class _ChannelBindSheet extends StatefulWidget {
  const _ChannelBindSheet({required this.channel, required this.mc});

  final _ChannelSpec channel;
  final McClient mc;

  @override
  State<_ChannelBindSheet> createState() => _ChannelBindSheetState();
}

class _ChannelBindSheetState extends State<_ChannelBindSheet> {
  final Map<String, TextEditingController> _fieldCtrls = {};
  final Map<String, bool> _obscured = {};
  final TextEditingController _flowInputCtrl = TextEditingController();

  _BindingSnapshot? _snap;
  bool _busy = false;
  String? _error;
  Timer? _pollTimer;

  bool get _isFlow => widget.channel.binding.kind == 'flow';
  bool get _isPairingCode => widget.channel.binding.pairing == 'code';

  @override
  void initState() {
    super.initState();
    for (final f in widget.channel.binding.fields) {
      _fieldCtrls[f.key] = TextEditingController();
      _obscured[f.key] = f.secret;
    }
    if (_isFlow) {
      Future.microtask(_startFlow);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _flowInputCtrl.dispose();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncPolling() {
    final s = _snap;
    final shouldPoll = s != null &&
        !_doneBindingStatuses.contains(s.status) &&
        !_failedBindingStatuses.contains(s.status);
    if (shouldPoll && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_poll());
      });
    } else if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _startFlow() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/channels/bindings',
        body: {
          'channel_id': widget.channel.id,
          'fields': const <String, String>{},
        },
      );
      final snap = _BindingSnapshot.fromJson(raw);
      if (!mounted) return;
      if (_doneBindingStatuses.contains(snap.status)) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _snap = snap);
      _syncPolling();
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitForm() async {
    final fields = <String, String>{};
    for (final f in widget.channel.binding.fields) {
      final v = _fieldCtrls[f.key]?.text.trim() ?? '';
      if (f.required && v.isEmpty) {
        setState(() => _error = '请填写「${f.label}」');
        return;
      }
      fields[f.key] = v;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/channels/bindings',
        body: {
          'channel_id': widget.channel.id,
          'fields': fields,
        },
      );
      final snap = _BindingSnapshot.fromJson(raw);
      if (!mounted) return;
      if (_doneBindingStatuses.contains(snap.status)) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _snap = snap);
      _syncPolling();
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll() async {
    final current = _snap;
    if (current == null || current.bindingId.isEmpty) return;
    try {
      final raw = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/channels/bindings/${Uri.encodeComponent(current.bindingId)}',
      );
      final next = _BindingSnapshot.fromJson(raw);
      if (!mounted) return;
      if (_doneBindingStatuses.contains(next.status)) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _snap = next);
      _syncPolling();
    } catch (_) {
      // 轮询瞬时错误静默等待下一轮
    }
  }

  Future<void> _submitFlowInput() async {
    final current = _snap;
    final val = _flowInputCtrl.text.trim();
    if (current == null || val.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await widget.mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/channels/bindings/${Uri.encodeComponent(current.bindingId)}/input',
        body: {'value': val},
      );
      final next = _BindingSnapshot.fromJson(raw);
      _flowInputCtrl.clear();
      if (!mounted) return;
      if (_doneBindingStatuses.contains(next.status)) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _snap = next);
      _syncPolling();
    } catch (e) {
      if (mounted) setState(() => _error = settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.channel.binding.hint.isNotEmpty
        ? widget.channel.binding.hint
        : widget.channel.description;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('接入 ${widget.channel.title}', style: McText.titleSm),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(hint, style: McText.caption.muted),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            SettingsNoticeBanner(
              text: _error!,
              tone: SettingsTone.danger,
              margin: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 14),
          if (_isFlow) _buildFlowBody() else _buildFormBody(),
        ],
      ),
    );
  }

  Widget _buildFlowBody() {
    final s = _snap;
    if (s == null) {
      if (_busy) {
        return const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Column(
        children: [
          Text('发起绑定失败', style: McText.ui.semibold),
          const SizedBox(height: 12),
          McActionPill(
            label: '重试',
            primary: true,
            expanded: true,
            onTap: _startFlow,
          ),
        ],
      );
    }

    final failed = _failedBindingStatuses.contains(s.status);
    final statusTitle = failed
        ? '绑定未完成'
        : s.status == 'pending'
            ? '等待扫码确认'
            : s.status == 'need_input'
                ? '还差一步：输入验证码'
                : '已扫码，正在确认…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!failed && (s.qrImage.isNotEmpty || s.qr.isNotEmpty)) ...[
          Center(child: _QrCodeDisplay(qrImage: s.qrImage, qrText: s.qr)),
          const SizedBox(height: 14),
        ],
        Center(child: Text(statusTitle, style: McText.ui.semibold)),
        if (s.message.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              s.message,
              textAlign: TextAlign.center,
              style: McText.caption.muted,
            ),
          ),
        ],
        if (s.status == 'need_input') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _flowInputCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: s.inputLabel ?? '输入手机上显示的配对数字',
                  ),
                  onSubmitted: (_) => _submitFlowInput(),
                ),
              ),
              const SizedBox(width: 10),
              McActionPill(
                label: '确认',
                primary: true,
                onTap: _busy ? null : _submitFlowInput,
              ),
            ],
          ),
        ],
        if (failed) ...[
          const SizedBox(height: 16),
          McActionPill(
            label: '重新发起绑定',
            primary: true,
            expanded: true,
            onTap: _busy ? null : _startFlow,
          ),
        ],
      ],
    );
  }

  Widget _buildFormBody() {
    final s = _snap;
    if (s != null) {
      if (s.status == 'pending') {
        return Column(
          children: [
            if (s.message.isNotEmpty)
              Text(s.message, textAlign: TextAlign.center, style: McText.ui),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: s.pairCode));
                McToast.success('已复制配对码');
              },
              child: SelectableText(
                s.pairCode,
                style: McText.display.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 8,
                  color: McTokens.accentStrong,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '请向机器人私聊发送以上 6 位配对码，发送后本页会自动完成绑定。',
              textAlign: TextAlign.center,
              style: McText.caption.muted,
            ),
            const SizedBox(height: 14),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Text('配对未完成', style: McText.ui.semibold)),
          if (s.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Center(child: Text(s.message, style: McText.caption.muted)),
          ],
          const SizedBox(height: 14),
          McActionPill(
            label: '返回修改配置',
            primary: true,
            expanded: true,
            onTap: () => setState(() => _snap = null),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in widget.channel.binding.fields) ...[
          TextField(
            controller: _fieldCtrls[f.key],
            obscureText: _obscured[f.key] ?? false,
            decoration: InputDecoration(
              labelText: f.required ? '${f.label} *' : '${f.label}（可选）',
              hintText: f.placeholder,
              helperText: f.help.isNotEmpty ? f.help : null,
              helperMaxLines: 2,
              suffixIcon: f.secret
                  ? IconButton(
                      icon: Icon(
                        (_obscured[f.key] ?? true)
                            ? McIcons.eyeOff
                            : McIcons.eyeOpen,
                        size: 18,
                      ),
                      onPressed: () => setState(
                        () => _obscured[f.key] = !(_obscured[f.key] ?? true),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 6),
        McActionPill(
          label: _busy
              ? '提交中…'
              : (_isPairingCode ? '获取 6 位配对码' : '完成接入'),
          primary: true,
          expanded: true,
          onTap: _busy ? null : _submitForm,
        ),
      ],
    );
  }
}

/// 渲染后端下发的 QR（支持 PNG data URI、SVG data URI `<rect>` 矩阵解析与纯文本兜底）。
class _QrCodeDisplay extends StatelessWidget {
  const _QrCodeDisplay({required this.qrImage, required this.qrText});

  final String qrImage;
  final String qrText;

  @override
  Widget build(BuildContext context) {
    final raster = _decodeRasterDataUri(qrImage);
    if (raster != null) {
      return Container(
        width: 204,
        height: 204,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Image.memory(raster, filterQuality: FilterQuality.none),
      );
    }

    final svgRects = _parseSvgRects(qrImage);
    if (svgRects != null) {
      return Container(
        width: 204,
        height: 204,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomPaint(painter: _SvgQrPainter(svgRects)),
      );
    }

    return Column(
      children: [
        SettingsCopyBox(value: qrText, copyLabel: '复制扫码链接'),
        const SizedBox(height: 8),
        Text(
          '若需用微信扫码，可复制链接生成二维码或在浏览器打开。',
          style: McText.caption.faint,
        ),
      ],
    );
  }

  static Uint8List? _decodeRasterDataUri(String uri) {
    final lower = uri.toLowerCase();
    if (!lower.startsWith('data:image/png;base64,') &&
        !lower.startsWith('data:image/jpeg;base64,') &&
        !lower.startsWith('data:image/webp;base64,')) {
      return null;
    }
    final comma = uri.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(uri.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  static _SvgQrData? _parseSvgRects(String uri) {
    if (!uri.toLowerCase().startsWith('data:image/svg+xml')) return null;
    final comma = uri.indexOf(',');
    if (comma < 0) return null;
    final payload = uri.substring(comma + 1);
    String svg;
    try {
      if (uri.substring(0, comma).toLowerCase().contains(';base64')) {
        svg = utf8.decode(base64Decode(payload));
      } else {
        svg = Uri.decodeComponent(payload);
      }
    } catch (_) {
      return null;
    }
    final vbMatch = RegExp(
      r'viewBox="[\d.\s-]*?\s+[\d.\s-]*?\s+([\d.]+)\s+([\d.]+)"',
    ).firstMatch(svg);
    final w = double.tryParse(vbMatch?.group(1) ?? '') ?? 0;
    final h = double.tryParse(vbMatch?.group(2) ?? '') ?? 0;
    if (w <= 0 || h <= 0) return null;

    final rects = <Rect>[];
    final rectRe = RegExp(
      r'<rect[^>]*x="([\d.]+)"[^>]*y="([\d.]+)"[^>]*width="([\d.]+)"[^>]*height="([\d.]+)"[^>]*>',
    );
    for (final m in rectRe.allMatches(svg)) {
      final tag = m.group(0) ?? '';
      if (tag.contains('#fff') || tag.contains('white')) continue;
      final x = double.tryParse(m.group(1) ?? '');
      final y = double.tryParse(m.group(2) ?? '');
      final rw = double.tryParse(m.group(3) ?? '');
      final rh = double.tryParse(m.group(4) ?? '');
      if (x != null && y != null && rw != null && rh != null) {
        if (rw >= w * 0.9 && rh >= h * 0.9) continue;
        rects.add(Rect.fromLTWH(x, y, rw, rh));
      }
    }
    if (rects.isEmpty) return null;
    return _SvgQrData(width: w, height: h, rects: rects);
  }
}

class _SvgQrData {
  const _SvgQrData({
    required this.width,
    required this.height,
    required this.rects,
  });

  final double width;
  final double height;
  final List<Rect> rects;
}

class _SvgQrPainter extends CustomPainter {
  const _SvgQrPainter(this.data);

  final _SvgQrData data;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / data.width;
    final sy = size.height / data.height;
    final paint = Paint()..color = Colors.black;
    for (final r in data.rects) {
      canvas.drawRect(
        Rect.fromLTWH(
          r.left * sx,
          r.top * sy,
          r.width * sx + 0.3,
          r.height * sy + 0.3,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SvgQrPainter oldDelegate) =>
      oldDelegate.data != data;
}
