import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../../../core/navigation/external_media_link.dart';
import '../../../core/session/permissions.dart';
import '../logic/torrent_search_logic.dart';
import '../models/search_models.dart';

/// 顶部流式进度条（站点数已知按完成比例推进，连接中展示扫光动画）。
class TorrentStreamProgressBar extends StatefulWidget {
  const TorrentStreamProgressBar({
    super.key,
    required this.settledCount,
    required this.totalSites,
  });

  final int settledCount;
  final int totalSites;

  @override
  State<TorrentStreamProgressBar> createState() =>
      _TorrentStreamProgressBarState();
}

class _TorrentStreamProgressBarState extends State<TorrentStreamProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 2.5,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final w = constraints.maxWidth;
            if (widget.totalSites <= 0) {
              return Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x14FFFFFF)),
                  ),
                  AnimatedBuilder(
                    animation: _sweep,
                    builder: (_, __) {
                      final barW = w * 0.4;
                      final dx = -barW + (w + barW) * _sweep.value;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Container(
                          width: barW,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: McTokens.accentStrong,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }
            final ratio = (widget.settledCount / widget.totalSites).clamp(0.06, 1.0);
            return Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x14FFFFFF)),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  width: w * ratio,
                  height: 2.5,
                  color: McTokens.accentStrong,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 站点状态聚合胶囊（点击打开 `SiteStatusSheet`）。
class SiteStatusPill extends StatelessWidget {
  const SiteStatusPill({
    super.key,
    required this.streaming,
    required this.settledCount,
    required this.totalSites,
    required this.failedCount,
    required this.onTap,
  });

