import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/models.dart';
import 'smart_wanted_section.dart';

/// 搜索轮次摘要条（1:1 对齐 iOS `SearchRoundBar`）。
class SearchRoundBar extends StatelessWidget {
  const SearchRoundBar({
    super.key,
    required this.activities,
    required this.wanted,
  });

  final List<SubActivityView> activities;
  final List<WantedView> wanted;

  @override
  Widget build(BuildContext context) {
    SubActivityView? latest;
    for (final a in activities) {
      if (a.type == 'searched') {
        latest = a;
        break;
      }
    }
    if (latest == null) return const SizedBox.shrink();

    final p = latest.payload;
    final failedVal = p['failed'];
    final failed = failedVal != null &&
        failedVal != false &&
        failedVal != 0 &&
        failedVal != '';
    final resultsCount = (p['results'] as num?)?.toInt();
    final hasStats = resultsCount != null && !failed;
    final nextDueList = wanted
        .where((w) => w.status == 'wanted' && w.nextSearchAt != null)
        .map((w) => w.nextSearchAt!)
        .toList()
      ..sort();
    final nextDue = nextDueList.isNotEmpty ? nextDueList.first : null;

    final statsLine = hasStats
        ? '命中 $resultsCount 条 · 身份匹配 ${(p['identity_hits'] as num?)?.toInt() ?? 0} · 过滤 ${(p['rejected'] as num?)?.toInt() ?? 0} · 投递 ${(p['dispatched_units'] as num?)?.toInt() ?? 0}'
            '${nextDue != null ? ' · 下轮 ${SubsFormat.dateTime(nextDue)}' : ''}'
        : latest.message;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: SubsColor.info,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${SubsFormat.relative(latest.createdAt)}搜了一轮',
                style: McText.sub.semibold.copyWith(color: McTokens.text),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(statsLine, style: McText.caption.faint.tabular),
        ],
      ),
    );
  }
}

/// 追踪明细（按季分组折叠 + 5/6 站里程碑链 + 智能选源 + 实时下载进度 + 片源标注入口）。
class TrackingList extends StatefulWidget {
  const TrackingList({
    super.key,
    required this.sub,
    this.downloads = const {},
    this.failures = const {},
    this.canAnnotate = false,
    this.canTune = false,
    this.openSeasons,
    this.onToggleSeason,
    this.onAnnotate,
    this.onSmartChanged,
    this.onSmartOriginalRequested,
  });

  final SubscriptionView sub;
  final Map<String, SubscriptionDownloadView> downloads;
  final Map<int, SubActivityView> failures;
  final bool canAnnotate;
  final bool canTune;
  final Set<int>? openSeasons;
  final ValueChanged<int>? onToggleSeason;
  final ValueChanged<int>? onAnnotate;
  final Future<void> Function()? onSmartChanged;
  final VoidCallback? onSmartOriginalRequested;

  @override
  State<TrackingList> createState() => _TrackingListState();
}

class _TrackingListState extends State<TrackingList> {
  int? _openWantedId;
  late Set<int> _localOpenSeasons;

  @override
  void initState() {
    super.initState();
    _localOpenSeasons = WantedLogic.defaultOpenSeasons(widget.sub.wanted);
  }

  Set<int> get _effectiveOpenSeasons => widget.openSeasons ?? _localOpenSeasons;

