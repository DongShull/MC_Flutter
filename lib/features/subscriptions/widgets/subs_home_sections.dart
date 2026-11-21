import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/player/player_page_args.dart';
import '../state/home_model.dart';
import '../state/models.dart';

/// 订阅首页各分区（逐块对齐鸿蒙 SubscriptionsPage.ets 的 Hero / 刚刚入库 / 日程 /
/// 剧集·电影订阅横滑行），海报墙（SubscriptionWallPage）复用同一张海报卡。

const double subsPagePadding = 16;

// ── 分区标题 ──

class SubsSectionTitle extends StatelessWidget {
  const SubsSectionTitle(
      {super.key, required this.title, this.trailing = '', this.onTap});

  final String title;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(width: 5),
            if (onTap != null)
              Icon(McIcons.chevronRight,
                  size: 13, color: theme.onSurface.withValues(alpha: 0.45)),
            const Spacer(),
            if (trailing.isNotEmpty)
              Text(trailing,
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.onSurface.withValues(alpha: 0.45))),
          ],
        ),
      ),
    );
  }
}

// ── 海报卡（SubsPosterCard） ──

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
    final theme = Theme.of(context).colorScheme;
    final st = home.standing(sub);
    final chipText = st.chipText ?? '追踪中';
    final chipColor = st.chipColor ?? subsToneInfo;
    final progress = home.seasonProgress(sub);

    return McTapMenu(
      onTap: onOpen,
      menuActions: [
        MenuItemSpec(McStrings.subsOpenSubscriptionDetail, McIcons.tv, onOpen),
        if (onOpenMedia != null)
          MenuItemSpec(
              McStrings.subsOpenMediaDetail, McIcons.film, onOpenMedia),
      ],
      child: SizedBox(
        width: 126,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      httpHeaders: mcImageHeaders(),
                      imageUrl: McImageUrls.resolve(sub.media.posterUrl,
                          widthPx: 240),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          ColoredBox(color: theme.surfaceContainerHighest),
                    ),
                  ),
                  // 状态 chip：色点 + 文字（黑 42% 胶囊）
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                color: chipColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(chipText,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  // 当季进度细线
                  if (progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10)),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2.5,
                          backgroundColor: Colors.black.withValues(alpha: 0.42),
                          valueColor: const AlwaysStoppedAnimation(subsToneOk),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(sub.media.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(home.meta(sub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.onSurface.withValues(alpha: 0.55))),
            if (flowLine != null && flowLine!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(flowLine!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.onSurface.withValues(alpha: 0.45))),
            ],
          ],
        ),
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
    final theme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: theme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(McIcons.chevronRight,
                size: 22, color: theme.onSurface.withValues(alpha: 0.55)),
            const SizedBox(height: 8),
            const Text(McStrings.subsViewAll,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(McStrings.subsCountN(count),
                style: TextStyle(
                    fontSize: 11,
                    color: theme.onSurface.withValues(alpha: 0.45))),
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
    final theme = Theme.of(context).colorScheme;
    final faint = theme.onSurface.withValues(alpha: 0.45);
    final chars = label.split('').join('\n');
    return SizedBox(
      width: 18,
      height: 165,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 1, height: 40, color: theme.outlineVariant),
          const SizedBox(height: 8),
          Text(chars,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w500,
                color: faint,
              )),
          const SizedBox(height: 8),
          Container(width: 1, height: 40, color: theme.outlineVariant),
        ],
      ),
    );
  }
}

