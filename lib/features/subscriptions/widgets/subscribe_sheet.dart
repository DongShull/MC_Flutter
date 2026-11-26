import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../state/rule_set_spec.dart';
import '../state/subscription_events.dart';
import '../state/subscription_index.dart';

/// 订阅创建弹层的种子（对齐 SubscribeSheetHost.Seed）。
class SubscribeSeed {
  const SubscribeSeed({
    required this.titleRef,
    this.title,
    this.posterUrl,
    this.year,
    this.kind,
  });

  final String titleRef;
  final String? title;
  final String? posterUrl;
  final int? year;
  final String? kind;
}

/// 订阅域内部带规则组选择的订阅创建毛玻璃弹层。
Future<void> showSubscribeSheet(BuildContext context, SubscribeSeed seed) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => _SubscribeSheet(seed: seed),
  );
}

class _SubscribeSheet extends ConsumerStatefulWidget {
  const _SubscribeSheet({required this.seed});

  final SubscribeSeed seed;

  @override
  ConsumerState<_SubscribeSheet> createState() => _SubscribeSheetState();
}

class _SubscribeSheetState extends ConsumerState<_SubscribeSheet> {
  PrepareView? _prepare;
  bool _loading = true;
  String? _error;
  final Set<int> _selected = {};
  bool _followFuture = false;
  int? _ruleSetId;
  List<RuleSetView> _ruleSets = const [];
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare_());
  }

  Future<void> _prepare_() async {
    final api = ref.read(subscriptionsApiProvider);
    try {
      final p = await api.titlePreview(widget.seed.titleRef);
      if (!mounted) return;
      setState(() {
        _prepare = p;
        _loading = false;
        final seasons = p.suggestedSeasons.isNotEmpty
            ? p.suggestedSeasons
            : [
                for (final s in p.seasons)
                  if (s.airedCount > 0) s.seasonNumber,
              ];
        _selected.addAll(seasons);
      });
      try {
        final rs = await api.ruleSets();
        if (mounted) {
          setState(() {
            _ruleSets = rs;
            _ruleSetId = rs.where((r) => r.isDefault).firstOrNull?.id ??
                rs.firstOrNull?.id;
          });
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '预检失败：$e';
        });
      }
    }
  }

  Future<void> _create() async {
    final p = _prepare;
    if (p == null || _creating) return;
    setState(() => _creating = true);
    final api = ref.read(subscriptionsApiProvider);
    try {
      final sub = await api.create(
        titleRef: widget.seed.titleRef,
        selectedSeasons: _selected.toList()..sort(),
        followFuture: _followFuture,
        ruleSetId: _ruleSetId,
      );
      ref.read(subscriptionIndexProvider).invalidate();
      SubscriptionEvents.notifyChanged();
      if (!mounted) return;
      Navigator.of(context).pop(sub.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = '创建失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _prepare?.media?.title ?? widget.seed.title ?? '';
    final poster = _prepare?.media?.posterUrl ?? widget.seed.posterUrl;
    final year = _prepare?.media?.year ?? widget.seed.year;
    final existing = _prepare?.existingSubscriptionId;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(McTokens.radiusSm),
                child: SizedBox(
                  width: 64,
                  height: 96,
                  child: poster != null
                      ? CachedNetworkImage(
                          httpHeaders: mcImageHeaders(),
                          imageUrl: McImageUrls.resolve(poster),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: McTokens.posterPlaceholder,
                          ),
                        )
                      : const ColoredBox(color: McTokens.posterPlaceholder),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: McText.titleSm),
                    if (year != null) ...[
                      const SizedBox(height: 2),
                      Text('$year', style: McText.caption.muted),
                    ],
                  ],
                ),
              ),
              McGlassIconButton(
                icon: McIcons.close2,
                size: 32,
                iconSize: 16,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: McLoadingView(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: McErrorView(text: _error!),
            )
          else ...[
            if (existing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '已订阅该作品（幂等返回已有订阅）',
                  style: McText.caption.muted,
                ),
              ),
            if (_prepare!.seasons.isNotEmpty) ...[
              McInsetGroup(
                margin: EdgeInsets.zero,
                dividerIndent: 46,
                children: [
                  for (final s in _prepare!.seasons)
                    McInsetRow(
                      leading: Icon(
                        _selected.contains(s.seasonNumber)
                            ? McIcons.checkCircleFill
                            : McIcons.circler,
                        size: 20,
                        color: _selected.contains(s.seasonNumber)
                            ? McTokens.accentStrong
                            : McTokens.textFaint,
                      ),
                      title: s.name ?? '第 ${s.seasonNumber} 季 · ${s.episodesLine}',
                      subtitle: s.airDate,
                      onTap: () => setState(() {
                        if (_selected.contains(s.seasonNumber)) {
                          _selected.remove(s.seasonNumber);
                        } else {
                          _selected.add(s.seasonNumber);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  title: '自动续订',
                  subtitle: '未来新一季自动纳入追踪',
                  trailing: Switch(
                    value: _followFuture,
                    onChanged: (v) => setState(() => _followFuture = v),
                  ),
                  onTap: () => setState(() => _followFuture = !_followFuture),
                ),
              ],
            ),
            if (_ruleSets.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _ruleSetId,
                decoration: const InputDecoration(labelText: '规则组'),
                items: [
                  for (final r in _ruleSets)
                    DropdownMenuItem(
                      value: r.id,
                      child: Text(
                        '${r.name}（${specSummary(r.spec)}）',
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _ruleSetId = v),
              ),
            ],
          ],
          const SizedBox(height: 18),
          McActionPill(
            label: existing != null
                ? '查看已有订阅'
                : (_creating ? '创建中…' : '创建订阅'),
            icon: McIcons.bookmarkFill,
            primary: true,
            expanded: true,
            height: 44,
            busy: _creating,
            onTap: (_creating || _loading || _error != null) ? null : _create,
          ),
        ],
      ),
    );
  }
}
