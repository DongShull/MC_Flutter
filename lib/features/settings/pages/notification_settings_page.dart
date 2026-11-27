import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../../core/push/push_center.dart';
import '../widgets/settings_ui.dart';
import 'cloud_settings_page.dart';

// ── 通知偏好数据模型（对齐 GET /api/v1/push/me）─────────────────────────────

class _PushEventItem {
  const _PushEventItem({
    required this.key,
    required this.group,
    required this.title,
    this.description = '',
    this.enabled = false,
  });

  factory _PushEventItem.fromJson(Map<String, dynamic> j) => _PushEventItem(
        key: (j['key'] ?? '').toString(),
        group: (j['group'] ?? '其他通知').toString(),
        title: (j['title'] ?? j['key'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        enabled: j['enabled'] == true,
      );

  final String key;
  final String group;
  final String title;
  final String description;
  final bool enabled;

  _PushEventItem copyWith({bool? enabled}) => _PushEventItem(
        key: key,
        group: group,
        title: title,
        description: description,
        enabled: enabled ?? this.enabled,
      );
}

class _PushLibraryItem {
  const _PushLibraryItem({required this.id, required this.name});

  factory _PushLibraryItem.fromJson(Map<String, dynamic> j) => _PushLibraryItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
      );

  final int id;
  final String name;
}

class _PushAttentionItem {
  const _PushAttentionItem({
    required this.deviceName,
    required this.statusText,
  });

  factory _PushAttentionItem.fromJson(Map<String, dynamic> j) =>
      _PushAttentionItem(
        deviceName: (j['device_name'] ?? j['deviceName'] ?? '').toString(),
        statusText: (j['status_text'] ?? j['statusText'] ?? '').toString(),
      );

  final String deviceName;
  final String statusText;
}

class _PushMutedItem {
  const _PushMutedItem({required this.id, required this.title, this.year});

  factory _PushMutedItem.fromJson(Map<String, dynamic> j) => _PushMutedItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        year: (j['year'] as num?)?.toInt(),
      );

  final int id;
  final String title;
  final int? year;
}

class _MyPushData {
  const _MyPushData({
    this.isAdmin = false,
    this.instanceReady = false,
    this.readyDevices = 0,
    this.imAccounts = 0,
    this.events = const [],
    this.libraries = const [],
    this.libraryIds,
    this.attention = const [],
    this.mutedItems = const [],
  });

