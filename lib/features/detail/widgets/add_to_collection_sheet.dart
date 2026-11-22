// 加入合集弹层（对照安卓详情页「合集」入口与 web 合集管理）。
//
// 走类型化 McApi：`GET /collections` 列合集 → 点合集
// `POST /collections/{id}/items` 加条目；没有合集时可就地新建
// （`POST /collections`）。失败如实报错，不静默吞掉。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/models.dart';
import '../../../core/designsystem/state_views.dart';

/// 打开「加入合集」弹层。返回 true = 已加入至少一个合集。
Future<bool?> showAddToCollectionSheet(
  BuildContext context, {
  required int mediaItemId,
  required String title,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddToCollectionSheet(
      mediaItemId: mediaItemId,
      title: title,
    ),
  );
}

class _AddToCollectionSheet extends ConsumerStatefulWidget {
  const _AddToCollectionSheet({
    required this.mediaItemId,
    required this.title,
  });

  final int mediaItemId;
  final String title;

  @override
  ConsumerState<_AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState
    extends ConsumerState<_AddToCollectionSheet> {
  List<CollectionView>? _collections;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _creating = false;
  final _nameInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(mcApiProvider)
          .collections(includeEmpty: true, includeHidden: true);
      if (mounted) {
        setState(() {
          _collections = list;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.friendlyMessage;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败：$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _addTo(CollectionView collection) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(mcApiProvider).collectionAddItems(
            collection.id,
            body: CollectionItemsPayload(
              mediaItemIds: [widget.mediaItemId],
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.friendlyMessage;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加入失败：$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final name = _nameInput.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await ref.read(mcApiProvider).createCollection(
            body: CollectionPayload(name: name),
          );
      if (!mounted) return;
      setState(() => _busy = false);
      await _addTo(created);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.friendlyMessage;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '新建失败：$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '加入合集',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: McLoadingView(),
              )
            else if (_error != null && _collections == null)
              McErrorView(text: _error!, onRetry: _load)
            else ...[
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in _collections ?? const <CollectionView>[])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.name),
                        subtitle: c.itemCount > 0
                            ? Text('${c.itemCount} 部')
                            : null,
                        trailing: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _addTo(c),
                      ),
                    if ((_collections ?? const []).isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('还没有合集，在下面新建一个。'),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              if (_creating) ...[
                TextField(
                  controller: _nameInput,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _create(),
                  decoration: const InputDecoration(
                    labelText: '新合集名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: Text(_busy ? '新建中…' : '新建并加入'),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () => setState(() => _creating = true),
                  icon: const Icon(Icons.add),
                  label: const Text('新建合集'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
