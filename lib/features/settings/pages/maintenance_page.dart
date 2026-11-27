import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/settings_ui.dart';

/// 服务器维护页（对齐 iOS AppMaintenanceSection + AppStorageSection）：
/// 1) 应用热更新、NER 识别模型更新、版本回退与保留策略、异常退出提示、服务重启恢复监测；
/// 2) 磁盘占用四段条、未登记目录告警、缓存/数据目录详情与 orphans/all 分级清理。
class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  late int _tab = widget.initialTab.clamp(0, 1);

  final _updateKey = GlobalKey<_AppUpdatePanelState>();
  final _storageKey = GlobalKey<_AppStoragePanelState>();

  void _refreshCurrent() {
    if (_tab == 0) {
      _updateKey.currentState?.load();
    } else {
      _storageKey.currentState?.load(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '更新、缓存与维护',
      actions: [
        McChip(
          icon: McIcons.refresh,
          label: _tab == 0 ? '刷新' : '重新统计',
          compact: true,
          onTap: _refreshCurrent,
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              4,
              McTokens.pagePadding,
              10,
            ),
            child: Row(
              children: [
                McChip(
                  icon: McIcons.dataupgrade,
                  label: '更新与服务',
                  compact: true,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                McChip(
                  icon: McIcons.hardDisk,
                  label: '存储与缓存',
                  compact: true,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _AppUpdatePanel(key: _updateKey),
                _AppStoragePanel(key: _storageKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 0: 热更新 / NER 模型 / 回退 / 服务重启
// ---------------------------------------------------------------------------

class _AppUpdatePanel extends ConsumerStatefulWidget {
  const _AppUpdatePanel({super.key});

  @override
  ConsumerState<_AppUpdatePanel> createState() => _AppUpdatePanelState();
}

class _AppUpdatePanelState extends ConsumerState<_AppUpdatePanel> {
  UpdateStatus? _status;
  PendingUpdate? _pending;
  UpdateProgressView? _progress;
  UpdateCheckView? _check;
  ModelUpdateCheckView? _modelCheck;

  bool _loading = true;
  String? _error;
  bool _checkingApp = false;
  bool _checkingModel = false;
  bool _applyingApp = false;
  bool _applyingModel = false;

  // 1s 更新进度轮询
  Timer? _progressTimer;

  // 重启恢复状态机（最多 90 次 x 2s = 3 分钟）
  bool _waitingRestart = false;
  bool _sawDown = false;
  bool _restartTimedOut = false;
  int _restartAttempts = 0;
  int _earlyHealthyStreak = 0;
  String _restartTitle = '正在等待服务重启完成…';
  Timer? _restartTimer;

  SettingsApi get _api => ref.read(settingsApiProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _restartTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      _loading = _status == null;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.updateStatus(),
        _api.pendingUpdate().catchError((_) => null),
        _api.updateProgress().catchError((_) => const UpdateProgressView()),
      ]);
      if (!mounted) return;
      final status = results[0] as UpdateStatus;
      final pending = results[1] as PendingUpdate?;
      final progress = results[2] as UpdateProgressView;
      setState(() {
        _status = status;
        _pending = pending;
        _progress = progress;
        _loading = false;
      });
      _syncProgressPolling(progress);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = settingsErrorText(e);
        _loading = false;
      });
    }
  }

  bool _isActivePhase(String phase) {
    final p = phase.toLowerCase();
    return p.isNotEmpty &&
        p != 'idle' &&
        p != 'done' &&
        p != 'completed' &&
        p != 'failed' &&
        p != 'error';
  }

  void _syncProgressPolling(UpdateProgressView p) {
    final phase = p.phase.toLowerCase();
    if (phase == 'restarting') {
      _progressTimer?.cancel();
      _progressTimer = null;
      if (!_waitingRestart) {
        _beginRestartWait(title: '更新包已就绪，正在等待服务重启…');
      }
      return;
    }
    if (_isActivePhase(phase)) {
      _progressTimer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _pollProgress(),
      );
    } else {
      _progressTimer?.cancel();
      _progressTimer = null;
    }
  }

  Future<void> _pollProgress() async {
    try {
      final p = await _api.updateProgress();
      if (!mounted) return;
      final wasActive = _progress != null && _isActivePhase(_progress!.phase);
      setState(() => _progress = p);
      if (p.phase.toLowerCase() == 'restarting') {
        _syncProgressPolling(p);
        return;
      }
      if (!_isActivePhase(p.phase)) {
        _progressTimer?.cancel();
        _progressTimer = null;
        if (wasActive) {
          if (p.phase.toLowerCase() == 'failed' ||
              (p.error != null && p.error!.isNotEmpty)) {
            McToast.error(p.error?.isNotEmpty == true ? p.error! : '更新失败');
          } else {
            McToast.success('更新完成');
          }
          await load();
        }
      }
    } catch (_) {
      // 网络瞬断：如果原本在应用阶段，可能已进入重启
      if (_applyingApp || _progress?.phase == 'installing') {
        _progressTimer?.cancel();
        _progressTimer = null;
        if (!_waitingRestart) {
          _beginRestartWait(title: '服务正在重启并加载新版本…');
        }
      }
    }
  }

  void _beginRestartWait({required String title}) {
    _restartTimer?.cancel();
    setState(() {
      _waitingRestart = true;
      _sawDown = false;
      _restartTimedOut = false;
      _restartAttempts = 0;
      _earlyHealthyStreak = 0;
      _restartTitle = title;
    });
    _restartTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _probeRestartHealth(),
    );
  }

  Future<void> _probeRestartHealth() async {
    if (!mounted || !_waitingRestart) return;
    _restartAttempts += 1;
    if (_restartAttempts > 90) {
      _restartTimer?.cancel();
      _restartTimer = null;
      setState(() => _restartTimedOut = true);
      return;
    }
    final healthy = await _api.probeHealth();
    if (!mounted || !_waitingRestart) return;
    if (!healthy) {
      setState(() {
        _sawDown = true;
        _earlyHealthyStreak = 0;
      });
      return;
    }
    if (_sawDown) {
      _finishRestartWait();
      return;
    }
    // 某些极快重启场景在首次 2s 轮询前已经恢复
    _earlyHealthyStreak += 1;
    if (_restartAttempts >= 4 && _earlyHealthyStreak >= 3) {
      _finishRestartWait();
    } else {
      setState(() {});
    }
  }

  Future<void> _finishRestartWait() async {
    _restartTimer?.cancel();
    _restartTimer = null;
    setState(() {
      _waitingRestart = false;
      _restartTimedOut = false;
      _applyingApp = false;
    });
    McToast.success('服务已恢复在线');
    await load();
  }

  Future<void> _checkAppUpdate() async {
    setState(() => _checkingApp = true);
    try {
      final res = await _api.checkUpdate();
      if (!mounted) return;
      setState(() => _check = res);
      if (res.updateAvailable) {
        McToast.success('发现新版本 v${res.latestVersion}');
      } else {
        McToast.info('当前已是最新版本');
      }
    } catch (e) {
      if (mounted) McToast.error('检查更新失败：${settingsErrorText(e)}');
    } finally {
      if (mounted) setState(() => _checkingApp = false);
    }
  }

  Future<void> _applyAppUpdate({
    required String targetVersion,
    required bool isKnownBad,
  }) async {
    final ok = await confirmDialog(
      context,
      title: isKnownBad ? '确认安装高风险版本' : '安装服务端热更新',
      message: isKnownBad
          ? '版本 v$targetVersion 曾被标记为异常退出版本，继续安装可能导致服务回退或不稳定，确认继续吗？'
          : '即将下载并应用 MovieClaw v$targetVersion，完成后服务会自动重启（约 10-30 秒）。',
      confirmLabel: '开始更新',
      destructive: isKnownBad,
    );
    if (!ok || !mounted) return;
    setState(() => _applyingApp = true);
    try {
      final prog = await _api.applyUpdate();
      if (!mounted) return;
      setState(() => _progress = prog);
      _syncProgressPolling(prog);
    } catch (e) {
      if (mounted) McToast.error('触发更新失败：${settingsErrorText(e)}');
      setState(() => _applyingApp = false);
    }
  }

  Future<void> _checkModelUpdate() async {
    setState(() => _checkingModel = true);
    try {
      final res = await _api.checkModelUpdate();
      if (!mounted) return;
      setState(() => _modelCheck = res);
      if (res.updateAvailable) {
        McToast.success('发现新版识别模型 ${res.latestTag}');
      } else {
        McToast.info('片名识别模型已是最新');
      }
    } catch (e) {
      if (mounted) McToast.error('检查模型失败：${settingsErrorText(e)}');
    } finally {
      if (mounted) setState(() => _checkingModel = false);
    }
  }

  Future<void> _applyModelUpdate() async {
    final ok = await confirmDialog(
      context,
      title: '更新片名识别模型',
      message: '下载并切换最新 NER 识别模型，期间不需要重启服务端。',
      confirmLabel: '立即更新',
    );
    if (!ok || !mounted) return;
    setState(() => _applyingModel = true);
    try {
      final prog = await _api.applyModelUpdate();
      if (!mounted) return;
      setState(() => _progress = prog);
      _syncProgressPolling(prog);
      if (!_isActivePhase(prog.phase)) {
        McToast.success('识别模型已更新');
        await load();
      }
    } catch (e) {
      if (mounted) McToast.error('模型更新失败：${settingsErrorText(e)}');
    } finally {
      if (mounted) setState(() => _applyingModel = false);
    }
  }

  Future<void> _dismissAbnormalExit() async {
    try {
      await _api.dismissLastExit();
      if (!mounted) return;
      setState(() => _status = _status?.copyWithoutExit());
      McToast.success('已忽略该异常提示');
    } catch (e) {
      if (mounted) McToast.error('操作失败：${settingsErrorText(e)}');
    }
  }

  Future<void> _restartServer() async {
    final ok = await confirmDialog(
      context,
      title: '重启 MovieClaw 服务',
      message: '重启期间所有播放、下载与客户端连接会短暂中断，通常 10-20 秒后恢复。确定重启吗？',
      confirmLabel: '重启服务',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _api.restartApp();
      if (!mounted) return;
      _beginRestartWait(title: '重启指令已发送，正在等待服务恢复…');
    } catch (e) {
      if (mounted) McToast.error('重启失败：${settingsErrorText(e)}');
    }
  }

  Future<void> _openRollbackSheet() async {
    final triggered = await showMcSheet<bool>(
      context: context,
      builder: (_) => _RollbackSheet(api: _api),
    );
    if (triggered == true && mounted) {
      _beginRestartWait(title: '回退任务已启动，正在等待服务重启…');
    }
  }

  void _showChangelog(String version, String changelog) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('v$version 更新说明', style: McText.titleSm),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: McTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: McTokens.line),
                    ),
                    child: SelectableText(
                      changelog.trim().isEmpty
                          ? '暂无详细更新日志。'
                          : changelog.trim(),
                      style: McText.sub.copyWith(height: 1.55),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _codeSourceLabel(String src) => switch (src.toLowerCase()) {
        'overlay' => '热更新覆盖层',
        'baseline' || 'image' => '容器内置镜像',
        'source' || 'git' => '源码运行',
        _ => src.isEmpty ? '未知来源' : src,
      };

  String _formatUnix(int ts) {
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      ts > 1000000000000 ? ts : ts * 1000,
    ).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _status == null) return const McLoadingView();
    if (_error != null && _status == null) {
      return McErrorView(text: _error!, onRetry: load);
    }

    final status = _status ?? const UpdateStatus();
    final pending = _pending;
    final check = _check;
    final progress = _progress;

    final hasUpdate = (check?.updateAvailable ?? false) ||
        (pending?.appVersion?.isNotEmpty ?? false);
    final targetVersion = (check?.latestVersion.isNotEmpty ?? false)
        ? check!.latestVersion
        : (pending?.appVersion ?? '');
    final compatible = check != null
        ? check.compatible
        : (pending?.appCompatible ?? true);
    final changelog = (check?.changelog.isNotEmpty ?? false)
        ? check!.changelog
        : (pending?.appChangelog ?? '');
    final knownBad = (check?.latestKnownBad ?? false) ||
        (targetVersion.isNotEmpty &&
            status.badVersions.contains(targetVersion));

    final hasModelUpdate = (_modelCheck?.updateAvailable ?? false) ||
        (pending?.modelTag?.isNotEmpty ?? false);
    final targetModelTag = (_modelCheck?.latestTag.isNotEmpty ?? false)
        ? _modelCheck!.latestTag
        : (pending?.modelTag ?? '');
    final modelInstallable = _modelCheck?.installable ??
        (pending?.modelTag?.isNotEmpty ?? false);

    final showProgress = progress != null && _isActivePhase(progress.phase);

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          if (_waitingRestart) ...[
            SettingsNoticeBanner(
              tone: _restartTimedOut ? SettingsTone.danger : SettingsTone.info,
              icon: _restartTimedOut ? McIcons.alertCircle : McIcons.restart,
              title: _restartTimedOut ? '等待重启超时' : _restartTitle,
              message: _restartTimedOut
                  ? '3 分钟内未能重新连上服务端，请检查 Docker / 宿主机日志或重试探测。'
                  : (_sawDown
                      ? '已检测到服务重启中，正在轮询健康检查（第 $_restartAttempts 次）…'
                      : '正在等待旧进程优雅退出（第 $_restartAttempts 次）…'),
              trailing: _restartTimedOut
                  ? McChip(
                      label: '重试探测',
                      compact: true,
                      selected: true,
                      onTap: () => _beginRestartWait(title: _restartTitle),
                    )
                  : const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
            const SizedBox(height: 14),
          ],
          if (status.lastAbnormalExit != null) ...[
            SettingsNoticeBanner(
              tone: SettingsTone.danger,
              icon: McIcons.alertCircle,
              title:
                  '上次服务异常退出（退出码 ${status.lastAbnormalExit!.exitCode}）',
              message: [
                if (status.lastAbnormalExit!.at > 0)
                  '时间：${_formatUnix(status.lastAbnormalExit!.at)}',
                if (status.lastAbnormalExit!.detail.isNotEmpty)
                  status.lastAbnormalExit!.detail,
                '如由热更新触发，系统可能已自动回退到上一个可用版本。',
              ].join('\n'),
              trailing: McChip(
                label: '忽略',
                compact: true,
                onTap: _dismissAbnormalExit,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (status.inactiveOverlayVersion != null &&
              status.inactiveOverlayVersion!.isNotEmpty) ...[
            SettingsNoticeBanner(
              tone: SettingsTone.warn,
              icon: McIcons.information,
              title: '存在未激活的热更新包 v${status.inactiveOverlayVersion}',
              message: (status.inactiveOverlayReason?.isNotEmpty ?? false)
                  ? status.inactiveOverlayReason!
                  : '当前未加载该热更新覆盖层，可能因基础镜像版本变更或自检保护已跳过。',
            ),
            const SizedBox(height: 14),
          ],
          if (showProgress) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: McTokens.surfaceInset,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: McTokens.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            progress.targetVersion?.isNotEmpty == true
                                ? '正在更新至 ${progress.targetVersion}（${progress.phase}）'
                                : '更新执行中（${progress.phase}）',
                            style: McText.sub.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (progress.percent != null)
                          Text(
                            '${progress.percent!.clamp(0, 100).toStringAsFixed(0)}%',
                            style: McText.caption.copyWith(
                              color: McTokens.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress.percent != null
                          ? (progress.percent!.clamp(0, 100) / 100.0)
                          : null,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    if (progress.detail.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(progress.detail, style: McText.caption.muted),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          McInsetGroup(
            header: 'MovieClaw 服务端版本',
            children: [
              McInsetRow(
                icon: McIcons.dataupgrade,
                title: status.currentVersion.isEmpty
                    ? 'MovieClaw 服务端'
                    : 'v${status.currentVersion}',
                subtitle: [
                  _codeSourceLabel(status.codeSource),
                  status.canUpdate ? '支持在线热更新' : '仅支持镜像拉取更新',
                ].join(' · '),
                trailing: hasUpdate
                    ? SettingsStatusBadge(
                        label: '新版本 v$targetVersion',
                        tone: knownBad
                            ? SettingsTone.danger
                            : SettingsTone.ok,
                      )
                    : const SettingsStatusBadge(
                        label: '已最新',
                        tone: SettingsTone.neutral,
                      ),
              ),
              if (hasUpdate) ...[
                if (!compatible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: SettingsNoticeBanner(
                      tone: SettingsTone.warn,
                      icon: McIcons.alertCircle,
                      title: '需要升级基础容器镜像',
                      message:
                          'v$targetVersion 依赖更高版本的基础运行环境，无法直接热更新，请通过 Docker / 应用商店更新镜像。',
                    ),
                  ),
                if (knownBad)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: SettingsNoticeBanner(
                      tone: SettingsTone.danger,
                      icon: McIcons.alertCircle,
                      title: '该版本曾触发异常退出保护',
                      message: '建议等待后续修复版本，除非确认环境问题已排除。',
                    ),
                  ),
                if (changelog.isNotEmpty)
                  McInsetRow(
                    icon: McIcons.fileText,
                    title: '查看 v$targetVersion 更新日志',
                    onTap: () => _showChangelog(targetVersion, changelog),
                  ),
                if (status.canUpdate && compatible)
                  McInsetRow(
                    icon: McIcons.downloadCloud,
                    title: _applyingApp ? '正在发起热更新…' : '立即安装 v$targetVersion',
                    subtitle: '下载覆盖层并自动重启服务端',
                    trailing: _applyingApp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(McIcons.chevronRight, size: 16),
                    onTap: _applyingApp || _waitingRestart
                        ? null
                        : () => _applyAppUpdate(
                              targetVersion: targetVersion,
                              isKnownBad: knownBad,
                            ),
                  ),
              ],
              McInsetRow(
                icon: McIcons.refresh,
                title: _checkingApp ? '正在检查服务端更新…' : '检查服务端更新',
                trailing: _checkingApp
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _checkingApp || _waitingRestart ? null : _checkAppUpdate,
              ),
              McInsetRow(
                icon: McIcons.history,
                title: '版本回退与保留策略',
                subtitle: '切换历史热更新版本、恢复数据库备份或调整保留份数',
                onTap: _waitingRestart ? null : _openRollbackSheet,
              ),
            ],
          ),
          const SizedBox(height: 18),
          McInsetGroup(
            header: '片名识别模型 (NER)',
            children: [
              McInsetRow(
                icon: McIcons.aiStarFill,
                title: '当前识别模型',
                subtitle: (status.modelTag?.isNotEmpty ?? false)
                    ? status.modelTag!
                    : '默认内置规则',
                trailing: hasModelUpdate
                    ? SettingsStatusBadge(
                        label: '新版 $targetModelTag',
                        tone: SettingsTone.info,
                      )
                    : null,
              ),
              McInsetRow(
                icon: McIcons.refresh,
                title: _checkingModel ? '正在检查识别模型…' : '检查模型更新',
                trailing: _checkingModel
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _checkingModel ? null : _checkModelUpdate,
              ),
              if (hasModelUpdate && modelInstallable)
                McInsetRow(
                  icon: McIcons.download,
                  title: _applyingModel
                      ? '正在下载模型…'
                      : '更新识别模型至 $targetModelTag',
                  subtitle: '无需重启服务，实时提升中英文剧集与电影解析准确率',
                  onTap: _applyingModel ? null : _applyModelUpdate,
                ),
            ],
          ),
          const SizedBox(height: 18),
          McInsetGroup(
            header: '服务进程控制',
            children: [
              McInsetRow(
                icon: McIcons.restart,
                title: '重启 MovieClaw 服务',
                subtitle: '重启主服务进程并自动监测健康恢复',
                onTap: _waitingRestart ? null : _restartServer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RollbackSheet extends StatefulWidget {
  const _RollbackSheet({required this.api});

  final SettingsApi api;

  @override
  State<_RollbackSheet> createState() => _RollbackSheetState();
}

class _RollbackSheetState extends State<_RollbackSheet> {
  RollbackOptionsView? _options;
  bool _loading = true;
  bool _savingRetention = false;
  bool _rollingBack = false;
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
      final opts = await widget.api.rollbackOptions();
      if (!mounted) return;
      setState(() {
        _options = opts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = settingsErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _updateRetention(int next) async {
    final clamped = next.clamp(2, 20);
    setState(() => _savingRetention = true);
    try {
      await widget.api.setUpdateRetention(clamped);
      if (!mounted) return;
      McToast.success('历史版本保留份数已设为 $clamped');
      await _load();
    } catch (e) {
      if (mounted) McToast.error('保存失败：${settingsErrorText(e)}');
    } finally {
      if (mounted) setState(() => _savingRetention = false);
    }
  }

  Future<void> _rollback(RollbackTargetView target) async {
    final isRestore = target.schemaAction == 'restore';
    final ok = await confirmDialog(
      context,
      title: '回退至 ${target.displayLabel}',
      message: isRestore
          ? '该版本与当前数据库结构不同，回退将同时恢复 ${target.backupTakenAt ?? '升级前'} 的数据库快照，期间新增的观看记录与配置改动会丢失。确认执行吗？'
          : '该版本兼容当前数据库结构，将以无损模式切换代码版本并重启服务。确认继续吗？',
      confirmLabel: isRestore ? '恢复快照并回退' : '无损切换',
      destructive: isRestore,
    );
    if (!ok || !mounted) return;
    setState(() => _rollingBack = true);
    try {
      final targetKey =
          target.kind == 'baseline' ? 'baseline' : (target.version ?? '');
      await widget.api.rollbackVersion(
        target: targetKey,
        restoreBackup: isRestore,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) McToast.error('回退失败：${settingsErrorText(e)}');
      setState(() => _rollingBack = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opts = _options;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('版本回退与保留策略', style: McText.titleSm),
                const Spacer(),
                if (opts != null && opts.versionsDirBytes > 0)
                  Text(
                    '历史包占 ${mcFormatBytes(opts.versionsDirBytes)}',
                    style: McText.caption.muted,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              McErrorView(text: _error!, onRetry: _load)
            else if (opts != null)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      McInsetGroup(
                        margin: EdgeInsets.zero,
                        header: '历史包保留数量（2 - 20）',
                        children: [
                          McInsetRow(
                            icon: McIcons.archive,
                            title: '最多保留 ${opts.keepVersions} 个版本',
                            subtitle: '自动清理超出份数的旧热更新包',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(McIcons.dash, size: 18),
                                  onPressed: _savingRetention ||
                                          opts.keepVersions <= 2
                                      ? null
                                      : () => _updateRetention(
                                            opts.keepVersions - 1,
                                          ),
                                ),
                                Text(
                                  '${opts.keepVersions}',
                                  style: McText.sub.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(McIcons.addS, size: 18),
                                  onPressed: _savingRetention ||
                                          opts.keepVersions >= 20
                                      ? null
                                      : () => _updateRetention(
                                            opts.keepVersions + 1,
                                          ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      McInsetGroup(
                        margin: EdgeInsets.zero,
                        header: '可回退目标 (${opts.targets.length})',
                        children: opts.targets.isEmpty
                            ? const [
                                McInsetRow(
                                  icon: McIcons.history,
                                  title: '暂无历史可回退版本',
                                  subtitle: '首次完成热更新后，旧版本会自动保留于此。',
                                ),
                              ]
                            : [
                                for (final t in opts.targets)
                                  McInsetRow(
                                    icon: t.kind == 'baseline'
                                        ? McIcons.docker
                                        : McIcons.gitCommit,
                                    title: t.displayLabel,
                                    subtitle: [
                                      if (t.sizeBytes != null &&
                                          t.sizeBytes! > 0)
                                        mcFormatBytes(t.sizeBytes!),
                                      if (t.installedAt?.isNotEmpty == true)
                                        '安装于 ${t.installedAt}',
                                      if (t.schemaAction == 'restore' &&
                                          t.backupTakenAt?.isNotEmpty == true)
                                        '需恢复快照 ${t.backupTakenAt}',
                                      if (t.schemaAction == 'unavailable')
                                        '缺少匹配数据库快照，无法回退',
                                    ].join(' · '),
                                    trailing: switch (t.schemaAction) {
                                      'switch' => const SettingsStatusBadge(
                                          label: '无损切换',
                                          tone: SettingsTone.ok,
                                        ),
                                      'restore' => const SettingsStatusBadge(
                                          label: '恢复快照',
                                          tone: SettingsTone.warn,
                                        ),
                                      _ => const SettingsStatusBadge(
                                          label: '不可回退',
                                          tone: SettingsTone.neutral,
                                        ),
                                    },
                                    onTap: _rollingBack ||
                                            t.schemaAction == 'unavailable'
                                        ? null
                                        : () => _rollback(t),
                                  ),
                              ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: 存储用量与目录清理
// ---------------------------------------------------------------------------

class _AppStoragePanel extends ConsumerStatefulWidget {
  const _AppStoragePanel({super.key});

  @override
  ConsumerState<_AppStoragePanel> createState() => _AppStoragePanelState();
}

class _AppStoragePanelState extends ConsumerState<_AppStoragePanel> {
  StorageState? _storage;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  SettingsApi get _api => ref.read(settingsApiProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool refresh = false, bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = _storage == null;
        _error = null;
      });
    }
    try {
      final st = await _api.storage(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _storage = st;
        _loading = false;
      });
      if (st.computing) {
        _pollTimer ??= Timer.periodic(
          const Duration(seconds: 2),
          (_) => load(silent: true),
        );
      } else {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = settingsErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _openDirSheet(StorageDir dir) async {
    final cleaned = await showMcSheet<bool>(
      context: context,
      builder: (_) => _StorageDirDetailSheet(api: _api, dir: dir),
    );
    if (cleaned == true && mounted) {
      await load(refresh: true);
    }
  }

  String _formatComputedAt(int ts) {
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      ts > 1000000000000 ? ts : ts * 1000,
    ).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _storage == null) return const McLoadingView();
    if (_error != null && _storage == null) {
      return McErrorView(text: _error!, onRetry: () => load(refresh: true));
    }

    final st = _storage ?? const StorageState();
    final cacheDirs = st.dirs.where((d) => d.group == 'cache').toList();
    final dataDirs = st.dirs.where((d) => d.group != 'cache').toList();

    final otherBytes =
        (st.diskUsed - st.dataBytes - st.cacheBytes).clamp(0, st.diskTotal);

    return RefreshIndicator(
      onRefresh: () => load(refresh: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          if (st.computing) ...[
            const SettingsNoticeBanner(
              tone: SettingsTone.info,
              icon: McIcons.hourglass,
              title: '正在后台扫描目录大小…',
              message: '数据目录较大时可能需要数秒，统计完成后会自动刷新。',
              trailing: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (st.error != null && st.error!.isNotEmpty) ...[
            SettingsNoticeBanner(
              tone: SettingsTone.danger,
              icon: McIcons.alertCircle,
              title: '上次存储统计出错',
              message: st.error!,
            ),
            const SizedBox(height: 14),
          ],
          if (st.hasUsage) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: McTokens.surfaceInset,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: McTokens.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '磁盘占用总览',
                          style: McText.sub.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${mcFormatBytes(st.diskUsed)} / ${mcFormatBytes(st.diskTotal)}',
                          style: McText.caption.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _FourSegmentBar(
                      total: st.diskTotal,
                      dataBytes: st.dataBytes,
                      cacheBytes: st.cacheBytes,
                      otherBytes: otherBytes,
                      freeBytes: st.diskFree,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _LegendDot(
                          color: McTokens.accent,
                          label: '应用数据 ${mcFormatBytes(st.dataBytes)}',
                        ),
                        _LegendDot(
                          color: McTokens.warn,
                          label: '可清缓存 ${mcFormatBytes(st.cacheBytes)}',
                        ),
                        _LegendDot(
                          color: McTokens.textMuted,
                          label: '系统及其他 ${mcFormatBytes(otherBytes)}',
                        ),
                        _LegendDot(
                          color: McTokens.glassFill,
                          label: '剩余 ${mcFormatBytes(st.diskFree)}',
                        ),
                      ],
                    ),
                    if (st.dataRoot.isNotEmpty || st.computedAt > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        [
                          if (st.dataRoot.isNotEmpty) '数据根目录：${st.dataRoot}',
                          if (st.computedAt > 0)
                            '统计于 ${_formatComputedAt(st.computedAt)}',
                        ].join(' · '),
                        style: McText.caption.faint,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (st.unregistered.isNotEmpty) ...[
            SettingsNoticeBanner(
              tone: SettingsTone.warn,
              icon: McIcons.fileWarning,
              title: '发现 ${st.unregistered.length} 个未登记目录',
              message: st.unregistered
                  .map((e) => '${e.path} (${mcFormatBytes(e.bytes)})')
                  .join('\n'),
            ),
            const SizedBox(height: 16),
          ],
          if (cacheDirs.isNotEmpty) ...[
            McInsetGroup(
              header: '可清理缓存目录 (${cacheDirs.length})',
              children: [
                for (final d in cacheDirs) _dirRow(d),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (dataDirs.isNotEmpty) ...[
            McInsetGroup(
              header: '应用数据目录 (${dataDirs.length})',
              children: [
                for (final d in dataDirs) _dirRow(d),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dirRow(StorageDir d) {
    final expensive = d.rebuildCost.toLowerCase() == 'expensive';
    return McInsetRow(
      icon: d.group == 'cache' ? McIcons.eraser : McIcons.folder,
      title: d.title.isEmpty ? d.key : d.title,
      subtitle: [
        if (d.summary.isNotEmpty) d.summary,
        if (expensive) '重建较慢',
        if (d.orphanAware) '支持孤立清理',
      ].join(' · '),
      valueText: mcFormatBytes(d.bytes),
      onTap: () => _openDirSheet(d),
    );
  }
}

class _FourSegmentBar extends StatelessWidget {
  const _FourSegmentBar({
    required this.total,
    required this.dataBytes,
    required this.cacheBytes,
    required this.otherBytes,
    required this.freeBytes,
  });

  final int total;
  final int dataBytes;
  final int cacheBytes;
  final int otherBytes;
  final int freeBytes;

  @override
  Widget build(BuildContext context) {
    final denom = total <= 0 ? 1 : total;
    int flexOf(int b) => ((b / denom) * 1000).round().clamp(0, 1000);
    final fData = flexOf(dataBytes);
    final fCache = flexOf(cacheBytes);
    final fOther = flexOf(otherBytes);
    final fFree = (1000 - fData - fCache - fOther).clamp(0, 1000);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (fData > 0)
              Expanded(
                flex: fData,
                child: const ColoredBox(color: McTokens.accent),
              ),
            if (fCache > 0)
              Expanded(
                flex: fCache,
                child: const ColoredBox(color: McTokens.warn),
              ),
            if (fOther > 0)
              Expanded(
                flex: fOther,
                child: ColoredBox(
                  color: McTokens.textMuted.withValues(alpha: 0.55),
                ),
              ),
            if (fFree > 0)
              Expanded(
                flex: fFree,
                child: const ColoredBox(color: McTokens.glassFill),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: McText.caption.muted),
      ],
    );
  }
}

class _StorageDirDetailSheet extends StatefulWidget {
  const _StorageDirDetailSheet({required this.api, required this.dir});

  final SettingsApi api;
  final StorageDir dir;

  @override
  State<_StorageDirDetailSheet> createState() => _StorageDirDetailSheetState();
}

class _StorageDirDetailSheetState extends State<_StorageDirDetailSheet> {
  bool _busy = false;

  Future<void> _runClean(String mode) async {
    final isOrphans = mode == 'orphans';
    final ok = await confirmDialog(
      context,
      title: isOrphans
          ? '清理「${widget.dir.title}」孤立残留'
          : '清空「${widget.dir.title}」全部内容',
      message: isOrphans
          ? '仅删除已无对应媒体条目的孤立文件，不影响现有正常缓存。'
          : (widget.dir.rebuildCost.toLowerCase() == 'expensive'
              ? '该目录重建成本较高，清空后相关预览/缓存将按需重新生成，确认清空吗？'
              : '将删除该目录下的全部缓存文件，不会影响原始影音文件。'),
      confirmLabel: isOrphans ? '清理孤立项' : '确认清空',
      destructive: !isOrphans,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await widget.api.cleanStorage(widget.dir.key, mode: mode);
      if (!mounted) return;
      final parts = <String>[
        '释放 ${mcFormatBytes(res.freedBytes)}',
        '移除 ${res.removed} 项',
        if (res.skippedBusy > 0) '跳过占用中 ${res.skippedBusy} 项',
      ];
      McToast.success('清理完成：${parts.join('，')}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) McToast.error('清理失败：${settingsErrorText(e)}');
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dir;
    final expensive = d.rebuildCost.toLowerCase() == 'expensive';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.title.isEmpty ? d.key : d.title,
                  style: McText.titleSm,
                ),
              ),
              Text(
                mcFormatBytes(d.bytes),
                style: McText.sub.copyWith(
                  color: McTokens.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (d.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.description, style: McText.sub.muted),
          ],
          if (d.path.isNotEmpty) ...[
            const SizedBox(height: 12),
            SettingsCopyBox(label: '目录路径', value: d.path),
          ],
          if (expensive) ...[
            const SizedBox(height: 12),
            const SettingsNoticeBanner(
              tone: SettingsTone.warn,
              icon: McIcons.alertCircle,
              title: '重建耗时较长',
              message: '此目录缓存重新生成需要较多 CPU / 磁盘 I/O，如空间充足建议优先使用孤立残留清理。',
            ),
          ],
          const SizedBox(height: 16),
          if (d.orphanAware) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _runClean('orphans'),
              icon: const Icon(McIcons.eraser, size: 16),
              label: const Text('仅清理孤立残留（推荐）'),
            ),
            const SizedBox(height: 8),
          ],
          if (d.clearable)
            FilledButton.icon(
              onPressed: _busy ? null : () => _runClean('all'),
              style: FilledButton.styleFrom(
                backgroundColor: McTokens.danger,
              ),
              icon: const Icon(McIcons.trash2, size: 16),
              label: Text(_busy ? '清理中…' : '清空全部缓存'),
            )
          else
            Text(
              '该目录包含核心持久化数据，不可直接清空。',
              textAlign: TextAlign.center,
              style: McText.caption.muted,
            ),
        ],
      ),
    );
  }
}
