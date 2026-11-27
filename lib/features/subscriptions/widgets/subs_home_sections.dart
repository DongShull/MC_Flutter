import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_ambient.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/player/player_page_args.dart';
import '../state/home_model.dart';
import '../state/models.dart';

/// 订阅首页各分区（1:1 对齐 iOS `SubscriptionsHomeHero.swift` & `SubscriptionsHomeSections.swift`）：
/// 全出血沉浸 Hero / 刚刚入库 16:9 横滑 / 7 天胶囊日程（含实时下载进度与 readyAt）/ 剧集·电影订阅书架。

const double subsPagePadding = McTokens.pagePadding;

// ── 分区标题 ──

class SubsSectionTitle extends StatelessWidget {
  const SubsSectionTitle({
    super.key,
    required this.title,
    this.trailing = '',
    this.onTap,
  });

  final String title;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return McSectionHeader(
      title: title,
      trailingText: trailing.isEmpty ? null : trailing,
      onTap: onTap,
    );
  }
}

// ── 海报卡 ──

class SubsPosterCard extends StatelessWidget {
  const SubsPosterCard({
    super.key,
    required this.sub,
    required this.home,
    this.flowLine,
    this.onOpen,
    this.onOpenMedia,
  });

  final SubscriptionView sub;
  final SubsHome home;
  final String? flowLine;
  final VoidCallback? onOpen;
  final VoidCallback? onOpenMedia;

  @override
  Widget build(BuildContext context) {
    final st = home.standing(sub);
    final chipText = st.chipText;
    final chipColor = st.chipColor ?? McTokens.info;
    final progress = home.seasonProgress(sub);

    return McTapMenu(
      onTap: onOpen,
      menuActions: [
        MenuItemSpec(McStrings.subsOpenSubscriptionDetail, McIcons.tv, onOpen),
        if (onOpenMedia != null)
          MenuItemSpec(
            McStrings.subsOpenMediaDetail,
            McIcons.film,
            onOpenMedia,
          ),
      ],
      child: McPosterCard(
        width: 124,
        title: sub.media.title,
        posterUrl: sub.media.posterUrl,
        subtitle: home.meta(sub),
        badge: chipText,
        badgeDotColor: chipText != null ? chipColor : null,
        progress: progress > 0 ? progress : null,
        abnormalLabel: (flowLine != null && flowLine!.isNotEmpty)
            ? flowLine
            : null,
        onTap: onOpen,
      ),
    );
  }
}

/// 「查看全部」卡（横滑末尾）。
class SubsSeeAllCard extends StatelessWidget {
  const SubsSeeAllCard({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return McPressable(
      onTap: onTap,
      child: Container(
        width: 112,
        margin: const EdgeInsets.only(bottom: 44),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(McTokens.posterRadius),
          border: Border.all(color: McTokens.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: McTokens.glassFillHover,
                shape: BoxShape.circle,
                border: Border.all(color: McTokens.line),
              ),
              child: const Icon(
                McIcons.chevronRight,
                size: 16,
                color: McTokens.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Text(McStrings.subsViewAll, style: McText.sub.semibold),
            const SizedBox(height: 2),
            Text(McStrings.subsCountN(count), style: McText.caption.faint),
          ],
        ),
      ),
    );
  }
}

/// 在追与歇着之间的竖排小字分隔。
class SubsRestingDivider extends StatelessWidget {
  const SubsRestingDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final chars = label.split('').join('\n');
    return SizedBox(
      width: 18,
      height: 176,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 1, height: 42, color: McTokens.line),
          const SizedBox(height: 8),
          Text(
            chars,
            textAlign: TextAlign.center,
            style: McText.micro.copyWith(
              height: 1.15,
              color: McTokens.textFaint,
            ),
          ),
          const SizedBox(height: 8),
          Container(width: 1, height: 42, color: McTokens.line),
        ],
      ),
    );
  }
}

/// 长按上下文菜单。
class MenuItemSpec {
  const MenuItemSpec(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class McTapMenu extends StatelessWidget {
  const McTapMenu({
    super.key,
    required this.child,
    this.onTap,
    this.menuActions,
  });

  final Widget child;
  final VoidCallback? onTap;
  final List<MenuItemSpec>? menuActions;

  Future<void> _show(BuildContext context, Offset position) async {
    final actions = menuActions;
    if (actions == null || actions.isEmpty) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final value = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(actions[i].icon, size: 17, color: McTokens.textMuted),
                const SizedBox(width: 10),
                Text(actions[i].label),
              ],
            ),
          ),
      ],
    );
    if (value != null) actions[value].onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (d) => _show(context, d.globalPosition),
      child: McPressable(onTap: onTap, child: child),
    );
  }
}

