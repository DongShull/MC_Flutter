import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../api/mc_client.dart';
import '../api/session_providers.dart';
import '../api/subscriptions_api.dart';
import '../image/image_urls.dart';
import '../session/permissions.dart';
import 'mc_chrome.dart';
import 'mc_glass.dart';
import 'mc_icons.dart';
import 'rule_set_editor_sheet.dart';
import 'state_views.dart';
import 'theme.dart';

/// 订阅创建毛玻璃弹层返回结果（保持与全站调用方兼容）。
enum SubscribeSheetOutcome { created, managed }

/// 全站唯一订阅入口：支持智能订阅、规则组、豆瓣歧义消解、投递路由预检、洗版模式与已订阅内联取消。
Future<SubscribeSheetOutcome?> showSubscribeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String titleRef,
  bool upgrade = false,
  String? initialTitle,
  String? initialPosterUrl,
}) {
  return showMcSheet<SubscribeSheetOutcome>(
    context: context,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
      ),
      child: _SubscribeSheet(
        titleRef: titleRef,
        upgrade: upgrade,
        initialTitle: initialTitle,
        initialPosterUrl: initialPosterUrl,
      ),
    ),
  );
}

/// 弹出管理员智能订阅默认偏好与记忆编辑器（`GET/PUT smart-defaults` + `GET/PATCH smart-memory`）。
Future<bool?> showSmartDefaultsEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onSaved,
}) {
  return showMcSheet<bool>(
    context: context,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
      ),
      child: SmartDefaultsEditorSheet(onSaved: onSaved),
    ),
  );
}

class _SubscribeSheet extends ConsumerStatefulWidget {
  const _SubscribeSheet({
    required this.titleRef,
    this.upgrade = false,
    this.initialTitle,
    this.initialPosterUrl,
  });

  final String titleRef;
  final bool upgrade;
  final String? initialTitle;
  final String? initialPosterUrl;

  @override
  ConsumerState<_SubscribeSheet> createState() => _SubscribeSheetState();
}

class _SubscribeSheetState extends ConsumerState<_SubscribeSheet> {
  late final SubscriptionsApi _api = SubscriptionsApi(
    McClient(session: ref.read(sessionStoreProvider)),
  );

  bool _loading = true;
  SubscribePreview? _prepared;
  String? _error;

  List<SubscribeRuleSetOption> _ruleSets = const [];
  List<SubscribeLibraryOption> _libraries = const [];
  final Set<int> _selectedSeasons = {};
  bool _followFuture = false;
  int? _ruleSetId;
  int? _libraryId;

  String _selectionMode = 'smart'; // smart | rules
  SmartChoice _smartChoice = const SmartChoice();
  bool _autoOpenedSmartSetup = false;

  DispatchPreviewView? _dispatchPreview;
  ({int libraryId, String? reason})? _routedLibrary;
  ({int ruleSetId, String reason})? _routedRule;

  UpgradeRunView? _upgradeReport;
  bool _submitting = false;

  McPermissions get _perms => ref.read(permissionsProvider);
  bool get _canManage => _perms.canManageSubscriptions;

  String? get _requestKind {
    final parts = widget.titleRef.split(':');
    if (parts.length >= 3 && (parts[1] == 'movie' || parts[1] == 'tv')) {
      return parts[1];
    }
    return null;
  }

  String get _kind => _prepared?.kind ?? _requestKind ?? 'movie';

  String get _displayTitle =>
      _prepared?.title ?? widget.initialTitle ?? '';

  List<SubscribeRuleSetOption> get _selectableRules => widget.upgrade
      ? _ruleSets.where((r) => r.upgradeTarget != null).toList()
      : _ruleSets;

  SubscribeRuleSetOption? get _pickedRule {
    for (final r in _selectableRules) {
      if (r.id == _ruleSetId) return r;
    }
    return null;
  }

  bool get _canSubmit {
    final p = _prepared;
    if (p == null || !p.isReady || p.existingSubscriptionId != null || _submitting) {
      return false;
    }
    if (_selectionMode == 'smart' && p.smart?.configured != true) {
      return false;
    }
    if (widget.upgrade && _canManage && _pickedRule == null) {
      return false;
    }
    if (_kind == 'movie') return true;
    return _selectedSeasons.isNotEmpty || _followFuture;
  }

  @override
  void initState() {
    super.initState();
    _selectionMode = widget.upgrade ? 'rules' : 'smart';
    _runPrepare(widget.titleRef);
  }

