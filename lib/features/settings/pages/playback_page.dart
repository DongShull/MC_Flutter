import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../../../core/models/format.dart';
import '../../../core/session/permissions.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/settings_ui.dart';

/// 播放设置与远程转码节点页（1:1 对齐 iOS `PlaybackSettingsView.swift` + commit `43eacf65`）：
/// - 软解策略、已看判定阈值 (`played_threshold_percent` & `played_use_outro`)、云盘串流模式 (`cloud_stream_mode`)、
///   Trickplay、转码缓存、片段预切 (`reel_clips_enabled` + 15s 进度轮询 + 关闭前清理确认)；
/// - 远程转码节点 (`GET/PUT /api/v1/transcode-worker/config` + 5s 轮询 `/transcode-worker/status` + 离线授权设备 + 3 步接入指南)。
class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key});

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  Timer? _clipTimer;
  Timer? _workerTimer;

  // 远程转码器状态（仅管理员加载）
  Map<String, dynamic>? _workerConfig;
  String? _workerConfigErr;
  Map<String, dynamic>? _workerStatus;
  String? _workerStatusErr;
  List<LoginDevice> _authorizedWorkers = const [];
  bool _policyBusy = false;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(playbackProvider.notifier).load();
      await _loadRemoteConfig();
      await _pollRemoteStatus();
    });
    _clipTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final p = ref.read(playbackProvider).valueOrNull;
      if (mounted &&
          !_policyBusy &&
          p != null &&
          p.reelClipsEnabled &&
          p.reelClipsProgress?.state != 'done') {
        ref.read(playbackProvider.notifier).load(silent: true);
      }
    });
    _workerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _isAdmin()) {
        unawaited(_pollRemoteStatus());
      }
    });
  }

  @override
  void dispose() {
    _clipTimer?.cancel();
    _workerTimer?.cancel();
    super.dispose();
  }

  bool _isAdmin() {
    final perms = ref.read(permissionsProvider);
    final profile = ref.read(profileProvider).valueOrNull;
    return perms.isAdmin || (profile?.isAdmin ?? false);
  }

  Future<void> _loadRemoteConfig() async {
    if (!_isAdmin()) return;
    try {
      final cfg = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/transcode-worker/config',
      );
      if (mounted) {
        setState(() {
          _workerConfig = cfg;
          _workerConfigErr = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _workerConfigErr = settingsErrorText(e));
    }
  }

  Future<void> _pollRemoteStatus() async {
    if (!_isAdmin()) return;
    try {
      final results = await Future.wait<dynamic>([
        _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/transcode-worker/status',
        ),
        _mc
            .unwrap<dynamic>(
              Channel.general,
              'GET',
              '/api/v1/auth/devices',
              query: const {'all': true},
            )
            .catchError((_) => const <dynamic>[]),
      ]);
      final st = results[0] as Map<String, dynamic>;
      final devRaw = results[1];
      final devList = devRaw is List
          ? devRaw
          : (devRaw is Map
              ? (devRaw['items'] ?? const []) as List<dynamic>
              : const <dynamic>[]);
      final authorized = devList
          .whereType<Map>()
          .map((e) => LoginDevice.fromJson(Map<String, dynamic>.from(e)))
          .where((d) => d.scope == 'transcode')
          .toList();
      if (mounted) {
        setState(() {
          _workerStatus = st;
          _authorizedWorkers = authorized;
          _workerStatusErr = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _workerStatusErr = settingsErrorText(e));
    }
  }

  Future<void> _updatePolicy({
    bool? softwareTranscodeEnabled,
    double? playedThresholdPercent,
    bool? playedUseOutro,
    bool? trickplayEnabled,
    bool? transcodeCacheEnabled,
    bool? reelClipsEnabled,
    String? cloudStreamMode,
    bool purgeClips = false,
  }) async {
    setState(() => _policyBusy = true);
    try {
      final err = await ref.read(playbackProvider.notifier).updatePolicy(
            softwareTranscodeEnabled: softwareTranscodeEnabled,
            playedThresholdPercent: playedThresholdPercent,
            playedUseOutro: playedUseOutro,
            trickplayEnabled: trickplayEnabled,
            transcodeCacheEnabled: transcodeCacheEnabled,
            reelClipsEnabled: reelClipsEnabled,
            cloudStreamMode: cloudStreamMode,
          );
      if (err != null) {
        McToast.error(err);
        return;
      }
      if (purgeClips) {
        await _mc.unwrap<dynamic>(
          Channel.general,
          'DELETE',
          '/api/v1/reels/clips',
        );
        McToast.success('已关闭片段预切并清理已有缓存');
      }
    } catch (e) {
      McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _policyBusy = false);
    }
  }

  /// 关闭片段预切前先查询 `/api/v1/reels/clips/stats`，若存在已切片段则询问「仅关闭保留」或「关闭并清理」。
  Future<void> _toggleReelClips(bool next) async {
    if (next) {
      await _updatePolicy(reelClipsEnabled: true);
      return;
    }
    try {
      final stats = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/reels/clips/stats',
      );
      final count = (stats['count'] as num?)?.toInt() ?? 0;
      final bytes = (stats['bytes'] as num?)?.toInt() ?? 0;
      if (count <= 0 || !mounted) {
        await _updatePolicy(reelClipsEnabled: false);
        return;
      }
      final choice = await showMcSheet<String>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('关闭精选片段预切？', style: McText.titleSm),
              const SizedBox(height: 8),
              Text(
                '当前磁盘上已有 $count 个预切视频片段（共占用 ${mcFormatBytes(bytes)}）。你可以仅关闭开关保留现有片段，或一并清理释放空间。',
                style: McText.sub.muted,
              ),
              const SizedBox(height: 18),
              McActionPill(
                label: '仅关闭并保留现有片段',
                primary: false,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop('keep'),
              ),
              const SizedBox(height: 10),
              McActionPill(
                label: '关闭并清理全部片段 (${mcFormatBytes(bytes)})',
                primary: false,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop('purge'),
              ),
            ],
          ),
        ),
      );
      if (choice == 'keep') {
        await _updatePolicy(reelClipsEnabled: false);
      } else if (choice == 'purge') {
        await _updatePolicy(reelClipsEnabled: false, purgeClips: true);
      }
    } catch (e) {
      McToast.error(settingsErrorText(e));
    }
  }

  Future<void> _openRemoteConfigEditor() async {
    final cfg = _workerConfig;
    if (cfg == null) return;
    var enabled = cfg['enabled'] == true;
    final urlCtrl = TextEditingController(
      text: (cfg['base_url_override'] ?? cfg['base_url'] ?? '').toString(),
    );
    var busy = false;
    String? err;

    await showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final u = urlCtrl.text.trim();
          final validUrl = u.isEmpty ||
              (Uri.tryParse(u)?.hasScheme == true &&
                  (u.startsWith('http://') || u.startsWith('https://')));
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('远程转码调度设置', style: McText.titleSm),
                if (err != null) ...[
                  const SizedBox(height: 10),
                  SettingsNoticeBanner(
                    text: err!,
                    tone: SettingsTone.danger,
                    margin: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 12),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    McInsetRow(
                      title: '启用远程转码节点调度',
                      subtitle: '将重负载硬件转码任务分发给局域网/异地的高性能节点',
                      trailing: Switch(
                        value: enabled,
                        onChanged: (v) => setSheet(() => enabled = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: '节点回连地址覆盖（可选）',
                    hintText: '留空自动使用外部访问地址',
                    errorText: validUrl ? null : '请输入有效的 http:// 或 https:// 地址',
                  ),
                  onChanged: (_) => setSheet(() => err = null),
                ),
                const SizedBox(height: 18),
                McActionPill(
                  label: busy ? '保存中…' : '保存设置',
                  primary: true,
                  expanded: true,
                  onTap: (!validUrl || busy)
                      ? null
                      : () async {
                          if (cfg['enabled'] == true && !enabled) {
                            final ok = await confirmDialog(
                              ctx,
                              title: '停用远程转码调度？',
                              message: '停用后新转码任务将回退到本机执行。',
                              confirmLabel: '停用并保存',
                            );
                            if (!ok) return;
                          }
                          setSheet(() {
                            busy = true;
                            err = null;
                          });
                          try {
                            final saved = await _mc.unwrap<Map<String, dynamic>>(
                              Channel.general,
                              'PUT',
                              '/api/v1/transcode-worker/config',
                              body: {
                                'enabled': enabled,
                                'base_url': u,
                                'max_artifact_bytes': 512 * 1024 * 1024,
                              },
                            );
                            if (mounted) {
                              setState(() => _workerConfig = saved);
                            }
                            unawaited(_pollRemoteStatus());
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            McToast.success('远程转码配置已保存');
                          } catch (e) {
                            setSheet(() {
                              busy = false;
                              err = settingsErrorText(e);
                            });
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
    urlCtrl.dispose();
  }

  void _openWorkerConnectGuide() {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('接入远程转码节点（3 步指南）', style: McText.titleSm),
            const SizedBox(height: 12),
            const McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.terminal,
                  title: '1. 在算力机运行 MovieClaw Worker',
                  subtitle: '支持配备 Intel QSV / NVIDIA NVENC / Apple VideoToolbox 的电脑或服务器',
                ),
                McInsetRow(
                  icon: McIcons.qrCodeFill,
                  title: '2. 授权连接（配对码或专用令牌）',
                  subtitle: '在「我的设备」批准终端配对码，或创建「仅限远程转码」手动令牌',
                ),
                McInsetRow(
                  icon: McIcons.checkCircleFill,
                  title: '3. 节点自动上线接单',
                  subtitle: '上方节点列表 5 秒内会显示在线状态、硬件后端与并发负载',
                ),
              ],
            ),
            const SizedBox(height: 16),
            McActionPill(
              icon: McIcons.device,
              label: '前往「我的设备」授权或创建令牌',
              primary: true,
              expanded: true,
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/settings/devices');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _clipsFooter(PlaybackPolicy p) {
    if (!p.reelClipsEnabled) {
      return '开启后后台会为媒体库影片预切短视频精彩片段，让「片段」流秒开无缓冲。';
    }
    final prog = p.reelClipsProgress;
    if (prog == null) return '正在准备片段预切任务…';
    if (prog.state == 'done') {
      final skipped = prog.total - prog.ready;
      return skipped > 0
          ? '已完成 ${prog.ready} 部影片预切（跳过 $skipped 部）。'
          : '已完成全部 ${prog.ready} 部影片的片段预切。';
    }
    if (prog.state == 'paused') {
      return '已暂停预切：已完成 ${prog.ready} / ${prog.total}。';
    }
    return '正在后台预切片段：已完成 ${prog.ready} / ${prog.total}…';
  }

  String _cloudStreamLabel(String? mode) => switch (mode) {
        'direct' || 'redirect' => '302 直链优先',
        'proxy' => '服务器中转代理',
        _ => '自动（默认）',
      };

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin();
    final state = ref.watch(playbackProvider);
    final policy = state.valueOrNull;

    return SettingsScaffold(
      title: '播放设置',
      body: policy == null
          ? state.isLoading
              ? const McLoadingView()
              : McErrorView(
                  text: '加载失败',
                  onRetry: () => ref.read(playbackProvider.notifier).load(),
                )
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(playbackProvider.notifier).load();
                if (isAdmin) {
                  await _loadRemoteConfig();
                  await _pollRemoteStatus();
                }
              },
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 36),
                children: [
                  // 1. 已看完成判定（commit 43eacf65）
                  McInsetGroup(
                    header: '已看判定规则',
                    footer: '当播放进度达到设定比例或进入片尾区段时，自动标记本片/本集为「已看」。',
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('已看进度阈值', style: McText.ui),
                                ),
                                Text(
                                  '${policy.playedThresholdPercent.round()}%',
                                  style: McText.sub.semibold.tabular.copyWith(
                                    color: McTokens.accentStrong,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final pct in const [75, 80, 85, 90, 95])
                                  McChip(
                                    label: '$pct%',
                                    compact: true,
                                    selected:
                                        policy.playedThresholdPercent.round() ==
                                            pct,
                                    onTap: _policyBusy
                                        ? null
                                        : () => _updatePolicy(
                                              playedThresholdPercent:
                                                  pct.toDouble(),
                                            ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      McInsetRow(
                        icon: McIcons.fastForward,
                        title: '进入片尾即视为已看 (played_use_outro)',
                        subtitle: '识别到片尾时间戳时，播至片尾起点即自动标为已看',
                        trailing: Switch(
                          value: policy.playedUseOutro,
                          onChanged: _policyBusy
                              ? null
                              : (v) => _updatePolicy(playedUseOutro: v),
                        ),
                        onTap: _policyBusy
                            ? null
                            : () => _updatePolicy(
                                  playedUseOutro: !policy.playedUseOutro,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. 转码、缓存与片段预切
                  McInsetGroup(
                    header: '转码、缓存与媒体体验',
                    dividerIndent: 48,
                    children: [
                      McInsetRow(
                        icon: McIcons.transcoding2,
                        title: '允许软件转码',
                        subtitle: '硬件转码不可用时，用 CPU 兜底转码',
                        trailing: Switch(
                          value: policy.softwareTranscodeEnabled,
                          onChanged: _policyBusy
                              ? null
                              : (v) => _updatePolicy(
                                    softwareTranscodeEnabled: v,
                                  ),
                        ),
                        onTap: _policyBusy
                            ? null
                            : () => _updatePolicy(
                                  softwareTranscodeEnabled:
                                      !policy.softwareTranscodeEnabled,
                                ),
                      ),
                      McInsetRow(
                        icon: McIcons.fastForward,
                        title: '生成进度条预览图 (Trickplay)',
                        subtitle: '拖动进度条时显示缩略图雪碧图',
                        trailing: Switch(
                          value: policy.trickplayEnabled,
                          onChanged: _policyBusy
                              ? null
                              : (v) => _updatePolicy(trickplayEnabled: v),
                        ),
                        onTap: _policyBusy
                            ? null
                            : () => _updatePolicy(
                                  trickplayEnabled: !policy.trickplayEnabled,
                                ),
                      ),
                      McInsetRow(
                        icon: McIcons.save,
                        title: '保留转码产物缓存',
                        subtitle: '转码结果缓存下来，下次播放免重复转码',
                        trailing: Switch(
                          value: policy.transcodeCacheEnabled,
                          onChanged: _policyBusy
                              ? null
                              : (v) => _updatePolicy(transcodeCacheEnabled: v),
                        ),
                        onTap: _policyBusy
                            ? null
                            : () => _updatePolicy(
                                  transcodeCacheEnabled:
                                      !policy.transcodeCacheEnabled,
                                ),
                      ),
                      if (policy.cloudStreamMode != null)
                        McInsetRow(
                          icon: McIcons.cloud,
                          title: '网盘串流模式',
                          valueText: _cloudStreamLabel(policy.cloudStreamMode),
                          onTap: _policyBusy
                              ? null
                              : () async {
                                  final picked = await showMcSheet<String>(
                                    context: context,
                                    builder: (ctx) => Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        20,
                                      ),
                                      child: McInsetGroup(
                                        header: '选择网盘串流模式',
                                        margin: EdgeInsets.zero,
                                        children: [
                                          for (final (v, t) in const [
                                            ('auto', '自动（默认）'),
                                            ('redirect', '302 直链优先'),
                                            ('proxy', '服务器中转代理'),
                                          ])
                                            McInsetRow(
                                              title: t,
                                              trailing:
                                                  policy.cloudStreamMode == v
                                                      ? const Icon(
                                                          McIcons
                                                              .checkCircleFill,
                                                          color: McTokens.ok,
                                                          size: 19,
                                                        )
                                                      : null,
                                              onTap: () =>
                                                  Navigator.of(ctx).pop(v),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (picked != null) {
                                    await _updatePolicy(
                                      cloudStreamMode: picked,
                                    );
                                  }
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  McInsetGroup(
                    header: '精选片段预切 (Reels)',
                    footer: _clipsFooter(policy),
                    children: [
                      McInsetRow(
                        icon: McIcons.play2Fill,
                        title: '后台预切精选短视频片段',
                        trailing: Switch(
                          value: policy.reelClipsEnabled,
                          onChanged: _policyBusy ? null : _toggleReelClips,
                        ),
                        onTap: _policyBusy
                            ? null
                            : () => _toggleReelClips(!policy.reelClipsEnabled),
                      ),
                    ],
                  ),

                  // 3. 硬件能力卡
                  const SettingsGroupLabel('本机硬件转码能力'),
                  SettingsInfoCard(
                    icon: McIcons.shieldCheck,
                    text: policy.hardwareAvailable
                        ? '服务器检测到可用硬件转码后端：${policy.hwBackends.join('、')}'
                        : '服务器未检测到可用的硬件转码后端；如已允许，将回退到软件转码。',
                  ),

                  // 4. 远程转码节点（仅管理员）
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    ..._buildRemoteTranscodeSections(),
                  ],
                ],
              ),
            ),
    );
  }

  List<Widget> _buildRemoteTranscodeSections() {
    if (_workerConfigErr != null && _workerConfig == null) {
      return [
        SettingsNoticeBanner(
          text: '读取远程转码配置失败：$_workerConfigErr',
          tone: SettingsTone.warn,
          action: McChip(
            label: '重试',
            compact: true,
            onTap: _loadRemoteConfig,
          ),
        ),
      ];
    }
    final cfg = _workerConfig;
    if (cfg == null) {
      return const [SettingsInfoCard(text: '正在加载远程转码配置…')];
    }

    final enabled = cfg['enabled'] == true;
    final ready = cfg['ready'] == true;
    final issues = ((cfg['issues'] ?? const []) as List<dynamic>)
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    final workers = ((_workerStatus?['workers'] ?? const []) as List<dynamic>)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final connectedIds =
        workers.map((w) => (w['worker_id'] ?? '').toString()).toSet();
    final offlineAuthorized =
        _authorizedWorkers.where((d) => !connectedIds.contains(d.name)).toList();

    return [
      McInsetGroup(
        header: '远程转码调度',
        footer: enabled
            ? '已开启远程转码调度，在线转码节点会自动分担客户端转码压力。'
            : '开启后可接入高性能电脑或服务器作为远程转码节点。',
        children: [
          McInsetRow(
            icon: McIcons.gpu,
            iconColor: enabled ? McTokens.ok : McTokens.textMuted,
            title: '远程转码配置',
            subtitle: (cfg['base_url_override'] ?? '').toString().isNotEmpty
                ? '回连地址：${cfg['base_url_override']}'
                : '自动使用服务器地址',
            trailing: SettingsStatusBadge(
              label: enabled ? '已启用' : '未启用',
              tone: enabled ? SettingsTone.ok : SettingsTone.neutral,
              showDot: true,
            ),
            showChevron: true,
            onTap: _openRemoteConfigEditor,
          ),
        ],
      ),
      for (final iss in issues) ...[
        const SizedBox(height: 6),
        SettingsNoticeBanner(text: iss, tone: SettingsTone.warn),
      ],
      const SizedBox(height: 14),
      if (_workerStatusErr != null)
        SettingsNoticeBanner(
          text: '节点状态刷新异常：$_workerStatusErr',
          tone: SettingsTone.warn,
        ),
      McInsetGroup(
        header: '远程转码节点（每 5 秒自动刷新）',
        children: [
          for (final w in workers) _buildOnlineWorkerRow(w),
          for (final d in offlineAuthorized)
            McInsetRow(
              icon: McIcons.gpu,
              iconColor: McTokens.textFaint,
              title: d.name,
              subtitle: d.lastSeenAt != null &&
                      DateTime.tryParse(d.lastSeenAt!) != null
                  ? '已授权转码设备 · 最近活跃 ${McFormatting.relative(DateTime.parse(d.lastSeenAt!))}'
                  : '已授权转码设备 · 未连接',
              trailing: const SettingsStatusBadge(
                label: '未连接',
                tone: SettingsTone.neutral,
              ),
            ),
          if (workers.isEmpty && offlineAuthorized.isEmpty)
            McInsetRow(
              icon: McIcons.gpu,
              title: ready ? '暂无在线转码节点' : '请先启用远程转码调度',
              subtitle: '点击下方接入指南绑定你的第一台算力机',
            ),
          McInsetRow(
            icon: McIcons.addS,
            title: '接入新的转码节点（3 步指南）',
            onTap: _openWorkerConnectGuide,
          ),
          McInsetRow(
            icon: McIcons.device,
            title: '管理已授权转码设备',
            onTap: () => context.push('/settings/devices'),
          ),
        ],
      ),
    ];
  }

  Widget _buildOnlineWorkerRow(Map<String, dynamic> w) {
    final id = (w['worker_id'] ?? '').toString();
    final online = w['online'] == true;
    final draining = w['draining'] == true;
    final platform = (w['platform'] ?? '').toString();
    final arch = (w['arch'] ?? '').toString();
    final ffmpeg = (w['ffmpeg_version'] ?? '').toString();
    final backends = ((w['backends'] ?? const []) as List<dynamic>)
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final activeJobs = (w['active_jobs'] as num?)?.toInt() ?? 0;
    final maxJobs = (w['max_jobs'] as num?)?.toInt() ?? 0;
    final lastSec = ((w['last_seen_seconds'] as num?)?.toDouble() ?? 0).round();

    final summary = [
      if (platform.isNotEmpty) platform,
      if (arch.isNotEmpty) arch,
      if (ffmpeg.isNotEmpty) 'ffmpeg $ffmpeg',
      if (backends.isNotEmpty) backends.join('/'),
      '任务 $activeJobs/$maxJobs',
      '${lastSec}s 前活跃',
    ].join(' · ');

    final (label, tone) = !online
        ? ('离线', SettingsTone.neutral)
        : draining
            ? ('排空中', SettingsTone.warn)
            : ('在线', SettingsTone.ok);

    return McInsetRow(
      icon: McIcons.gpu,
      iconColor: settingsToneColor(tone),
      title: id,
      subtitle: summary,
      trailing: SettingsStatusBadge(label: label, tone: tone, showDot: true),
    );
  }
}
