import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/activity/pages/activity_page.dart';
import '../../features/discover/pages/discover_page.dart';
import '../../features/library/pages/library_home_page.dart';
import '../../features/library/state/home_rows.dart';
import '../../features/library/state/library_home_controller.dart';
import '../../features/library/state/models.dart';
import '../../features/library/widgets/library_shared.dart';
import '../../features/more/pages/more_page.dart';
import '../../features/more/widgets/account_switcher_sheet.dart';
import '../../features/root/pages/root_page.dart';
import '../../features/root/state/main_tab_bus.dart';
import '../../features/root/state/shell_badges.dart';
import '../../features/subscriptions/pages/subscriptions_page.dart';
import '../api/api_exception.dart';
import '../api/mc_client.dart';
import '../api/session_providers.dart';
import '../auth/session_watch.dart';
import '../designsystem/adaptive.dart';
import '../designsystem/mc_chrome.dart';
import '../designsystem/mc_glass.dart';
import '../designsystem/mc_icons.dart';
import '../designsystem/theme.dart';
import '../image/image_urls.dart';
import '../player/player_page_args.dart';
import '../session/permissions.dart';
import '../session/session_store.dart';
import 'tab_collapse.dart';

/// 主壳组合根（唯一允许整合各顶层 feature 页面的地方）：
/// - 按 `McPermissions` 动态裁剪页签：媒体库 / [订阅] / 发现 / [活动] / 我的；
/// - 头像页签长按弹出账号切换面板，双击一键切回上一个账号（`appSession.previousAccount`），
///   多账号首次出现 `AccountGestureTip` 液态玻璃引导气泡；
/// - 独立拉取本设备 `GET /api/v1/playback/up-next?limit=1&this_device=true` 渲染「接着看」浮条，
///   持久化隐藏键，长按菜单支持「查看详情（含季集）」与「隐藏」；
/// - 平板/桌面侧边栏自动挂载「我的收藏」「媒体库列表（含部数）」「首页合集（含部数）」。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _resumeHiddenPrefsKey = 'mc_resume_bar_hidden_key';
  static const _accountTipShownPrefsKey = 'mc_tip_account_gestures_v2';

  late MainTab _activeTab = MainTab.values[widget.initialTab.clamp(0, 4)];
  UpNextItem? _resumeItem;
  String? _dismissedResumeKey;
  bool _resumeOffline = false;
  bool _switchingAccount = false;
  bool _showAccountTip = false;
  Timer? _tipTimer;
  Timer? _tipHideTimer;
  AppLifecycleListener? _lifecycle;

  bool get _isTestEnv => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    MainTabBus.instance.addListener(_consumeBus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeBus();
      _loadHiddenResumeKeyAndRefresh();
      _maybeScheduleAccountGestureTip();
    });
    if (!_isTestEnv) {
      _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(_refreshResume()),
      );
    }
  }

  @override
  void dispose() {
    MainTabBus.instance.removeListener(_consumeBus);
    _tipTimer?.cancel();
    _tipHideTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  static List<MainTab> _visibleTabs(McPermissions perms) => <MainTab>[
        MainTab.library,
        if (perms.canSubscribe) MainTab.subscriptions,
        MainTab.discover,
        if (perms.isAdmin) MainTab.activity,
        MainTab.more,
      ];

  void _consumeBus() {
    final pending = MainTabBus.instance.consume();
    if (pending != null && mounted) {
      final perms = ref.read(mcPermissionsProvider);
      final visible = _visibleTabs(perms);
      final target = visible.contains(pending) ? pending : MainTab.library;
      setState(() => _activeTab = target);
    }
  }

  void _onSelectTab(MainTab tab) {
    TabCollapseBus.instance.reset();
    setState(() => _activeTab = tab);
    if (tab == MainTab.activity) {
      ref.read(shellBadgesProvider.notifier).refresh();
    }
  }

  static String _resumeKey(UpNextItem item) =>
      '${item.mediaItemId}|${item.seasonNumber}|${item.episodeNumber}|${item.lastPlayedAt ?? ''}';

  Future<void> _loadHiddenResumeKeyAndRefresh() async {
    if (_isTestEnv) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_resumeHiddenPrefsKey);
      if (mounted && saved != null) {
        setState(() => _dismissedResumeKey = saved);
      }
    } catch (_) {}
    await _refreshResume();
  }

  Future<void> _refreshResume() async {
    if (_isTestEnv || !appSession.isReady) return;
    try {
      final client = ref.read(mcClientProvider);
      final body = await client
          .unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/playback/up-next',
            query: const {'limit': 1, 'this_device': true},
          )
          .timeout(const Duration(seconds: 8));
      final items = (body['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => UpNextItem.fromJson(m.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() {
        _resumeItem = items.isEmpty ? null : items.first;
        _resumeOffline = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNetworkError) {
        setState(() => _resumeOffline = true);
      }
    } catch (_) {
      // 保留上次数据避免闪烁
    }
  }

  Future<void> _dismissResume(UpNextItem item) async {
    final key = _resumeKey(item);
    setState(() => _dismissedResumeKey = key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_resumeHiddenPrefsKey, key);
    } catch (_) {}
  }

  Future<void> _maybeScheduleAccountGestureTip() async {
    if (_isTestEnv) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_accountTipShownPrefsKey) == true) return;
      final savedCount = await _savedAccountCount();
      if (savedCount <= 1 || !mounted) return;
      _tipTimer?.cancel();
      _tipTimer = Timer(const Duration(milliseconds: 1200), () async {
        if (!mounted) return;
        await prefs.setBool(_accountTipShownPrefsKey, true);
        if (!mounted) return;
        setState(() => _showAccountTip = true);
        _tipHideTimer?.cancel();
        _tipHideTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _showAccountTip = false);
        });
      });
    } catch (_) {}
  }

  Future<int> _savedAccountCount() async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      final raw = await storage.read(key: 'mc_servers');
      if (raw == null || raw.isEmpty) return 0;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return 0;
      var total = 0;
      for (final s in decoded.whereType<Map>()) {
        final accts = s['accounts'];
        if (accts is List) total += accts.length;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _switchToPreviousAccount() async {
    if (_switchingAccount) return;
    final prev = appSession.previousAccount;
    if (prev == null) return;
    _switchingAccount = true;
    HapticFeedback.mediumImpact();
    setState(() => _showAccountTip = false);
    try {
      final ok = await appSession.switchAccount(
        origin: prev.origin,
        username: prev.username,
      );
      if (!mounted) return;
      if (ok) {
        final name = appSession.username.isNotEmpty
            ? appSession.username
            : prev.username;
        McToast.success('已切换到 $name');
        unawaited(_refreshResume());
        try {
          final me = await ref
              .read(mcClientProvider)
              .unwrap<Map<String, dynamic>>(
                Channel.general,
                'GET',
                '/api/v1/auth/me',
              );
          await appSession.updateFromMeJson(me);
        } catch (_) {}
      } else {
        McToast.error('上一个账号登录已失效，请重新登录');
        if (mounted) {
          unawaited(showAccountSwitcherSheet(context));
        }
      }
    } finally {
      _switchingAccount = false;
    }
  }

  void _openResumeLongPressMenu(UpNextItem item) {
    HapticFeedback.mediumImpact();
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: item.title,
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              icon: McIcons.film,
              title: '查看详情',
              subtitle: item.isEpisode
                  ? episodeCode(item.seasonNumber, item.episodeNumber)
                  : null,
              showChevron: true,
              onTap: () {
                Navigator.of(ctx).pop();
                final detailPath = item.isEpisode
                    ? '/detail/${item.libraryId}/${item.mediaItemId}?season=${item.seasonNumber}&episode=${item.episodeNumber}'
                    : '/detail/${item.libraryId}/${item.mediaItemId}';
                context.push(detailPath).then((_) {
                  if (mounted) unawaited(_refreshResume());
                });
              },
            ),
            McInsetRow(
              icon: McIcons.eyeOff,
              title: '隐藏',
              onTap: () {
                Navigator.of(ctx).pop();
                unawaited(_dismissResume(item));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageFor(MainTab tab) => switch (tab) {
        MainTab.library => const LibraryHomePage(),
        MainTab.subscriptions => const SubscriptionsPage(),
        MainTab.discover => const DiscoverPage(),
        MainTab.activity => const ActivityPage(),
        MainTab.more => const MorePage(),
      };

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(mcPermissionsProvider);
    final visibleTabs = _visibleTabs(perms);

    // 权限回收或切换账号导致当前页签不可见时自动回落至媒体库。
    final effectiveTab =
        visibleTabs.contains(_activeTab) ? _activeTab : MainTab.library;
    if (effectiveTab != _activeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeTab != effectiveTab) {
          setState(() => _activeTab = effectiveTab);
        }
      });
    }

    // 切换账号后刷新本设备「接着看」并检查手势提示。
    ref.listen<int>(mcSessionGenerationProvider, (prev, next) {
      if (prev != null && prev != next) {
        setState(() {
          _resumeItem = null;
          _resumeOffline = false;
        });
        unawaited(_refreshResume());
        unawaited(_maybeScheduleAccountGestureTip());
      }
    });

    final currentRoutePath =
        GoRouterState.of(context).matchedLocation;
    final onReels = currentRoutePath.startsWith('/reels');
    final onAgent = currentRoutePath.startsWith('/agent');
    final onAdminMore = effectiveTab == MainTab.more && perms.isAdmin;

    final resumeItem = _resumeItem;
    final showResume = !onReels &&
        !onAgent &&
        !onAdminMore &&
        !_resumeOffline &&
        resumeItem != null &&
        _resumeKey(resumeItem) != _dismissedResumeKey;

    // 片段页与管理员「我的」页（自带 AI 快捷输入）不触发底栏收起。
    final blockTabCollapse = onReels || onAdminMore;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical) {
          if (blockTabCollapse) {
            TabCollapseBus.instance.expand();
          } else {
            TabCollapseBus.instance.onScroll(n.metrics.pixels);
          }
        }
        return false;
      },
      child: RootShell(
        tabs: visibleTabs,
        activeTab: effectiveTab,
        onSelectTab: _onSelectTab,
        onAvatarLongPress: () {
          if (_showAccountTip) setState(() => _showAccountTip = false);
          showAccountSwitcherSheet(context);
        },
        onAvatarDoubleTap: _switchToPreviousAccount,
        sidebarExtra: const _SidebarLibrarySections(),
        accountGestureTip: _showAccountTip
            ? _AccountGestureTipBubble(
                onDismiss: () => setState(() => _showAccountTip = false),
              )
            : null,
        bottomAccessory: showResume
            ? _ResumeAccessoryBar(
                item: resumeItem,
                onPlay: () {
                  context
                      .push(
                        '/player',
                        extra: PlayerPageArgs(
                          mediaItemId: resumeItem.mediaItemId,
                          seasonNumber: resumeItem.isEpisode
                              ? resumeItem.seasonNumber
                              : null,
                          episodeNumber: resumeItem.isEpisode
                              ? resumeItem.episodeNumber
                              : null,
                          title: resumeItem.title,
                          subtitle: resumeItem.isEpisode
                              ? episodeCode(
                                  resumeItem.seasonNumber,
                                  resumeItem.episodeNumber,
                                )
                              : null,
                          startPosition: resumeItem.positionMs > 0
                              ? Duration(milliseconds: resumeItem.positionMs)
                              : null,
                          isEpisode: resumeItem.isEpisode,
                        ),
                      )
                      .then((_) {
                        if (mounted) unawaited(_refreshResume());
                      });
                },
                onLongPress: () => _openResumeLongPressMenu(resumeItem),
                onDismiss: () => unawaited(_dismissResume(resumeItem)),
              )
            : null,
        pages: [for (final t in visibleTabs) _pageFor(t)],
      ),
    );
  }
}

