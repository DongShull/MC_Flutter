import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/subscriptions_api.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/session/permissions.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../state/subscription_events.dart';
import '../state/subscription_index.dart';
import '../widgets/activity_timeline.dart';
import '../widgets/media_source_annotation_sheet.dart';
import '../widgets/smart_defaults_sheet.dart';
import '../widgets/subscription_dialogs.dart';
import '../widgets/tracking_list.dart';
import '../widgets/upgrade_run_sheet.dart';

/// 订阅详情分析页（1:1 对齐 iOS `SubscriptionDetailView.swift`）：
/// - 摘要卡：海报/片名/原名/时间 → 配置事实格 → `episode_windows` 说明 → 三色进度条 → 3 键操作栏；
/// - 实时轮询：1.5s `forecast_pending`（上限 40 次）/ 5s 实时下载进度 / 30s 静默全量刷新；
/// - 搜索轮次摘要 → 按季折叠 5/6 站里程碑链（含智能选源 + 片源标注）→ 排查记录折叠时间线；
/// - 成员 vs 管理员取消订阅区分 + 智能原版后追问写入 `smart-memory`。
class SubscriptionDetailPage extends ConsumerStatefulWidget {
  const SubscriptionDetailPage({
    super.key,
    required this.id,
    this.openUpgradeRun = false,
  });

  final int id;
  final bool openUpgradeRun;