  factory _MyPushData.fromJson(Map<String, dynamic> j) {
    final rawLibIds = j.containsKey('library_ids')
        ? j['library_ids']
        : j['libraryIds'];
    final libIds = rawLibIds is List
        ? rawLibIds.whereType<num>().map((e) => e.toInt()).toList()
        : null;
    final mutedRaw = j['muted_items'] ?? j['mutedItems'] ?? const <dynamic>[];
    return _MyPushData(
      isAdmin: j['is_admin'] == true || j['isAdmin'] == true,
      instanceReady:
          j['instance_ready'] == true || j['instanceReady'] == true,
      readyDevices:
          ((j['ready_devices'] ?? j['readyDevices']) as num?)?.toInt() ?? 0,
      imAccounts:
          ((j['im_accounts'] ?? j['imAccounts']) as num?)?.toInt() ?? 0,
      events: ((j['events'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => _PushEventItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      libraries: ((j['libraries'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => _PushLibraryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      libraryIds: libIds,
      attention: ((j['attention'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map(
            (e) => _PushAttentionItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      mutedItems: (mutedRaw as List<dynamic>)
          .whereType<Map>()
          .map((e) => _PushMutedItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  final bool isAdmin;
  final bool instanceReady;
  final int readyDevices;
  final int imAccounts;
  final List<_PushEventItem> events;
  final List<_PushLibraryItem> libraries;
  final List<int>? libraryIds; // null = 全部媒体库
  final List<_PushAttentionItem> attention;
  final List<_PushMutedItem> mutedItems;

  _MyPushData copyWith({
    List<_PushEventItem>? events,
    List<int>? libraryIds,
    bool clearLibraryIds = false,
    List<_PushMutedItem>? mutedItems,
  }) =>
      _MyPushData(
        isAdmin: isAdmin,
        instanceReady: instanceReady,
        readyDevices: readyDevices,
        imAccounts: imAccounts,
        events: events ?? this.events,
        libraries: libraries,
        libraryIds: clearLibraryIds ? null : (libraryIds ?? this.libraryIds),
        attention: attention,
        mutedItems: mutedItems ?? this.mutedItems,
      );
}

/// 设置 → 通知偏好（所有人可用，1:1 对齐 iOS `NotificationSettingsView.swift`）。
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  static const _libraryEventKey = 'library.items.arrived';

  late final CloudConnectionController _cloudCtrl;
  _MyPushData? _data;
  bool _loading = true;
  String? _error;
  bool _sendingTest = false;
  bool _cloudWasConnected = false;

  // 串行写队列（防止快速连点乱序覆盖）
  Future<void> _writeChain = Future<void>.value();
  int _writeSeq = 0;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    _cloudCtrl = CloudConnectionController(_mc);
    _cloudCtrl.addListener(_onCloudChanged);
    PushCenter.instance.addListener(_onPushChanged);
    Future.microtask(() async {
      await PushCenter.instance.refreshPushInfo();
      unawaited(PushCenter.instance.sync());
      await _load();
    });
  }

  @override
  void dispose() {
    _cloudCtrl.removeListener(_onCloudChanged);
    _cloudCtrl.dispose();
    PushCenter.instance.removeListener(_onPushChanged);
    super.dispose();
  }

  void _onPushChanged() {
    if (mounted) {
      setState(() {});
      unawaited(_load(silent: true));
    }
  }

  void _onCloudChanged() {
    if (!mounted) return;
    final nowConnected = _cloudCtrl.isConnected;
    if (!_cloudWasConnected && nowConnected) {
      McToast.success('手机推送通道已开启');
      unawaited(_reloadUntilReady());
    }
    _cloudWasConnected = nowConnected;
    setState(() {});
  }

  Future<void> _reloadUntilReady() async {
    for (final sec in const [0, 3, 6]) {
      if (sec > 0) await Future<void>.delayed(Duration(seconds: sec));
      if (!mounted) return;
      await _load(silent: true);
      if (_data?.instanceReady == true) return;
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _data == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/push/me',
      );
      final parsed = _MyPushData.fromJson(raw);
      if (!mounted) return;
      setState(() {
        _data = parsed;
        _loading = false;
        _error = null;
      });
      if (parsed.isAdmin && !parsed.instanceReady && _cloudCtrl.status == null) {
        unawaited(_cloudCtrl.load());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_data == null) _error = settingsErrorText(e);
      });
    }
  }

  Future<void> _enqueueWrite(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    final mine = ++_writeSeq;
    final prev = _writeChain;
    final completer = Completer<void>();
    _writeChain = completer.future;
    await prev;
    try {
      final raw = await action();
      if (mounted && mine == _writeSeq) {
        setState(() => _data = _MyPushData.fromJson(raw));
      }
    } catch (e) {
      if (mounted) {
        McToast.error(settingsErrorText(e));
        if (mine == _writeSeq) {
          await _load(silent: true);
        }
      }
    } finally {
      completer.complete();
    }
  }

  void _toggleEvent(String key, bool enabled) {
    final cur = _data;
    if (cur == null) return;
    final nextEvents = [
      for (final e in cur.events)
        e.key == key ? e.copyWith(enabled: enabled) : e,
    ];
    setState(() => _data = cur.copyWith(events: nextEvents));
    unawaited(
      _enqueueWrite(
        () => _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'PUT',
          '/api/v1/push/me/preferences',
          body: {
            'events': {key: enabled},
          },
        ),
      ),
    );
  }

  /// 勾/取消勾媒体库：全选回传显式 `library_ids: null`；全不选则关闭 `library.items.arrived` 并复位 `null`。
  void _toggleLibrary(int id) {
    final cur = _data;
    if (cur == null) return;
    final allIds = cur.libraries.map((e) => e.id).toList();
    final chosen = List<int>.from(cur.libraryIds ?? allIds);
    if (chosen.contains(id)) {
      chosen.remove(id);
    } else {
      chosen.add(id);
    }

    if (chosen.isEmpty) {
      final nextEvents = [
        for (final e in cur.events)
          e.key == _libraryEventKey ? e.copyWith(enabled: false) : e,
      ];
      setState(
        () => _data = cur.copyWith(events: nextEvents, clearLibraryIds: true),
      );
      unawaited(
        _enqueueWrite(
          () => _mc.unwrap<Map<String, dynamic>>(
            Channel.general,
            'PUT',
            '/api/v1/push/me/preferences',
            body: <String, dynamic>{
              'library_ids': null,
              'events': {_libraryEventKey: false},
            },
          ),
        ),
      );
      return;
    }

    final isAll = chosen.toSet().length == allIds.toSet().length &&
        allIds.every(chosen.contains);
    final nextIds = isAll
        ? null
        : allIds.where(chosen.contains).toList();
    setState(
      () => _data = cur.copyWith(
        libraryIds: nextIds,
        clearLibraryIds: nextIds == null,
      ),
    );
    unawaited(
      _enqueueWrite(
        () => _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'PUT',
          '/api/v1/push/me/preferences',
          body: <String, dynamic>{'library_ids': nextIds},
        ),
      ),
    );
  }

  void _unmute(int itemId) {
    final cur = _data;
    if (cur == null) return;
    final nextMuted = cur.mutedItems.where((e) => e.id != itemId).toList();
    setState(() => _data = cur.copyWith(mutedItems: nextMuted));
    unawaited(
      _enqueueWrite(() async {
        try {
          return await _mc.unwrap<Map<String, dynamic>>(
            Channel.general,
            'DELETE',
            '/api/v1/push/me/muted-items/$itemId',
          );
        } on ApiException catch (e) {
          if (e.httpStatus == 404) {
            return _mc.unwrap<Map<String, dynamic>>(
              Channel.general,
              'DELETE',
              '/api/v1/push/me/muted/$itemId',
            );
          }
          rethrow;
        }
      }),
    );
  }

  Future<void> _sendTest() async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    try {
      final res = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/push/me/test',
      );
      final sent = (res['sent'] as num?)?.toInt() ?? 0;
      final results = (res['results'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      if (sent > 0) {
        final hasIm = results.any(
          (r) =>
              (r['device_id'] ?? r['deviceId']) == 'im' && r['result'] == 'ok',
        );
        final devices = sent - (hasIm ? 1 : 0);
        final targets = <String>[
          if (devices > 0) '$devices 台设备',
          if (hasIm) 'IM 通道',
        ];
        McToast.success('测试通知已发送至 ${targets.join(' 和 ')}');
      } else {
        final msg = results
            .map((r) => (r['message'] ?? '').toString())
            .firstWhere((m) => m.isNotEmpty, orElse: () => '当前没有可接收通知的设备');
        McToast.info(msg);
      }
    } catch (e) {
      McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  List<({String title, List<_PushEventItem> events})> _groupedEvents(
    List<_PushEventItem> events,
  ) {
    final order = <String>[];
    final map = <String, List<_PushEventItem>>{};
    for (final e in events) {
      if (!map.containsKey(e.group)) order.add(e.group);
      map.putIfAbsent(e.group, () => []).add(e);
    }
    return [for (final g in order) (title: g, events: map[g]!)];
  }

  String _testTargetHint(_MyPushData d) {
    final parts = <String>[
      if (d.readyDevices > 0) '${d.readyDevices} 台设备',
      if (d.imAccounts > 0) '${d.imAccounts} 个 IM 账号',
    ];
    if (parts.isEmpty) return '当前没有可送达的设备或 IM 账号';
    return '将发送给你的 ${parts.join(' 和 ')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = McL10n.of(context);
    final push = PushCenter.instance;
    final perm = push.permission;
    final data = _data;

    return SettingsScaffold(
      title: '通知偏好',
      actions: [
        McChip(label: '刷新', compact: true, onTap: _load),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 36),
          children: [
            // 1. 本机系统通知权限
            McInsetGroup(
              header: '本机通知权限',
              footer: push.unsupportedBuild
                  ? '当前为侧载/未签名推送构建，系统推送令牌可能不可用。'
                  : (perm == PushPermission.denied
                      ? '本机已关闭 MovieClaw 通知权限，请在系统设置中重新开启。'
                      : null),
              children: [
                McInsetRow(
                  icon: perm == PushPermission.denied
                      ? McIcons.bellOff
                      : McIcons.bellOn,
                  iconColor: perm == PushPermission.denied
                      ? McTokens.warning
                      : McTokens.accentStrong,
                  title: '系统通知权限',
                  valueText: perm.label(l10n),
                ),
                if (perm == PushPermission.notDetermined)
                  McInsetRow(
                    icon: McIcons.checkCircleFill,
                    title: '允许本机接收推送通知',
                    onTap: () async {
                      await push.requestAuthorization();
                      await _load(silent: true);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading && data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: McLoadingView(),
              )
            else if (_error != null && data == null)
              McErrorView(text: _error!, onRetry: _load)
            else if (data != null) ...[
              // 2. 服务器推送通道就绪状态
              ..._buildReadiness(data),

              // 3. 不可达设备提示
              if (data.instanceReady && data.attention.isNotEmpty) ...[
                SettingsNoticeBanner(
                  text:
                      '${data.attention.length == 1 ? '有 1 台设备收不到通知：' : '有 ${data.attention.length} 台设备收不到通知：'}\n'
                      '${data.attention.map((a) => '${a.deviceName}：${a.statusText}').join('\n')}',
                  tone: SettingsTone.warn,
                ),
                const SizedBox(height: 6),
                McInsetGroup(
                  children: [
                    McInsetRow(
                      icon: McIcons.device,
                      title: '前往「我的设备」排查',
                      onTap: () => context.push('/settings/devices'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 4. 分组事件开关 + 媒体库多选
              for (final (idx, group)
                  in _groupedEvents(data.events).indexed) ...[
                McInsetGroup(
                  header: group.title,
                  footer: _eventGroupFooter(
                    data,
                    group.events,
                    isLast: idx == _groupedEvents(data.events).length - 1,
                  ),
                  dividerIndent: 16,
                  children: [
                    for (final ev in group.events) ...[
                      McInsetRow(
                        title: ev.title,
                        subtitle:
                            ev.description.isNotEmpty ? ev.description : null,
                        trailing: Switch(
                          value: ev.enabled,
                          onChanged: (v) => _toggleEvent(ev.key, v),
                        ),
                        onTap: () => _toggleEvent(ev.key, !ev.enabled),
                      ),
                      if (ev.key == _libraryEventKey &&
                          ev.enabled &&
                          data.libraries.length > 1)
                        for (final lib in data.libraries)
                          _buildLibraryCheckbox(data, lib),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 5. 不再提醒的剧（静音列表）
              if (data.mutedItems.isNotEmpty) ...[
                McInsetGroup(
                  header: '不再提醒的剧 (${data.mutedItems.length})',
                  footer: '静音只关闭推送提醒，不影响正常追更与自动下载。',
                  children: [
                    for (final item in data.mutedItems)
                      McInsetRow(
                        title: item.year != null
                            ? '${item.title}（${item.year}）'
                            : item.title,
                        trailing: McChip(
                          label: '恢复',
                          compact: true,
                          onTap: () => _unmute(item.id),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 6. 发送测试通知
              McInsetGroup(
                header: '送达测试',
                footer: (data.readyDevices == 0 && data.imAccounts == 0)
                    ? (data.instanceReady
                        ? '请确认本机已允许通知权限，或前往「我的设备」查看推送登记状态。'
                        : '请先在服务器开启手机推送通道或接入 IM 推送。')
                    : null,
                children: [
                  McInsetRow(
                    icon: McIcons.sendPlane,
                    title: '发送测试通知',
                    subtitle: _testTargetHint(data),
                    trailing: McChip(
                      label: _sendingTest ? '发送中…' : '发送',
                      selected: data.readyDevices > 0 || data.imAccounts > 0,
                      compact: true,
                      onTap: (_sendingTest ||
                              (data.readyDevices == 0 && data.imAccounts == 0))
                          ? null
                          : _sendTest,
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

  List<Widget> _buildReadiness(_MyPushData data) {
    if (data.instanceReady) {
      if (data.isAdmin && _cloudCtrl.isConnected) {
        final conn = _cloudCtrl.status?.connection;
        return [
          McInsetGroup(
            children: [
              McInsetRow(
                icon: McIcons.checkCircleFill,
                iconColor: McTokens.ok,
                title: '手机推送已开启',
                subtitle: conn != null
                    ? '已连接 ${conn.instanceName} · ${conn.accountDisplay}'
                    : null,
                trailing: const SettingsStatusBadge(
                  label: '正常',
                  tone: SettingsTone.ok,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ];
      }
      return const [];
    }

    if (!data.isAdmin) {
      return const [
        SettingsNoticeBanner(
          text: '管理员还没有为这台服务器开启手机推送通道。你可以先调整下方通知开关，开启后将立即生效。',
          tone: SettingsTone.info,
        ),
        SizedBox(height: 14),
      ];
    }

    final cloud = _cloudCtrl.status;
    if (cloud != null && cloud.isConnected) {
      return [
        SettingsNoticeBanner(
          text: cloud.healthMessage ?? '已连接 MovieClaw Cloud，但当前没有可用的官方推送通道。',
          tone: SettingsTone.warn,
        ),
        const SizedBox(height: 6),
        McInsetGroup(
          children: [
            McInsetRow(
              icon: McIcons.cloud,
              title: '前往 MovieClaw Cloud 查看详情',
              onTap: () => context.push('/settings/cloud'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ];
    }

    // 管理员未连接云端：页内一步配对
    final hasPairing =
        cloud?.pendingPairing != null || cloud?.endedPairing != null;
    if (hasPairing) {
      return [
        CloudPairingPanel(controller: _cloudCtrl),
        const SizedBox(height: 16),
      ];
    }

    return [
      McInsetGroup(
        header: '开启手机通知',
        footer: '连接管理员的 MovieClaw 账号即可启用官方加密推送通道。',
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('连接 MovieClaw Cloud 以启用推送', style: McText.titleSm),
                const SizedBox(height: 6),
                Text(
                  '为「${cloud?.serverName.isNotEmpty == true ? cloud!.serverName : '当前服务器'}」开通官方推送，所有家庭成员的 App 均可收到即时提醒。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 14),
                McActionPill(
                  icon: McIcons.bellOn,
                  label: _cloudCtrl.busy ? '正在获取配对码…' : '开启手机通知',
                  primary: true,
                  expanded: true,
                  onTap: _cloudCtrl.busy
                      ? null
                      : () async {
                          try {
                            final next = await _cloudCtrl.startPairing();
                            final uri = next.pendingPairing
                                    ?.verificationUriComplete ??
                                '';
                            if (mounted && uri.isNotEmpty) {
                              await openExternalUrl(context, uri);
                            }
                          } catch (e) {
                            McToast.error(settingsErrorText(e));
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildLibraryCheckbox(_MyPushData data, _PushLibraryItem lib) {
    final selected =
        data.libraryIds == null || data.libraryIds!.contains(lib.id);
    return InkWell(
      onTap: () => _toggleLibrary(lib.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 11, 16, 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lib.name,
                style: McText.sub.copyWith(color: McTokens.text),
              ),
            ),
            Icon(
              selected ? McIcons.checkCircleFill : McIcons.radioButtonLine,
              size: 19,
              color: selected ? McTokens.accentStrong : McTokens.textFaint,
            ),
          ],
        ),
      ),
    );
  }

  String? _eventGroupFooter(
    _MyPushData data,
    List<_PushEventItem> events, {
    required bool isLast,
  }) {
    final parts = <String>[];
    final hasLib = events.any((e) => e.key == _libraryEventKey && e.enabled);
    if (hasLib && data.libraries.length > 1) {
      parts.add(
        data.libraryIds == null
            ? '当前覆盖全部媒体库（包含未来新建的媒体库）。'
            : '仅在上方勾选的媒体库入库新片时发送提醒；全部取消勾选将关闭该提醒。',
      );
    }
    if (isLast && !data.instanceReady) {
      parts.add('你的通知偏好已保存在服务器，推送通道就绪后立即生效。');
    }
    return parts.isEmpty ? null : parts.join('\n');
  }
}