/// 长按菜单（InkWell + showMenu，触觉反馈对齐鸿蒙 bindContextMenu）。
class MenuItemSpec {
  const MenuItemSpec(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class McTapMenu extends StatelessWidget {
  const McTapMenu(
      {super.key, required this.child, this.onTap, this.menuActions});

  final Widget child;
  final VoidCallback? onTap;
  final List<MenuItemSpec>? menuActions;

  Future<void> _show(BuildContext context, Offset position) async {
    final actions = menuActions;
    if (actions == null || actions.isEmpty) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final value = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy,
          overlay.size.width - position.dx, overlay.size.height - position.dy),
      items: [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(actions[i].icon, size: 18),
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
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// 播放入口：会话协商起播（页签跳转统一 context.push 路由）。
void subsPlay(BuildContext context, RecentArrivalView r) {
  final isTv = r.media.kind == 'tv';
  context.push('/player',
      extra: PlayerPageArgs(
        mediaItemId: r.media.mediaItemId,
        seasonNumber: isTv ? r.seasonNumber : 0,
        episodeNumber: isTv ? r.episodeNumber : 0,
        title: r.media.title,
        subtitle:
            isTv ? 'S${pad2(r.seasonNumber)}E${pad2(r.episodeNumber)}' : null,
        isEpisode: isTv,
      ));
}

/// 影片详情：订阅域没有库内条目 id，走发现侧 title_ref（同鸿蒙 discoverDetail）。
void subsOpenMedia(BuildContext context, MediaBrief media) {
  context.push(
      '/discover/title?ref=${Uri.encodeComponent('tmdb:${media.kind}:${media.tmdbId ?? 0}')}');
}

// ── Hero 轮播 ──

class SubsHeroCarousel extends StatefulWidget {
  const SubsHeroCarousel({super.key, required this.home, required this.now});

  final SubsHome home;
  final DateTime now;

  @override
  State<SubsHeroCarousel> createState() => _SubsHeroCarouselState();
}

class _SubsHeroCarouselState extends State<SubsHeroCarousel>
    with SingleTickerProviderStateMixin {
  static const _period = Duration(seconds: 8);
  late final AnimationController _fill;
  late final PageController _page;
  Timer? _timer;

  int get _count => buildHeroSlides(widget.home, widget.home.nowMs).length;

  @override
  void initState() {
    super.initState();
    _page = PageController();
    _fill = AnimationController(vsync: this, duration: _period)..repeat();
    _timer = Timer.periodic(_period, (_) {
      if (!mounted || _count < 2) return;
      _page.nextPage(
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void didUpdateWidget(SubsHeroCarousel old) {
    super.didUpdateWidget(old);
    if (buildHeroSlides(old.home, old.home.nowMs).length != _count &&
        _page.hasClients) {
      _page.jumpToPage(0);
      _fill.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fill.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = buildHeroSlides(widget.home, widget.home.nowMs);
    if (slides.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = (w * 0.62).clamp(380.0, 500.0);
      return SizedBox(
        height: h,
        width: w,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: slides.length,
              onPageChanged: (_) => _fill.forward(from: 0),
              itemBuilder: (context, i) => _HeroSlideView(
                  slide: slides[i],
                  onTap: () => context.push(
                      '/subscriptions/detail/${slides[i].subscriptionId}')),
            ),
            // 底图渐变压暗
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.55, 1.0],
                    colors: [Colors.black26, Colors.black45, Colors.black87],
                  ),
                ),
              ),
            ),
            // 居中指示器（选中条内白色填充按轮播进度）
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slides.length; i++)
                    _IndicatorBar(
                      selected: i ==
                          (_page.hasClients ? (_page.page ?? 0).round() : 0),
                      fill: _fill,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _IndicatorBar extends StatelessWidget {
  const _IndicatorBar({required this.selected, required this.fill});

  final bool selected;
  final Animation<double> fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: selected ? 24 : 12,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: selected
          ? AnimatedBuilder(
              animation: fill,
              builder: (context, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fill.value.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _HeroSlideView extends StatelessWidget {
  const _HeroSlideView({required this.slide, required this.onTap});

  final HeroSlide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clockNumeric = heroClockIsNumeric(slide.clock);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 底图（backdrop ?? poster，原图不取变体）
          CachedNetworkImage(
            httpHeaders: mcImageHeaders(),
            imageUrl: McImageUrls.resolve(
                slide.media.backdropUrl ?? slide.media.posterUrl),
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // logo 或片名
                  if ((slide.media.logoUrl ?? '').isNotEmpty)
                    SizedBox(
                      height: 72,
                      width: 200,
                      child: Center(
                        child: CachedNetworkImage(
                          httpHeaders: mcImageHeaders(),
                          imageUrl: McImageUrls.resolve(slide.media.logoUrl),
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    )
                  else
                    Text(
                      slide.media.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  const SizedBox(height: 16),
                  // 状态行（色点 + eyebrow）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: slide.eyebrowTone, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text(slide.eyebrow,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                  if (slide.clock.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(slide.clockLabel,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6))),
                    const SizedBox(height: 2),
                    Text(slide.clock,
                        style: TextStyle(
                            fontSize: clockNumeric ? 48 : 36,
                            fontWeight: clockNumeric
                                ? FontWeight.w300
                                : FontWeight.w500,
                            color: Colors.white)),
                  ] else if (slide.detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(slide.detail,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9))),
                  ],
                  if (slide.footnote.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(slide.footnote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6))),
                  ],
                  if (slide.progress > 0) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 168,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1.5),
                        child: LinearProgressIndicator(
                          value: slide.progress.clamp(0.0, 1.0),
                          minHeight: 2.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFF7FB0FF)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _heroButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroButton(BuildContext context) {
    final playable = slide.playable;
    final label = playable
        ? (slide.resumePercent > 0
            ? McStrings.subsContinuePlay
            : McStrings.subsPlay)
        : McStrings.subsViewSubscription;
    final style = FilledButton.styleFrom(
      backgroundColor: playable
          ? const Color(0xFF0B0D12)
          : Colors.white.withValues(alpha: 0.18),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    );
    Widget button = FilledButton.icon(
      style: style,
      onPressed: playable
          ? () => context.push('/player',
              extra: PlayerPageArgs(
                mediaItemId: slide.media.mediaItemId,
                seasonNumber: slide.media.kind == 'tv' ? 1 : 0,
                episodeNumber: 0,
                title: slide.media.title,
                isEpisode: slide.media.kind == 'tv',
              ))
          : () => context.push('/subscriptions/detail/${slide.subscriptionId}'),
      icon: Icon(playable ? McIcons.playFill : McIcons.tv, size: 15),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
    if (!playable) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: button,
      );
    }
    return button;
  }
}

// ── 刚刚入库横滑 ──

class SubsRecentRow extends StatelessWidget {
  const SubsRecentRow({super.key, required this.home, required this.now});

  final SubsHome home;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final items = home.recent;
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 182,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final r = items[i];
          final sub = home.subById(r.subscriptionId);
          final fresh = recentFreshCount(r, nowMs: home.nowMs);
          final isTv = r.media.kind == 'tv';
          return McTapMenu(
            onTap: () => subsPlay(context, r),
            menuActions: [
              MenuItemSpec(McStrings.subsPlay, McIcons.playFill,
                  () => subsPlay(context, r)),
              if (sub != null)
                MenuItemSpec(McStrings.subsOpenSubscriptionDetail, McIcons.tv,
                    () => context.push('/subscriptions/detail/${sub.id}')),
              MenuItemSpec(McStrings.subsOpenMediaDetail, McIcons.film,
                  () => subsOpenMedia(context, r.media)),
            ],
            child: SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 180,
                    height: 101,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            httpHeaders: mcImageHeaders(),
                            imageUrl: McImageUrls.resolve(
                                r.stillUrl ??
                                    r.media.backdropUrl ??
                                    r.media.posterUrl,
                                widthPx: 480),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: Color(0x22FFFFFF)),
                          ),
                        ),
                        // 续播进度线
                        if ((r.progressPercent ?? 0) > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: (r.progressPercent! / 100).clamp(0.0, 1.0),
                              minHeight: 2.5,
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.42),
                              valueColor:
                                  const AlwaysStoppedAnimation(subsToneInfo),
                            ),
                          ),
                        // 新 N 集 chip
                        if (fresh > 0)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: subsToneOk,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isTv && fresh > 1
                                    ? McStrings.subsNewEpisodesN(fresh)
                                    : McStrings.subsNewEpisode,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        // 播放角标
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(McIcons.playFill,
                                size: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(r.media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(_label(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55))),
                  const SizedBox(height: 2),
                  Text(recentAgeText(r, nowMs: home.nowMs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _label(RecentArrivalView r) {
    final isTv = r.media.kind == 'tv';
    if (isTv) {
      return 'S${pad2(r.seasonNumber)}E${pad2(r.episodeNumber)} · ${r.media.title}';
    }
    return '${r.media.year ?? ''} · ${McStrings.subsMovieWord}';
  }
}

// ── 日程分区 ──

class SubsScheduleRow extends StatefulWidget {
  const SubsScheduleRow({super.key, required this.home, required this.now});

  final SubsHome home;
  final DateTime now;

  @override
  State<SubsScheduleRow> createState() => _SubsScheduleRowState();
}

class _SubsScheduleRowState extends State<SubsScheduleRow> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final home = widget.home;
    final days = scheduleDays(home.today);
    final selected = days[_selected];
    final groups = dayGroups(home.today, selected.daysAhead);
    final caption =
        McStrings.subsScheduleCaption(selected.dateLabel, selected.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsSectionTitle(title: McStrings.subsScheduleTitle, trailing: caption),
        const SizedBox(height: 10),
        // 七天日期条（等分整行）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
          child: Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                    child: _dayChip(context, days[i], i == _selected,
                        () => setState(() => _selected = i))),
            ],
          ),
        ),
        if (groups.isEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
            child: Text(McStrings.subsScheduleEmptyDay,
                style: TextStyle(
                    fontSize: 13,
                    color: theme.onSurface.withValues(alpha: 0.45))),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: subsPagePadding),
            child: Container(
              decoration: BoxDecoration(
                color: theme.onSurface.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: theme.onSurface.withValues(alpha: 0.07)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < groups.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          indent: 86,
                          color: theme.onSurface.withValues(alpha: 0.06)),
                    _agendaTile(context, groups[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dayChip(BuildContext context, ScheduleDay day, bool selected,
      VoidCallback onTap) {
    final theme = Theme.of(context).colorScheme;
    final dim = day.count == 0;
    final tones = dayGroups(widget.home.today, day.daysAhead)
        .map((g) =>
            groupPresentation(g, widget.home.etas, widget.home.nowMs).tone)
        .toSet()
        .toList();
    return Opacity(
      opacity: dim && !selected ? 0.36 : 1,
      child: GestureDetector(
        onTap: dim ? null : onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? theme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(day.weekday,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? theme.surface
                          : theme.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 2),
              Text('${day.dayNumber}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected ? theme.surface : theme.onSurface)),
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
                        decoration:
                            BoxDecoration(color: t, shape: BoxShape.circle),
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
    final theme = Theme.of(context).colorScheme;
    final home = widget.home;
    final p = groupPresentation(group, home.etas, home.nowMs);
    final sub = home.subById(group.subscriptionId);
    final thumb = sub?.media.backdropUrl ?? sub?.media.posterUrl ?? '';
    final pending = p.timeLabel == McStrings.subsTimePending;
    return McTapMenu(
      onTap: sub == null
          ? null
          : () => context.push('/subscriptions/detail/${sub.id}'),
      menuActions: [
        if (sub != null)
          MenuItemSpec(McStrings.subsOpenSubscriptionDetail, McIcons.tv,
              () => context.push('/subscriptions/detail/${sub.id}')),
        if (sub != null)
          MenuItemSpec(McStrings.subsOpenMediaDetail, McIcons.film,
              () => subsOpenMedia(context, sub.media)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 时刻列
            SizedBox(
              width: 62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.timeLabel,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              pending ? FontWeight.w400 : FontWeight.w600,
                          color: pending
                              ? theme.onSurface.withValues(alpha: 0.45)
                              : theme.onSurface)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: p.tone, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(p.statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.tone)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 剧照
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 92,
                height: 52,
                color: theme.surfaceContainerHighest,
                child: thumb.isEmpty
                    ? null
                    : CachedNetworkImage(
                        httpHeaders: mcImageHeaders(),
                        imageUrl: McImageUrls.resolve(thumb, widthPx: 360),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(group.label(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
            Icon(McIcons.chevronRight,
                size: 12, color: theme.onSurface.withValues(alpha: 0.45)),
          ],
        ),
      ),
    );
  }
}

// ── 剧集/电影订阅横滑行 ──

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

  @override
  Widget build(BuildContext context) {
    final split = home.shelfSplit(kind);
    if (split.all.isEmpty) return const SizedBox.shrink();
    final active = split.active.take(20).toList();
    final hasResting = split.paused.isNotEmpty || split.done.isNotEmpty;
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
            itemCount: active.length + (hasResting ? 1 : 0) + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i == active.length + (hasResting ? 1 : 0)) {
                return SubsSeeAllCard(
                    count: split.all.length, onTap: onViewAll);
              }
              if (i == active.length) {
                return SubsRestingDivider(label: home.restingLabel(kind));
              }
              final sub = active[i];
              final resting = home.standing(sub).phase != 'active';
              return Opacity(
                opacity: resting ? 0.55 : 1,
                child: SubsPosterCard(
                  sub: sub,
                  home: home,
                  flowLine: flowLineOf?.call(sub),
                  onOpen: () => context.push('/subscriptions/detail/${sub.id}'),
                  onOpenMedia: () => subsOpenMedia(context, sub.media),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