  @override
  ConsumerState<SubscriptionDetailPage> createState() =>
      _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState
    extends ConsumerState<SubscriptionDetailPage> {
  SubscriptionView? _detail;
  List<SubActivityView> _activities = const [];
  List<RuleSetView> _ruleSets = const [];
  Map<String, SubscriptionDownloadView> _downloads = const {};

  bool _loading = true;
  bool _busy = false;
  String? _error;

  Set<int> _openSeasons = {};
  bool _seasonsInitialized = false;
  bool _upgradeRunConsumed = false;

  Timer? _forecastTimer;
  int _forecastPolls = 0;
  Timer? _downloadsTimer;
  Timer? _globalTimer;

  McPermissions get _perms => ref.read(permissionsProvider);

  bool get _hasInFlight =>
      _detail?.wanted
          .any((w) => w.status == 'grabbed' || w.status == 'downloaded') ??
      false;

  bool _canTune(SubscriptionView d) => _perms.canSubscribe && d.canManage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    _downloadsTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshDownloads(),
    );
    _globalTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_hasInFlight || _detail?.isSmart == true) {
          _reload(silent: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _forecastTimer?.cancel();
    _downloadsTimer?.cancel();
    _globalTimer?.cancel();
    super.dispose();
  }

  void _syncForecastPolling(bool pending) {
    if (!pending) {
      _forecastTimer?.cancel();
      _forecastTimer = null;
      _forecastPolls = 0;
      return;
    }
    if (_forecastTimer != null) return;
    _forecastPolls = 0;
    _forecastTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) async {
        if (!mounted || _forecastPolls >= 40) {
          _forecastTimer?.cancel();
          _forecastTimer = null;
          return;
        }
        _forecastPolls++;
        try {
          final fresh =
              await ref.read(subscriptionsApiProvider).subscription(widget.id);
          if (!mounted) return;
          setState(() => _detail = fresh);
          if (!fresh.forecastPending) {
            _forecastTimer?.cancel();
            _forecastTimer = null;
          }
        } catch (_) {}
      },
    );
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && _detail == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final api = ref.read(subscriptionsApiProvider);
    try {
      final results = await Future.wait([
        api.subscription(widget.id),
        api.activities(widget.id, limit: 100),
        _perms.canManageSubscriptions
            ? api.ruleSets().catchError((_) => <RuleSetView>[])
            : Future.value(<RuleSetView>[]),
      ]);
      final fresh = results[0] as SubscriptionView;
      final acts = results[1] as List<SubActivityView>;
      final rules = results[2] as List<RuleSetView>;
      if (!mounted) return;
      setState(() {
        _detail = fresh;
        _activities = acts;
        _ruleSets = rules;
        _loading = false;
        _error = null;
        if (!_seasonsInitialized) {
          _openSeasons = WantedLogic.defaultOpenSeasons(fresh.wanted);
          _seasonsInitialized = true;
        }
      });
      _syncForecastPolling(fresh.forecastPending);

      if (_hasInFlight) {
        await _refreshDownloads();
      } else if (_downloads.isNotEmpty && mounted) {
        setState(() => _downloads = const {});
      }

      if (widget.openUpgradeRun &&
          !_upgradeRunConsumed &&
          _canTune(fresh) &&
          mounted) {
        _upgradeRunConsumed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _detail != null) _openUpgradeRun(_detail!);
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_detail == null) {
        setState(() {
          _loading = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_detail == null) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _refreshDownloads() async {
    if (!_hasInFlight || !mounted) return;
    try {
      final list =
          await ref.read(subscriptionsApiProvider).activeDownloads(widget.id);
      if (!mounted) return;
      setState(() {
        _downloads = {
          for (final d in list)
            if (d.infoHash.isNotEmpty) d.infoHash.toLowerCase(): d,
        };
      });
    } catch (_) {}
  }

  void _refreshGlobalIndex() {
    ref.read(subscriptionIndexProvider).invalidate();
    SubscriptionEvents.notifyChanged();
  }

  // ── 操作动作 ──

  Future<void> _searchNow(SubscriptionView detail) async {
    final ok = await showSubsConfirmDialog(
      context,
      title: '立即搜索《${detail.media.title}》？',
      message: '将跳过冷却时间，立即把当前缺失且已可搜索的工单重新排队搜索。',
      confirmTitle: '立即搜索',
      cancelTitle: '返回',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final resetCount =
          await ref.read(subscriptionsApiProvider).searchNow(detail.id);
      McToast.success('已重新排队 $resetCount 个缺口，正在搜索');
      await _reload(silent: true);
    } on ApiException catch (e) {
      McToast.error(e.friendlyMessage);
    } catch (e) {
      McToast.error('触发搜索失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openManualPick(SubscriptionView detail) {
    final also = <String>[
      if ((detail.media.englishTitle ?? '').isNotEmpty &&
          detail.media.englishTitle != detail.media.title)
        detail.media.englishTitle!,
      if ((detail.media.originalTitle ?? '').isNotEmpty &&
          detail.media.originalTitle != detail.media.title &&
          detail.media.originalTitle != detail.media.englishTitle)
        detail.media.originalTitle!,
    ];
    final scope = detail.media.kind == 'movie' ? 'movie' : 'tv';
    final params = <String, String>{
      'q': detail.media.title,
      'tab': 'torrent',
      'scope': scope,
      'for_sub': '${detail.id}',
      if (also.isNotEmpty) 'also': also.join(','),
    };
    final query = Uri(queryParameters: params).query;
    context.push('/search?$query');
  }

  Future<void> _openMore(SubscriptionView detail) async {
    final action = await showSubscriptionManageSheet(
      context,
      detail: detail,
      permissions: _perms,
      busy: _busy,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case SubscriptionManageAction.adjust:
        final saved =
            await showSubscriptionAdjustSheet(context, ref, detail: detail);
        if (mounted && saved == true) {
          _refreshGlobalIndex();
          await _reload(silent: true);
        }
      case SubscriptionManageAction.upgradeRun:
        await _openUpgradeRun(detail);
      case SubscriptionManageAction.toggleFollow:
        await _toggleFollowFuture(detail);
      case SubscriptionManageAction.switchRule:
        await _switchRuleSet(detail);
      case SubscriptionManageAction.smartDefaults:
        final saved = await showSmartDefaultsEditorSheet(context, ref);
        if (mounted && saved == true) {
          await _reload(silent: true);
        }
      case SubscriptionManageAction.togglePause:
        await _togglePause(detail);
      case SubscriptionManageAction.remove:
        await _remove(detail);
    }
  }

  Future<void> _openUpgradeRun(SubscriptionView detail) async {
    final ran = await showUpgradeRunSheet(context, ref, detail: detail);
    if (mounted && ran == true) {
      _refreshGlobalIndex();
      await _reload(silent: true);
    }
  }

  Future<void> _toggleFollowFuture(SubscriptionView detail) async {
    final next = !detail.followFuture;
    setState(() => _busy = true);
    try {
      await ref
          .read(subscriptionsApiProvider)
          .setFollowFuture(detail.id, enabled: next);
      McToast.success(next ? '已开启自动续订' : '已关闭自动续订');
      _refreshGlobalIndex();
      await _reload(silent: true);
    } on ApiException catch (e) {
      McToast.error(e.friendlyMessage);
    } catch (e) {
      McToast.error('设置失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchRuleSet(SubscriptionView detail) async {
    var rules = _ruleSets;
    if (rules.isEmpty) {
      try {
        rules = await ref.read(subscriptionsApiProvider).ruleSets();
      } catch (_) {
        McToast.error('规则组仅管理员可用');
        return;
      }
    }
    if (!mounted) return;
    final switched = await showRuleSetSwitchSheet(
      context,
      ref,
      ruleSets: rules,
      currentId: detail.ruleSetId ?? 0,
      onPick: (id) async {
        await ref
            .read(subscriptionsApiProvider)
            .update(detail.id, {'rule_set_id': id});
      },
    );
    if (mounted && switched == true) {
      McToast.success('已更换规则组');
      _refreshGlobalIndex();
      await _reload(silent: true);
    }
  }

  Future<void> _togglePause(SubscriptionView detail) async {
    final resuming = detail.status == 'paused';
    final ok = await showSubsConfirmDialog(
      context,
      title: resuming
          ? '恢复追踪《${detail.media.title}》？'
          : '暂停追踪《${detail.media.title}》？',
      message: resuming
          ? '恢复后将继续自动搜索并下载缺失资源。'
          : '暂停后将停止自动搜索与投递，已有下载不受影响，可随时恢复。',
      confirmTitle: resuming ? '恢复追踪' : '暂停追踪',
      cancelTitle: '返回',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(subscriptionsApiProvider)
          .setTrackingState(detail.id, paused: !resuming);
      McToast.success(resuming ? '已恢复追踪' : '已暂停追踪');
      _refreshGlobalIndex();
      await _reload(silent: true);
    } on ApiException catch (e) {
      McToast.error(e.friendlyMessage);
    } catch (e) {
      McToast.error('操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(SubscriptionView detail) async {
    if (_perms.isAdmin) {
      final result = await showSubscriptionCancelSheet(
        context,
        ref,
        subscriptionId: detail.id,
        title: detail.media.title,
      );
      if (!mounted || result == null || !result.confirmed) return;
      McToast.success(
        result.cleanupJobId != null ? '已取消订阅，清理任务已在后台执行' : '订阅已取消',
      );
      ref.read(subscriptionIndexProvider).remove(detail.id);
      SubscriptionEvents.notifyChanged();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/subscriptions');
      }
      return;
    }

    // 成员取消关注：走 DELETE /following（绝不调用管理员 DELETE）
    final ok = await showSubsConfirmDialog(
      context,
      title: '取消关注《${detail.media.title}》？',
      message: '只会取消你对这部作品的订阅关注，不影响其他成员与媒体库已有内容。',
      confirmTitle: '取消订阅',
      cancelTitle: '先不',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(subscriptionsApiProvider)
          .unsubscribeFollowing(detail.id);
      if (!mounted) return;
      McToast.success('已取消订阅');
      ref.read(subscriptionIndexProvider).remove(detail.id);
      SubscriptionEvents.notifyChanged();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/subscriptions');
      }
    } on ApiException catch (e) {
      McToast.error(e.friendlyMessage);
    } catch (e) {
      McToast.error('取消失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _annotateSeason(SubscriptionView detail, int season) async {
    final msg = await showMediaSourceAnnotationSheet(
      context,
      ref,
      mediaItemId: detail.media.mediaItemId,
      seasonNumber: season,
      isMovie: detail.media.kind == 'movie',
    );
    if (!mounted || msg == null) return;
    try {
      await ref.read(subscriptionsApiProvider).upgradeRun(detail.id);
      McToast.success('$msg，已重新排期洗版');
    } catch (_) {
      McToast.success(msg);
    }
    await _reload(silent: true);
  }

  /// 智能订阅点击「这次先下原版」后，追问管理员是否看得懂该语言并写入 `smart-memory`。
  Future<void> _handleOriginalRequested() async {
    final detail = _detail;
    if (detail == null || !_perms.isAdmin) return;
    final sub = detail.smartSubtitle;
    if (sub == null || sub.understood) return;

    final yes = await showSubsConfirmDialog(
      context,
      title: '你看得懂${sub.languageLabel}吗？',
      message: '如果看得懂${sub.languageLabel}，以后遇到同类作品将不再等待中文字幕。',
      confirmTitle: '看得懂，记住它',
      cancelTitle: '仅这一次',
    );
    if (!yes || !mounted) return;
    try {
      final api = ref.read(subscriptionsApiProvider);
      final memory = await api.getSmartMemory();
      if (memory != null) {
        await api.updateSmartMemory(
          SmartMemoryPatch(
            revision: memory.revision,
            language: sub.language,
            understood: true,
          ),
        );
        McToast.success('已将${sub.languageLabel}记为看得懂的语言');
        await _reload(silent: true);
      }
    } on ApiException catch (e) {
      McToast.error(e.friendlyMessage);
    } catch (e) {
      McToast.error('更新智能记忆失败：$e');
    }
  }

  // ── 视图构建 ──

  String _statusLabel(SubscriptionView detail) {
    final base = subscriptionStatusLabel(detail);
    final upgrading = detail.progress.upgrading;
    final upText = detail.progress.total > 1 ? '洗版中 $upgrading' : '洗版中';
    if (detail.status == 'completed' && upgrading > 0) {
      return '$base · $upText';
    }
    if (detail.status == 'active' &&
        upgrading > 0 &&
        detail.progress.wanted == 0) {
      return '$base · $upText';
    }
    return base;
  }

  String _ruleSetFact(SubscriptionView detail) {
    final rule =
        _ruleSets.where((r) => r.id == detail.ruleSetId).firstOrNull;
    if (rule == null) return '#${detail.ruleSetId ?? 0}';
    final target = rule.upgradeTarget;
    return target != null ? '${rule.name} · 洗到 $target' : rule.name;
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () => context.canPop()
                ? context.pop()
                : context.go('/subscriptions'),
            title: detail?.media.title ?? '订阅详情',
            titleVisible: true,
            trailing: [
              if (detail != null &&
                  (_perms.canSubscribe || _perms.canManageSubscriptions))
                McGlassIconButton(
                  icon: McIcons.more,
                  tooltip: '更多操作',
                  onTap: () => _openMore(detail),
                ),
            ],
          ),
          Expanded(
            child: _loading && detail == null
                ? const _SubscriptionDetailSkeleton()
                : _error != null && detail == null
                    ? McErrorView(
                        text: _error!,
                        onRetry: () => _reload(),
                      )
                    : detail == null
                        ? const SizedBox.shrink()
                        : RefreshIndicator(
                            color: McTokens.accentStrong,
                            backgroundColor: McTokens.surfaceSolid,
                            onRefresh: () => _reload(silent: true),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                10,
                                McTokens.pagePadding,
                                40,
                              ),
                              children: [
                                _buildSummaryCard(detail),
                                if (detail.smartNotice != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color:
                                          SubsColor.warn.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                        McTokens.cardRadius,
                                      ),
                                      border: Border.all(
                                        color: SubsColor.warn
                                            .withValues(alpha: 0.38),
                                      ),
                                    ),
                                    child: Text(
                                      detail.smartNotice!,
                                      style: McText.sub
                                          .copyWith(color: SubsColor.warn),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                SearchRoundBar(
                                  activities: _activities,
                                  wanted: detail.wanted,
                                ),
                                const SizedBox(height: 14),
                                TrackingList(
                                  sub: detail,
                                  downloads: _downloads,
                                  failures:
                                      WantedLogic.pendingFailures(_activities),
                                  canAnnotate: _perms.isAdmin,
                                  canTune: _canTune(detail),
                                  openSeasons: _openSeasons,
                                  onToggleSeason: (season) => setState(() {
                                    if (!_openSeasons.remove(season)) {
                                      _openSeasons.add(season);
                                    }
                                  }),
                                  onAnnotate: (season) =>
                                      _annotateSeason(detail, season),
                                  onSmartChanged: () => _reload(silent: true),
                                  onSmartOriginalRequested:
                                      _handleOriginalRequested,
                                ),
                                const SizedBox(height: 6),
                                ActivityLogSection(activities: _activities),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(SubscriptionView detail) {
    final isMovie = detail.media.kind == 'movie';
    final statusColor = detail.status == 'active'
        ? SubsColor.infoSoft
        : subscriptionStatusColor(detail);
    final mediaRoute =
        '/discover/title?ref=${Uri.encodeComponent('tmdb:${detail.media.kind}:${detail.media.tmdbId ?? 0}')}';
    final windowNotes = SubsFormat.fromWindowNotes(detail.episodeWindows);

    final facts = <({String label, String value})>[
      (
        label: '收录范围',
        value: isMovie
            ? '正片'
            : (detail.selectedSeasons.isEmpty
                ? '仅追新集'
                : SubsFormat.seasonList(detail.selectedSeasons)),
      ),
      if (!isMovie)
        (
          label: '自动续订',
          value: detail.followFuture ? '已开启' : '未开启',
        ),
      if (detail.isSmart && detail.smartPreferences != null) ...[
        (
          label: '智能目标',
          value: detail.smartPreferences!.targetLabel,
        ),
        (
          label: '后续洗版',
          value: detail.smartPreferences!.allowUpgrade
              ? (isMovie ? '达标后停止' : '达标后停止')
              : '关闭',
        ),
        if (detail.smartSubtitle != null)
          (
            label: '字幕要求',
            value: detail.smartSubtitle!.understood
                ? '不需要字幕'
                : detail.smartSubtitle!.line.split(' · ').last,
          ),
      ] else if (!detail.isSmart && _perms.canManageSubscriptions)
        (
          label: '规则组',
          value: _ruleSetFact(detail),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: McTokens.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶行：类型 + 状态点
          Row(
            children: [
              Text(
                isMovie ? '电影订阅' : '剧集订阅',
                style: McText.micro.copyWith(
                  letterSpacing: 2,
                  color: McTokens.accent2,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _statusLabel(detail),
                style: McText.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 海报与片名身份
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => context.push(mediaRoute),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 76,
                    height: 114,
                    color: McTokens.posterPlaceholder,
                    child: (detail.media.posterUrl ?? '').isNotEmpty
                        ? CachedNetworkImage(
                            httpHeaders: mcImageHeaders(),
                            imageUrl: McImageUrls.resolve(
                              detail.media.posterUrl,
                              widthPx: 240,
                            ),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          )
                        : const Icon(
                            McIcons.film,
                            color: McTokens.textFaint,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push(mediaRoute),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: detail.media.title,
                          style: McText.title,
                          children: [
                            if (detail.media.year != null)
                              TextSpan(
                                text: '  ${detail.media.year}',
                                style: McText.sub.faint.tabular,
                              ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((detail.media.originalTitle ?? '').isNotEmpty &&
                          detail.media.originalTitle !=
                              detail.media.title) ...[
                        const SizedBox(height: 4),
                        Text(
                          detail.media.originalTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.caption.muted,
                        ),
                      ],
                      if (detail.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '订阅于 ${SubsFormat.dateTime(detail.createdAt)}',
                          style: McText.micro.faint.tabular,
                        ),
                      ],
                      if (detail.smartQualityNote != null &&
                          detail.smartQualityNote!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detail.smartQualityNote!,
                          style: McText.micro.copyWith(color: SubsColor.info),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: McTokens.line),
          const SizedBox(height: 12),

          // 配置事实网格
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final f in facts)
                SizedBox(
                  width: detail.isSmart ? 140 : 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label, style: McText.micro.faint),
                      const SizedBox(height: 3),
                      Text(
                        f.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.semibold
                            .copyWith(color: McTokens.text),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: McTokens.line),

          for (final note in windowNotes) ...[
            const SizedBox(height: 8),
            Text(note, style: McText.micro.faint),
          ],

          const SizedBox(height: 12),
          _ProgressStrip(progress: detail.progress, isMovie: isMovie),

          const SizedBox(height: 14),
          _buildActionBar(detail),
        ],
      ),
    );
  }

  Widget _buildActionBar(SubscriptionView detail) {
    final tune = _canTune(detail);
    final showSearch =
        tune && detail.progress.wanted > 0 && detail.status != 'paused';
    final showManual = _perms.canGrabForSubscription &&
        tune &&
        (detail.progress.wanted > 0 ||
            detail.wanted.any((w) => w.upgrade != null));
    final showMore = _perms.canSubscribe || _perms.canManageSubscriptions;

    if (!showSearch && !showManual && !showMore) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (showSearch) ...[
          Expanded(
            child: McActionPill(
              label: '立即搜索',
              icon: McIcons.refreshS,
              primary: true,
              expanded: true,
              height: 40,
              busy: _busy,
              onTap: _busy ? null : () => _searchNow(detail),
            ),
          ),
          if (showManual || showMore) const SizedBox(width: 8),
        ],
        if (showManual) ...[
          Expanded(
            child: McActionPill(
              label: '手动选种',
              icon: McIcons.search,
              primary: false,
              expanded: true,
              height: 40,
              onTap: _busy ? null : () => _openManualPick(detail),
            ),
          ),
          if (showMore) const SizedBox(width: 8),
        ],
        if (showMore)
          Expanded(
            child: McActionPill(
              label: '更多',
              icon: McIcons.more,
              primary: false,
              expanded: true,
              height: 40,
              onTap: _busy ? null : () => _openMore(detail),
            ),
          ),
      ],
    );
  }
}

/// 三色进度条（1:1 对齐 iOS `ProgressStrip`：绿 = 已入库、青 = 洗版中、蓝 = 下载/整理中、暗底 = 仍缺失）。
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.progress, required this.isMovie});

  final ProgressView progress;
  final bool isMovie;

  @override
  Widget build(BuildContext context) {
    final denom = progress.total > 0 ? progress.total : 1;
    final inPipeline = progress.grabbed + progress.downloaded;
    final upgrading = progress.upgrading;
    final settled =
        (progress.imported - upgrading).clamp(0, progress.imported);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '收录进度',
              style: McText.caption.semibold.copyWith(color: McTokens.text),
            ),
            const Spacer(),
            Text(
              isMovie
                  ? '${progress.imported} / ${progress.total} 部'
                  : '${progress.imported} / ${progress.total} 集',
              style: McText.caption.muted.tabular,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            color: Colors.white.withValues(alpha: 0.12),
            child: LayoutBuilder(
              builder: (_, c) {
                final w = c.maxWidth;
                return Row(
                  children: [
                    if (settled > 0)
                      Container(
                        width: w * (settled / denom).clamp(0.0, 1.0),
                        color: SubsColor.ok,
                      ),
                    if (upgrading > 0)
                      Container(
                        width: w * (upgrading / denom).clamp(0.0, 1.0),
                        color: SubsColor.upgrade,
                      ),
                    if (inPipeline > 0)
                      Container(
                        width: w * (inPipeline / denom).clamp(0.0, 1.0),
                        color: SubsColor.infoSoft,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _legend(SubsColor.ok, '已入库 $settled'),
            if (upgrading > 0) _legend(SubsColor.upgrade, '洗版中 $upgrading'),
            _legend(SubsColor.info, '下载中 $inPipeline'),
            _legend(Colors.white.withValues(alpha: 0.24), '缺失 ${progress.wanted}'),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: McText.micro.faint.tabular),
      ],
    );
  }
}

class _SubscriptionDetailSkeleton extends StatelessWidget {
  const _SubscriptionDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        10,
        McTokens.pagePadding,
        40 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            McShimmerBox(width: 78, height: 114, radius: 10),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  McShimmerBox(width: 160, height: 20, radius: 6),
                  SizedBox(height: 10),
                  McShimmerBox(width: 120, height: 14, radius: 5),
                  SizedBox(height: 10),
                  McShimmerBox(height: 32, radius: 10),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 18),
        McShimmerBox(height: 76, radius: McTokens.cardRadius),
        SizedBox(height: 14),
        McShimmerBox(height: 156, radius: McTokens.cardRadius),
        SizedBox(height: 14),
        McShimmerBox(height: 120, radius: McTokens.cardRadius),
      ],
    );
  }
}