/// 播放入口：会话协商起播（准确传入新入库的 `seasonNumber` 与 `episodeNumber`）。
void subsPlay(BuildContext context, RecentArrivalView r) {
  final isTv = r.media.kind == 'tv';
  context.push(
    '/player',
    extra: PlayerPageArgs(
      mediaItemId: r.media.mediaItemId,
      seasonNumber: isTv ? r.seasonNumber : 0,
      episodeNumber: isTv ? r.episodeNumber : 0,
      title: r.media.title,
      subtitle:
          isTv ? 'S${pad2(r.seasonNumber)}E${pad2(r.episodeNumber)}' : null,
      isEpisode: isTv,
    ),
  );
}

/// 影片详情：走发现侧 title_ref。
void subsOpenMedia(BuildContext context, MediaBrief media) {
  context.push(
    '/discover/title?ref=${Uri.encodeComponent('tmdb:${media.kind}:${media.tmdbId ?? 0}')}',
  );
}

// ── 全出血沉浸式 Hero 轮播 ──

class SubsHeroCarousel extends StatelessWidget {
  const SubsHeroCarousel({
    super.key,
    required this.home,
    required this.now,
    this.scrollOffset = 0,
    this.topClearance = 88,
    this.onAmbientColorChanged,
  });

  final SubsHome home;
  final DateTime now;
  final double scrollOffset;
  final double topClearance;
  final ValueChanged<Color?>? onAmbientColorChanged;

  @override
  Widget build(BuildContext context) {
    final slides = buildHeroSlides(home, home.nowMs);
    if (slides.isEmpty) {
      return SizedBox(height: topClearance);
    }

    return McImmersiveHero(
      height: 495,
      scrollOffset: scrollOffset,
      itemCount: slides.length,
      imageUrlOf: (i) =>
          slides[i].media.backdropUrl ?? slides[i].media.posterUrl,
      onAmbientColorChanged: onAmbientColorChanged,
      onTapSlide: (i) =>
          context.push('/subscriptions/detail/${slides[i].subscriptionId}'),
      foregroundBuilder: (context, i) => _HeroSlideForeground(slide: slides[i]),
    );
  }
}

class _HeroSlideForeground extends StatelessWidget {
  const _HeroSlideForeground({required this.slide});

  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    final clockNumeric = heroClockIsNumeric(slide.clock);
    final playArrival = slide.playArrival;
    final playable = playArrival != null;
    final label = playable
        ? (slide.resumePercent > 0
            ? McStrings.subsContinuePlay
            : McStrings.subsPlay)
        : McStrings.subsViewSubscription;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((slide.media.logoUrl ?? '').isNotEmpty)
          SizedBox(
            height: 76,
            width: 240,
            child: Center(
              child: CachedNetworkImage(
                httpHeaders: mcImageHeaders(),
                imageUrl:
                    McImageUrls.resolve(slide.media.logoUrl, widthPx: 640),
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => Text(
                  slide.media.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.display.copyWith(fontSize: 28),
                ),
              ),
            ),
          )
        else
          Text(
            slide.media.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: McText.display.copyWith(
              fontSize: 28,
              shadows: const [
                Shadow(color: Color(0xCC000000), blurRadius: 16),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: slide.eyebrowTone ?? McTokens.info,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                slide.eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.sub.copyWith(
                  color: McTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (slide.clock.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (slide.clockLabel.isNotEmpty)
            Text(slide.clockLabel, style: McText.caption.muted),
          const SizedBox(height: 2),
          Text(
            slide.clock,
            style: TextStyle(
              fontFamily: McText.fontFamily,
              fontFamilyFallback: McText.fontFallback,
              fontSize: clockNumeric ? 40 : 30,
              fontWeight: clockNumeric ? FontWeight.w300 : FontWeight.w600,
              color: McTokens.text,
              fontFeatures: McText.tabular,
            ),
          ),
        ] else if (slide.detail.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            slide.detail,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.sub.copyWith(color: McTokens.textMuted),
          ),
        ],
        if (slide.footnote.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            slide.footnote,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.caption.muted,
          ),
        ],
        if (slide.progress > 0) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 176,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: slide.progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: const Color(0x38FFFFFF),
                valueColor: const AlwaysStoppedAnimation(McTokens.info),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        McActionPill(
          label: label,
          icon: playable ? McIcons.playFill : McIcons.bookmarkFill,
          primary: playable,
          tone: McGlassTone.secondary,
          onTap: playable
              // 修复 S1E0 Bug：直接起播实际新到的季号与集号！
              ? () => subsPlay(context, playArrival)
              : () =>
                  context.push('/subscriptions/detail/${slide.subscriptionId}'),
        ),
      ],
    );
  }
}