  Future<void> _runPrepare(String refStr) async {
    setState(() {
      _loading = true;
      _prepared = null;
      _error = null;
      _smartChoice = const SmartChoice();
      _selectionMode = widget.upgrade ? 'rules' : 'smart';
      _upgradeReport = null;
      _dispatchPreview = null;
      _routedLibrary = null;
      _routedRule = null;
    });

    try {
      final previewFuture = _api.titlePreview(refStr);
      final rulesFuture =
          _canManage ? _api.ruleSets() : Future.value(<SubscribeRuleSetOption>[]);
      final initialKind = _requestKind;
      final libsFuture = (_canManage && initialKind != null)
          ? _api.libraries(kind: initialKind)
          : Future.value(<SubscribeLibraryOption>[]);

      final results = await Future.wait([previewFuture, rulesFuture, libsFuture]);
      final result = results[0] as SubscribePreview;
      final rules = results[1] as List<SubscribeRuleSetOption>;
      var libs = results[2] as List<SubscribeLibraryOption>;

      final resolvedKind = result.kind ?? initialKind ?? 'movie';
      if (_canManage && resolvedKind != initialKind) {
        libs = await _api.libraries(kind: resolvedKind);
      }

      int? pickedLibrary =
          libs.where((l) => l.isDefault).firstOrNull?.id ?? libs.firstOrNull?.id;
      int? pickedRuleId;
      String? pickedRuleReason;
      ({int libraryId, String? reason})? routedLib;
      ({int ruleSetId, String reason})? routedRule;

      if (_canManage && result.isReady && result.tmdbId != null) {
        try {
          final routing = await _api.downloadRoutingPreview(
            kind: resolvedKind,
            tmdbId: result.tmdbId,
          );
          if (routing.libraryId != null &&
              libs.any((l) => l.id == routing.libraryId)) {
            pickedLibrary = routing.libraryId;
            routedLib = (libraryId: routing.libraryId!, reason: routing.routeReason);
          }
          if (routing.ruleSetId != null) {
            pickedRuleId = routing.ruleSetId;
            if (routing.ruleSetMatched == true &&
                routing.ruleSetReason != null &&
                routing.ruleSetReason!.isNotEmpty) {
              pickedRuleReason = routing.ruleSetReason;
            }
          }
        } catch (_) {}
      }

      final candidates = widget.upgrade
          ? rules.where((r) => r.upgradeTarget != null).toList()
          : rules;
      final scopedRule = candidates.where((r) => r.id == pickedRuleId).firstOrNull;
      final finalRule = scopedRule ??
          candidates.where((r) => r.isDefault).firstOrNull ??
          candidates.firstOrNull;
      if (scopedRule != null && pickedRuleReason != null) {
        routedRule = (ruleSetId: scopedRule.id, reason: pickedRuleReason);
      }

      // 默认季：洗版按库存预填；豆瓣季条目采信 suggested_seasons；否则全部已播正季（排除 S00）
      final List<int> defaultSeasons;
      if (widget.upgrade) {
        defaultSeasons = result.seasons
            .where((s) => (s.ownedCount ?? 0) > 0)
            .map((s) => s.number)
            .toList();
      } else if (result.suggestedSeasons.isNotEmpty) {
        defaultSeasons = [...result.suggestedSeasons];
      } else {
        defaultSeasons = result.seasons
            .where((s) => s.number > 0 && s.airedCount > 0)
            .map((s) => s.number)
            .toList();
      }

      // 仅在播剧（Returning Series）默认开自动续订
      final follow = !widget.upgrade &&
          resolvedKind == 'tv' &&
          result.mediaStatus == 'Returning Series';

      // 服务器早于 0.42.0 不带 smart 摘要：自动回退规则模式
      final mode = (result.isReady && result.smart == null)
          ? 'rules'
          : (widget.upgrade ? 'rules' : 'smart');

      if (!mounted) return;
      setState(() {
        _loading = false;
        _prepared = result;
        _ruleSets = rules;
        _libraries = libs;
        _libraryId = pickedLibrary;
        _ruleSetId = finalRule?.id;
        _routedLibrary = routedLib;
        _routedRule = routedRule;
        _selectedSeasons
          ..clear()
          ..addAll(defaultSeasons);
        _followFuture = follow;
        _selectionMode = mode;
      });

      // 刷新投递目录预览（带 title/year 供服务端渲染 entry_dir）
      if (_canManage && result.isReady && pickedLibrary != null) {
        await _refreshDispatchPreview();
      }

      // 首次使用智能订阅：管理员自动打开智能默认偏好编辑器
      if (mounted &&
          !_autoOpenedSmartSetup &&
          mode == 'smart' &&
          result.isReady &&
          result.existingSubscriptionId == null &&
          result.smart != null &&
          !result.smart!.configured &&
          result.smart!.canEdit) {
        _autoOpenedSmartSetup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openSmartDefaults();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '预检失败：$e';
        });
      }
    }
  }

  Future<void> _refreshDispatchPreview() async {
    final p = _prepared;
    if (!_canManage || _libraryId == null || p == null || !p.isReady) {
      if (mounted) setState(() => _dispatchPreview = null);
      return;
    }
    try {
      final dp = await _api.downloadRoutingPreview(
        kind: _kind,
        libraryId: _libraryId,
        tmdbId: p.tmdbId,
        title: p.title,
        year: p.year,
      );
      if (mounted) setState(() => _dispatchPreview = dp);
    } catch (_) {}
  }

  /// 智能设置保存或 409 冲突后，仅刷新 `PrepareView.smart`，保留已选季与目标库。
  Future<void> _refreshSmartPlan() async {
    final p = _prepared;
    if (p == null) return;
    final refStr =
        p.tmdbId != null ? 'tmdb:$_kind:${p.tmdbId}' : widget.titleRef;
    try {
      final next = await _api.titlePreview(refStr);
      if (!mounted) return;
      setState(() {
        _smartChoice = const SmartChoice();
        _prepared = p.copyWith(smart: next.smart);
        if (next.smart == null && _selectionMode == 'smart') {
          _selectionMode = 'rules';
        }
      });
    } catch (_) {}
  }

  Future<void> _openSmartDefaults() async {
    final saved = await showSmartDefaultsEditorSheet(context, ref);
    if (mounted && saved == true) {
      await _refreshSmartPlan();
    }
  }

  Future<void> _openSmartQuality(SmartPlanView plan) async {
    final updated = await showMcSheet<SmartChoice>(
      context: context,
      builder: (_) => SmartQualitySheet(plan: plan, initial: _smartChoice),
    );
    if (mounted && updated != null) {
      setState(() => _smartChoice = updated);
    }
  }

  Future<void> _createRuleSet() async {
    final saved = await showRuleSetEditorSheet(context, ref);
    if (mounted && saved != null) {
      setState(() {
        _ruleSets = [..._ruleSets, saved];
        if (!widget.upgrade || saved.upgradeTarget != null) {
          _ruleSetId = saved.id;
        }
      });
    }
  }

  Future<void> _submit() async {
    final p = _prepared;
    if (!_canSubmit || p == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final smart = _selectionMode == 'smart' ? p.smart : null;
      final choice = smart != null ? _smartChoice.payloadFor(smart) : null;
      final canonicalRef = p.tmdbId != null
          ? 'tmdb:$_kind:${p.tmdbId}'
          : widget.titleRef;
      final sourceRef =
          widget.titleRef.startsWith('douban:') ? widget.titleRef : null;

      final createdId = await _api.createSubscription(
        titleRef: canonicalRef,
        sourceTitleRef: sourceRef,
        selectedSeasons: _selectedSeasons.toList()..sort(),
        followFuture: _followFuture,
        selectionMode: _selectionMode,
        ruleSetId: (_canManage && _selectionMode == 'rules') ? _ruleSetId : null,
        libraryId: _canManage ? _libraryId : null,
        smartProfileRevision: smart?.profileRevision,
        smartLanguageAnswer: choice?.language,
        smartResolution: choice?.resolution,
        smartSource: choice?.source,
        smartScope: choice?.scope,
        smartMemoryRevision: choice?.memoryRevision,
      );

      if (widget.upgrade && createdId != null) {
        try {
          final report = await _api.upgradeRun(
            createdId,
            ruleSetId: _canManage ? _ruleSetId : null,
          );
          if (mounted) {
            setState(() {
              _submitting = false;
              _upgradeReport = report;
            });
          }
          return;
        } on ApiException catch (e) {
          if (mounted) {
            setState(() {
              _submitting = false;
              _error = '订阅已创建，但洗版触发失败：${e.friendlyMessage}';
            });
          }
          return;
        } catch (e) {
          if (mounted) {
            setState(() {
              _submitting = false;
              _error = '订阅已创建，但洗版触发失败：$e';
            });
          }
          return;
        }
      }

      if (mounted) Navigator.of(context).pop(SubscribeSheetOutcome.created);
    } on ApiException catch (e) {
      if (e.httpStatus == 409) {
        await _refreshSmartPlan();
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = '智能偏好或记忆已在别处更新，已自动刷新为最新方案，请再次确认。';
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '订阅失败：$e';
        });
      }
    }
  }

  Future<void> _unsubscribeExisting(int existingId) async {
    if (_perms.isAdmin) {
      final removed = await showAdminCancelSubscriptionSheet(
        context,
        ref,
        subscriptionId: existingId,
        title: _displayTitle,
      );
      if (mounted && removed == true) {
        McToast.success('订阅已取消');
        Navigator.of(context).pop(SubscribeSheetOutcome.managed);
      }
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.unsubscribeFollowing(existingId);
      if (mounted) {
        McToast.success('已取消关注订阅');
        Navigator.of(context).pop(SubscribeSheetOutcome.managed);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '取消失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_upgradeReport != null) {
      return _buildUpgradeReportView(_upgradeReport!);
    }

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_displayTitle.isNotEmpty || widget.initialPosterUrl != null)
              _headerCard(loading: true),
            const SizedBox(height: 18),
            const SizedBox(height: 90, child: McLoadingView()),
          ],
        ),
      );
    }

    final p = _prepared;
    if (p == null || p.notFound) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p == null ? (_error ?? '预检失败') : 'TMDB 未收录该作品，暂无法订阅',
              style: McText.titleSm,
            ),
            const SizedBox(height: 16),
            McActionPill(
              label: '关闭',
              primary: false,
              expanded: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    if (p.isAmbiguous) {
      return _buildAmbiguousView(p);
    }

    if (p.existingSubscriptionId != null) {
      return _buildExistingView(p, p.existingSubscriptionId!);
    }

    return _buildReadyForm(p);
  }

  Widget _headerCard({bool loading = false}) {
    final p = _prepared;
    final posterUrl = p?.posterUrl ?? widget.initialPosterUrl;
    final kindLabel = _kind == 'movie' ? '电影' : '剧集';
    final metaParts = [
      if (p?.year != null) '${p!.year}',
      if (p?.kind != null || _requestKind != null) kindLabel,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 54,
            height: 80,
            color: McTokens.surfaceInset,
            child: (posterUrl != null && posterUrl.isNotEmpty)
                ? CachedNetworkImage(
                    httpHeaders: mcImageHeaders(),
                    imageUrl: McImageUrls.resolve(posterUrl, widthPx: 180),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  )
                : const Icon(McIcons.film, size: 22, color: McTokens.textFaint),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayTitle.isEmpty ? '正在读取作品信息…' : _displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: McText.titleSm,
              ),
              if (metaParts.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(metaParts.join(' · '), style: McText.caption.muted),
              ],
              if (loading) ...[
                const SizedBox(height: 4),
                Text('正在读取季集与订阅方案…', style: McText.micro.faint),
              ] else if (p?.movieOwned == true &&
                  p?.existingSubscriptionId == null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(McIcons.check, size: 13, color: McTokens.ok),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.upgrade ? '媒体库已有本片，将体检并洗版' : '媒体库已有本片，不会重复下载',
                        style: McText.micro.copyWith(color: McTokens.ok),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmbiguousView(SubscribePreview p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(),
          const SizedBox(height: 14),
          const Text('找到多部同名作品，请选择对应的 TMDB 条目', style: McText.sub),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: p.candidates.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: 0.54,
            ),
            itemBuilder: (_, i) {
              final c = p.candidates[i];
              return GestureDetector(
                onTap: () => _runPrepare(c.titleRef),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          color: McTokens.surfaceInset,
                          child: (c.posterUrl != null && c.posterUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  httpHeaders: mcImageHeaders(),
                                  imageUrl: McImageUrls.resolve(
                                    c.posterUrl,
                                    widthPx: 240,
                                  ),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                )
                              : const Icon(
                                  McIcons.film,
                                  size: 24,
                                  color: McTokens.textFaint,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.caption.semibold
                          .copyWith(color: McTokens.text),
                    ),
                    Text(
                      c.year?.toString() ?? '年份未知',
                      style: McText.micro.faint,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExistingView(SubscribePreview p, int existingId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                McIcons.checkCircleFill,
                size: 18,
                color: McTokens.ok,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _kind == 'movie' ? '这部电影已在订阅中' : '这部剧集已在追更队列中',
                  style: McText.sub.copyWith(color: McTokens.text),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ],
          const SizedBox(height: 18),
          McActionPill(
            label: widget.upgrade ? '前往详情触发洗版' : '管理订阅',
            icon: widget.upgrade ? McIcons.aiStarFill : McIcons.setting1,
            primary: true,
            expanded: true,
            height: 44,
            onTap: () => Navigator.of(context).pop(SubscribeSheetOutcome.managed),
          ),
          const SizedBox(height: 10),
          McActionPill(
            label: _submitting ? '正在取消…' : '取消订阅',
            icon: McIcons.linkUnlink,
            primary: false,
            tone: McGlassTone.danger,
            expanded: true,
            height: 42,
            busy: _submitting,
            onTap: _submitting ? null : () => _unsubscribeExisting(existingId),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyForm(SubscribePreview p) {
    final isMovie = _kind == 'movie';
    final plan = p.smart;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerCard(),
                if (widget.upgrade) ...[
                  const SizedBox(height: 8),
                  Text(
                    '创建订阅后立即体检现有库存并触发一轮洗版。',
                    style: McText.caption.muted,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: McTokens.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: McTokens.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: McText.caption.copyWith(color: McTokens.danger),
                    ),
                  ),
                ],

                // 选择模式切换（非洗版模式且服务端支持智能订阅时）
                if (!widget.upgrade && (plan != null || _canManage)) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (plan != null) ...[
                        McChip(
                          label: '智能选择',
                          icon: McIcons.aiStarFill,
                          selected: _selectionMode == 'smart',
                          compact: true,
                          onTap: () => setState(() => _selectionMode = 'smart'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      McChip(
                        label: '指定规则组',
                        icon: McIcons.listSettings2,
                        selected: _selectionMode == 'rules',
                        compact: true,
                        onTap: () => setState(() => _selectionMode = 'rules'),
                      ),
                    ],
                  ),
                ],

                // 智能选择方案卡片
                if (_selectionMode == 'smart') ...[
                  const SizedBox(height: 12),
                  SmartPlanSection(
                    plan: plan,
                    choice: _smartChoice,
                    onChoiceChanged: (next) =>
                        setState(() => _smartChoice = next),
                    onOpenSettings: _openSmartDefaults,
                    onOpenQuality:
                        plan != null ? () => _openSmartQuality(plan) : null,
                  ),
                ] else if (_canManage) ...[
                  // 规则组选择区
                  const SizedBox(height: 12),
                  _buildRuleSetPicker(),
                ],

                // 目标媒体库（管理员可见）
                if (_canManage && _libraries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildLibraryPicker(),
                ],

                // 投递路由预检提示
                if (_dispatchPreview != null) ...[
                  const SizedBox(height: 10),
                  _DispatchPreviewBanner(preview: _dispatchPreview!),
                ],

                // 剧集选季与自动追更（直接置于外层单一滚动容器，消除嵌套滚动冲突）
                if (!isMovie) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('追踪范围', style: McText.caption.semibold.muted),
                      const Spacer(),
                      Text(
                        _selectedSeasons.isEmpty
                            ? (_followFuture ? '仅追后续新集' : '请至少选一季')
                            : '已选 ${_selectedSeasons.length} 季',
                        style: McText.micro.copyWith(
                          color: (_selectedSeasons.isEmpty && !_followFuture)
                              ? McTokens.warn
                              : McTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    dividerIndent: 44,
                    children: [
                      for (final s in p.seasons) _seasonRow(s),
                    ],
                  ),
                  const SizedBox(height: 10),
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      McInsetRow(
                        title: '自动续订后续新季',
                        subtitle: '未来播出的新集与新季自动纳入追踪',
                        trailing: Switch(
                          value: _followFuture,
                          onChanged: (v) => setState(() => _followFuture = v),
                        ),
                        onTap: () =>
                            setState(() => _followFuture = !_followFuture),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: McTokens.line),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: McActionPill(
              label: _submitting
                  ? (widget.upgrade ? '正在创建并洗版…' : '正在创建订阅…')
                  : (widget.upgrade ? '订阅并洗一轮版' : '确认订阅'),
              icon: widget.upgrade ? McIcons.aiStarFill : McIcons.bookmarkFill,
              primary: true,
              expanded: true,
              height: 44,
              busy: _submitting,
              onTap: _canSubmit ? _submit : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _seasonRow(SubscribeSeason s) {
    final checked = _selectedSeasons.contains(s.number);
    final total = s.episodeCount ?? 0;
    final progress = (total > 0 && s.airedCount >= total)
        ? '共 $total 集（已播完）'
        : total > 0
            ? '已播 ${s.airedCount} / $total 集'
            : (s.airedCount > 0 ? '已播 ${s.airedCount} 集' : '尚未播出');
    final owned = (s.ownedCount != null && s.ownedCount! > 0)
        ? (total > 0 && s.ownedCount! >= total
            ? ' · 已入库全季'
            : ' · 已入库 ${s.ownedCount} 集')
        : '';
    return McInsetRow(
      leading: Icon(
        checked ? McIcons.checkCircleFill : McIcons.circler,
        size: 20,
        color: checked ? McTokens.accentStrong : McTokens.textFaint,
      ),
      title: s.number == 0 ? '特别篇' : (s.name?.isNotEmpty == true ? s.name! : '第 ${s.number} 季'),
      subtitle: '$progress$owned',
      onTap: () => setState(() {
        if (checked) {
          _selectedSeasons.remove(s.number);
        } else {
          _selectedSeasons.add(s.number);
        }
      }),
    );
  }

  Widget _buildRuleSetPicker() {
    final selectable = _selectableRules;
    final picked = _pickedRule;
    final chips = picked != null
        ? RuleSetSpecFormatter.summaryChips(RuleSetSpec.fromJson(picked.spec))
        : const <String>[];
    final showRuleReason = _routedRule != null &&
        _ruleSetId == _routedRule!.ruleSetId &&
        picked?.isDefault == false;

    return Container(
      padding: const EdgeInsets.all(12),
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
                widget.upgrade ? '洗版规则组' : '资源规则组',
                style: McText.caption.semibold.muted,
              ),
              const Spacer(),
              GestureDetector(
                onTap: _createRuleSet,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(McIcons.addS, size: 14, color: McTokens.info),
                    const SizedBox(width: 3),
                    Text(
                      '新建规则组',
                      style: McText.micro.copyWith(color: McTokens.info),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.upgrade && selectable.isEmpty)
            Text(
              '还没有配置洗版目标的规则组，请点击右上角「新建规则组」。',
              style: McText.caption.copyWith(color: McTokens.warn),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final r in selectable)
                  McChip(
                    label: r.isDefault ? '${r.name}（默认）' : r.name,
                    selected: _ruleSetId == r.id,
                    compact: true,
                    onTap: () => setState(() => _ruleSetId = r.id),
                  ),
              ],
            ),
            if (picked != null) ...[
              const SizedBox(height: 8),
              Text(
                chips.isEmpty
                    ? '未设置过滤条件（任意合格资源都可能被抓取）'
                    : chips.join(' · '),
                style: McText.micro.copyWith(
                  color: chips.isEmpty ? McTokens.warn : McTokens.textMuted,
                ),
              ),
            ],
            if (showRuleReason) ...[
              const SizedBox(height: 5),
              Text(
                '✦ ${_routedRule!.reason}',
                style: McText.micro.copyWith(color: McTokens.info),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLibraryPicker() {
    final showRouteReason = _routedLibrary != null &&
        _routedLibrary!.reason != null &&
        _routedLibrary!.reason!.isNotEmpty &&
        _libraryId == _routedLibrary!.libraryId &&
        _libraries.where((l) => l.id == _libraryId).firstOrNull?.isDefault ==
            false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('入库目标媒体库', style: McText.caption.semibold.muted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final l in _libraries)
                McChip(
                  label: l.isDefault ? '${l.name}（默认）' : l.name,
                  selected: _libraryId == l.id,
                  compact: true,
                  onTap: () {
                    setState(() => _libraryId = l.id);
                    _refreshDispatchPreview();
                  },
                ),
            ],
          ),
          if (showRouteReason) ...[
            const SizedBox(height: 6),
            Text(
              '✦ ${_routedLibrary!.reason}',
              style: McText.micro.copyWith(color: McTokens.info),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpgradeReportView(UpgradeRunView report) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text('洗版体检报告', style: McText.title),
              ),
              McActionPill(
                label: '完成',
                primary: true,
                height: 36,
                onTap: () =>
                    Navigator.of(context).pop(SubscribeSheetOutcome.created),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: McTokens.line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: UpgradeReportBody(
              title: _displayTitle,
              isMovie: _kind == 'movie',
              report: report,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 投递路由预检横幅 ──

class _DispatchPreviewBanner extends StatelessWidget {
  const _DispatchPreviewBanner({required this.preview});

  final DispatchPreviewView preview;

  @override
  Widget build(BuildContext context) {
    if (preview.ok) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          preview.formattedPathNote(),
          style: McText.micro.muted,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: McTokens.warn.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: McTokens.warn.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(McIcons.alert1, size: 15, color: McTokens.warn),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              preview.warning ?? '下载与入库链路尚未就绪，暂无法自动入库',
              style: McText.caption.copyWith(color: McTokens.warn),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 智能订阅方案卡片（1:1 对齐 iOS `SmartPlanSection.swift`） ──

class SmartPlanSection extends StatefulWidget {
  const SmartPlanSection({
    super.key,
    required this.plan,
    required this.choice,
    required this.onChoiceChanged,
    required this.onOpenSettings,
    this.onOpenQuality,
  });

  final SmartPlanView? plan;
  final SmartChoice choice;
  final ValueChanged<SmartChoice> onChoiceChanged;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenQuality;

  @override
  State<SmartPlanSection> createState() => _SmartPlanSectionState();
}

class _SmartPlanSectionState extends State<SmartPlanSection> {
  bool _editingSubtitle = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    if (plan == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: McTokens.line),
        ),
        child: Text(
          '当前服务器版本暂不支持智能订阅，已自动切换为规则组模式。',
          style: McText.caption.muted,
        ),
      );
    }

    if (!plan.configured) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: McTokens.lineStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('智能选择', style: McText.micro.muted),
            const SizedBox(height: 6),
            Text(
              plan.canEdit ? '首次使用，先设置默认画质与等待时间' : '需要管理员先完成智能订阅初始设置',
              style: McText.ui.semibold,
            ),
            const SizedBox(height: 4),
            Text(
              plan.canEdit
                  ? '只需设置一次，后续订阅自动记住你的偏好与语言习惯。'
                  : '请联系管理员在订阅设置中开启智能选择，或改用规则组模式。',
              style: McText.caption.muted,
            ),
            if (plan.canEdit) ...[
              const SizedBox(height: 12),
              McActionPill(
                label: '去设置默认偏好',
                icon: McIcons.setting1,
                primary: true,
                height: 36,
                onTap: widget.onOpenSettings,
              ),
            ],
          ],
        ),
      );
    }

    final changed = widget.choice.qualityChanged(plan);
    final effectiveLabel = changed
        ? '优先 ${SmartLabels.quality(resolution: widget.choice.resolution ?? plan.resolution, source: widget.choice.source ?? plan.source)}'
        : (plan.qualityLabel ?? '');
    final scopeLabel = widget.choice.scope == 'only'
        ? '仅这部'
        : (plan.scopeOptions
                .where((o) => o.value == widget.choice.scope)
                .firstOrNull
                ?.label ??
            '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                  const Icon(McIcons.aiStarFill, size: 14, color: McTokens.info),
                  const SizedBox(width: 6),
                  Text('智能选择', style: McText.caption.semibold.muted),
                  const Spacer(),
                  if (plan.canEdit)
                    GestureDetector(
                      onTap: widget.onOpenSettings,
                      child: Text(
                        '默认偏好',
                        style: McText.micro.copyWith(color: McTokens.info),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(effectiveLabel, style: McText.titleSm),
              if (!changed &&
                  plan.qualityNote != null &&
                  plan.qualityNote!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(plan.qualityNote!, style: McText.caption.muted),
              ],
              if (!changed &&
                  plan.qualityShadow != null &&
                  plan.qualityShadow!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  plan.qualityShadow!,
                  style: McText.micro.faint,
                ),
              ],
              if (plan.waitLabel != null && plan.waitLabel!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(plan.waitLabel!, style: McText.caption.muted),
              ],
              if (plan.canEdit && widget.onOpenQuality != null) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: McTokens.line),
                InkWell(
                  onTap: widget.onOpenQuality,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Text('调整画质与习惯', style: McText.sub.copyWith(color: McTokens.text)),
                        const Spacer(),
                        if (changed && scopeLabel.isNotEmpty)
                          Text(scopeLabel, style: McText.caption.copyWith(color: McTokens.info)),
                        const SizedBox(width: 4),
                        const Icon(
                          McIcons.chevronRight,
                          size: 14,
                          color: McTokens.textFaint,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (plan.subtitleLanguageLabel != null && plan.subtitleLine != null) ...[
          const SizedBox(height: 10),
          _buildSubtitleCard(
            plan,
            plan.subtitleLanguageLabel!,
            plan.subtitleLine!,
          ),
        ],
      ],
    );
  }

  Widget _buildSubtitleCard(
    SmartPlanView plan,
    String language,
    String line,
  ) {
    final currentAnswer = widget.choice.language ??
        (plan.subtitleUnderstood == true ? 'understood' : 'subtitles');
    final showQuestion = plan.canEdit && (plan.question != null || _editingSubtitle);

    if (showQuestion) {
      final q = plan.question ?? plan.subtitleEditQuestion;
      final prompt = q?.prompt ?? '这是$language作品，需要中文字幕吗？';
      final subLabel = q?.subtitlesLabel ??
          (plan.subtitleUnderstood == true
              ? '要，只下带中文字幕的'
              : line.replaceFirst('$language · ', '要，'));
      final undLabel = q?.understoodLabel ?? '不用，我看得懂$language';
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: McTokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prompt, style: McText.caption.semibold.copyWith(color: McTokens.text)),
            const SizedBox(height: 8),
            _radioOption(
              label: subLabel,
              selected: currentAnswer == 'subtitles',
              onTap: () => widget.onChoiceChanged(
                widget.choice.copyWith(language: 'subtitles'),
              ),
            ),
            const SizedBox(height: 6),
            _radioOption(
              label: undLabel,
              selected: currentAnswer == 'understood',
              onTap: () => widget.onChoiceChanged(
                widget.choice.copyWith(language: 'understood'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: McTokens.surfaceInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: McTokens.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.choice.language == 'understood'
                  ? '$language · 看得懂，不需要中文字幕'
                  : line,
              style: McText.sub.copyWith(color: McTokens.text),
            ),
          ),
          if (plan.canEdit) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _editingSubtitle = true),
              child: Text(
                '修改',
                style: McText.caption.copyWith(color: McTokens.info),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _radioOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? McTokens.glassFillActive : McTokens.glassFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? McTokens.accentStrong : McTokens.line,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? McIcons.checkCircleFill : McIcons.circler,
              size: 18,
              color: selected ? McTokens.accentStrong : McTokens.textFaint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: McText.sub.copyWith(color: McTokens.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 智能画质微调弹层（1:1 对齐 iOS `SmartQualityPage`） ──

class SmartQualitySheet extends StatefulWidget {
  const SmartQualitySheet({
    super.key,
    required this.plan,
    required this.initial,
  });

  final SmartPlanView plan;
  final SmartChoice initial;

  @override
  State<SmartQualitySheet> createState() => _SmartQualitySheetState();
}

class _SmartQualitySheetState extends State<SmartQualitySheet> {
  late SmartChoice _choice = widget.initial;

  String get _resolution =>
      _choice.resolution ?? widget.plan.resolution ?? '2160p';
  String get _source => _choice.source ?? widget.plan.source ?? 'web-dl';

  @override
  Widget build(BuildContext context) {
    final changed = _choice.qualityChanged(widget.plan);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('调整画质', style: McText.title)),
              McActionPill(
                label: '确定',
                primary: true,
                height: 36,
                onTap: () => Navigator.of(context).pop(_choice),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('首选分辨率', style: McText.caption.semibold.muted),
          const SizedBox(height: 8),
          Row(
            children: [
              McChip(
                label: '4K (2160p)',
                selected: _resolution == '2160p',
                onTap: () => setState(
                  () => _choice = _choice.copyWith(resolution: '2160p'),
                ),
              ),
              const SizedBox(width: 8),
              McChip(
                label: '1080p',
                selected: _resolution == '1080p',
                onTap: () => setState(
                  () => _choice = _choice.copyWith(resolution: '1080p'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('首选片源', style: McText.caption.semibold.muted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in const [
                ('web-dl', 'WEB-DL'),
                ('blu-ray', '蓝光'),
                ('remux', 'Remux'),
              ])
                McChip(
                  label: s.$2,
                  selected: _source == s.$1,
                  onTap: () => setState(
                    () => _choice = _choice.copyWith(source: s.$1),
                  ),
                ),
            ],
          ),
          if (widget.plan.qualityNote != null &&
              widget.plan.qualityNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('当前依据：${widget.plan.qualityNote}', style: McText.micro.faint),
          ],
          if (changed && widget.plan.scopeOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('这次调整记住的范围', style: McText.caption.semibold.muted),
            const SizedBox(height: 8),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final opt in widget.plan.scopeOptions)
                  McInsetRow(
                    leading: Icon(
                      _choice.scope == opt.value
                          ? McIcons.checkCircleFill
                          : McIcons.circler,
                      size: 19,
                      color: _choice.scope == opt.value
                          ? McTokens.accentStrong
                          : McTokens.textFaint,
                    ),
                    title: opt.label,
                    onTap: () => setState(
                      () => _choice = _choice.copyWith(scope: opt.value),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '记住后同类新订阅会自动沿用此画质，可随时在「智能默认偏好」中移除。',
              style: McText.micro.faint,
            ),
          ],
        ],
      ),
    );
  }
}

// ── 智能默认偏好与记忆编辑器（1:1 对齐 iOS `SmartDefaultsEditor`） ──

class SmartDefaultsEditorSheet extends ConsumerStatefulWidget {
  const SmartDefaultsEditorSheet({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  ConsumerState<SmartDefaultsEditorSheet> createState() =>
      _SmartDefaultsEditorSheetState();
}

class _SmartDefaultsEditorSheetState
    extends ConsumerState<SmartDefaultsEditorSheet> {
  late final SubscriptionsApi _api = SubscriptionsApi(
    McClient(session: ref.read(sessionStoreProvider)),
  );

  SmartDefaultsView? _defaults;
  SmartDefaultsPayload? _draft;
  SmartMemoryView? _memory;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getSmartDefaults(),
        _api.getSmartMemory(),
      ]);
      final d = results[0] as SmartDefaultsView;
      final m = results[1] as SmartMemoryView?;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _defaults = d;
        _memory = m;
        _draft = SmartDefaultsPayload(
          movieRevision: d.movieRevision,
          tvRevision: d.tvRevision,
          resolution: d.resolution,
          source: d.source,
          allowUpgrade: d.allowUpgrade,
          strictResolution: d.strictResolution,
          movieWaitSeconds: d.movieWaitSeconds,
          tvWaitSeconds: d.tvWaitSeconds,
        );
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载智能设置失败：$e';
        });
      }
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.saveSmartDefaults(
        draft,
        useLegacyProfiles: _defaults?.isLegacyProfiles ?? false,
      );
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '保存失败：$e';
        });
      }
    }
  }

  Future<void> _patchMemory(SmartMemoryPatch patch) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await _api.updateSmartMemory(patch);
      widget.onSaved?.call();
      if (mounted) {
        setState(() {
          _busy = false;
          _memory = updated;
        });
      }
    } on ApiException catch (e) {
      final refreshed = await _api.getSmartMemory().catchError((_) => _memory);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.friendlyMessage;
          _memory = refreshed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '更新记忆失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final memory = _memory;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
          child: Row(
            children: [
              const Expanded(child: Text('智能默认偏好', style: McText.title)),
              McActionPill(
                label: _busy ? '保存中…' : '保存',
                primary: true,
                busy: _busy,
                height: 36,
                onTap: (draft == null || _busy) ? null : _save,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: McTokens.line),
        Flexible(
          child: _loading && draft == null
              ? const SizedBox(height: 180, child: McLoadingView())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: McTokens.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: McTokens.danger.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: McText.caption
                                      .copyWith(color: McTokens.danger),
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('重新读取'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (draft != null) ...[
                        _buildDefaultsForm(draft),
                        if (memory != null && _defaults?.configured == true) ...[
                          const SizedBox(height: 18),
                          _buildMemorySection(memory),
                        ],
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDefaultsForm(SmartDefaultsPayload draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('首选分辨率', style: McText.caption.semibold.muted),
        const SizedBox(height: 8),
        Row(
          children: [
            McChip(
              label: '4K (2160p)',
              selected: draft.resolution == '2160p',
              onTap: () => setState(
                () => _draft = draft.copyWith(resolution: '2160p'),
              ),
            ),
            const SizedBox(width: 8),
            McChip(
              label: '1080p',
              selected: draft.resolution == '1080p',
              onTap: () => setState(
                () => _draft = draft.copyWith(resolution: '1080p'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('首选片源', style: McText.caption.semibold.muted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in const [
              ('web-dl', 'WEB-DL'),
              ('blu-ray', '蓝光'),
              ('remux', 'Remux'),
            ])
              McChip(
                label: s.$2,
                selected: draft.source == s.$1,
                onTap: () => setState(
                  () => _draft = draft.copyWith(source: s.$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _WaitPickerRow(
          title: '电影等待上限',
          seconds: draft.movieWaitSeconds,
          onChanged: (sec) =>
              setState(() => _draft = draft.copyWith(movieWaitSeconds: sec)),
        ),
        const SizedBox(height: 10),
        _WaitPickerRow(
          title: '剧集等待上限',
          seconds: draft.tvWaitSeconds,
          onChanged: (sec) =>
              setState(() => _draft = draft.copyWith(tvWaitSeconds: sec)),
        ),
        const SizedBox(height: 14),
        McInsetGroup(
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              title: '允许后续自动洗版',
              subtitle: '先下可用版，目标版本出现后自动升级替换',
              trailing: Switch(
                value: draft.allowUpgrade,
                onChanged: (v) =>
                    setState(() => _draft = draft.copyWith(allowUpgrade: v)),
              ),
              onTap: () => setState(
                () => _draft = draft.copyWith(allowUpgrade: !draft.allowUpgrade),
              ),
            ),
            McInsetRow(
              title: '最低要求：只接受 ${draft.resolution == '2160p' ? '4K' : '1080p'}',
              subtitle: '不降级回落到更低分辨率',
              trailing: Switch(
                value: draft.strictResolution,
                onChanged: (v) => setState(
                  () => _draft = draft.copyWith(strictResolution: v),
                ),
              ),
              onTap: () => setState(
                () => _draft =
                    draft.copyWith(strictResolution: !draft.strictResolution),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemorySection(SmartMemoryView memory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('看得懂的语言（无需中文字幕）', style: McText.caption.semibold.muted),
        const SizedBox(height: 8),
        McInsetGroup(
          margin: EdgeInsets.zero,
          children: [
            for (final lang in memory.languages)
              McInsetRow(
                title: lang.label,
                subtitle: !lang.removable
                    ? '默认'
                    : (lang.sourceTitle != null
                        ? '来自《${lang.sourceTitle}》'
                        : '在设置中添加'),
                trailing: lang.removable
                    ? TextButton(
                        onPressed: _busy
                            ? null
                            : () => _patchMemory(
                                  SmartMemoryPatch(
                                    revision: memory.revision,
                                    language: lang.key,
                                    understood: false,
                                  ),
                                ),
                        child: Text(
                          '移除',
                          style: McText.caption.copyWith(color: McTokens.danger),
                        ),
                      )
                    : null,
              ),
          ],
        ),
        if (memory.addableLanguages.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final opt in memory.addableLanguages)
                McChip(
                  label: '+ ${opt.label}',
                  compact: true,
                  onTap: _busy
                      ? null
                      : () => _patchMemory(
                            SmartMemoryPatch(
                              revision: memory.revision,
                              language: opt.key,
                              understood: true,
                            ),
                          ),
                ),
            ],
          ),
        ],
        if (memory.habits.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('记住的画质习惯', style: McText.caption.semibold.muted),
          const SizedBox(height: 8),
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              for (final h in memory.habits)
                McInsetRow(
                  title: '${h.label} · ${h.qualityLabel}',
                  subtitle: h.sourceTitle != null
                      ? '来自《${h.sourceTitle}》'
                      : '来自历史偏好',
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _patchMemory(
                              SmartMemoryPatch(
                                revision: memory.revision,
                                removeHabit: h.key,
                              ),
                            ),
                    child: Text(
                      '移除',
                      style: McText.caption.copyWith(color: McTokens.danger),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _WaitPickerRow extends StatelessWidget {
  const _WaitPickerRow({
    required this.title,
    required this.seconds,
    required this.onChanged,
  });

  final String title;
  final int seconds;
  final ValueChanged<int> onChanged;

  static const _presets = <(int, String)>[
    (0, '不等待'),
    (10800, '3 小时'),
    (86400, '1 天'),
    (259200, '3 天'),
    (604800, '7 天'),
  ];

  @override
  Widget build(BuildContext context) {
    final isPreset = _presets.any((p) => p.$1 == seconds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: McText.caption.semibold.muted),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final p in _presets)
              McChip(
                label: p.$2,
                selected: seconds == p.$1,
                compact: true,
                onTap: () => onChanged(p.$1),
              ),
            if (!isPreset)
              McChip(
                label: SmartLabels.wait(seconds),
                selected: true,
                compact: true,
                onTap: () {},
              ),
          ],
        ),
      ],
    );
  }
}

// ── 管理员取消订阅确认弹层（供 SubscribeSheet 与 SubscriptionDetailPage 共用） ──

Future<bool?> showAdminCancelSubscriptionSheet(
  BuildContext context,
  WidgetRef ref, {
  required int subscriptionId,
  required String title,
}) {
  return showMcSheet<bool>(
    context: context,
    builder: (_) => AdminCancelSubscriptionSheet(
      subscriptionId: subscriptionId,
      title: title,
    ),
  );
}

class AdminCancelSubscriptionSheet extends ConsumerStatefulWidget {
  const AdminCancelSubscriptionSheet({
    super.key,
    required this.subscriptionId,
    required this.title,
    this.onConfirm,
  });

  final int subscriptionId;
  final String title;
  final Future<void> Function(bool deleteTorrents, bool deleteFiles)? onConfirm;

  @override
  ConsumerState<AdminCancelSubscriptionSheet> createState() =>
      _AdminCancelSubscriptionSheetState();
}

class _AdminCancelSubscriptionSheetState
    extends ConsumerState<AdminCancelSubscriptionSheet> {
  late final SubscriptionsApi _api = SubscriptionsApi(
    McClient(session: ref.read(sessionStoreProvider)),
  );

  SubscriptionRemovalPreviewView? _preview;
  bool _deleteTorrents = false;
  bool _deleteFiles = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final p = await _api.removalPreview(widget.subscriptionId);
      if (mounted) setState(() => _preview = p);
    } catch (_) {
      if (mounted) {
        setState(() => _preview = const SubscriptionRemovalPreviewView());
      }
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.onConfirm != null) {
        await widget.onConfirm!(_deleteTorrents, _deleteFiles);
      } else {
        await _api.deleteSubscription(
          widget.subscriptionId,
          deleteTorrents: _deleteTorrents,
          deleteLibraryFiles: _deleteFiles,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '取消失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final torrentCount = p?.torrentCount ?? 0;
    final fileCount = p?.libraryFileCount ?? 0;
    final hrCount = p?.hitAndRunCount ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('取消订阅', style: McText.title),
          const SizedBox(height: 6),
          Text(
            '取消《${widget.title}》将停止追踪剩余内容。默认只取消订阅，已下载和入库的内容都会保留。',
            style: McText.sub.muted,
          ),
          const SizedBox(height: 14),
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              McInsetRow(
                leading: Checkbox(
                  value: _deleteTorrents,
                  onChanged: (p == null || torrentCount == 0 || _busy)
                      ? null
                      : (v) => setState(() => _deleteTorrents = v == true),
                ),
                title: p == null
                    ? '同时删除下载任务（加载中…）'
                    : torrentCount == 0
                        ? '没有关联下载任务'
                        : '同时删除 $torrentCount 个下载任务',
                subtitle: torrentCount == 0
                    ? null
                    : '从下载器中移除任务及数据文件（不可恢复）',
                onTap: (p == null || torrentCount == 0 || _busy)
                    ? null
                    : () => setState(() => _deleteTorrents = !_deleteTorrents),
              ),
              McInsetRow(
                leading: Checkbox(
                  value: _deleteFiles,
                  onChanged: (p == null || fileCount == 0 || _busy)
                      ? null
                      : (v) => setState(() => _deleteFiles = v == true),
                ),
                title: p == null
                    ? '同时删除媒体库文件（加载中…）'
                    : fileCount == 0
                        ? '媒体库中没有关联文件'
                        : '同时删除 $fileCount 个媒体库文件（${_formatBytes(p.libraryBytes)}）',
                subtitle: fileCount == 0
                    ? null
                    : '移入回收站保留 ${p?.recycleRetentionDays ?? 7} 天，期间可恢复',
                onTap: (p == null || fileCount == 0 || _busy)
                    ? null
                    : () => setState(() => _deleteFiles = !_deleteFiles),
              ),
            ],
          ),
          if (_deleteTorrents && hrCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: McTokens.warn.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: McTokens.warn.withValues(alpha: 0.4)),
              ),
              child: Text(
                '注意：其中有 $hrCount 个任务处于 H&R 考核或状态未知，删除可能影响 PT 站点考核。',
                style: McText.caption.copyWith(color: McTokens.warn),
              ),
            ),
          ],
          if (_deleteTorrents || _deleteFiles) ...[
            const SizedBox(height: 8),
            Text('勾选的清理操作将在后台任务中异步执行。', style: McText.micro.faint),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '先不',
                  primary: false,
                  expanded: true,
                  onTap: _busy ? null : () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: _busy ? '正在取消…' : '取消订阅',
                  primary: false,
                  tone: McGlassTone.danger,
                  expanded: true,
                  busy: _busy,
                  onTap: _busy ? null : _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 洗版体检报告正文（供 SubscribeSheet 洗版变体与 UpgradeRunSheet 共用） ──

class UpgradeReportBody extends StatelessWidget {
  const UpgradeReportBody({
    super.key,
    required this.title,
    required this.isMovie,
    required this.report,
    this.canAnnotate = false,
    this.onAnnotate,
  });

  final String title;
  final bool isMovie;
  final UpgradeRunView report;
  final bool canAnnotate;
  final ValueChanged<int>? onAnnotate;

  static ({String label, Color color}) stateMeta(String state) {
    return switch (state) {
      'upgradable' => (label: '可洗已排期', color: const Color(0xFF2DD4BF)),
      'in_flight' => (label: '洗版在途', color: const Color(0xFF34D399)),
      'at_cutoff' => (label: '已达目标', color: McTokens.ok),
      'not_comparable' => (label: '无法确认', color: const Color(0xFF9CA3AF)),
      _ => (label: '缺失待补', color: McTokens.warn),
    };
  }

  static String unitNote(UpgradeRunUnitView u) {
    final cur = (u.currentLabel != null && u.currentLabel!.isNotEmpty)
        ? u.currentLabel!
        : '未知档位';
    return switch (u.state) {
      'upgradable' => '当前 $cur → 目标 ${u.targetLabel}，已排入搜索',
      'in_flight' => '已有洗版任务正在进行中',
      'at_cutoff' => '当前 $cur，已达到目标档位',
      'not_comparable' => '无法识别现有文件片源档位，标注片源后可参与洗版',
      _ => '当前未入库，将走正常补缺流程',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bySeason = <int, List<UpgradeRunUnitView>>{};
    for (final u in report.units) {
      bySeason.putIfAbsent(u.seasonNumber, () => []).add(u);
    }
    final keys = bySeason.keys.toList()..sort();
    final annotatable = (canAnnotate && onAnnotate != null)
        ? report.units
            .where((u) => u.state == 'not_comparable')
            .map((u) => u.seasonNumber)
            .toSet()
        : <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$title · 目标 ${report.targetLabel}',
          style: McText.caption.muted,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x1F2DD4BF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x552DD4BF)),
          ),
          child: Text(
            report.summary,
            style: McText.sub.copyWith(color: const Color(0xFF5EEAD4)),
          ),
        ),
        for (final season in keys) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                isMovie
                    ? '正片'
                    : (season == 0 ? '特别篇' : '第 $season 季'),
                style: McText.caption.semibold.muted,
              ),
              const Spacer(),
              if (annotatable.contains(season))
                GestureDetector(
                  onTap: () => onAnnotate?.call(season),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: McTokens.glassFillHover,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: McTokens.lineStrong),
                    ),
                    child: Text(
                      '标注片源',
                      style: McText.micro.copyWith(color: McTokens.text),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              children: [
                for (final pair in (bySeason[season]!
                      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber)))
                    .indexed) ...[
                  if (pair.$1 > 0) const Divider(height: 1, color: McTokens.line),
                  _unitTile(pair.$2),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('后续洗版进展可在订阅详情的「追踪明细」中持续查看。', style: McText.micro.faint),
      ],
    );
  }

  Widget _unitTile(UpgradeRunUnitView u) {
    final meta = stateMeta(u.state);
    final code = isMovie
        ? '正片'
        : 'E${u.episodeNumber.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              code,
              style: McText.caption.semibold
                  .copyWith(color: McTokens.text)
                  .tabular,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    meta.label,
                    style: McText.micro.copyWith(color: meta.color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(unitNote(u), style: McText.caption.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var idx = 0;
  while (value >= 1024 && idx < units.length - 1) {
    value /= 1024;
    idx++;
  }
  final text =
      (value >= 100 || idx == 0) ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$text ${units[idx]}';
}