/// 首次多账号手势液态玻璃提示气泡（对齐 iOS `AccountGestureTipBubble`）。
class _AccountGestureTipBubble extends StatelessWidget {
  const _AccountGestureTipBubble({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: McLiquidGlass(
        radius: 18,
        blurSigma: 22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  McIcons.userSwitch,
                  size: 14,
                  color: McTokens.accentStrong,
                ),
                const SizedBox(width: 7),
                Text(
                  '长按头像切换账号',
                  style: McText.caption.copyWith(color: McTokens.text),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  McIcons.history1,
                  size: 14,
                  color: McTokens.accentStrong,
                ),
                const SizedBox(width: 7),
                Text(
                  '双击头像切回上一个账号',
                  style: McText.caption.copyWith(color: McTokens.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 平板 / 桌面侧边栏扩展分组（对齐 iOS `PadSidebarLibraryTabs`）：
/// 展示「我的收藏」、可见媒体库列表（带部数）、以及置顶在首页的合集列表（带部数）。
class _SidebarLibrarySections extends ConsumerWidget {
  const _SidebarLibrarySections();

  static IconData _iconForLibraryKind(String kind) => switch (kind) {
        'movie' => McIcons.movie,
        'tv' => McIcons.tv,
        'photo' => McIcons.image,
        _ => McIcons.playCircle,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = McFormWatch.of(context);
    final collapsed = ref.watch(mcSidebarCollapsedProvider);
    final extended =
        (form == McDeviceForm.tv || MediaQuery.widthOf(context) >= 900) &&
            !collapsed;
    if (!extended) return const SizedBox.shrink();

    final home = ref.watch(libraryHomeProvider);
    final libraries = home.visibleLibraries;
    final pinnedCollections = <CollectionView>[];
    final seenCollectionIds = <int>{};
    for (final row in home.rows) {
      final k = row.kind;
      if (k is CollectionRowKind && seenCollectionIds.add(k.collection.id)) {
        pinnedCollections.add(k.collection);
      }
    }

    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Divider(height: 1, color: McTokens.line),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              children: [
                _SidebarNavTile(
                  icon: McIcons.heart2,
                  label: '我的收藏',
                  onTap: () => context.push('/library/favorites'),
                ),
                if (libraries.isNotEmpty) ...[
                  const _SidebarSectionTitle('媒体库'),
                  for (final lib in libraries)
                    _SidebarNavTile(
                      icon: _iconForLibraryKind(lib.kind),
                      label: lib.name,
                      count: lib.stats.itemCount,
                      onTap: () => context.push('/library/detail/${lib.id}'),
                    ),
                ],
                if (pinnedCollections.isNotEmpty) ...[
                  const _SidebarSectionTitle('合集'),
                  for (final col in pinnedCollections)
                    _SidebarNavTile(
                      icon: McIcons.stack,
                      label: col.name,
                      count: col.itemCount,
                      onTap: () =>
                          context.push('/library/collection/${col.id}'),
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

class _SidebarSectionTitle extends StatelessWidget {
  const _SidebarSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        text,
        style: McText.micro.copyWith(
          color: McTokens.textFaint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  const _SidebarNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return McFocusRing(
      borderRadius: 12,
      child: McPressable(
        onTap: onTap,
        scaleDown: 0.985,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: McTokens.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(color: McTokens.textMuted),
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: McText.micro.copyWith(color: McTokens.textFaint).tabular,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃「接着看」底部附件条（1:1 复刻 iOS `ResumeAccessory.swift`）。
class _ResumeAccessoryBar extends StatelessWidget {
  const _ResumeAccessoryBar({
    required this.item,
    required this.onPlay,
    required this.onLongPress,
    required this.onDismiss,
  });

  final UpNextItem item;
  final VoidCallback onPlay;
  final VoidCallback onLongPress;
  final VoidCallback onDismiss;

  String get _detailLine {
    final parts = <String>[];
    if (item.isEpisode) {
      parts.add(episodeCode(item.seasonNumber, item.episodeNumber));
    }
    final pct = item.progressPercent;
    if (item.positionMs > 0 && pct != null && pct > 0) {
      parts.add('看到 ${pct.round().clamp(1, 99)}%');
    } else if (item.advanced) {
      parts.add('下一集');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = McImageUrls.resolve(
      item.episodeStillUrl ?? item.backdropUrl ?? item.posterUrl,
      widthPx: 200,
    );
    return McLiquidGlass(
      radius: McTokens.pillRadius,
      blurSigma: 22,
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      child: Row(
        children: [
          Expanded(
            child: McPressable(
              onTap: onPlay,
              onLongPress: onLongPress,
              scaleDown: 0.985,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      width: 50,
                      height: 29,
                      color: McTokens.posterPlaceholder,
                      child: thumbUrl.isEmpty
                          ? const Icon(
                              McIcons.film,
                              size: 14,
                              color: McTokens.textFaint,
                            )
                          : CachedNetworkImage(
                              imageUrl: thumbUrl,
                              httpHeaders: mcImageHeaders(),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.sub.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (_detailLine.isNotEmpty)
                          Text(
                            _detailLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.micro.copyWith(
                              color: McTokens.textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      McIcons.playFill,
                      size: 16,
                      color: McTokens.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          McPressable(
            onTap: onDismiss,
            haptic: true,
            child: const SizedBox(
              width: 32,
              height: 30,
              child: Icon(
                McIcons.close,
                size: 14,
                color: McTokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