// ── 刚刚入库横滑（16:9 McUpNextCard + 右下玻璃播放圆钮） ──

class SubsRecentRow extends StatelessWidget {
  const SubsRecentRow({super.key, required this.home, required this.now});

  final SubsHome home;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final items = home.recent;
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const McSectionHeader(title: McStrings.subsRecentTitle),
        const SizedBox(height: 12),
        SizedBox(
          height: 202,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final r = items[i];
              final sub = home.subById(r.subscriptionId);
              final fresh = recentFreshCount(r, nowMs: home.nowMs);
              final isTv = r.media.kind == 'tv';
              final badge = fresh > 0
                  ? (isTv && fresh > 1
                      ? McStrings.subsNewEpisodesN(fresh)
                      : McStrings.subsNewEpisode)
                  : null;
              return McTapMenu(
                onTap: () => subsPlay(context, r),
                menuActions: [
                  MenuItemSpec(
                    McStrings.subsPlay,
                    McIcons.playFill,
                    () => subsPlay(context, r),
                  ),
                  if (sub != null)
                    MenuItemSpec(
                      McStrings.subsOpenSubscriptionDetail,
                      McIcons.tv,
                      () => context.push('/subscriptions/detail/${sub.id}'),
                    ),
                  MenuItemSpec(
                    McStrings.subsOpenMediaDetail,
                    McIcons.film,
                    () => subsOpenMedia(context, r.media),
                  ),
                ],
                child: McUpNextCard(
                  width: 224,
                  title: r.media.title,
                  backdropUrl:
                      r.stillUrl ?? r.media.backdropUrl ?? r.media.posterUrl,
                  subtitle: _label(r),
                  footnote: recentAgeText(r, nowMs: home.nowMs),
                  badge: badge,
                  progress: (r.progressPercent ?? 0) > 0
                      ? (r.progressPercent! / 100.0).clamp(0.0, 1.0)
                      : null,
                  centerPlayIcon: false,
                  onPlay: () => subsPlay(context, r),
                  onTap: () => subsPlay(context, r),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _label(RecentArrivalView r) {
    final isTv = r.media.kind == 'tv';
    if (isTv) {
      final code = 'S${pad2(r.seasonNumber)}E${pad2(r.episodeNumber)}';
      if ((r.episodeName ?? '').isNotEmpty) return '$code · ${r.episodeName}';
      return code;
    }
    return '${r.media.year ?? ''} · ${McStrings.subsMovieWord}';
  }
}

// ── 追更日程分区 ──

class SubsScheduleRow extends StatefulWidget {
  const SubsScheduleRow({super.key, required this.home, required this.now});

  final SubsHome home;
  final DateTime now;

  @override
  State<SubsScheduleRow> createState() => _SubsScheduleRowState();
}

class _SubsScheduleRowState extends State<SubsScheduleRow> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    final days = scheduleDays(home.today);
    if (!days.any((d) => d.count > 0)) return const SizedBox.shrink();

    final firstActive = days.indexWhere((d) => d.count > 0);
    final idx = (_selected != null && _selected! < days.length)
        ? _selected!
        : (firstActive >= 0 ? firstActive : 0);
    final selected = days[idx];
    final groups = dayGroups(home.today, selected.daysAhead);
    final caption =
        McStrings.subsScheduleCaption(selected.dateLabel, selected.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        McSectionHeader(
          title: McStrings.subsScheduleTitle,
          trailingText: caption,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
          child: Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: _dayChip(
                    days[i],
                    i == idx,
                    () => setState(() => _selected = i),
                  ),
                ),
            ],
          ),
        ),
        if (groups.isEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
            child: Text(
              McStrings.subsScheduleEmptyDay,
              style: McText.sub.faint,
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          McInsetGroup(
            dividerIndent: 88,
            children: [
              for (final g in groups) _agendaTile(context, g),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dayChip(ScheduleDay day, bool selected, VoidCallback onTap) {
    final dim = day.count == 0;
    final tones = dayGroups(widget.home.today, day.daysAhead)
        .map(
          (g) => groupPresentation(
            g,
            widget.home.etas,
            widget.home.nowMs,
            tasks: widget.home.tasksByHash,
          ).tone,
        )
        .whereType<Color>()
        .toSet()
        .toList();

    return Opacity(
      opacity: dim && !selected ? 0.36 : 1,
      child: GestureDetector(
        onTap: dim ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? McTokens.accentStrong
                : (dim ? Colors.transparent : McTokens.surfaceInset),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.transparent : McTokens.line,
            ),
          ),
          child: Column(
            children: [
              Text(
                day.weekday,
                style: McText.micro.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selected ? McTokens.onAccent : McTokens.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${day.dayNumber}',
                style: McText.ui
                    .copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? McTokens.onAccent : McTokens.text,
                    )
                    .tabular,
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final t in tones.take(3))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: selected ? McTokens.onAccent : t,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agendaTile(BuildContext context, DayGroup group) {
    final home = widget.home;
    final p = groupPresentation(
      group,
      home.etas,
      home.nowMs,
      tasks: home.tasksByHash,
    );
    final timeStr = groupTime(
      group,
      home.etas,
      home.nowMs,
      tasks: home.tasksByHash,
    );
    final liveProg = p.statusLabel == '下载中'
        ? group.liveProgress(home.tasksByHash)
        : null;
    final statusStr = liveProg != null
        ? '${p.statusLabel} ${(liveProg * 100).round()}%'
        : p.statusLabel;

    final sub = home.subById(group.subscriptionId);
    final thumb = sub?.media.backdropUrl ?? sub?.media.posterUrl ?? '';
    final pending = timeStr == '待定';

    return McTapMenu(
      onTap: sub == null
          ? null
          : () => context.push('/subscriptions/detail/${sub.id}'),
      menuActions: [
        if (sub != null)
          MenuItemSpec(
            McStrings.subsOpenSubscriptionDetail,
            McIcons.tv,
            () => context.push('/subscriptions/detail/${sub.id}'),
          ),
        if (sub != null)
          MenuItemSpec(
            McStrings.subsOpenMediaDetail,
            McIcons.film,
            () => subsOpenMedia(context, sub.media),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeStr,
                    style: McText.titleSm
                        .copyWith(
                          fontSize: 18,
                          fontWeight:
                              pending ? FontWeight.w400 : FontWeight.w700,
                          color: pending ? McTokens.textFaint : McTokens.text,
                        )
                        .tabular,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (p.tone != null) ...[
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: p.tone,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          statusStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.micro.copyWith(
                            color: p.tone ?? McTokens.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(McTokens.radiusSm),
              child: SizedBox(
                width: 92,
                height: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    McArtwork(
                      url: thumb,
                      frameAspect: McTokens.backdropAspect,
                      widthPx: 360,
                    ),
                    if (liveProg != null)
                      Positioned(
                        left: 6,
                        right: 6,
                        bottom: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: liveProg.clamp(0.02, 1.0),
                            minHeight: 2.5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                            valueColor:
                                const AlwaysStoppedAnimation(subsToneInfo),
                          ),
                        ),
                      ),
                  ],
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
                    style: McText.ui.semibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    group.label(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption,
                  ),
                ],
              ),
            ),
            const Icon(
              McIcons.chevronRight,
              size: 14,
              color: McTokens.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 剧集/电影订阅横滑行（修复歇着区卡片被吞 Bug，1:1 对齐 iOS `SubsHomeShelfRow`） ──

class SubsShelfRow extends StatelessWidget {
  const SubsShelfRow({
    super.key,
    required this.home,
    required this.title,
    required this.kind,
    required this.onViewAll,
    this.flowLineOf,
  });

  final SubsHome home;
  final String title;
  final String kind;
  final VoidCallback onViewAll;
  final String? Function(SubscriptionView sub)? flowLineOf;

  static const int _limit = 20;

  @override
  Widget build(BuildContext context) {
    final split = home.shelfSplit(kind);
    if (split.all.isEmpty) return const SizedBox.shrink();

    final active = split.active.take(_limit).toList();
    final remaining = (_limit - active.length).clamp(0, _limit);
    final resting = split.resting.take(remaining).toList();
    final hidden = split.all.length - active.length - resting.length;

    final entries = <Widget>[
      for (final sub in active)
        SubsPosterCard(
          sub: sub,
          home: home,
          flowLine: flowLineOf?.call(sub),
          onOpen: () => context.push('/subscriptions/detail/${sub.id}'),
          onOpenMedia: () => subsOpenMedia(context, sub.media),
        ),
      if (resting.isNotEmpty && active.isNotEmpty)
        SubsRestingDivider(label: home.restingLabel(kind)),
      for (final sub in resting)
        Opacity(
          opacity: 0.55,
          child: SubsPosterCard(
            sub: sub,
            home: home,
            flowLine: flowLineOf?.call(sub),
            onOpen: () => context.push('/subscriptions/detail/${sub.id}'),
            onOpenMedia: () => subsOpenMedia(context, sub.media),
          ),
        ),
      if (hidden > 0)
        SubsSeeAllCard(
          count: split.all.length,
          onTap: onViewAll,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsSectionTitle(
          title: title,
          trailing: home.countSummary(kind),
          onTap: onViewAll,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: flowLineOf == null ? 236 : 256,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => entries[i],
          ),
        ),
      ],
    );
  }
}
