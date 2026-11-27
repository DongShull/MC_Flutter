import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/subscriptions_api.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/mc_api.dart';
import '../state/models.dart';

/// 弹出整季片源标注弹层（1:1 对齐 iOS `MediaSourceAnnotationSheet.swift`）。
Future<String?> showMediaSourceAnnotationSheet(
  BuildContext context,
  WidgetRef ref, {
  required int mediaItemId,
  required int seasonNumber,
  required bool isMovie,
}) {
  return showMcSheet<String>(
    context: context,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
      ),
      child: MediaSourceAnnotationSheet(
        mediaItemId: mediaItemId,
        seasonNumber: seasonNumber,
        isMovie: isMovie,
      ),
    ),
  );
}

class MediaSourceAnnotationSheet extends ConsumerStatefulWidget {
  const MediaSourceAnnotationSheet({
    super.key,
    required this.mediaItemId,
    required this.seasonNumber,
    required this.isMovie,
  });

  final int mediaItemId;
  final int seasonNumber;
  final bool isMovie;

  static const options = <({
    String value,
    String label,
    String consequence,
    bool destructive,
  })>[
    (
      value: 'Remux',
      label: 'Remux',
      consequence: '视作原盘无损封装，除非目标高于 Remux，否则不再洗版',
      destructive: false,
    ),
    (
      value: 'Blu-ray',
      label: '蓝光 (Blu-ray)',
      consequence: '视作蓝光压制，目标为 Remux 时会参与洗版',
      destructive: false,
    ),
    (
      value: 'WEB-DL',
      label: 'WEB-DL',
      consequence: '视作流媒体直录，目标为蓝光/Remux 时会参与洗版',
      destructive: false,
    ),
    (
      value: 'WEBRip',
      label: 'WEBRip',
      consequence: '视作流媒体二次压制，目标为 WEB-DL 或更高时会参与洗版',
      destructive: false,
    ),
    (
      value: 'HDTV',
      label: '电视录制 (HDTV)',
      consequence: '视作电视录制片源，低于 WEB-DL，将参与更高档位洗版',
      destructive: false,
    ),
    (
      value: 'user-lowest',
      label: '不确定（按最低档处理）',
      consequence: '显式记作最低片源档，后续将对这些文件触发整季洗版重下',
      destructive: true,
    ),
  ];

  @override
  ConsumerState<MediaSourceAnnotationSheet> createState() =>
      _MediaSourceAnnotationSheetState();
}

class _MediaSourceAnnotationSheetState
    extends ConsumerState<MediaSourceAnnotationSheet> {
  List<MediaSourceAnnotationCandidateView>? _candidates;
  String? _picked;
  bool _busy = false;
  String? _error;

  String get _scopeLabel =>
      widget.isMovie ? '正片' : SubsFormat.seasonName(widget.seasonNumber);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref
          .read(subscriptionsApiProvider)
          .mediaSourceAnnotationCandidates(
            mediaItemId: widget.mediaItemId,
            seasonNumber: widget.seasonNumber,
          );
      if (mounted) setState(() => _candidates = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendlyMessage);
    } catch (_) {
      if (mounted) setState(() => _error = '加载待标注文件列表失败');
    }
  }

  Future<void> _apply() async {
    final picked = _picked;
    if (picked == null || _busy) return;
    final opt = MediaSourceAnnotationSheet.options
        .where((o) => o.value == picked)
        .firstOrNull;
    if (opt == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await ref
          .read(subscriptionsApiProvider)
          .annotateMediaSource(
            mediaItemId: widget.mediaItemId,
            seasonNumber: widget.seasonNumber,
            mediaSource: opt.value,
          );
      final files = count > 0 ? count : (_candidates?.length ?? 0);
      final msg = '已将$_scopeLabel共 $files 个文件标注为「${opt.label}」';
      if (mounted) Navigator.of(context).pop(msg);
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
          _error = '标注失败：$e';
        });
      }
    }
  }

  String? _sourceDisplay(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value == 'user-lowest') return '最低档(人工)';
    if (value == 'Disc') return '原盘';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final canConfirm =
        _picked != null && candidates != null && candidates.isNotEmpty && !_busy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('标注$_scopeLabel片源', style: McText.title),
                    const SizedBox(height: 2),
                    Text(
                      '仅标注片源未知或此前人工标注的文件，不影响已自动识别的文件',
                      style: McText.micro.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              McActionPill(
                label: _busy ? '提交中…' : '确认标注',
                primary: true,
                busy: _busy,
                height: 36,
                onTap: canConfirm ? _apply : null,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: McTokens.line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SubsColor.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: SubsColor.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: McText.caption.copyWith(color: SubsColor.danger),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text('待标注文件', style: McText.caption.semibold.muted),
                const SizedBox(height: 6),
                if (candidates == null && _error == null)
                  const SizedBox(height: 80, child: McLoadingView())
                else if (candidates == null || candidates.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: McTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: McTokens.line),
                    ),
                    child: Text(
                      '$_scopeLabel当前没有需要标注片源的文件。',
                      style: McText.caption.muted,
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: McTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: McTokens.line),
                    ),
                    child: Column(
                      children: [
                        for (final pair in candidates.indexed) ...[
                          if (pair.$1 > 0)
                            const Divider(height: 1, color: McTokens.line),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    pair.$2.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: McText.caption
                                        .copyWith(color: McTokens.text),
                                  ),
                                ),
                                if (pair.$2.mediaSourceManual &&
                                    _sourceDisplay(pair.$2.mediaSource) !=
                                        null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: McTokens.glassFillHover,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '当前 ${_sourceDisplay(pair.$2.mediaSource)}',
                                      style: McText.micro.muted,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Text(
                                  SubsFormat.bytes(pair.$2.sizeBytes),
                                  style: McText.micro.faint.tabular,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('共 ${candidates.length} 个文件', style: McText.micro.faint),
                ],
                const SizedBox(height: 16),
                Text('选择片源档位', style: McText.caption.semibold.muted),
                const SizedBox(height: 8),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final opt in MediaSourceAnnotationSheet.options)
                      McInsetRow(
                        leading: Icon(
                          _picked == opt.value
                              ? McIcons.checkCircleFill
                              : McIcons.circler,
                          size: 20,
                          color: _picked == opt.value
                              ? (opt.destructive
                                  ? SubsColor.warn
                                  : SubsColor.upgrade)
                              : McTokens.textFaint,
                        ),
                        title: opt.label,
                        subtitle: opt.consequence,
                        onTap: (_busy || (candidates?.isEmpty ?? true))
                            ? null
                            : () => setState(() => _picked = opt.value),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
