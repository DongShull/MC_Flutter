import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/llm_capability_probe.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../../../core/navigation/external_media_link.dart';
import '../state/activity_derive.dart';
import '../state/models.dart';

/// 活动页复用组件集合（1:1 对齐 iOS `JobCard.swift` / `TaskCards.swift` / `NowPlayingRows.swift`）。

class ActivityProgressBar extends StatelessWidget {
  const ActivityProgressBar({
    super.key,
    this.progress,
    this.label,
    this.color,
  });

  final double? progress;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress?.clamp(0.0, 1.0),
            minHeight: 3.5,
            color: color ?? McTokens.accentStrong,
            backgroundColor: const Color(0x26FFFFFF),
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label!, style: McText.caption.muted),
        ],
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: McText.caption.copyWith(
          color: danger ? McTokens.danger : McTokens.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 活动页顶部告警横幅（支持可选右侧动作按钮，如「检查设置」）。
class ActivityWarningBanner extends StatelessWidget {
  const ActivityWarningBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1FFF6B6B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x4DFF6B6B), width: 1),
      ),
      child: Row(
        children: [
          const Icon(McIcons.alert1, color: McTokens.danger, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            McPressable(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: McText.caption.copyWith(
                  color: McTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 下载器不可用 / 快照读取失败告警条（对齐 iOS `TaskSourceWarning`）。
class TaskSourceWarningBanner extends StatelessWidget {
  const TaskSourceWarningBanner({
    super.key,
    required this.sources,
    this.downloadsError,
  });

  final List<DownloadTaskSource> sources;
  final String? downloadsError;

  @override
  Widget build(BuildContext context) {
    final failed = sources.where((s) => s.status != 'active').toList();
    if (failed.isEmpty && downloadsError == null) {
      return const SizedBox.shrink();
    }
    final msg = downloadsError ??
        failed
            .map(
              (s) => (s.message != null && s.message!.isNotEmpty)
                  ? '下载器「${s.name}」异常：${s.message}'
                  : '下载器「${s.name}」当前不可用',
            )
            .join('；');
    return ActivityWarningBanner(
      message: msg,
      actionLabel: '检查设置',
      onAction: () => context.push('/settings/downloaders'),
    );
  }
}

/// 小圆点状态指示。
class ActivityStatusDot extends StatelessWidget {
  const ActivityStatusDot({
    super.key,
    required this.color,
    this.size = 9,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 隐藏范围脚注条（对齐 iOS `scopeFooter` / `HiddenCountRow`）。
class ActivityScopeFooter extends StatelessWidget {
  const ActivityScopeFooter({
    super.key,
    required this.hiddenCount,
    required this.scope,
    required this.hiddenText,
    required this.onToggleScope,
  });

  final int hiddenCount;
  final String scope;
  final String hiddenText;
  final Future<void> Function(String nextScope) onToggleScope;

  @override
  Widget build(BuildContext context) {
    if (hiddenCount <= 0 && scope != 'all') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hiddenCount > 0 ? hiddenText : '当前已包含你可见范围外的记录',
              style: McText.caption.faint,
            ),
          ),
          const SizedBox(width: 8),
          McPressable(
            onTap: () => onToggleScope(hiddenCount > 0 ? 'all' : 'visible'),
            child: Text(
              hiddenCount > 0 ? '显示全部' : '仅看我的范围',
              style: McText.caption.copyWith(
                color: McTokens.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 忽略任务弹层（支持 mute_source） ──

Future<void> showDismissJobSheet(
  BuildContext context, {
  required JobView job,
  required Future<void> Function(bool muteSource) onConfirm,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => DismissJobSheet(job: job, onConfirm: onConfirm),
  );
}

class DismissJobSheet extends StatefulWidget {
  const DismissJobSheet({
    super.key,
    required this.job,
    required this.onConfirm,
  });

  final JobView job;
  final Future<void> Function(bool muteSource) onConfirm;

  @override
  State<DismissJobSheet> createState() => _DismissJobSheetState();
}

class _DismissJobSheetState extends State<DismissJobSheet> {
  late bool _muteSource =
      autoRecreatedJobTypes.containsKey(widget.job.jobType);
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final muteLabel = autoRecreatedJobTypes[widget.job.jobType];
    final subject = (widget.job.subject?.isNotEmpty ?? false)
        ? widget.job.subject!
        : jobTypeLabel(widget.job);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('忽略这个任务', style: McText.title),
          const SizedBox(height: 8),
          Text(
            '忽略后该任务将从「需要处理」移入已结束历史记录，之后仍可随时撤销忽略。',
            style: McText.sub.muted,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: McTokens.line),
            ),
            child: Text(subject, style: McText.sub.copyWith(color: McTokens.text)),
          ),
          if (muteLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _muteSource
                    ? const Color(0x14FFFFFF)
                    : McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _muteSource ? McTokens.lineStrong : McTokens.line,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          muteLabel,
                          style: McText.sub.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '后续自动扫描不再为此对象重复创建同类任务（手动触发不受影响）。',
                          style: McText.caption.muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _muteSource,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _muteSource = v),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '取消',
                  primary: false,
                  height: 44,
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: McActionPill(
                  label: _busy ? '正在忽略…' : '确认忽略',
                  primary: true,
                  height: 44,
                  busy: _busy,
                  onTap: _busy
                      ? null
                      : () async {
                          setState(() {
                            _busy = true;
                            _error = null;
                          });
                          try {
                            await widget.onConfirm(_muteSource);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _busy = false;
                                _error = e.toString();
                              });
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 删除种子确认弹层（支持 delete_files 勾选） ──

Future<void> showDeleteTorrentSheet(
  BuildContext context, {
  required DownloadTask task,
  required Future<void> Function(bool deleteFiles) onConfirm,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => DeleteTorrentDialog(task: task, onConfirm: onConfirm),
  );
}

class DeleteTorrentDialog extends StatefulWidget {
  const DeleteTorrentDialog({
    super.key,
    required this.task,
    required this.onConfirm,
  });

  final DownloadTask task;
  final Future<void> Function(bool deleteFiles) onConfirm;

  @override
  State<DeleteTorrentDialog> createState() => _DeleteTorrentDialogState();
}

class _DeleteTorrentDialogState extends State<DeleteTorrentDialog> {
  bool _deleteFiles = false;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final dlName = (widget.task.downloaderName?.isNotEmpty ?? false)
        ? widget.task.downloaderName!
        : '下载器 #${widget.task.downloaderId ?? 0}';
    final title = (widget.task.name?.isNotEmpty ?? false)
        ? widget.task.name!
        : widget.task.infoHash;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('删除下载任务', style: McText.title),
          const SizedBox(height: 8),
          Text(
            '将从「$dlName」中移除以下种子任务：',
            style: McText.sub.muted,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: McTokens.line),
            ),
            child: Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.copyWith(color: McTokens.text),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _deleteFiles
                  ? const Color(0x18FF6B6B)
                  : McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _deleteFiles
                    ? const Color(0x55FF6B6B)
                    : McTokens.line,
              ),
            ),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _deleteFiles,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _deleteFiles = v ?? false),
              title: Text(
                '同时删除磁盘上的数据文件',
                style: McText.sub.copyWith(
                  color: _deleteFiles ? McTokens.danger : McTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '默认仅移除任务并保留文件；勾选后将永久删除已下载文件。',
                style: McText.caption.muted,
              ),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
          if (widget.task.source == 'subscription') ...[
            const SizedBox(height: 8),
            Text(
              '提示：删除下载任务不会取消对应的追更订阅。',
              style: McText.caption.copyWith(color: McTokens.warning),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '取消',
                  primary: false,
                  height: 44,
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: McActionPill(
                  label: _busy
                      ? '正在删除…'
                      : (_deleteFiles ? '连文件一起删除' : '仅移除任务'),
                  primary: false,
                  tone: McGlassTone.danger,
                  height: 44,
                  busy: _busy,
                  onTap: _busy
                      ? null
                      : () async {
                          setState(() {
                            _busy = true;
                            _error = null;
                          });
                          try {
                            await widget.onConfirm(_deleteFiles);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _busy = false;
                                _error = e.toString();
                              });
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 季集标签（EpisodeUnitsLabel） ──

class EpisodeUnitsLabel extends StatefulWidget {
  const EpisodeUnitsLabel({
    super.key,
    required this.units,
    required this.purpose,
  });

  final List<DownloadTaskUnit> units;
  final String purpose;

  @override
  State<EpisodeUnitsLabel> createState() => _EpisodeUnitsLabelState();
}

class _EpisodeUnitsLabelState extends State<EpisodeUnitsLabel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final summary = summarizeEpisodeUnits(widget.units);
    if (summary == null) return const SizedBox.shrink();
    final upgrade = widget.purpose == 'upgrade';
    final doneKeys = widget.units
        .where((u) => upgrade ? u.replaced : u.status == 'imported')
        .map((u) => '${u.seasonNumber}:${u.episodeNumber}')
        .toSet();
    final doneWord = upgrade ? '已替换' : '已入库';

    if (summary.isMovie || summary.episodeCount <= 1) {
      return Text.rich(
        TextSpan(
          text: summary.label,
          style: McText.caption.copyWith(color: McTokens.text).tabular,
          children: [
            if (!summary.isMovie && doneKeys.isNotEmpty)
              TextSpan(
                text: '（$doneWord）',
                style: McText.caption.copyWith(color: McTokens.ok),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        McPressable(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  summary.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.copyWith(color: McTokens.text).tabular,
                ),
              ),
              if (doneKeys.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '$doneWord ${doneKeys.length} 集',
                  style: McText.caption.copyWith(color: McTokens.ok).tabular,
                ),
              ],
              const SizedBox(width: 3),
              Icon(
                _open ? McIcons.arrowUpS : McIcons.arrowDownS,
                size: 13,
                color: McTokens.textFaint,
              ),
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in summary.seasons) ...[
                  Row(
                    children: [
                      Text(
                        'S${mcPad2(s.season)}',
                        style: McText.micro.copyWith(
                          color: McTokens.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '共 ${s.episodes.length} 集',
                        style: McText.micro.faint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final ep in s.episodes)
                        Builder(
                          builder: (_) {
                            final done = doneKeys.contains('${s.season}:$ep');
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: done
                                    ? McTokens.ok.withValues(alpha: 0.16)
                                    : const Color(0x0EFFFFFF),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'E${mcPad2(ep)}',
                                style: McText.micro
                                    .copyWith(
                                      color: done
                                          ? McTokens.ok
                                          : McTokens.textMuted,
                                    )
                                    .tabular,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  if (s != summary.seasons.last) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── 下载生命周期步进视图（DownloadLifecycleView） ──

class DownloadLifecycleView extends StatelessWidget {
  const DownloadLifecycleView({
    super.key,
    required this.task,
    this.ingestJob,
  });

  final DownloadTask task;
  final JobView? ingestJob;

  Color _dotColor(LifecycleTone tone) => switch (tone) {
        LifecycleTone.done => McTokens.ok,
        LifecycleTone.current => McTokens.info,
        LifecycleTone.waiting => McTokens.warning,
        LifecycleTone.attention => McTokens.danger,
        LifecycleTone.future => McTokens.textFaint,
      };

  @override
  Widget build(BuildContext context) {
    final steps = downloadLifecycleSteps(task, ingestJob);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16, color: McTokens.line),
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 14,
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: steps[i].tone == LifecycleTone.future
                              ? Colors.transparent
                              : _dotColor(steps[i].tone),
                          border: steps[i].tone == LifecycleTone.future
                              ? Border.all(color: McTokens.lineStrong, width: 1)
                              : null,
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1,
                            margin: const EdgeInsets.only(top: 3),
                            color: McTokens.line,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == steps.length - 1 ? 0 : 7,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].label,
                          style: McText.micro.copyWith(
                            color: steps[i].tone == LifecycleTone.future
                                ? McTokens.textFaint
                                : _dotColor(steps[i].tone),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (steps[i].detail.isNotEmpty)
                          Text(
                            steps[i].detail,
                            maxLines:
                                steps[i].tone == LifecycleTone.attention ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: McText.micro.copyWith(
                              fontWeight: FontWeight.w400,
                              color: steps[i].tone == LifecycleTone.attention
                                  ? McTokens.danger.withValues(alpha: 0.8)
                                  : McTokens.textFaint,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── 下载任务分组卡（修复 multi-task group 操作缺失，增加生命周期、集号、换种、AI 诊断、删种弹层） ──

class DownloadGroupCard extends StatelessWidget {
  const DownloadGroupCard({
    super.key,
    required this.group,
    required this.ingestJobs,
    required this.onReplace,
    required this.onDelete,
  });

  final DownloadGroup group;
  final Map<String, JobView> ingestJobs;
  final Future<void> Function(DownloadTask) onReplace;
  final Future<void> Function(DownloadTask, bool deleteFiles) onDelete;

  @override
  Widget build(BuildContext context) {
    if (group.mediaItemId == null && group.tasks.length == 1) {
      final task = group.tasks.first;
      return DownloadTaskCard(
        task: task,
        ingestJob: ingestJobs[task.infoHash.toLowerCase()],
        grouped: false,
        onReplace: onReplace,
        onDelete: onDelete,
      );
    }

    final resolved = McImageUrls.resolve(group.posterUrl, widthPx: 140);
    final sub = group.tasks.expand((t) => t.subscriptions).firstOrNull;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: resolved.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: resolved,
                          httpHeaders: mcImageHeaders(),
                          width: 36,
                          height: 54,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 36,
                          height: 54,
                          color: McTokens.posterPlaceholder,
                          alignment: Alignment.center,
                          child: const Icon(
                            McIcons.film,
                            size: 16,
                            color: McTokens.textFaint,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.copyWith(
                          color: McTokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.kind == 'tv' ? '剧集' : '电影'} · ${group.tasks.length} 个资源',
                        style: McText.caption.faint.tabular,
                      ),
                    ],
                  ),
                ),
                if (sub != null && sub.id > 0) ...[
                  const SizedBox(width: 8),
                  McActionPill(
                    label: '查看订阅',
                    primary: false,
                    height: 30,
                    onTap: () => context.push('/subscriptions/detail/${sub.id}'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                for (var i = 0; i < group.tasks.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  DownloadTaskCard(
                    task: group.tasks[i],
                    ingestJob: ingestJobs[group.tasks[i].infoHash.toLowerCase()],
                    grouped: true,
                    onReplace: onReplace,
                    onDelete: onDelete,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadTaskCard extends StatefulWidget {
  const DownloadTaskCard({
    super.key,
    required this.task,
    this.ingestJob,
    this.grouped = false,
    required this.onReplace,
    required this.onDelete,
  });

  final DownloadTask task;
  final JobView? ingestJob;
  final bool grouped;
  final Future<void> Function(DownloadTask) onReplace;
  final Future<void> Function(DownloadTask, bool deleteFiles) onDelete;

  @override
  State<DownloadTaskCard> createState() => _DownloadTaskCardState();
}

class _DownloadTaskCardState extends State<DownloadTaskCard> {
  bool _replacing = false;

  Color _stateColor(String state, JobView? ingest, bool ingestOwns) {
    if (ingestOwns && ingest != null) {
      if (jobNeedsAttention(ingest)) return McTokens.danger;
      if (ingest.status == 'running' || ingest.status == 'succeeded') {
        return McTokens.ok;
      }
      return McTokens.warning;
    }
    return switch (state) {
      'downloading' || 'checking' => McTokens.info,
      'completed' => McTokens.ok,
      'error' || 'missing' => McTokens.danger,
      'paused' || 'stalled' => McTokens.warning,
      _ => McTokens.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final ingest = widget.ingestJob;
    final ingestOwns = ingestOwnsTaskState(task, ingest);
    final attention = downloadTaskNeedsAttention(task, ingest);
    final accent = _stateColor(task.state, ingest, ingestOwns);
    final title = widget.grouped
        ? ((task.name?.isNotEmpty ?? false)
            ? task.name!
            : (task.mediaTitle ?? task.infoHash))
        : ((task.mediaTitle?.isNotEmpty ?? false)
            ? task.mediaTitle!
            : (task.name ?? task.infoHash));
    final torrentName =
        !widget.grouped && task.name != null && task.name != title
            ? task.name
            : null;
    final note = downloadTaskNote(task, ingest);
    final percent = ingestOwns
        ? ingest?.progress.percent
        : (task.progress != null ? task.progress! * 100 : null);
    final sub = task.subscriptions.firstOrNull;
    final specs = [
      if (task.resolution != null && task.resolution!.isNotEmpty)
        task.resolution!,
      if (task.mediaSource != null && task.mediaSource!.isNotEmpty)
        task.mediaSource!,
      if (task.remux) 'Remux',
      if (task.sizeBytes != null) mcFormatBytes(task.sizeBytes!),
    ];

    return Container(
      margin: widget.grouped
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(widget.grouped ? 12 : 14),
      decoration: BoxDecoration(
        color: widget.grouped
            ? const Color(0x28000000)
            : McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(widget.grouped ? 12 : 16),
        border: Border.all(
          color: attention
              ? McTokens.danger.withValues(alpha: 0.28)
              : McTokens.line,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: ActivityStatusDot(color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (task.pageUrl != null || task.downloaderId != null)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(
                    McIcons.more,
                    size: 17,
                    color: McTokens.textMuted,
                  ),
                  onSelected: (v) async {
                    if (v == 'page' && task.pageUrl != null) {
                      await ExternalMediaLink.open(task.pageUrl!);
                    } else if (v == 'delete') {
                      await showDeleteTorrentSheet(
                        context,
                        task: task,
                        onConfirm: (delFiles) =>
                            widget.onDelete(task, delFiles),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    if (task.pageUrl != null && task.pageUrl!.isNotEmpty)
                      const PopupMenuItem(
                        value: 'page',
                        child: Text('打开站点种子页'),
                      ),
                    if (task.downloaderId != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '删除下载任务',
                          style: TextStyle(color: McTokens.danger),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (torrentName != null || note != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: attention ? const EdgeInsets.all(10) : EdgeInsets.zero,
              decoration: attention
                  ? BoxDecoration(
                      color: const Color(0x14FF6B6B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x38FF6B6B)),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: McText.caption.copyWith(
                        color: attention ? McTokens.danger : McTokens.textMuted,
                      ),
                      children: [
                        if (attention)
                          const TextSpan(
                            text: '需要处理：',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        if (torrentName != null) TextSpan(text: torrentName),
                        if (torrentName != null && note != null)
                          const TextSpan(text: ' · '),
                        if (note != null) TextSpan(text: note),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (shouldOfferInlineReplacement(task)) ...[
                    const SizedBox(height: 8),
                    McActionPill(
                      label: _replacing ? '正在换种…' : '立即换种',
                      primary: false,
                      tone: McGlassTone.danger,
                      height: 32,
                      busy: _replacing,
                      onTap: _replacing
                          ? null
                          : () async {
                              setState(() => _replacing = true);
                              try {
                                await widget.onReplace(task);
                              } finally {
                                if (mounted) setState(() => _replacing = false);
                              }
                            },
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (sub != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isUpgradeTask(task))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x222DD4BF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x552DD4BF)),
                    ),
                    child: Text(
                      '洗版',
                      style: McText.micro.copyWith(
                        color: const Color(0xFF2DD4BF),
                      ),
                    ),
                  ),
                EpisodeUnitsLabel(units: sub.units, purpose: sub.purpose),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            [
              downloadSourceLabel(task),
              if (task.siteName != null && task.siteName!.isNotEmpty)
                task.siteName!,
              if (task.downloaderName != null &&
                  task.downloaderName!.isNotEmpty)
                task.downloaderName!,
              ...specs,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: McText.micro.faint.tabular,
          ),
          if (percent != null && task.state != 'missing') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  ingestOwns ? '入库进度' : '下载进度',
                  style: McText.micro.muted,
                ),
                if (!ingestOwns &&
                    task.state == 'downloading' &&
                    (task.dlspeedBytes ?? 0) > 0) ...[
                  Text(' · ', style: McText.micro.faint),
                  Text(
                    '↓ ${mcFormatSpeed(task.dlspeedBytes!)}',
                    style: McText.micro.copyWith(color: McTokens.info).tabular,
                  ),
                ],
                if (!ingestOwns &&
                    task.state == 'downloading' &&
                    (task.etaSeconds ?? 0) > 0) ...[
                  Text(' · ', style: McText.micro.faint),
                  Text(
                    '剩 ${formatDurationSeconds(task.etaSeconds!.toDouble())}',
                    style: McText.micro.faint.tabular,
                  ),
                ],
                const Spacer(),
                Text(
                  '${percent.floor().clamp(0, 100)}%',
                  style: McText.micro.muted.tabular,
                ),
              ],
            ),
            const SizedBox(height: 5),
            ActivityProgressBar(
              progress: percent / 100.0,
              color: accent,
            ),
          ],
          DownloadLifecycleView(task: task, ingestJob: ingest),
          if (attention) ...[
            const Divider(height: 18, color: McTokens.line),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                McAgentHandoffButton(
                  kind: 'download',
                  refId: task.infoHash,
                  compact: true,
                ),
                if ((task.state == 'error' ||
                        (task.landingError?.isNotEmpty ?? false)) &&
                    task.downloaderId != null)
                  McActionPill(
                    label: '删除下载任务',
                    primary: false,
                    tone: McGlassTone.danger,
                    height: 32,
                    onTap: () => showDeleteTorrentSheet(
                      context,
                      task: task,
                      onConfirm: (delFiles) => widget.onDelete(task, delFiles),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── 完整 JobCard（支持 error.actions、DismissJobSheet、领域芯片、入库文件展开、LLM Token 用量） ──

class JobCard extends ConsumerStatefulWidget {
  const JobCard({
    super.key,
    required this.job,
    this.historical = false,
    this.onCancel,
    this.onRetry,
    this.onDismiss,
    this.onUndismiss,
  });

  final JobView job;
  final bool historical;
  final Future<void> Function()? onCancel;
  final Future<void> Function()? onRetry;
  final Future<void> Function(bool muteSource)? onDismiss;
  final Future<void> Function()? onUndismiss;

  @override
  ConsumerState<JobCard> createState() => _JobCardState();
}

class _JobCardState extends ConsumerState<JobCard> {
  String? _busyAction;
  String? _actionError;
  bool _filesOpen = false;
  bool _usageOpen = false;

  Color _statusColor(String status) => switch (status) {
        'running' => McTokens.info,
        'retry_wait' || 'cancelling' => McTokens.warning,
        'blocked' || 'failed' => McTokens.danger,
        'succeeded' => McTokens.ok,
        _ => McTokens.textFaint,
      };

  String _settingsRouteForAction(JobErrorAction action) {
    if (action.type == 'inspect_logs') return '/settings/system?section=logs';
    if (action.type == 'update_runtime') return '/update';
    final target = action.target ?? '';
    return switch (target) {
      'llm' || 'ai' => '/settings/ai',
      'downloaders' => '/settings/downloaders',
      'sites' || 'search' => '/settings/sites',
      'scrape' || 'import-watch' => '/settings/scrape',
      'playback' => '/settings/playback',
      'logs' || 'network' || 'system' => '/settings/system?section=$target',
      'maintenance' || 'about' || 'cloud' || 'app' =>
        '/settings/maintenance?section=$target',
      _ => '/settings',
    };
  }

  Future<void> _runErrorAction(JobErrorAction action) async {
    setState(() {
      _busyAction = action.type;
      _actionError = null;
    });
    try {
      switch (action.type) {
        case 'retry_job':
          if (widget.onRetry != null) await widget.onRetry!();
          break;
        case 'handoff_agent':
          final sid = await AgentHandoffApi.handoff(
            ref.read(mcClientProvider),
            kind: 'job',
            ref: widget.job.id,
          );
          if (mounted) {
            context.push('/agent/session/${Uri.encodeComponent(sid)}');
          }
          break;
        default:
          if (mounted) context.push(_settingsRouteForAction(action));
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final active = activeFeedJobStatuses.contains(job.status);
    final dismissed = jobIsDismissed(job);
    final attention = jobNeedsAttention(job);
    final details = jobDetailItems(job);
    final hasDomainAlert = details.any((d) => d.alert);
    final compact =
        widget.historical ||
        ((job.status == 'succeeded' || job.status == 'cancelled') &&
            !hasDomainAlert);
    final title = (job.subject?.isNotEmpty ?? false)
        ? job.subject!
        : jobTypeLabel(job);
    final completedLang =
        job.status == 'succeeded' ? subtitleLanguageLabel(job) : null;
    final summary = completedLang != null
        ? '已生成 $completedLang 字幕'
        : ((job.error?.message.isNotEmpty ?? false)
            ? job.error!.message
            : (job.progress.message.isNotEmpty
                ? job.progress.message
                : historicalJobSummary(job)));
    final imported = job.jobType == 'library.ingest'
        ? stringList(job.progress.details, 'imported_files')
        : const <String>[];
    final usage = subtitleUsageSummary(job);
    final probe = ref.watch(llmCapabilityProbeProvider);

    final actions = (job.error?.actions ?? const <JobErrorAction>[])
        .where(
          (a) =>
              supportedErrorActions.contains(a.type) &&
              (a.type != 'handoff_agent' || probe.allowsHandoff),
        )
        .toList();
    if (job.status == 'cancelled' &&
        !jobIsSystemCancelled(job) &&
        !actions.any((a) => a.type == 'retry_job')) {
      actions.insert(0, const JobErrorAction(type: 'retry_job', label: '重新执行'));
    }

    final cancellable = active && job.status != 'cancelling' && widget.onCancel != null;
    final dismissable = job.status == 'failed' && !dismissed && widget.onDismiss != null;
    final restorable = dismissed && widget.onUndismiss != null;
    final hasMenu = cancellable || actions.isNotEmpty || dismissable || restorable;
    final hasHandoffAction = actions.any((a) => a.type == 'handoff_agent');

    final borderColor = attention
        ? McTokens.danger.withValues(alpha: 0.3)
        : hasDomainAlert
            ? McTokens.warning.withValues(alpha: 0.25)
            : McTokens.line;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: ActivityStatusDot(color: _statusColor(job.status)),
              ),
              const SizedBox(width: 8),
              if (job.subject != null && job.subject!.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: McTokens.surfaceInset,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Text(
                    jobTypeLabel(job),
                    style: McText.micro.muted,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  widget.historical ? historicalJobTitle(job) : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasMenu)
                PopupMenuButton<String>(
                  enabled: _busyAction == null,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    McIcons.more,
                    size: 17,
                    color: McTokens.textMuted,
                  ),
                  onSelected: (value) async {
                    if (value == '__cancel' && widget.onCancel != null) {
                      setState(() => _busyAction = 'cancel');
                      try {
                        await widget.onCancel!();
                      } catch (e) {
                        if (mounted) setState(() => _actionError = e.toString());
                      } finally {
                        if (mounted) setState(() => _busyAction = null);
                      }
                    } else if (value == '__dismiss' && widget.onDismiss != null) {
                      await showDismissJobSheet(
                        context,
                        job: job,
                        onConfirm: widget.onDismiss!,
                      );
                    } else if (value == '__undismiss' &&
                        widget.onUndismiss != null) {
                      setState(() => _busyAction = 'undismiss');
                      try {
                        await widget.onUndismiss!();
                      } catch (e) {
                        if (mounted) setState(() => _actionError = e.toString());
                      } finally {
                        if (mounted) setState(() => _busyAction = null);
                      }
                    } else if (value.startsWith('act:')) {
                      final idx = int.tryParse(value.substring(4));
                      if (idx != null && idx >= 0 && idx < actions.length) {
                        await _runErrorAction(actions[idx]);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    if (cancellable)
                      const PopupMenuItem(
                        value: '__cancel',
                        child: Text('取消任务'),
                      ),
                    for (var i = 0; i < actions.length; i++)
                      PopupMenuItem(
                        value: 'act:$i',
                        child: Text(actions[i].label),
                      ),
                    if (dismissable)
                      const PopupMenuItem(
                        value: '__dismiss',
                        child: Text('忽略此任务'),
                      ),
                    if (restorable)
                      const PopupMenuItem(
                        value: '__undismiss',
                        child: Text('撤销忽略'),
                      ),
                  ],
                ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            SizedBox(height: compact ? 6 : 10),
            Container(
              width: double.infinity,
              padding: attention ? const EdgeInsets.all(10) : EdgeInsets.zero,
              decoration: attention
                  ? BoxDecoration(
                      color: const Color(0x14FF6B6B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x38FF6B6B)),
                    )
                  : null,
              child: SelectableText.rich(
                TextSpan(
                  style: (compact ? McText.caption : McText.sub).copyWith(
                    color: attention
                        ? McTokens.danger
                        : (compact ? McTokens.textFaint : McTokens.textMuted),
                  ),
                  children: [
                    if (attention)
                      const TextSpan(
                        text: '需要处理：',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    TextSpan(text: summary),
                  ],
                ),
                maxLines: compact ? 2 : 4,
              ),
            ),
          ],
          if (imported.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: McTokens.surfaceInset,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: McTokens.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  McPressable(
                    onTap: imported.length > 1
                        ? () => setState(() => _filesOpen = !_filesOpen)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          if (imported.length > 1) ...[
                            Icon(
                              _filesOpen
                                  ? McIcons.arrowDownS
                                  : McIcons.arrowRightS,
                              size: 13,
                              color: McTokens.textFaint,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            imported.length == 1
                                ? '新增文件'
                                : '新增 ${imported.length} 个文件',
                            style: McText.micro.faint,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              imported.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.micro.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_filesOpen) ...[
                    const Divider(height: 1, color: McTokens.line),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final f in imported)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: SelectableText(
                                f,
                                style: McText.micro.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (!compact &&
              !(job.jobType == 'library.scan' && job.status == 'succeeded') &&
              (job.progress.percent != null ||
                  job.status == 'running' ||
                  job.status == 'cancelling' ||
                  job.status == 'retry_wait')) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  jobPhaseLabel(job.progress.phase),
                  style: McText.micro.muted,
                ),
                if (job.progress.phaseIndex != null &&
                    job.progress.phaseCount != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '第 ${job.progress.phaseIndex}/${job.progress.phaseCount} 步',
                    style: McText.micro.faint.tabular,
                  ),
                ],
                const Spacer(),
                Text(
                  job.progress.percent != null
                      ? '${job.progress.percent!.round()}%'
                      : (job.status == 'retry_wait'
                          ? '等待重试'
                          : job.progress.mode == 'waiting'
                              ? '等待中'
                              : '处理中'),
                  style: McText.micro.faint.tabular,
                ),
              ],
            ),
            const SizedBox(height: 5),
            ActivityProgressBar(
              progress: job.progress.percent == null
                  ? null
                  : job.progress.percent! / 100.0,
              color: _statusColor(job.status),
            ),
            if (cardProgressAmount(job) != null || job.status == 'retry_wait') ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (cardProgressAmount(job) != null) cardProgressAmount(job)!,
                  if (job.status == 'retry_wait')
                    '第 ${job.attempt.clamp(1, 999)} / ${job.maxAttempts} 次尝试',
                ].join(' · '),
                style: McText.micro.faint.tabular,
              ),
            ],
          ],
          if (!compact && details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in details)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.alert
                          ? McTokens.warning.withValues(alpha: 0.08)
                          : McTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.alert
                            ? McTokens.warning.withValues(alpha: 0.25)
                            : McTokens.line,
                      ),
                    ),
                    child: Text(
                      item.label,
                      style: McText.micro.copyWith(
                        color: item.alert
                            ? McTokens.warning
                            : McTokens.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (usage != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: McTokens.line),
            McPressable(
              onTap: () => setState(() => _usageOpen = !_usageOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _usageOpen ? McIcons.arrowDownS : McIcons.arrowRightS,
                      size: 13,
                      color: McTokens.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _usageOpen ? '收起模型用量' : '查看模型用量',
                      style: McText.micro.muted,
                    ),
                    const Spacer(),
                    Text(
                      '${formatInteger(usage.totalTokens)} tokens · ${usage.requests} 次请求',
                      style: McText.micro.faint.tabular,
                    ),
                  ],
                ),
              ),
            ),
            if (_usageOpen)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x26000000),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: McTokens.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _UsageCell('总 Tokens', formatInteger(usage.totalTokens)),
                        _UsageCell('输入', formatInteger(usage.promptTokens)),
                        _UsageCell('输出', formatInteger(usage.completionTokens)),
                        _UsageCell('缓存命中', formatInteger(usage.cacheReadTokens)),
                      ],
                    ),
                    const Divider(height: 14, color: McTokens.line),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (job.providerRef != null &&
                            job.providerRef!.isNotEmpty)
                          Text(job.providerRef!, style: McText.micro.faint),
                        Text('请求 ${usage.requests} 次',
                            style: McText.micro.faint.tabular),
                        if (usage.failedRequests > 0)
                          Text(
                            '失败 ${usage.failedRequests} 次',
                            style: McText.micro
                                .copyWith(color: McTokens.warning)
                                .tabular,
                          ),
                        Text(
                          '累计耗时 ${formatModelDuration(usage.totalDurationMs)}',
                          style: McText.micro.faint.tabular,
                        ),
                        Text(
                          '单次峰值 ${formatModelDuration(usage.maxDurationMs)}',
                          style: McText.micro.faint.tabular,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
          if (attention && (actions.isNotEmpty || dismissable)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (hasHandoffAction || attention)
                  McAgentHandoffButton(
                    kind: 'job',
                    refId: job.id,
                    compact: true,
                  ),
                for (final act in actions.where((a) => a.type != 'handoff_agent'))
                  McActionPill(
                    label: _busyAction == act.type ? '处理中…' : act.label,
                    primary: act.type == 'retry_job',
                    height: 30,
                    onTap: _busyAction == null
                        ? () => _runErrorAction(act)
                        : null,
                  ),
                if (dismissable)
                  McActionPill(
                    label: '忽略',
                    primary: false,
                    height: 30,
                    onTap: _busyAction == null
                        ? () => showDismissJobSheet(
                              context,
                              job: job,
                              onConfirm: widget.onDismiss!,
                            )
                        : null,
                  ),
              ],
            ),
          ],
          if (_actionError != null) ...[
            const SizedBox(height: 8),
            Text(
              _actionError!,
              style: McText.micro.copyWith(color: McTokens.danger),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${cardOriginLabel(job)} · ${mcFromNowIso(job.createdAt, empty: '')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.micro.faint.tabular,
                ),
              ),
              if (dismissed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: McTokens.surfaceInset,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Text('已忽略', style: McText.micro.faint),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageCell extends StatelessWidget {
  const _UsageCell(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: McText.micro.faint),
          const SizedBox(height: 2),
          Text(
            value,
            style: McText.caption
                .copyWith(color: McTokens.text, fontWeight: FontWeight.w600)
                .tabular,
          ),
        ],
      ),
    );
  }
}

// ── 历史入库文件展开块（IngestHistoryFiles） ──

class IngestHistoryFiles extends StatefulWidget {
  const IngestHistoryFiles({super.key, required this.detail});

  final IngestHistoryDetail detail;

  @override
  State<IngestHistoryFiles> createState() => _IngestHistoryFilesState();
}

class _IngestHistoryFilesState extends State<IngestHistoryFiles> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    if (d.fileGroups.isEmpty && d.context == null) {
      return const SizedBox.shrink();
    }
    final fileCount =
        d.fileGroups.fold<int>(0, (acc, g) => acc + g.files.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        McPressable(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _open ? McIcons.arrowDownS : McIcons.arrowRightS,
                size: 13,
                color: McTokens.textFaint,
              ),
              const SizedBox(width: 4),
              Text('文件明细', style: McText.micro.faint),
              if (fileCount > 0) ...[
                const SizedBox(width: 4),
                Text('$fileCount 个', style: McText.micro.faint.tabular),
              ],
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.context != null) ...[
                  Text(d.context!, style: McText.micro.faint),
                  const SizedBox(height: 6),
                ],
                for (final g in d.fileGroups) ...[
                  Text(
                    '${g.label} · ${g.files.length} 个',
                    style: McText.micro.copyWith(
                      color: McTokens.textFaint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  for (final f in g.files)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: SelectableText(f, style: McText.micro.muted),
                    ),
                  if (g != d.fileGroups.last) const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── 正在播放行（完整解析 delivery，绝不硬编码「直连」，带结束播放/注销设备二次确认） ──

Color deliveryBadgeColor(PlaybackDeliveryView delivery) {
  switch (delivery.mode) {
    case 'direct':
      return McTokens.ok;
    case 'remux':
    case 'audio':
      return McTokens.info;
    default:
      final kind = delivery.executionKind;
      if (kind == 'remote' || delivery.label == '远程转码') {
        return const Color(0xFFA78BFA);
      }
      if (kind == 'software' || delivery.label == '软件转码') {
        return McTokens.danger;
      }
      return McTokens.warning;
  }
}

String? deliveryDetailLine(PlaybackDeliveryView delivery) {
  if (delivery.mode == 'direct') return null;
  final parts = [
    if (delivery.target != null && delivery.target!.isNotEmpty) delivery.target!,
    if (delivery.executor != null && delivery.executor!.isNotEmpty)
      delivery.executor!,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

Future<bool> _confirmDeviceDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: McTokens.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res == true;
}

class ActivityPlaybackSessionRow extends StatelessWidget {
  const ActivityPlaybackSessionRow({
    super.key,
    required this.session,
    required this.onEnd,
    required this.onRevoke,
  });

  final ActivePlaybackSession session;
  final Future<String> Function() onEnd;
  final Future<String> Function() onRevoke;

  Future<void> _confirmEnd(BuildContext context, String device) async {
    final ok = await _confirmDeviceDialog(
      context,
      title: '结束「$device」的播放？',
      message: '会立即中断该设备当前的播放，对方重新点击播放可继续观看。',
      confirmLabel: '结束播放',
      destructive: true,
    );
    if (!ok) return;
    try {
      final msg = await onEnd();
      McToast.success(msg);
    } catch (e) {
      McToast.error(e.toString());
    }
  }

  Future<void> _confirmRevoke(BuildContext context, String device) async {
    final ok = await _confirmDeviceDialog(
      context,
      title: '注销此设备？',
      message: '将立即撤销「$device」的登录凭证，该设备需要重新登录才能访问媒体库。',
      confirmLabel: '注销设备',
      destructive: true,
    );
    if (!ok) return;
    try {
      final msg = await onRevoke();
      McToast.success(msg);
    } catch (e) {
      McToast.error(e.toString());
    }
  }

  void _showContextMenu(BuildContext context, String device, {Offset? pos}) {
    final delivery = session.delivery;
    final media = session.media;
    final canOpenDetail = media.libraryId != null && media.browsable;

    showMcContextActions(
      context: context,
      title: media.title.isEmpty ? device : media.title,
      globalPosition: pos,
      actions: [
        if (delivery?.reason != null && delivery!.reason!.isNotEmpty)
          McPosterMenuAction(
            icon: McIcons.circleNote2,
            label: '为什么使用「${delivery.label}」',
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('为什么使用「${delivery.label}」'),
                content: Text(delivery.reason!),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            ),
          ),
        if (canOpenDetail)
          McPosterMenuAction(
            icon: McIcons.film,
            label: '打开影片详情',
            onTap: () =>
                context.push('/detail/${media.libraryId}/${media.mediaItemId}'),
          ),
        McPosterMenuAction(
          icon: McIcons.stopCircle,
          label: '结束播放',
          destructive: true,
          onTap: () => _confirmEnd(context, device),
        ),
        if (session.revocable)
          McPosterMenuAction(
            icon: McIcons.logout,
            label: '注销此设备',
            destructive: true,
            onTap: () => _confirmRevoke(context, device),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = session.media;
    final poster = McImageUrls.resolve(media.posterUrl, widthPx: 140);
    final device = watchDeviceLabel(session.client, session.deviceName);
    final posMs = session.positionMs ?? 0;
    final durMs = session.durationMs ?? 0;
    final int? pct = session.progressPercent ??
        ((posMs > 0 && durMs > 0)
            ? ((posMs / durMs) * 100).round().clamp(0, 100)
            : null);
    final double? progress = pct != null ? pct / 100.0 : null;
    final epLabel = media.kind == 'tv' && media.seasonNumber > 0
        ? ' ${mcEpisodeLabel(media.seasonNumber, media.episodeNumber)}'
        : '';
    final delivery = session.delivery;
    final deliveryDetail =
        delivery != null ? deliveryDetailLine(delivery) : null;
    final canOpenDetail = media.libraryId != null && media.browsable;
    final remainingMs =
        (durMs > 0 && durMs > posMs) ? (durMs - posMs) : null;

    return Dismissible(
      key: ValueKey('play-session-${session.deviceId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmEnd(context, device);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: McTokens.danger,
        child: const Icon(McIcons.stopCircle, color: Colors.white, size: 20),
      ),
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context, device),
        onSecondaryTapUp: (d) =>
            _showContextMenu(context, device, pos: d.globalPosition),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              McPressable(
                onTap: canOpenDetail
                    ? () => context.push(
                          '/detail/${media.libraryId}/${media.mediaItemId}',
                        )
                    : null,
                child: _ActivityPosterThumb(url: poster, width: 48, height: 70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: McPressable(
                            onTap: canOpenDetail
                                ? () => context.push(
                                      '/detail/${media.libraryId}/${media.mediaItemId}',
                                    )
                                : null,
                            child: Text.rich(
                              TextSpan(
                                style: McText.sub
                                    .copyWith(
                                      color: McTokens.text,
                                      fontWeight: FontWeight.w600,
                                    )
                                    .tabular,
                                children: [
                                  TextSpan(
                                    text: media.title.isEmpty
                                        ? '未知内容'
                                        : media.title,
                                  ),
                                  if (media.year != null)
                                    TextSpan(
                                      text: ' ${media.year}',
                                      style: McText.caption.faint,
                                    ),
                                  if (epLabel.isNotEmpty)
                                    TextSpan(
                                      text: epLabel,
                                      style: McText.caption.muted,
                                    ),
                                  if (!media.browsable)
                                    TextSpan(
                                      text: '  [仅管理]',
                                      style: McText.micro.faint,
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        McGlassIconButton(
                          icon: McIcons.more,
                          size: 28,
                          iconSize: 15,
                          tooltip: '设备操作',
                          onTap: () => _showContextMenu(context, device),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (session.memberName.isNotEmpty) session.memberName,
                        device,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.caption.muted,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (delivery != null && delivery.label.isNotEmpty) ...[
                          Builder(
                            builder: (_) {
                              final c = deliveryBadgeColor(delivery);
                              return McPressable(
                                onTap: (delivery.reason?.isNotEmpty ?? false)
                                    ? () => showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title:
                                                Text('为什么使用「${delivery.label}」'),
                                            content: Text(delivery.reason!),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                                child: const Text('知道了'),
                                              ),
                                            ],
                                          ),
                                        )
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: c.withValues(alpha: 0.45),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    delivery.label,
                                    style: McText.micro.copyWith(color: c),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          [
                            session.paused ? '❚❚ 已暂停' : '▶ 播放中',
                            if (pct != null) '$pct%',
                          ].join(' · '),
                          style: McText.caption
                              .copyWith(
                                color: session.paused
                                    ? McTokens.textMuted
                                    : McTokens.ok,
                              )
                              .tabular,
                        ),
                        const Spacer(),
                        if (session.playMethod != 'local')
                          Text('网盘直链', style: McText.micro.faint)
                        else if ((session.rateBytesPerSecond ?? 0) > 0)
                          Text(
                            '↓ ${mcFormatSpeed(session.rateBytesPerSecond!)}',
                            style: McText.micro
                                .copyWith(color: McTokens.info)
                                .tabular,
                          ),
                      ],
                    ),
                    if (deliveryDetail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        deliveryDetail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: McText.micro.faint,
                      ),
                    ],
                    if (progress != null) ...[
                      const SizedBox(height: 6),
                      ActivityProgressBar(
                        progress: progress,
                        color: session.paused
                            ? McTokens.textFaint
                            : McTokens.info,
                      ),
                    ],
                    if (session.positionMs != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            mcFormatClock(posMs ~/ 1000),
                            style: McText.micro.faint.tabular,
                          ),
                          if (remainingMs != null)
                            Text(
                              '还剩 ${mcFormatWatched(remainingMs)}',
                              style: McText.micro.faint.tabular,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 正在下载（整文件离线缓存）行，支持可注销设备的菜单。
class ActivityFileDownloadRow extends StatelessWidget {
  const ActivityFileDownloadRow({
    super.key,
    required this.download,
    required this.onRevoke,
  });

  final ActiveFileDownload download;
  final Future<String> Function() onRevoke;

  Future<void> _confirmRevoke(BuildContext context, String device) async {
    final ok = await _confirmDeviceDialog(
      context,
      title: '注销此设备？',
      message: '将立即撤销「$device」的登录凭证并中断其文件下载。',
      confirmLabel: '注销设备',
      destructive: true,
    );
    if (!ok) return;
    try {
      final msg = await onRevoke();
      McToast.success(msg);
    } catch (e) {
      McToast.error(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = download.media;
    final poster = McImageUrls.resolve(media?.posterUrl, widthPx: 140);
    final device = watchDeviceLabel(download.client, download.deviceName);
    final pct = download.progressPercent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityPosterThumb(url: poster, width: 44, height: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (media?.title.isNotEmpty ?? false)
                            ? media!.title
                            : download.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.copyWith(
                          color: McTokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (download.revocable)
                      McGlassIconButton(
                        icon: McIcons.logout,
                        size: 28,
                        iconSize: 14,
                        iconColor: McTokens.danger,
                        tooltip: '注销设备',
                        onTap: () => _confirmRevoke(context, device),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (download.memberName.isNotEmpty) download.memberName,
                    device,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if ((download.rateBytesPerSecond ?? 0) > 0) ...[
                      Text(
                        mcFormatSpeed(download.rateBytesPerSecond!),
                        style:
                            McText.micro.copyWith(color: McTokens.info).tabular,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        download.sizeBytes > 0
                            ? '${mcFormatBytes(download.positionBytes)} / ${mcFormatBytes(download.sizeBytes)}'
                            : mcFormatBytes(download.sizeBytes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.micro.faint.tabular,
                      ),
                    ),
                    if (pct != null)
                      Text('$pct%', style: McText.micro.muted.tabular),
                  ],
                ),
                if (pct != null) ...[
                  const SizedBox(height: 5),
                  ActivityProgressBar(
                    progress: pct / 100.0,
                    color: McTokens.info,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 总览页的刷流做种摘要行（对齐 iOS `ActivityBoostSummaryRow`）。
class ActivityBoostSummaryRow extends StatelessWidget {
  const ActivityBoostSummaryRow({
    super.key,
    required this.tasks,
    this.pool,
    required this.onTap,
  });

  final List<DownloadTask> tasks;
  final BoostPoolView? pool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totals = ActivityBoostTotals(tasks);
    final sites = ActivityBoostSites(tasks, pool);
    final off = sites.count(BoostSiteMode.off);
    final paused = sites.count(BoostSiteMode.paused);
    final scheduled = sites.scheduledCount;
    final allOff = off == totals.count && totals.count > 0;
    final allPaused = paused == totals.count && totals.count > 0;

    final title = allOff
        ? '刷流已关闭'
        : allPaused
            ? '刷流已暂停'
            : '刷流做种';
    final iconColor = allOff
        ? McTokens.textFaint
        : allPaused
            ? McTokens.warning
            : McTokens.ok;
    final parts = <String>[
      allOff
          ? '${totals.count} 个种子仍在做种'
          : allPaused
              ? '${totals.count} 个种子限速做种'
              : '${totals.count} 个种子',
      '↑ ${mcFormatSpeed(totals.upSpeed)}',
      if (!allOff && off > 0) '$off 个已关闭站点残留',
      if (!allPaused && paused > 0) '$paused 个已暂停',
      if (scheduled > 0) '$scheduled 个待清理',
      if (!allOff && off == 0 && paused == 0 && scheduled == 0)
        '累计上传 ${mcFormatBytes(totals.uploaded)}',
    ];

    return McPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              allPaused ? McIcons.pause : McIcons.fileSeedFill,
              size: 19,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: McText.sub.copyWith(
                      color: McTokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted.tabular,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              McIcons.arrowRightS,
              size: 16,
              color: McTokens.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// 最近播放单行（对齐 iOS `ActivityRecentPlayRow`：播放中 / ✓ 看完 / 看到 N%）。
class ActivityRecentPlayRow extends StatelessWidget {
  const ActivityRecentPlayRow({super.key, required this.entry});

  final PlaybackLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    final poster = McImageUrls.resolve(media.posterUrl, widthPx: 120);
    final ep = media.kind == 'tv' && media.seasonNumber > 0
        ? ' ${mcEpisodeLabel(media.seasonNumber, media.episodeNumber)}'
        : '';
    final canOpen = media.libraryId != null && media.browsable;
    final device = watchDeviceLabel(entry.client, entry.deviceName);

    return McPressable(
      onTap: canOpen
          ? () => context.push('/detail/${media.libraryId}/${media.mediaItemId}')
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _ActivityPosterThumb(url: poster, width: 34, height: 50, radius: 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: McText.sub
                          .copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w600,
                          )
                          .tabular,
                      children: [
                        TextSpan(
                          text: media.title.isEmpty ? '已删除条目' : media.title,
                        ),
                        if (ep.isNotEmpty)
                          TextSpan(text: ep, style: McText.caption.muted),
                        if (!media.browsable && media.libraryId != null)
                          TextSpan(text: ' [仅管理]', style: McText.micro.faint),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (entry.memberName.isNotEmpty) entry.memberName,
                      device,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (entry.isPlaying)
                  Text(
                    '播放中',
                    style: McText.caption
                        .copyWith(
                          color: McTokens.ok,
                          fontWeight: FontWeight.w600,
                        )
                        .tabular,
                  )
                else if (entry.completed)
                  Text(
                    '✓ 看完',
                    style: McText.caption
                        .copyWith(
                          color: McTokens.ok,
                          fontWeight: FontWeight.w600,
                        )
                        .tabular,
                  )
                else if (entry.progressPercent != null)
                  Text(
                    '看到 ${entry.progressPercent}%',
                    style: McText.caption.muted.tabular,
                  )
                else
                  Text('播放过', style: McText.caption.muted),
                if (!entry.isPlaying) ...[
                  const SizedBox(height: 2),
                  Text(
                    mcFromNowIso(entry.startedAt, empty: ''),
                    style: McText.micro.faint.tabular,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPosterThumb extends StatelessWidget {
  const _ActivityPosterThumb({
    required this.url,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final String url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: McTokens.posterPlaceholder,
          border: Border.all(color: McTokens.line, width: 1),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                httpHeaders: mcImageHeaders(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  McIcons.film,
                  color: McTokens.textFaint,
                  size: 16,
                ),
              )
            : const Icon(McIcons.film, color: McTokens.textFaint, size: 16),
      ),
    );
  }
}

// 向后兼容导出（避免旧引用失效）。
class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.entry});

  final PlaybackLogEntry entry;

  @override
  Widget build(BuildContext context) => ActivityRecentPlayRow(entry: entry);
}
