import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/mc_client.dart';
import '../api/session_providers.dart';
import '../api/subscriptions_api.dart';

/// 订阅创建弹层（对齐 Kotlin SubscribeSheetHost / SubscribeScreen 的三步流程）：
/// title-preview（标题 + 简介）→ 季多选（无季 = 电影直接确认）→ POST /subscriptions。
/// 详情页与发现侧条目详情共用（跨 feature 只经 core，不互相 import）。

/// 弹层结果：created = 新建成功；managed = 已有订阅，用户选择去管理。
enum SubscribeSheetOutcome { created, managed }

/// 打开订阅弹层。调用方拿到结果后自己 toast / 跳转管理页。
Future<SubscribeSheetOutcome?> showSubscribeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String titleRef,
}) {
  return showModalBottomSheet<SubscribeSheetOutcome>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
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
  late final SubscriptionsApi _api = SubscriptionsApi(McClient(session: ref.read(sessionStoreProvider)));
  late final Future<SubscribePreview?> _preview;
  final Set<int> _selected = {};
  bool _followFuture = false;
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
      if (!mounted) return p;
      setState(() {
        _selected.addAll(p.suggestedSeasons);
        // 没给建议就默认全勾（对齐「不选 = 不订阅任何季」的歧义规避）。
        if (_selected.isEmpty && p.seasons.isNotEmpty) {
          _selected.addAll(p.seasons.map((s) => s.number));
        }
        _followFuture = p.seasons.isNotEmpty;
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
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: FutureBuilder<SubscribePreview?>(
        future: _preview,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final p = snap.data;
          if (p == null || p.notFound) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(p == null ? (_error ?? '预检失败') : '未找到该作品',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            );
          }
          // 已订阅：入口转管理订阅。
          final existingId = p.existingSubscriptionId;
          if (existingId != null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('已订阅《${p.title}》',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(SubscribeSheetOutcome.managed),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('管理订阅'),
                  ),
                ],
              ),
            );
          }
          final isMovie = p.seasons.isEmpty;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // —— title-preview：标题 + 简介 ——
                Text(
                  '${p.title ?? ''}${p.year != null ? '（${p.year}）' : ''}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (p.movieOwned)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('该影片已在库中',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
                if (p.overview != null && p.overview!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      p.overview!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
                    ),
                  ),
                // —— 季多选（电影没有季，只给说明）——
                if (!isMovie) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final s in p.seasons)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _selected.contains(s.number),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(s.name ?? '第 ${s.number} 季'),
                            subtitle: s.episodeCount != null
                                ? Text('共 ${s.episodeCount} 集${s.ownedCount != null ? ' · 已入库 ${s.ownedCount} 集' : ''}',
                                    style: TextStyle(
                                        fontSize: 12, color: scheme.onSurfaceVariant))
                                : null,
                            onChanged: (on) {
                              setState(() {
                                if (on == true) {
                                  _selected.add(s.number);
                                } else {
                                  _selected.remove(s.number);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  if (p.seasons.length > 1)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _followFuture,
                      title: const Text('自动追后续新季'),
                      onChanged: (v) => setState(() => _followFuture = v),
                    ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: TextStyle(fontSize: 12, color: scheme.error)),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting || (!isMovie && _selected.isEmpty)
                      ? null
                      : () => _submit(p),
                  child: Text(_submitting ? '提交中…' : '确认订阅'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