  final bool streaming;
  final int settledCount;
  final int totalSites;
  final int failedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = streaming
        ? McTokens.accent
        : (failedCount > 0 ? McTokens.danger : McTokens.ok);
    return Tooltip(
      message: '查看各站点搜索状态',
      child: Semantics(
        button: true,
        label: '查看各站点搜索状态',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(McTokens.pillRadius),
              border: Border.all(color: McTokens.lineStrong, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                if (streaming)
                  Text('$settledCount/$totalSites 站点',
                      style: McText.caption.tabular)
                else ...[
                  Text('$totalSites 站点', style: McText.caption.tabular),
                  if (failedCount > 0) ...[
                    Text(
                      ' · $failedCount 失败',
                      style: McText.caption
                          .copyWith(color: McTokens.danger)
                          .tabular,
                    ),
                  ],
                ],
                const SizedBox(width: 3),
                const Icon(
                  McIcons.arrowDownS,
                  size: 13,
                  color: McTokens.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 逐站搜索详情弹层（对齐 iOS `SiteStatusSheet`）：状态点、命中数、耗时、错误原因、单站重试、超管直达 `/settings/sites`。
class SiteStatusSheet extends StatelessWidget {
  const SiteStatusSheet({
    super.key,
    required this.sites,
    required this.totalElapsedMs,
    required this.canRetry,
    required this.isAdmin,
    required this.onRetrySite,
  });

  final List<SiteProgress> sites;
  final int? totalElapsedMs;
  final bool canRetry;
  final bool isAdmin;
  final ValueChanged<String> onRetrySite;

  static Future<void> show(
    BuildContext context, {
    required List<SiteProgress> sites,
    required int? totalElapsedMs,
    required bool canRetry,
    required bool isAdmin,
    required ValueChanged<String> onRetrySite,
  }) =>
      showMcSheet<void>(
        context: context,
        builder: (_) => SiteStatusSheet(
          sites: sites,
          totalElapsedMs: totalElapsedMs,
          canRetry: canRetry,
          isAdmin: isAdmin,
          onRetrySite: onRetrySite,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
            child: Row(
              children: [
                const Expanded(child: Text('站点搜索状态', style: McText.titleSm)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  footer: totalElapsedMs != null
                      ? '整次搜索总耗时 ${TorrentSearchLogic.elapsedText(totalElapsedMs!)}（取决于最慢站点）'
                      : null,
                  children: [
                    for (final site in sites) _siteRow(context, site),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _siteRow(BuildContext context, SiteProgress site) {
    final dotColor = switch (site.state) {
      SiteProgressState.searching => McTokens.accent,
      SiteProgressState.ok => McTokens.ok,
      SiteProgressState.error => McTokens.danger,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  site.siteName,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              switch (site.state) {
                SiteProgressState.searching => const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                SiteProgressState.ok => Text(
                    '${site.count} 条'
                    '${site.elapsedMs != null ? ' · ${TorrentSearchLogic.elapsedText(site.elapsedMs!)}' : ''}',
                    style: McText.caption.muted.tabular,
                  ),
                SiteProgressState.error => Text(
                    '失败'
                    '${site.elapsedMs != null ? ' · ${TorrentSearchLogic.elapsedText(site.elapsedMs!)}' : ''}',
                    style: McText.caption
                        .copyWith(color: McTokens.danger)
                        .tabular,
                  ),
              },
            ],
          ),
          if (site.state == SiteProgressState.error) ...[
            if (site.error != null && site.error!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 17),
                child: Text(
                  site.error!,
                  style: McText.caption.copyWith(
                    color: McTokens.danger.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canRetry)
                    McGlassButton(
                      onTap: () {
                        Navigator.of(context).pop();
                        onRetrySite(site.siteId);
                      },
                      tone: McGlassTone.secondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(McIcons.refreshS, size: 13),
                          const SizedBox(width: 4),
                          Text('重试该站', style: McText.caption.semibold),
                        ],
                      ),
                    ),
                  if (isAdmin)
                    McGlassButton(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/settings/sites');
                      },
                      tone: McGlassTone.secondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(McIcons.setting1, size: 13),
                          const SizedBox(width: 4),
                          Text('去站点设置', style: McText.caption.semibold),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 排序 + 12 维自排除分面胶囊横滚条（对齐 iOS `TorrentResultsView.conditionChips`）。
class TorrentConditionChipsBar extends StatelessWidget {
  const TorrentConditionChipsBar({
    super.key,
    required this.sort,
    required this.smartSortKeys,
    required this.filters,
    required this.facets,
    required this.okSites,
    required this.siteNameOf,
    required this.onChangeSort,
    required this.onToggleFacet,
    required this.onClearDim,
    required this.onClearAllFilters,
  });

  final TorrentSort sort;
  final List<TorrentSortKey> smartSortKeys;
  final TorrentFilters filters;
  final TorrentFacets facets;
  final List<SiteProgress> okSites;
  final String Function(String siteId) siteNameOf;
  final ValueChanged<TorrentSort> onChangeSort;
  final void Function(TorrentFilterDim dim, String value) onToggleFacet;
  final ValueChanged<TorrentFilterDim> onClearDim;
  final VoidCallback onClearAllFilters;

  List<TorrentFacetValue> _dimValues(TorrentFilterDim dim) {
    if (dim != TorrentFilterDim.site) return facets.values(dim);
    final counts = {
      for (final f in facets.values(TorrentFilterDim.site)) f.value: f.count,
    };
    return [
      for (final s in okSites)
        TorrentFacetValue(value: s.siteId, count: counts[s.siteId] ?? 0),
    ];
  }

  String? _chipSummary(TorrentFilterDim dim) {
    final sel = filters.values(dim);
    if (sel.isEmpty) return null;
    final labels = (sel.toList()..sort())
        .map((v) => TorrentSearchLogic.facetLabel(dim, v, siteNameOf))
        .toList();
    return labels.length <= 2
        ? labels.join('、')
        : '${labels.first} 等 ${labels.length} 个';
  }

  void _openSortSheet(BuildContext context) {
    final smart = TorrentSortKey.smart
        .where((k) => smartSortKeys.contains(k) || k == sort.key)
        .toList();
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text('排序方式（再次点击切换升降序）', style: McText.titleSm),
            ),
            McInsetGroup(
              header: '常规排序',
              margin: EdgeInsets.zero,
              children: [
                for (final k in TorrentSortKey.regular)
                  _sortRow(ctx, k),
              ],
            ),
            if (smart.isNotEmpty) ...[
              const SizedBox(height: 12),
              McInsetGroup(
                header: '智能排序',
                margin: EdgeInsets.zero,
                children: [
                  for (final k in smart) _sortRow(ctx, k),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sortRow(BuildContext ctx, TorrentSortKey key) {
    final active = key == sort.key;
    return McInsetRow(
      title: key.label,
      trailing: active
          ? Icon(
              sort.descending ? McIcons.arrowDown : McIcons.arrowUp,
              size: 16,
              color: McTokens.accentStrong,
            )
          : null,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(ctx).pop();
        onChangeSort(sort.picking(key));
      },
    );
  }

  void _openDimSheet(BuildContext context, TorrentFilterDim dim) {
    final values = _dimValues(dim);
    final localSelected = Set<String>.from(filters.values(dim));
    showMcSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomPad = MediaQuery.paddingOf(ctx).bottom;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('筛选 · ${dim.title}', style: McText.titleSm),
                      ),
                      if (localSelected.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            onClearDim(dim);
                            setSheetState(localSelected.clear);
                          },
                          child: const Text(
                            '移除此条件',
                            style: TextStyle(color: McTokens.danger),
                          ),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: McTokens.line),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + bottomPad),
                    itemCount: values.length,
                    itemBuilder: (_, i) {
                      final f = values[i];
                      final isOn = localSelected.contains(f.value);
                      final label = TorrentSearchLogic.facetLabel(
                        dim,
                        f.value,
                        siteNameOf,
                      );
                      return Semantics(
                        button: true,
                        selected: isOn,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onToggleFacet(dim, f.value);
                            setSheetState(() {
                              if (!localSelected.remove(f.value)) {
                                localSelected.add(f.value);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: McText.sub.copyWith(
                                      color: isOn
                                          ? McTokens.text
                                          : McTokens.textMuted,
                                      fontWeight: isOn
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${f.count} 条',
                                  style: McText.caption.faint.tabular,
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  isOn
                                      ? McIcons.checkCircleFill
                                      : McIcons.circler,
                                  size: 18,
                                  color: isOn
                                      ? McTokens.accentStrong
                                      : McTokens.textFaint,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dims = TorrentFilterDim.values
        .where((d) => _dimValues(d).isNotEmpty || filters.values(d).isNotEmpty)
        .toList();
    final clearing = filters.isActive;

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          if (clearing) ...[
            const SizedBox(width: 16),
            McChip(
              label: '清空',
              icon: McIcons.close,
              compact: true,
              selected: false,
              onTap: onClearAllFilters,
            ),
          ],
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(clearing ? 8 : 16, 0, 16, 0),
              children: [
                McChip(
                  label: '${sort.key.label} ${sort.descending ? '↓' : '↑'}',
                  compact: true,
                  selected: !sort.isDefault,
                  onTap: () => _openSortSheet(context),
                ),
                const SizedBox(width: 8),
                for (final dim in dims) ...[
                  McChip(
                    label: _chipSummary(dim) ?? dim.title,
                    compact: true,
                    selected: _chipSummary(dim) != null,
                    onTap: () => _openDimSheet(context, dim),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 作品分组区块（对齐 iOS `TorrentGroupSection`）：默认展开、前 4 条展示 + 「展开其余 N 条」。
class TorrentGroupSection extends StatefulWidget {
  const TorrentGroupSection({
    super.key,
    required this.entityKey,
    required this.rows,
    this.entity,
    required this.onTapHit,
    this.onOpenImages,
  });

  final String entityKey;
  final List<TorrentHit> rows;
  final TorrentEntity? entity;
  final ValueChanged<TorrentHit> onTapHit;
  final ValueChanged<TorrentHit>? onOpenImages;

  @override
  State<TorrentGroupSection> createState() => _TorrentGroupSectionState();
}

class _TorrentGroupSectionState extends State<TorrentGroupSection> {
  static const _cap = 4;
  bool _collapsed = false;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final entity = widget.entity;
    final rows = widget.rows;
    final freeCount =
        rows.where((r) => r.free || r.downloadVolumeFactor == 0).length;
    final topRes = TorrentSearchLogic.maxResolution(rows);
    final hasPack = rows.any((r) => r.attrs?.complete == true);
    final info = entity == null
        ? '未识别作品（按原始名称展示）'
        : [
            if (entity.year != null) '${entity.year}',
            if (entity.mediaType != null &&
                TorrentSearchLogic.mediaTypeLabels[entity.mediaType] != null)
              TorrentSearchLogic.mediaTypeLabels[entity.mediaType]!,
            if (entity.contentType != null &&
                TorrentSearchLogic.contentTypeLabels[entity.contentType] !=
                    null)
              TorrentSearchLogic.contentTypeLabels[entity.contentType]!,
          ].join(' · ');

    final shown =
        _showAll || rows.length <= _cap ? rows : rows.take(_cap).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _collapsed = !_collapsed);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        _collapsed ? McIcons.chevronRight : McIcons.arrowDownS,
                        size: 15,
                        color: McTokens.textFaint,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            entity?.nameZh ?? entity?.nameEn ?? '未识别作品',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.ui.semibold,
                          ),
                          if (entity != null &&
                              entity.nameZh != null &&
                              entity.nameEn != null)
                            Text(
                              entity.nameEn!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.caption.muted,
                            ),
                          if (info.isNotEmpty)
                            Text(
                              info,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.caption.faint,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 19),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _MiniTag(text: '${rows.length} 个版本'),
                      if (topRes != null)
                        _MiniTag(text: '最高 $topRes', fg: McTokens.accent2),
                      if (hasPack)
                        const _MiniTag(
                          text: '含全集包',
                          fg: Color(0xFF99C7FF),
                          bg: Color(0x2E7FB0FF),
                        ),
                      if (freeCount > 0)
                        _MiniTag(
                          text: '$freeCount 免费',
                          fg: const Color(0xFF78D194),
                          bg: const Color(0x264ADE80),
                          bold: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_collapsed) ...[
            const SizedBox(height: 8),
            for (final hit in shown)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: TorrentRowCard(
                  hit: hit,
                  grouped: true,
                  onTap: () => widget.onTapHit(hit),
                  onOpenImages: widget.onOpenImages != null
                      ? () => widget.onOpenImages!(hit)
                      : null,
                ),
              ),
            if (!_showAll && rows.length > _cap)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: TextButton(
                  onPressed: () => setState(() => _showAll = true),
                  child: Text('展开其余 ${rows.length - _cap} 条'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 单条种子卡片（对齐 iOS `TorrentRow`：4 档做种健康色 + 结构化属性徽标 + 促销徽标）。
class TorrentRowCard extends StatelessWidget {
  const TorrentRowCard({
    super.key,
    required this.hit,
    this.grouped = false,
    this.rawTitles = false,
    required this.onTap,
    this.onOpenImages,
  });

  final TorrentHit hit;
  final bool grouped;
  final bool rawTitles;
  final VoidCallback onTap;
  final VoidCallback? onOpenImages;

  Color _seederColor(int n) {
    if (n == 0) return const Color(0xFFFF9999);
    if (n < 5) return McTokens.warning;
    if (n >= 100) return McTokens.ok;
    return const Color(0xFF78D194);
  }

  @override
  Widget build(BuildContext context) {
    final name = rawTitles ? null : TorrentSearchLogic.parsedName(hit);
    final specRow = grouped && name != null;
    final attrs = hit.attrs;
    final complete = TorrentSearchLogic.completeLabel(attrs);
    final size = TorrentSearchLogic.sizeText(hit);
    final slidesCount = hit.slides.length;

    return GestureDetector(
      onTap: (hit.hasActions || slidesCount > 0) ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xD1101219),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x0FFFFFFF), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (specRow && attrs != null)
              Text(
                TorrentSearchLogic.specSummary(attrs) ?? hit.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: McText.sub.copyWith(
                  color: McTokens.text,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (name != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      name.primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.sub.copyWith(
                        color: McTokens.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (name.secondary != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        name.secondary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.muted,
                      ),
                    ),
                  ],
                  if (attrs?.year != null) ...[
                    const SizedBox(width: 6),
                    Text('${attrs!.year}', style: McText.caption.faint),
                  ],
                ],
              )
            else
              Text(
                hit.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: McText.sub.copyWith(
                  color: McTokens.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if ((name == null && hit.subtitle.isNotEmpty) ||
                hit.siteCategoryName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (name == null && hit.subtitle.isNotEmpty)
                    Expanded(
                      flex: 2,
                      child: Text(
                        hit.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.muted,
                      ),
                    ),
                  if (hit.siteCategoryName != null) ...[
                    if (name == null && hit.subtitle.isNotEmpty)
                      const SizedBox(width: 8),
                    Flexible(
                      flex: 1,
                      child: Text(
                        hit.siteCategoryName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.faint,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _MiniTag(text: hit.siteName, fg: McTokens.accent2),
                if (complete != null)
                  _MiniTag(
                    text: complete,
                    fg: const Color(0xFF99C7FF),
                    bg: const Color(0x2E7FB0FF),
                    bold: true,
                  ),
                ..._promoTags(hit),
                if (attrs != null && !specRow) ..._attrTags(attrs),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (size.isNotEmpty)
                        Text(size, style: McText.caption.muted.tabular),
                      Text(
                        '↑${hit.seeders}',
                        style: McText.caption
                            .copyWith(
                              color: _seederColor(hit.seeders),
                              fontWeight: hit.seeders >= 100
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            )
                            .tabular,
                      ),
                      Text(
                        '↓${hit.leechers}',
                        style: McText.caption.faint.tabular,
                      ),
                      if (hit.snatched > 0)
                        Text(
                          '完成 ${hit.snatched}',
                          style: McText.caption.faint.tabular,
                        ),
                    ],
                  ),
                ),
                if (hit.uploadTime != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    mcFromNowIso(hit.uploadTime, empty: ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.faint,
                  ),
                ],
                if (slidesCount > 0 && onOpenImages != null) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '查看截图（$slidesCount）',
                    child: Semantics(
                      button: true,
                      label: '查看截图，共 $slidesCount 张',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onOpenImages!();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x18FFFFFF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: McTokens.lineStrong,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                McIcons.image3Fill,
                                size: 12,
                                color: McTokens.textMuted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$slidesCount',
                                style: McText.micro
                                    .copyWith(color: McTokens.text)
                                    .tabular,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

/// 海报图览模式卡片（对齐 iOS `TorrentPosterCard`：点图进灯箱、点文字开操作面板）。
class TorrentPosterCard extends StatelessWidget {
  const TorrentPosterCard({
    super.key,
    required this.hit,
    required this.onOpenImages,
    required this.onOpenActions,
  });

  final TorrentHit hit;
  final VoidCallback onOpenImages;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    final slides = hit.slides;
    final resolved = McImageUrls.resolve(hit.posterUrl, widthPx: 480);
    final name = TorrentSearchLogic.parsedName(hit);
    final spec = [
      if (hit.attrs?.resolution != null) hit.attrs!.resolution!,
      TorrentSearchLogic.sizeText(hit),
    ].where((e) => e.isNotEmpty).join(' · ');
    final epChip = TorrentSearchLogic.seasonEpisodeChip(hit.attrs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onOpenImages,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: McTokens.posterPlaceholder,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: McTokens.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Text(hit.siteName, style: McText.caption.faint),
                  ),
                  if (resolved.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: resolved,
                      httpHeaders: mcImageHeaders(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tag in _promoTags(hit, solid: true)) ...[
                          tag,
                          const SizedBox(height: 4),
                        ],
                      ],
                    ),
                  ),
                  if (slides.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              McIcons.image3Fill,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${slides.length}',
                              style: McText.micro.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (epChip != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: epChip.pack
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF8C5CF5),
                                  ],
                                )
                              : null,
                          color: epChip.pack ? null : const Color(0xB3000000),
                        ),
                        child: Text(
                          epChip.text,
                          style: McText.micro.copyWith(
                            color: epChip.pack
                                ? Colors.white
                                : const Color(0xFF99C7FF),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hit.hasActions ? onOpenActions : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name?.primary ?? hit.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub.copyWith(
                          color: name == null ? McTokens.textMuted : McTokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (name != null && hit.attrs?.year != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${hit.attrs!.year}',
                        style: McText.caption.muted.tabular,
                      ),
                    ],
                  ],
                ),
                if (spec.isNotEmpty)
                  Text(
                    spec,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hit.siteName +
                            (hit.uploadTime != null
                                ? ' · ${mcFromNowIso(hit.uploadTime, empty: '')}'
                                : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.micro.faint,
                      ),
                    ),
                    Text(
                      '↑${hit.seeders}',
                      style: McText.micro
                          .copyWith(color: const Color(0xFFA6D9B5))
                          .tabular,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '↓${hit.leechers}',
                      style: McText.micro
                          .copyWith(color: const Color(0xFFE0C29E))
                          .tabular,
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

/// 资源操作面板（对齐 iOS `TorrentActionsSheet`）：浏览图片 / 打开站点详情页 / 投给订阅 / 下载。
class TorrentActionsSheet extends StatelessWidget {
  const TorrentActionsSheet({
    super.key,
    required this.hit,
    required this.perms,
    required this.downloadState,
    required this.grabState,
    this.grabTarget,
    this.showsImages = true,
    this.onOpenImages,
    this.onGrab,
    this.onDownload,
  });

  final TorrentHit hit;
  final McPermissions perms;
  final TorrentSubmitState downloadState;
  final TorrentSubmitState grabState;
  final ({int id, String title})? grabTarget;
  final bool showsImages;
  final VoidCallback? onOpenImages;
  final VoidCallback? onGrab;
  final VoidCallback? onDownload;

  static Future<void> show(
    BuildContext context, {
    required TorrentHit hit,
    required McPermissions perms,
    required TorrentSubmitState downloadState,
    required TorrentSubmitState grabState,
    ({int id, String title})? grabTarget,
    bool showsImages = true,
    VoidCallback? onOpenImages,
    VoidCallback? onGrab,
    VoidCallback? onDownload,
  }) =>
      showMcSheet<void>(
        context: context,
        builder: (_) => TorrentActionsSheet(
          hit: hit,
          perms: perms,
          downloadState: downloadState,
          grabState: grabState,
          grabTarget: grabTarget,
          showsImages: showsImages,
          onOpenImages: onOpenImages,
          onGrab: onGrab,
          onDownload: onDownload,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = TorrentSearchLogic.parsedName(hit);
    final secondary =
        name != null ? hit.title : (hit.subtitle.isNotEmpty ? hit.subtitle : null);
    final meta = [
      hit.siteName,
      TorrentSearchLogic.sizeText(hit),
      '做种 ${hit.seeders}',
      if (hit.uploadTime != null) mcFromNowIso(hit.uploadTime, empty: ''),
    ].where((e) => e.isNotEmpty).join(' · ');

    final dlDisabled = downloadState == TorrentSubmitState.submitting ||
        downloadState == TorrentSubmitState.done ||
        downloadState == TorrentSubmitState.exists;
    final grabDisabled = grabState == TorrentSubmitState.submitting ||
        grabState == TorrentSubmitState.done;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name?.primary ?? hit.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: McText.titleSm,
          ),
          if (secondary != null) ...[
            const SizedBox(height: 4),
            Text(
              secondary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.muted,
            ),
          ],
          const SizedBox(height: 6),
          Text(meta, style: McText.caption.faint.tabular),
          const SizedBox(height: 16),
          if (showsImages && hit.slides.isNotEmpty && onOpenImages != null) ...[
            McActionPill(
              label: '浏览图片（${hit.slides.length}）',
              icon: McIcons.gallery1,
              primary: false,
              expanded: true,
              onTap: () {
                Navigator.of(context).pop();
                onOpenImages!();
              },
            ),
            const SizedBox(height: 10),
          ],
          if (hit.detailUrl != null && hit.detailUrl!.isNotEmpty) ...[
            McActionPill(
              label: '打开站点详情页',
              icon: McIcons.links,
              primary: false,
              expanded: true,
              onTap: () {
                Navigator.of(context).pop();
                ExternalMediaLink.open(hit.detailUrl!);
              },
            ),
            const SizedBox(height: 10),
          ],
          if (grabTarget != null &&
              hit.downloadUrl != null &&
              onGrab != null) ...[
            McActionPill(
              label: grabState.grabLabel,
              icon: McIcons.bookmarkFill,
              primary: false,
              expanded: true,
              busy: grabState == TorrentSubmitState.submitting,
              onTap: grabDisabled
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onGrab!();
                    },
            ),
            const SizedBox(height: 10),
          ],
          if (perms.canDirectDownload &&
              hit.downloadUrl != null &&
              onDownload != null)
            McActionPill(
              label: downloadState.downloadLabel,
              icon: McIcons.download,
              primary: true,
              expanded: true,
              busy: downloadState == TorrentSubmitState.submitting,
              onTap: dlDisabled
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onDownload!();
                    },
            ),
        ],
      ),
    );
  }
}

/// 种子截图全屏可缩放灯箱（对齐 iOS `DiscoverLightbox` + `TorrentLightboxActions`）：
/// 顶部右侧提供 详情 / 投给订阅 / 下载 快捷操作键，底部缩略图条直达。
class TorrentScreenshotLightbox extends StatefulWidget {
  const TorrentScreenshotLightbox({
    super.key,
    required this.hit,
    required this.perms,
    required this.downloadState,
    required this.grabState,
    this.grabTarget,
    this.onGrab,
    this.onDownload,
  });

  final TorrentHit hit;
  final McPermissions perms;
  final TorrentSubmitState downloadState;
  final TorrentSubmitState grabState;
  final ({int id, String title})? grabTarget;
  final VoidCallback? onGrab;
  final VoidCallback? onDownload;

  static Future<void> show(
    BuildContext context, {
    required TorrentHit hit,
    required McPermissions perms,
    required TorrentSubmitState downloadState,
    required TorrentSubmitState grabState,
    ({int id, String title})? grabTarget,
    VoidCallback? onGrab,
    VoidCallback? onDownload,
  }) {
    if (hit.slides.isEmpty) return Future.value();
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => TorrentScreenshotLightbox(
          hit: hit,
          perms: perms,
          downloadState: downloadState,
          grabState: grabState,
          grabTarget: grabTarget,
          onGrab: onGrab,
          onDownload: onDownload,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<TorrentScreenshotLightbox> createState() =>
      _TorrentScreenshotLightboxState();
}

class _TorrentScreenshotLightboxState extends State<TorrentScreenshotLightbox> {
  int _index = 0;
  final PageController _pageCtrl = PageController();
  final ScrollController _thumbCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _focusNode.dispose();
    _pageCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  void _jumpTo(int i) {
    final len = widget.hit.slides.length;
    if (!_pageCtrl.hasClients || len == 0) return;
    final target = i.clamp(0, len - 1);
    if (target == _index) return;
    if (_isZoomed) setState(() => _isZoomed = false);
    _pageCtrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _prev() {
    if (_index > 0) _jumpTo(_index - 1);
  }

  void _next() {
    if (_index < widget.hit.slides.length - 1) _jumpTo(_index + 1);
  }

  void _scrollThumbIntoView(int i) {
    if (!_thumbCtrl.hasClients) return;
    const itemW = 48.0;
    final target = (i * itemW - 120).clamp(
      0.0,
      _thumbCtrl.position.maxScrollExtent,
    );
    _thumbCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.hit.slides;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final compactHeader = MediaQuery.sizeOf(context).width < 460;
    final dlDisabled = widget.downloadState == TorrentSubmitState.submitting ||
        widget.downloadState == TorrentSubmitState.done ||
        widget.downloadState == TorrentSubmitState.exists;
    final grabDisabled = widget.grabState == TorrentSubmitState.submitting ||
        widget.grabState == TorrentSubmitState.done;

    final actionButtons = <Widget>[
      if (widget.hit.detailUrl != null && widget.hit.detailUrl!.isNotEmpty)
        McGlassButton(
          onTap: () => ExternalMediaLink.open(widget.hit.detailUrl!),
          tone: McGlassTone.secondary,
          radius: McTokens.pillRadius,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          child: Text('详情', style: McText.caption.semibold),
        ),
      if (widget.grabTarget != null &&
          widget.hit.downloadUrl != null &&
          widget.onGrab != null)
        McGlassButton(
          onTap: grabDisabled
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onGrab!();
                },
          tone: McGlassTone.secondary,
          radius: McTokens.pillRadius,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          child: Text(
            widget.grabState.grabLabel,
            style: McText.caption.semibold,
          ),
        ),
      if (widget.perms.canDirectDownload &&
          widget.hit.downloadUrl != null &&
          widget.onDownload != null)
        McGlassButton(
          onTap: dlDisabled
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onDownload!();
                },
          tone: McGlassTone.primary,
          radius: McTokens.pillRadius,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Text(
            widget.downloadState.downloadLabel,
            style: McText.caption.copyWith(
              color: McTokens.onAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _prev,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageCtrl,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: slides.length,
                onPageChanged: (i) {
                  setState(() {
                    _index = i;
                    _isZoomed = false;
                  });
                  _scrollThumbIntoView(i);
                },
                itemBuilder: (_, i) => _TorrentZoomSlide(
                  rawUrl: slides[i],
                  isActive: i == _index,
                  onZoomChanged: (zoomed) {
                    if (i == _index && _isZoomed != zoomed && mounted) {
                      setState(() => _isZoomed = zoomed);
                    }
                  },
                ),
              ),
              // 顶部信息与操作栏（关闭 + 标题/序号 + 详情/投给订阅/下载）
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xC7000000), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          McGlassIconButton(
                            icon: McIcons.close,
                            tooltip: '关闭',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.hit.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: McText.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_index + 1} / ${slides.length}',
                                  style: McText.micro
                                      .copyWith(color: const Color(0xB3FFFFFF))
                                      .tabular,
                                ),
                              ],
                            ),
                          ),
                          if (!compactHeader && actionButtons.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: actionButtons,
                            ),
                          ],
                        ],
                      ),
                      if (compactHeader && actionButtons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            children: actionButtons,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (slides.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomPad + 12,
                  child: SizedBox(
                    height: 58,
                    child: ListView.separated(
                      controller: _thumbCtrl,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: slides.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final active = i == _index;
                        final thumb =
                            McImageUrls.resolve(slides[i], widthPx: 160);
                        return Semantics(
                          button: true,
                          selected: active,
                          label: '第 ${i + 1} 张截图',
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _jumpTo(i);
                            },
                            child: Opacity(
                              opacity: active ? 1.0 : 0.55,
                              child: Container(
                                width: 40,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: active
                                        ? McTokens.accentStrong
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: CachedNetworkImage(
                                  imageUrl: thumb,
                                  httpHeaders: mcImageHeaders(),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    McIcons.image3Fill,
                                    size: 16,
                                    color: McTokens.textFaint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TorrentZoomSlide extends StatefulWidget {
  const _TorrentZoomSlide({
    required this.rawUrl,
    required this.isActive,
    required this.onZoomChanged,
  });

  final String rawUrl;
  final bool isActive;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_TorrentZoomSlide> createState() => _TorrentZoomSlideState();
}

class _TorrentZoomSlideState extends State<_TorrentZoomSlide>
    with SingleTickerProviderStateMixin {
  final TransformationController _ctrl = TransformationController();
  late final AnimationController _zoomAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _matrixAnim;
  TapDownDetails? _tap;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTransformChanged);
    _zoomAnim.addListener(_onZoomAnimTick);
  }

  @override
  void didUpdateWidget(covariant _TorrentZoomSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _resetZoom();
    }
  }

  @override
  void dispose() {
    _zoomAnim.removeListener(_onZoomAnimTick);
    _ctrl.removeListener(_onTransformChanged);
    _zoomAnim.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onZoomAnimTick() {
    final v = _matrixAnim?.value;
    if (v != null) _ctrl.value = v;
  }

  void _onTransformChanged() {
    final zoomed = _ctrl.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
      if (mounted) setState(() {});
    }
  }

  void _resetZoom() {
    _zoomAnim.stop();
    if (_ctrl.value != Matrix4.identity()) {
      _ctrl.value = Matrix4.identity();
    }
  }

  void _animateTo(Matrix4 target) {
    _zoomAnim.stop();
    _matrixAnim = Matrix4Tween(
      begin: _ctrl.value.clone(),
      end: target,
    ).animate(
      CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOutCubic),
    );
    _zoomAnim.forward(from: 0);
  }

  void _onDoubleTap() {
    if (_ctrl.value.getMaxScaleOnAxis() > 1.01) {
      _animateTo(Matrix4.identity());
      return;
    }
    final p = _tap?.localPosition ?? Offset.zero;
    const s = 2.5;
    final boxSize = context.size;
    var tx = -p.dx * (s - 1);
    var ty = -p.dy * (s - 1);
    if (boxSize != null) {
      tx = tx.clamp(-boxSize.width * (s - 1), 0.0);
      ty = ty.clamp(-boxSize.height * (s - 1), 0.0);
    }
    final target = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(s);
    _animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = McImageUrls.resolve(widget.rawUrl, widthPx: 1920);
    return GestureDetector(
      onDoubleTapDown: (d) => _tap = d,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _ctrl,
        panEnabled: _zoomed,
        minScale: 1,
        maxScale: 5,
        onInteractionStart: (_) => _zoomAnim.stop(),
        child: Center(
          child: CachedNetworkImage(
            imageUrl: resolved,
            httpHeaders: mcImageHeaders(),
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (_, __, ___) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  McIcons.image3Fill,
                  size: 40,
                  color: McTokens.textFaint,
                ),
                const SizedBox(height: 8),
                Text('种子原图床图片暂不可用', style: McText.caption.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _promoTags(TorrentHit hit, {bool solid = false}) {
  return [
    for (final p in TorrentSearchLogic.promos(hit))
      switch (p.kind) {
        TorrentPromoKind.free => _MiniTag(
            text: p.label,
            fg: solid ? const Color(0xFF052E17) : const Color(0xFF78D194),
            bg: McTokens.ok.withValues(alpha: solid ? 0.92 : 0.16),
            bold: true,
          ),
        TorrentPromoKind.discount => _MiniTag(
            text: p.label,
            fg: solid ? Colors.white : const Color(0xFF99C7FF),
            bg: McTokens.info.withValues(alpha: solid ? 0.85 : 0.16),
            bold: true,
          ),
        TorrentPromoKind.upload => _MiniTag(
            text: p.label,
            fg: solid ? Colors.white : const Color(0xFFC7A6FF),
            bg: const Color(0xFFC791FF).withValues(alpha: solid ? 0.85 : 0.16),
            bold: true,
          ),
        TorrentPromoKind.hitAndRun => _MiniTag(
            text: p.label,
            fg: solid ? const Color(0xFF3B2600) : McTokens.warning,
            bg: const Color(0xFFF59E0A).withValues(alpha: solid ? 0.9 : 0.16),
            bold: true,
          ),
      },
  ];
}

List<Widget> _attrTags(TorrentAttrs attrs) {
  final chips = TorrentSearchLogic.attrBadges(attrs);
  Color toneColor(TorrentAttrTone t) => switch (t) {
        TorrentAttrTone.plain => McTokens.textMuted,
        TorrentAttrTone.season => McTokens.accent2,
        TorrentAttrTone.content => const Color(0xFFF0B5D9),
        TorrentAttrTone.remux => const Color(0xFF99C7FF),
        TorrentAttrTone.hdr => const Color(0xFFC7A6FF),
        TorrentAttrTone.subtitle => const Color(0xFF7DE3B8),
        TorrentAttrTone.audio => const Color(0xFFFFD18A),
        TorrentAttrTone.group => McTokens.accent,
        TorrentAttrTone.platform => const Color(0xFF8FD9FF),
      };
  return [
    for (final c in chips.take(4)) _MiniTag(text: c.text, fg: toneColor(c.tone)),
    if (chips.length > 4)
      _MiniTag(text: '+${chips.length - 4}', fg: McTokens.textFaint),
  ];
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.text,
    this.fg = McTokens.textMuted,
    this.bg = const Color(0x0FFFFFFF),
    this.bold = false,
  });

  final String text;
  final Color fg;
  final Color bg;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: McText.micro.copyWith(
          color: fg,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
