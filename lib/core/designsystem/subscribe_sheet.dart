import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/mc_client.dart';
import '../api/session_providers.dart';
import '../api/subscriptions_api.dart';
import 'mc_chrome.dart';
import 'mc_icons.dart';
import 'state_views.dart';
import 'theme.dart';

/// 订阅创建毛玻璃弹层（全站唯一入口：支持智能模式 / 规则组模式、选季、自动追更与目标媒体库）。
enum SubscribeSheetOutcome { created, managed }

Future<SubscribeSheetOutcome?> showSubscribeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String titleRef,
}) {
  return showMcSheet<SubscribeSheetOutcome>(
    context: context,
    builder: (_) => _SubscribeSheet(titleRef: titleRef),
  );
}

class _SubscribeSheet extends ConsumerStatefulWidget {
  const _SubscribeSheet({required this.titleRef});

  final String titleRef;

  @override
  ConsumerState<_SubscribeSheet> createState() => _SubscribeSheetState();
}

class _SubscribeSheetState extends ConsumerState<_SubscribeSheet> {
  late final SubscriptionsApi _api = SubscriptionsApi(
    McClient(session: ref.read(sessionStoreProvider)),
  );
  late final Future<SubscribePreview?> _preview;
  final Set<int> _selected = {};
  bool _followFuture = false;
  String _selectionMode = 'smart'; // smart | rules
  List<SubscribeRuleSetOption> _ruleSets = const [];
  List<SubscribeLibraryOption> _libraries = const [];
  int? _ruleSetId;
  int? _libraryId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preview = _load();
  }

  Future<SubscribePreview?> _load() async {
    try {
      final p = await _api.titlePreview(widget.titleRef);
      final rs = await _api.ruleSets();
      final libs = await _api.libraries(
        kind: p.seasons.isEmpty ? 'movie' : 'tv',
      );
      if (!mounted) return p;
      setState(() {
        _selected.addAll(p.suggestedSeasons);
        if (_selected.isEmpty && p.seasons.isNotEmpty) {
          _selected.addAll(p.seasons.map((s) => s.number));
        }
        _followFuture = p.seasons.isNotEmpty;
        _ruleSets = rs;
        _libraries = libs;
        if (rs.isNotEmpty) {
          _ruleSetId = rs.where((r) => r.isDefault).firstOrNull?.id ??
              rs.first.id;
        }
      });
      return p;
    } catch (e) {
      if (mounted) setState(() => _error = '预检失败：$e');
      return null;
    }
  }

  Future<void> _submit(SubscribePreview p) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.createSubscription(
        titleRef: widget.titleRef,
        selectedSeasons: _selected.toList()..sort(),
        followFuture: _followFuture,
        selectionMode: _selectionMode,
        ruleSetId: _selectionMode == 'rules' ? _ruleSetId : null,
        libraryId: _libraryId,
      );
      if (mounted) Navigator.of(context).pop(SubscribeSheetOutcome.created);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '订阅失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscribePreview?>(
      future: _preview,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 190, child: McLoadingView());
        }
        final p = snap.data;
        if (p == null || p.notFound) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p == null ? (_error ?? '预检失败') : '未找到该作品',
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

        if (p.existingSubscriptionId != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      McIcons.checkCircleFill,
                      size: 20,
                      color: McTokens.ok,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已订阅《${p.title ?? ''}》',
                        style: McText.titleSm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '该作品已在追更队列中，可前往订阅管理调整选季或洗版策略。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 18),
                McActionPill(
                  label: '管理订阅',
                  icon: McIcons.setting1,
                  primary: true,
                  expanded: true,
                  height: 44,
                  onTap: () =>
                      Navigator.of(context).pop(SubscribeSheetOutcome.managed),
                ),
              ],
            ),
          );
        }

        final isMovie = p.seasons.isEmpty;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${p.title ?? ''}${p.year != null ? '（${p.year}）' : ''}',
                      style: McText.title,
                    ),
                  ),
                  if (p.movieOwned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1F4ADE80),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x4D4ADE80)),
                      ),
                      child: Text(
                        '已在库',
                        style: McText.micro.copyWith(color: McTokens.ok),
                      ),
                    ),
                ],
              ),
              if (p.overview != null && p.overview!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  p.overview!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted,
                ),
              ],
              if (_ruleSets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    McChip(
                      label: '智能选源',
                      icon: McIcons.aiStarFill,
                      selected: _selectionMode == 'smart',
                      compact: true,
                      onTap: () => setState(() => _selectionMode = 'smart'),
                    ),
                    const SizedBox(width: 8),
                    McChip(
                      label: '指定规则组',
                      icon: McIcons.listSettings2,
                      selected: _selectionMode == 'rules',
                      compact: true,
                      onTap: () => setState(() => _selectionMode = 'rules'),
                    ),
                  ],
                ),
                if (_selectionMode == 'rules') ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final r in _ruleSets)
                        McChip(
                          label: r.name,
                          selected: _ruleSetId == r.id,
                          compact: true,
                          onTap: () => setState(() => _ruleSetId = r.id),
                        ),
                    ],
                  ),
                ],
              ],
              if (_libraries.length > 1) ...[
                const SizedBox(height: 12),
                Text('入库目标媒体库', style: McText.micro.muted),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    McChip(
                      label: '自动路由',
                      selected: _libraryId == null,
                      compact: true,
                      onTap: () => setState(() => _libraryId = null),
                    ),
                    for (final l in _libraries)
                      McChip(
                        label: l.name,
                        selected: _libraryId == l.id,
                        compact: true,
                        onTap: () => setState(() => _libraryId = l.id),
                      ),
                  ],
                ),
              ],
              if (!isMovie) ...[
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 210),
                  child: SingleChildScrollView(
                    child: McInsetGroup(
                      margin: EdgeInsets.zero,
                      dividerIndent: 44,
                      children: [
                        for (final s in p.seasons)
                          McInsetRow(
                            leading: Icon(
                              _selected.contains(s.number)
                                  ? McIcons.checkCircleFill
                                  : McIcons.circler,
                              size: 20,
                              color: _selected.contains(s.number)
                                  ? McTokens.accentStrong
                                  : McTokens.textFaint,
                            ),
                            title: s.name ?? '第 ${s.number} 季',
                            subtitle: s.episodeCount != null
                                ? '共 ${s.episodeCount} 集${s.ownedCount != null ? ' · 已入库 ${s.ownedCount} 集' : ''}'
                                : null,
                            onTap: () {
                              setState(() {
                                if (_selected.contains(s.number)) {
                                  _selected.remove(s.number);
                                } else {
                                  _selected.add(s.number);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    McInsetRow(
                      title: '自动追后续新季',
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
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: McText.caption.copyWith(color: McTokens.danger),
                ),
              ],
              const SizedBox(height: 18),
              McActionPill(
                label: _submitting ? '正在创建订阅…' : '确认订阅',
                icon: McIcons.bookmarkFill,
                primary: true,
                expanded: true,
                height: 44,
                busy: _submitting,
                onTap: _submitting || (!isMovie && _selected.isEmpty)
                    ? null
                    : () => _submit(p),
              ),
            ],
          ),
        );
      },
    );
  }
}