  void _toggleSeason(int season) {
    if (widget.onToggleSeason != null) {
      widget.onToggleSeason!(season);
    } else {
      setState(() {
        if (!_localOpenSeasons.remove(season)) {
          _localOpenSeasons.add(season);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wanted = widget.sub.wanted;
    final isMovie = widget.sub.media.kind == 'movie';
    if (wanted.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: McTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(McTokens.cardRadius),
          border: Border.all(color: McTokens.line),
        ),
        child: Text(
          isMovie ? '影片暂无追踪明细' : '暂无追踪工单',
          style: McText.sub.muted,
        ),
      );
    }

    final bySeason = <int, List<WantedView>>{};
    for (final w in wanted) {
      bySeason.putIfAbsent(w.seasonNumber, () => []).add(w);
    }
    // 倒序：最新一季排最上（默认展开）
    final seasons = bySeason.keys.toList()..sort((a, b) => b.compareTo(a));
    final collapsible = !isMovie && seasons.length > 1;
    final annotatable = widget.canAnnotate
        ? wanted
            .where((w) => w.upgrade?.indeterminate == true)
            .map((w) => w.seasonNumber)
            .toSet()
        : <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final season in seasons) ...[
          _buildSeasonCard(
            season: season,
            items: [...bySeason[season]!]
              ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber)),
            isMovie: isMovie,
            collapsible: collapsible,
            open: !collapsible || _effectiveOpenSeasons.contains(season),
            annotatable: annotatable.contains(season),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildSeasonCard({
    required int season,
    required List<WantedView> items,
    required bool isMovie,
    required bool collapsible,
    required bool open,
    required bool annotatable,
  }) {
    final arranged = items.where((w) => w.status != 'wanted').length;
    final upgrading = items.where((w) => w.upgrade?.active == true).length;

    return Container(
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (!isMovie || annotatable)
            InkWell(
              onTap: collapsible ? () => _toggleSeason(season) : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                child: Row(
                  children: [
                    if (collapsible) ...[
                      Icon(
                        open ? McIcons.arrowDownS : McIcons.chevronRight,
                        size: 14,
                        color: McTokens.textFaint,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isMovie ? '正片' : SubsFormat.seasonName(season),
                      style: McText.sub.semibold.copyWith(color: McTokens.text),
                    ),
                    if (!isMovie) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$arranged/${items.length}',
                        style: McText.caption.faint.tabular,
                      ),
                    ],
                    if (upgrading > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '洗版中 $upgrading',
                        style: McText.caption
                            .copyWith(color: SubsColor.upgrade)
                            .tabular,
                      ),
                    ],
                    const Spacer(),
                    if (collapsible && !open) ...[
                      SizedBox(
                        width: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: items.isEmpty ? 0 : arranged / items.length,
                            minHeight: 4,
                            backgroundColor: McTokens.glassFillHover,
                            valueColor: AlwaysStoppedAnimation(
                              arranged == items.length
                                  ? SubsColor.ok
                                  : SubsColor.warn,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (annotatable && widget.onAnnotate != null)
                      GestureDetector(
                        onTap: () => widget.onAnnotate!(season),
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
              ),
            ),
          if (open) ...[
            if (!isMovie || annotatable)
              const Divider(height: 1, color: McTokens.line),
            for (final pair in items.indexed) ...[
              if (pair.$1 > 0) const Divider(height: 1, color: McTokens.line),
              _WantedRow(
                wanted: pair.$2,
                isMovie: isMovie,
                download: pair.$2.infoHash != null
                    ? widget.downloads[pair.$2.infoHash!.toLowerCase()]
                    : null,
                failure: widget.failures[pair.$2.id],
                expanded: isMovie || _openWantedId == pair.$2.id,
                smart: widget.sub.isSmart
                    ? SmartWantedContext(
                        wanted: pair.$2,
                        detail: widget.sub,
                        canManage: widget.canTune,
                        onChanged: widget.onSmartChanged ?? () async {},
                        onOriginalRequested: widget.onSmartOriginalRequested,
                      )
                    : null,
                onToggle: () => setState(() {
                  _openWantedId =
                      _openWantedId == pair.$2.id ? null : pair.$2.id;
                }),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WantedRow extends StatelessWidget {
  const _WantedRow({
    required this.wanted,
    required this.isMovie,
    this.download,
    this.failure,
    required this.expanded,
    this.smart,
    required this.onToggle,
  });

  final WantedView wanted;
  final bool isMovie;
  final SubscriptionDownloadView? download;
  final SubActivityView? failure;
  final bool expanded;
  final SmartWantedContext? smart;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final stuckOnImport = failure?.type == 'import_failed' ? failure : null;
    final pres = stuckOnImport != null
        ? WantedPresentation(
            label: '入库失败',
            color: SubsColor.danger,
            note: stuckOnImport.message,
            short: '失败',
          )
        : WantedLogic.presentation(wanted);
    final live = (stuckOnImport == null &&
            (wanted.status == 'grabbed' || wanted.status == 'downloaded'))
        ? download
        : null;
    final chain = WantedLogic.milestones(
      wanted,
      isMovie: isMovie,
      live: live,
      failure: failure,
      isSmart: smart != null,
    );
    final lit = WantedLogic.stuckIndex(chain);

    return Column(
      children: [
        InkWell(
          onTap: isMovie ? null : onToggle,
          child: Container(
            color: (expanded && !isMovie)
                ? McTokens.glassFill
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMovie
                          ? '正片'
                          : 'E${SubsFormat.pad(wanted.episodeNumber)}',
                      style: McText.sub.semibold
                          .copyWith(color: McTokens.text)
                          .tabular,
                    ),
                    const Spacer(),
                    _miniPill(pres, chain, lit),
                    if (!isMovie) ...[
                      const SizedBox(width: 6),
                      Icon(
                        expanded ? McIcons.arrowDownS : McIcons.chevronRight,
                        size: 13,
                        color: McTokens.textFaint,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  live != null ? WantedLogic.downloadNote(live) : pres.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted.tabular,
                ),
                if (live != null &&
                    live.progress != null &&
                    live.state != 'missing') ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: live.progress!.clamp(0.01, 1.0),
                      minHeight: 3.5,
                      backgroundColor: McTokens.glassFillHover,
                      valueColor: const AlwaysStoppedAnimation(SubsColor.ok),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (expanded)
          MilestoneChainView(
            chain: chain,
            color: pres.color,
            smart: smart,
          ),
      ],
    );
  }

  Widget _miniPill(WantedPresentation pres, List<Milestone> chain, int lit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: pres.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chain.length; i++)
            Container(
              width: 4.5,
              height: 4.5,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i == lit
                    ? pres.color
                    : chain[i].state == MilestoneState.done
                        ? Colors.white.withValues(alpha: 0.38)
                        : Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 4),
          Text(
            pres.shortLabel,
            style: McText.micro.copyWith(color: pres.color),
          ),
        ],
      ),
    );
  }
}

/// 5/6 站里程碑链视图（1:1 对齐 iOS `MilestoneChainView`）。
class MilestoneChainView extends StatelessWidget {
  const MilestoneChainView({
    super.key,
    required this.chain,
    required this.color,
    this.smart,
  });

  final List<Milestone> chain;
  final Color color;
  final SmartWantedContext? smart;

  @override
  Widget build(BuildContext context) {
    final stuck = WantedLogic.stuckIndex(chain);
    return Container(
      width: double.infinity,
      color: McTokens.surfaceInset,
      padding: const EdgeInsets.fromLTRB(18, 12, 15, 10),
      child: Column(
        children: [
          for (var i = 0; i < chain.length; i++)
            _stationRow(
              milestone: chain[i],
              index: i,
              isLast: i == chain.length - 1,
              passed: i < stuck,
            ),
        ],
      ),
    );
  }

  Widget _stationRow({
    required Milestone milestone,
    required int index,
    required bool isLast,
    required bool passed,
  }) {
    final isNow = milestone.state == MilestoneState.now ||
        milestone.state == MilestoneState.fail;
    final labelColor = isNow
        ? color
        : milestone.state == MilestoneState.done
            ? Colors.white.withValues(alpha: 0.68)
            : McTokens.textFaint;
    final detailColor = milestone.state == MilestoneState.done
        ? McTokens.textFaint
        : milestone.state == MilestoneState.todo
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.85);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: isNow ? 10 : 8.5,
                  height: isNow ? 10 : 8.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: milestone.state == MilestoneState.done
                        ? Colors.white.withValues(alpha: 0.34)
                        : Colors.transparent,
                    border: milestone.state == MilestoneState.done
                        ? null
                        : Border.all(
                            color: isNow
                                ? color
                                : Colors.white.withValues(alpha: 0.18),
                            width: isNow ? 2.4 : 1.4,
                          ),
                    boxShadow: isNow
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: passed
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        milestone.label,
                        style: McText.caption.copyWith(
                          fontWeight: isNow ? FontWeight.w600 : FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
                      const Spacer(),
                      if (milestone.time.isNotEmpty)
                        Text(
                          milestone.time,
                          style: McText.micro.faint.tabular,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    milestone.detail,
                    style: McText.caption.copyWith(color: detailColor).tabular,
                  ),
                  if (milestone.key == 'search' && smart != null)
                    SmartWantedSelection(contextData: smart!),
                  if (milestone.why != null && milestone.why!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      milestone.why!,
                      style: McText.micro.copyWith(color: SubsColor.reason),
                    ),
                  ],
                  for (final src in milestone.sources) ...[
                    const SizedBox(height: 3),
                    Text(
                      src,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: McText.micro.faint,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
