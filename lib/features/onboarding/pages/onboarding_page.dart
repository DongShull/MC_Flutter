import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_store.dart';
import '../state/onboarding_controller.dart';
import '../state/server_discovery.dart';
import 'qr_scan_page.dart';

class _WelcomeQuote {
  const _WelcomeQuote({
    required this.line,
    required this.original,
    required this.english,
    required this.film,
    required this.filmEnglish,
    required this.year,
  });

  final String line;
  final String original;
  final String english;
  final String film;
  final String filmEnglish;
  final int year;

  String headline(bool isChinese) {
    if (isChinese) return line;
    if (original.isNotEmpty) return original;
    if (english.isNotEmpty) return english;
    return line;
  }

  String? subline(bool isChinese) {
    if (isChinese) return original.isEmpty ? null : original;
    return original.isEmpty ? line : null;
  }

  String source(bool isChinese) {
    if (isChinese) {
      return year > 0 ? '——《$film》· $year' : '——《$film》';
    }
    final name = filmEnglish.isNotEmpty ? filmEnglish : film;
    return year > 0 ? '— $name, $year' : '— $name';
  }
}

const _fallbackQuotes = <_WelcomeQuote>[
  _WelcomeQuote(
    line: '不要温和地走进那个良夜。',
    original: 'Do not go gentle into that good night.',
    english: '',
    film: '星际穿越',
    filmEnglish: 'Interstellar',
    year: 2014,
  ),
  _WelcomeQuote(
    line: '毕竟，明天又是新的一天。',
    original: 'After all, tomorrow is another day.',
    english: '',
    film: '乱世佳人',
    filmEnglish: 'Gone with the Wind',
    year: 1939,
  ),
  _WelcomeQuote(
    line: '所有那些时刻，终将流失在时间里，一如眼泪消失在雨中。',
    original: 'All those moments will be lost in time, like tears in rain.',
    english: '',
    film: '银翼杀手',
    filmEnglish: 'Blade Runner',
    year: 1982,
  ),
  _WelcomeQuote(
    line: '愿原力与你同在。',
    original: 'May the Force be with you.',
    english: '',
    film: '星球大战',
    filmEnglish: 'Star Wars',
    year: 1977,
  ),
  _WelcomeQuote(
    line: '生活就像一盒巧克力，你永远不知道下一颗是什么味道。',
    original:
        "Life was like a box of chocolates. You never know what you're gonna get.",
    english: '',
    film: '阿甘正传',
    filmEnglish: 'Forrest Gump',
    year: 1994,
  ),
];

enum _DiscoveryStatus { idle, searching, found, notFound }

class _SavedChooserAccount {
  const _SavedChooserAccount({
    required this.origin,
    required this.username,
    required this.nickname,
    this.avatarUrl,
  });

  final String origin;
  final String username;
  final String nickname;
  final String? avatarUrl;

  String get id => '$origin#$username';
  String get hostLabel => ServerRoutes.hostLabelOf(origin);
}

/// 星空电影欢迎与服务器接入页（1:1 对齐 iOS `WelcomeView.swift` & `WelcomeSignInPanel.swift`）：
/// - 深空缓慢旋转星野 + 流星 + 行星轨道日出大气弧光背景（`McCosmosBackdrop`）；
/// - 支持 `?mode=add`、`?mode=relogin`、`?server=`、`?username=` 路由入参；
/// - 承接 `SessionPhase.unreachable`（重试 / 修改服务器 / 切换账号）与 `SessionPhase.chooseAccount`；
/// - 局域网 UDP 7359 单播多轮自动发现（含「重新查找」）、裸主机智能探测与确认密码初始化向导。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({
    super.key,
    this.mode,
    this.prefillServer,
    this.prefillUsername,
  });

  final String? mode;
  final String? prefillServer;
  final String? prefillUsername;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _sheetOpen = false;
  bool _overrideToForm = false;
  bool _overrideToChooser = false;

  _DiscoveryStatus _discovery = _DiscoveryStatus.idle;
  String? _discoveredName;
  String? _discoveredAddress;
  int _discoveryToken = 0;

  List<_WelcomeQuote> _quotes = _fallbackQuotes;
  int _quoteIndex = 0;
  Timer? _quoteTimer;

  List<_SavedChooserAccount> _chooserAccounts = const [];
  String? _switchingAccountId;
  String? _chooserError;
  bool _retryingConnect = false;

  bool get _isAddMode => widget.mode == 'add';
  bool get _isReloginMode => widget.mode == 'relogin';
  bool get _isModalMode => _isAddMode || _isReloginMode;

  @override
  void initState() {
    super.initState();
    _applyPrefill();
    _loadQuotes();
    _startQuoteRotation();
    _loadChooserAccounts();
    appSession.addListener(_onSessionChange);
  }

  @override
  void didUpdateWidget(covariant OnboardingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.prefillServer != widget.prefillServer ||
        oldWidget.prefillUsername != widget.prefillUsername) {
      _applyPrefill();
    }
  }

  @override
  void dispose() {
    appSession.removeListener(_onSessionChange);
    _discoveryToken++;
    _quoteTimer?.cancel();
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onSessionChange() {
    if (!mounted) return;
    if (appSession.phase == SessionPhase.chooseAccount ||
        appSession.phase == SessionPhase.unreachable) {
      _loadChooserAccounts();
    }
    setState(() {});
  }

  void _applyPrefill() {
    final server = (widget.prefillServer ?? '').trim().isNotEmpty
        ? widget.prefillServer!.trim()
        : (_isAddMode || _isReloginMode || appSession.expiredUsername != null
            ? (appSession.baseUrl ?? '')
            : '');
    final user = (widget.prefillUsername ?? '').trim().isNotEmpty
        ? widget.prefillUsername!.trim()
        : (!_isAddMode ? (appSession.expiredUsername ?? '') : '');

    if (server.isNotEmpty) {
      _hostCtrl.text = server;
    }
    if (user.isNotEmpty) {
      _userCtrl.text = user;
    }
    if (_isModalMode || appSession.expiredUsername != null) {
      _sheetOpen = true;
      _overrideToForm = true;
    }
    if (_sheetOpen && _hostCtrl.text.trim().isEmpty) {
      _startLanDiscovery();
    }
  }

  Future<void> _loadChooserAccounts() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      final raw = await storage.read(key: 'mc_servers');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final list = <_SavedChooserAccount>[];
      for (final s in decoded.whereType<Map>()) {
        final origin = SessionStore.normalizeOrigin((s['origin'] ?? '').toString());
        if (origin.isEmpty) continue;
        final accounts = s['accounts'] as List? ?? const [];
        for (final a in accounts.whereType<Map>()) {
          final username = (a['username'] ?? '').toString().trim();
          if (username.isEmpty) continue;
          if (!appSession.hasTokenFor(origin: origin, username: username)) {
            continue;
          }
          final nick = (a['nickname'] ?? '').toString().trim();
          list.add(
            _SavedChooserAccount(
              origin: origin,
              username: username,
              nickname: nick.isNotEmpty ? nick : username,
              avatarUrl: a['avatar_url']?.toString(),
            ),
          );
        }
      }
      if (mounted) {
        setState(() => _chooserAccounts = list);
      }
    } catch (_) {}
  }

  Future<void> _loadQuotes() async {
    try {
      final raw = await rootBundle.loadString('assets/data/welcome_quotes.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final parsed = <_WelcomeQuote>[];
      for (final item in decoded.whereType<Map>()) {
        final line = (item['line'] ?? '').toString().trim();
        final film = (item['film'] ?? '').toString().trim();
        if (line.isEmpty || film.isEmpty) continue;
        parsed.add(
          _WelcomeQuote(
            line: line,
            original: (item['original'] ?? '').toString().trim(),
            english: (item['english'] ?? '').toString().trim(),
            film: film,
            filmEnglish: (item['filmEnglish'] ?? '').toString().trim(),
            year: (item['year'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      if (parsed.isNotEmpty && mounted) {
        setState(() {
          _quotes = parsed;
          _quoteIndex = DateTime.now().second % parsed.length;
        });
      }
    } catch (_) {}
  }

  void _startQuoteRotation() {
    _quoteTimer?.cancel();
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _quoteTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted || _sheetOpen || _quotes.length <= 1) return;
      setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length);
    });
  }

  void _nextQuote() {
    if (_quotes.length <= 1) return;
    HapticFeedback.selectionClick();
    setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length);
    _startQuoteRotation();
  }

  void _openLoginCard({String? server, String? username}) {
    HapticFeedback.lightImpact();
    if (server != null) _hostCtrl.text = server;
    if (username != null) _userCtrl.text = username;
    setState(() {
      _sheetOpen = true;
      _overrideToForm = true;
      _overrideToChooser = false;
    });
    if (_hostCtrl.text.trim().isEmpty) {
      _startLanDiscovery();
    }
  }

  Future<void> _startLanDiscovery({bool manual = false}) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (!manual && _hostCtrl.text.trim().isNotEmpty) return;

    final token = ++_discoveryToken;
    setState(() {
      _discovery = _DiscoveryStatus.searching;
      _discoveredName = null;
      _discoveredAddress = null;
    });

    final found = await ServerDiscovery.findFirst(
      rounds: manual ? 4 : 6,
      interval: const Duration(milliseconds: 1500),
      isCancelled: () => !mounted || token != _discoveryToken,
    );
    if (!mounted || token != _discoveryToken) return;

    if (!manual && _hostCtrl.text.trim().isNotEmpty) {
      setState(() => _discovery = _DiscoveryStatus.idle);
      return;
    }
    if (found == null) {
      setState(() => _discovery = _DiscoveryStatus.notFound);
      return;
    }
    setState(() {
      _hostCtrl.text = found.origin;
      _discoveredName = found.name;
      _discoveredAddress = found.origin;
      _discovery = _DiscoveryStatus.found;
    });
  }

  Future<void> _scanConnect() async {
    final host = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (host != null && host.isNotEmpty && mounted) {
      ref.read(onboardingProvider.notifier).resetNeedsInit();
      setState(() {
        _sheetOpen = true;
        _overrideToForm = true;
        _hostCtrl.text = host;
      });
    }
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final st = ref.read(onboardingProvider);
    if (st.needsInit) {
      await ref.read(onboardingProvider.notifier).bootstrapAndLogin(
            _hostCtrl.text.trim(),
            _userCtrl.text.trim(),
            _passCtrl.text,
            confirmPassword: _confirmCtrl.text,
          );
      return;
    }
    await ref
        .read(onboardingProvider.notifier)
        .login(_hostCtrl.text.trim(), _userCtrl.text.trim(), _passCtrl.text);
  }

  void _closeModalOrSheet() {
    FocusScope.of(context).unfocus();
    if (_isModalMode) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }
    setState(() {
      _sheetOpen = false;
      _overrideToForm = false;
    });
  }

  Future<void> _pickChooserAccount(_SavedChooserAccount acct) async {
    if (_switchingAccountId != null) return;
    setState(() {
      _switchingAccountId = acct.id;
      _chooserError = null;
    });
    final ok = await appSession.switchAccount(
      origin: acct.origin,
      username: acct.username,
    );
    if (!mounted) return;
    setState(() => _switchingAccountId = null);
    if (ok) {
      context.go('/home');
    } else {
      _openLoginCard(server: acct.origin, username: acct.username);
    }
  }

  Future<void> _retryUnreachable() async {
    if (_retryingConnect) return;
    setState(() => _retryingConnect = true);
    final ok = await ref.read(onboardingProvider.notifier).reconnect();
    if (!mounted) return;
    setState(() => _retryingConnect = false);
    if (ok) {
      context.go('/home');
    } else {
      McToast.error('仍无法连接到服务器，请检查网络或地址');
    }
  }

  String get _sheetTitle {
    final st = ref.read(onboardingProvider);
    if (st.needsInit) return '初始化服务器';
    if (_isAddMode) return '添加账号';
    if (_isReloginMode || appSession.expiredUsername != null) return '重新登录';
    return '连接服务器';
  }

  String get _sheetSubtitle {
    final st = ref.read(onboardingProvider);
    if (st.needsInit) return '这台服务器还未创建管理员，请确认密码完成初始化';
    if (_isAddMode) return '可登录当前服务器的另一个账号，或修改地址连接到新服务器';
    if (_isReloginMode || appSession.expiredUsername != null) {
      final user = _userCtrl.text.trim();
      return user.isEmpty ? '登录已过期，请重新输入密码' : '「$user」的登录已过期，请重新输入密码';
    }
    return '输入你的 MovieClaw 媒体服务器地址与账号';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final l10n = McL10n.of(context);

    ref.listen<OnboardingState>(onboardingProvider, (prev, next) {
      if (next.done && (prev?.done != true)) {
        ref.read(onboardingProvider.notifier).resetDone();
        if (_isModalMode && context.canPop()) {
          context.pop(true);
        } else {
          context.go('/home');
        }
      }
      if (next.resolvedHost != null &&
          next.resolvedHost != prev?.resolvedHost &&
          next.resolvedHost!.isNotEmpty) {
        _hostCtrl.text = next.resolvedHost!;
      }
      if ((next.error != null && next.error != prev?.error) ||
          (next.needsInit && prev?.needsInit != true)) {
        if (!_sheetOpen) setState(() => _sheetOpen = true);
      }
    });

    final form = McFormWatch.of(context);
    final cardMaxWidth =
        mcWindowClassOf(form) == McWindowClass.compact ? 440.0 : 480.0;
    final kbHeight = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kbHeight > 80;
    final quote = _quotes[_quoteIndex % _quotes.length];

    final showUnreachable = !_isModalMode &&
        !_overrideToForm &&
        !_overrideToChooser &&
        appSession.phase == SessionPhase.unreachable;
    final showChooser = !_isModalMode &&
        !_overrideToForm &&
        (_overrideToChooser ||
            (appSession.phase == SessionPhase.chooseAccount &&
                _chooserAccounts.isNotEmpty));

    final showHomeStage = !_sheetOpen && !showUnreachable && !showChooser;

    return Scaffold(
      backgroundColor: McTokens.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const McCosmosBackdrop(),

          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            color: !showHomeStage
                ? const Color(0x78000000)
                : const Color(0x00000000),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SizedBox(height: keyboardOpen ? 16 : 48),
                  AnimatedOpacity(
                    opacity: keyboardOpen ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    child: const McBrandMark(size: 36, showWordmark: true),
                  ),
                  const Spacer(),
                  if (showHomeStage)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _nextQuote,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Column(
                            key: ValueKey('$_quoteIndex-${l10n.isChinese}'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.isChinese
                                    ? '“${quote.headline(true)}”'
                                    : '“${quote.headline(false)}”',
                                textAlign: TextAlign.center,
                                style: McText.welcomeSerif(
                                  size: 22,
                                  color: McTokens.text,
                                  height: 1.55,
                                ),
                              ),
                              if (quote.subline(l10n.isChinese) != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  quote.subline(l10n.isChinese)!,
                                  textAlign: TextAlign.center,
                                  style: McText.sub.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: McTokens.textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Text(
                                quote.source(l10n.isChinese),
                                style: McText.caption.faint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (showHomeStage) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: McFocusRing(
                        borderRadius: McTokens.pillRadius,
                        child: McActionPill(
                          label: _hostCtrl.text.trim().isNotEmpty
                              ? '登录'
                              : '连接服务器',
                          primary: true,
                          expanded: true,
                          height: 46,
                          onTap: () => _openLoginCard(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    McPressable(
                      onTap: mcIsDesktopPlatform()
                          ? () => _openLoginCard()
                          : _scanConnect,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              mcIsDesktopPlatform()
                                  ? McIcons.device
                                  : McIcons.scan,
                              size: 15,
                              color: McTokens.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mcIsDesktopPlatform() ? '配对码快速接入' : '扫码快速接入',
                              style: McText.caption.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ),

          // 底部卡片层：服务器不可达卡 / 账号选择卡 / 登录与初始化表单卡
          if (showUnreachable)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  math.max(20.0, MediaQuery.paddingOf(context).bottom + 12),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardMaxWidth),
                  child: _buildUnreachableCard(),
                ),
              ),
            )
          else if (showChooser)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  math.max(20.0, MediaQuery.paddingOf(context).bottom + 12),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardMaxWidth),
                  child: _buildAccountChooserCard(),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                offset: _sheetOpen ? Offset.zero : const Offset(0, 1.25),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: IgnorePointer(
                  ignoring: !_sheetOpen,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      math.max(16.0, kbHeight + 12),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardMaxWidth),
                      child: _buildLoginSheet(state),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnreachableCard() {
    final origin = appSession.baseUrl ?? '';
    return _glassCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('暂时连不上服务器', style: McText.title),
          const SizedBox(height: 4),
          Text(
            '你的登录凭证仍然保存在本机，服务器恢复后点「重试」即可直接进入。',
            style: McText.caption.muted,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: McTokens.line),
            ),
            child: Row(
              children: [
                const Icon(McIcons.server, size: 18, color: McTokens.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    origin.isEmpty ? '未配置服务器' : origin,
                    style: McText.sub.copyWith(color: McTokens.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          McActionPill(
            label: _retryingConnect ? '正在连接…' : '重试',
            primary: true,
            expanded: true,
            height: 44,
            busy: _retryingConnect,
            onTap: _retryingConnect ? null : _retryUnreachable,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '修改服务器',
                  primary: false,
                  expanded: true,
                  onTap: () => _openLoginCard(server: origin),
                ),
              ),
              if (_chooserAccounts.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: McActionPill(
                    label: '切换其他账号',
                    primary: false,
                    expanded: true,
                    onTap: () => setState(() => _overrideToChooser = true),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountChooserCard() {
    return _glassCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('选择账号', style: McText.title),
          const SizedBox(height: 4),
          Text('本机还有其他已保存的账号，轻点即可直接进入。', style: McText.caption.muted),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  for (final acct in _chooserAccounts)
                    McPressable(
                      onTap: _switchingAccountId == null
                          ? () => _pickChooserAccount(acct)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            _ChooserAvatar(acct: acct),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(acct.nickname, style: McText.ui.semibold),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${acct.username} · ${acct.hostLabel}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: McText.caption.muted,
                                  ),
                                ],
                              ),
                            ),
                            if (_switchingAccountId == acct.id)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: McTokens.accentStrong,
                                ),
                              )
                            else
                              const Icon(
                                McIcons.chevronRight,
                                size: 16,
                                color: McTokens.textFaint,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_chooserError != null) ...[
            const SizedBox(height: 10),
            Text(
              _chooserError!,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ],
          const SizedBox(height: 14),
          McActionPill(
            label: '登录其他账号',
            primary: false,
            expanded: true,
            height: 44,
            onTap: () => _openLoginCard(),
          ),
        ],
      ),
    );
  }

  Widget _glassCardShell({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(McTokens.sheetRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEB151821),
            borderRadius: BorderRadius.circular(McTokens.sheetRadius),
            border: Border.all(color: McTokens.lineStrong, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 36,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoveryStatus() {
    switch (_discovery) {
      case _DiscoveryStatus.searching when _hostCtrl.text.trim().isEmpty:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: McTokens.accentStrong,
                ),
              ),
              const SizedBox(width: 8),
              Text('正在局域网查找 MovieClaw 服务器…', style: McText.caption.muted),
            ],
          ),
        );
      case _DiscoveryStatus.found
          when _discoveredAddress != null &&
              _discoveredAddress == _hostCtrl.text.trim():
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const Icon(
                McIcons.checkCircleFill,
                size: 14,
                color: McTokens.ok,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '已自动发现并填入 ${_discoveredName ?? 'MovieClaw'}',
                  style: McText.caption.copyWith(color: McTokens.ok),
                ),
              ),
            ],
          ),
        );
      case _DiscoveryStatus.notFound when _hostCtrl.text.trim().isEmpty:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Text('未在局域网发现服务器，可手动输入或 ', style: McText.caption.muted),
              McPressable(
                onTap: () => _startLanDiscovery(manual: true),
                child: Text(
                  '重新查找',
                  style: McText.caption.copyWith(
                    color: McTokens.accentStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLoginSheet(OnboardingState state) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEB151821),
        borderRadius: BorderRadius.circular(McTokens.sheetRadius),
        border: Border.all(color: McTokens.lineStrong, width: 1),
        boxShadow: _sheetOpen
            ? const [
                BoxShadow(
                  color: Color(0xCC000000),
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ]
            : const [],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_sheetTitle, style: McText.title),
                      const SizedBox(height: 2),
                      Text(_sheetSubtitle, style: McText.caption.muted),
                    ],
                  ),
                ),
                if (!mcIsDesktopPlatform()) ...[
                  McGlassIconButton(
                    icon: McIcons.scan,
                    size: 36,
                    iconSize: 17,
                    tooltip: '扫码填入地址',
                    onTap: state.busy ? null : _scanConnect,
                  ),
                  const SizedBox(width: 8),
                ],
                McGlassIconButton(
                  icon: McIcons.close,
                  size: 36,
                  iconSize: 17,
                  tooltip: _isModalMode ? '关闭' : '收起',
                  onTap: state.busy ? null : _closeModalOrSheet,
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _hostCtrl,
              keyboardType: TextInputType.url,
              enabled: !state.busy,
              style: McText.body,
              onChanged: (_) {
                ref.read(onboardingProvider.notifier).resetNeedsInit();
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://media.example.com 或 192.168.1.10',
                prefixIcon: const Icon(McIcons.server, size: 18),
                suffixIcon: _hostCtrl.text.isNotEmpty && !state.busy
                    ? IconButton(
                        icon: const Icon(McIcons.close, size: 16),
                        tooltip: '清空服务器地址',
                        onPressed: () {
                          _hostCtrl.clear();
                          ref
                              .read(onboardingProvider.notifier)
                              .resetNeedsInit();
                          setState(() {
                            _discovery = _DiscoveryStatus.idle;
                            _discoveredAddress = null;
                          });
                        },
                      )
                    : null,
              ),
            ),
            _buildDiscoveryStatus(),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              enabled: !state.busy,
              style: McText.body,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(
                labelText: state.needsInit ? '管理员账号（至少 3 位）' : '账号',
                prefixIcon: const Icon(McIcons.user, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              enabled: !state.busy,
              obscureText: _obscure,
              style: McText.body,
              autofillHints: [
                state.needsInit
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              onSubmitted: (_) {
                if (!state.needsInit) _connect();
              },
              decoration: InputDecoration(
                labelText: state.needsInit ? '密码（至少 8 位）' : '密码',
                prefixIcon: const Icon(McIcons.lock, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? McIcons.eyeOff : McIcons.eyeOpen,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (state.needsInit) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                enabled: !state.busy,
                obscureText: _obscureConfirm,
                style: McText.body,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _connect(),
                decoration: InputDecoration(
                  labelText: '确认密码',
                  prefixIcon: const Icon(McIcons.lock, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? McIcons.eyeOff : McIcons.eyeOpen,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x1FF5C451),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x4DF5C451)),
                ),
                child: Text(
                  '检测到全新未初始化服务器：账号至少 3 位，密码至少 8 位，确认密码一致后即可创建超级管理员并进入。',
                  style: McText.caption.copyWith(color: McTokens.warning),
                ),
              ),
            ],
            if (state.pairingUserCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: McTokens.surfaceInset,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: McTokens.lineStrong),
                ),
                child: Column(
                  children: [
                    Text(
                      '在已登录手机的「我的 → 右上角扫码/配对」中输入：',
                      textAlign: TextAlign.center,
                      style: McText.caption.muted,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      state.pairingUserCode!,
                      style: McText.display.tabular.copyWith(
                        letterSpacing: 3,
                        color: McTokens.accentStrong,
                      ),
                    ),
                    const SizedBox(height: 8),
                    McChip(
                      label: '取消配对码等待',
                      compact: true,
                      onTap: () => ref
                          .read(onboardingProvider.notifier)
                          .cancelDevicePairing(),
                    ),
                  ],
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: McText.caption.copyWith(color: McTokens.danger),
              ),
            ],
            const SizedBox(height: 18),
            McFocusRing(
              borderRadius: McTokens.pillRadius,
              child: McActionPill(
                label: state.busy
                    ? '正在连接…'
                    : (state.needsInit ? '初始化服务器并创建超管' : '连接'),
                primary: true,
                expanded: true,
                height: 44,
                busy: state.busy,
                onTap: state.busy ? null : _connect,
              ),
            ),
            if (!_isModalMode && _chooserAccounts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Center(
                child: McPressable(
                  onTap: () => setState(() {
                    _overrideToForm = false;
                    _overrideToChooser = true;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '切换到其他已保存账号',
                      style: McText.caption.copyWith(
                        color: McTokens.accentStrong,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (state.pairingUserCode == null && !state.needsInit) ...[
              const SizedBox(height: 8),
              Center(
                child: McPressable(
                  onTap: state.busy
                      ? null
                      : () => ref
                          .read(onboardingProvider.notifier)
                          .startDevicePairing(_hostCtrl.text.trim()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '使用手机配对码免密登录',
                      style: McText.caption.muted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (!_sheetOpen) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(McTokens.sheetRadius),
        child: content,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(McTokens.sheetRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: content,
      ),
    );
  }
}

class _ChooserAvatar extends StatelessWidget {
  const _ChooserAvatar({required this.acct});

  final _SavedChooserAccount acct;

  @override
  Widget build(BuildContext context) {
    final initials = McPermissions.avatarInitials(acct.nickname);
    final url = acct.avatarUrl != null && acct.avatarUrl!.isNotEmpty
        ? McImageUrls.resolve(
            McImageUrls.tagAccount(acct.avatarUrl, acct.username),
            widthPx: 96,
            baseUrl: acct.origin,
          )
        : '';
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF3E6DA8), Color(0xFF6B53A8)],
        ),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            initials,
            style: McText.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (url.isNotEmpty)
            Positioned.fill(
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: url,
                  httpHeaders: mcImageHeadersFor(
                    origin: acct.origin,
                    username: acct.username,
                  ),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Meteor {
  const _Meteor({
    required this.startX,
    required this.startY,
    required this.angleRad,
    required this.travel,
    required this.length,
    required this.brightness,
  });

  final double startX;
  final double startY;
  final double angleRad;
  final double travel;
  final double length;
  final double brightness;

  static _Meteor random(math.Random rng) {
    final toRight = rng.nextBool();
    final bright = rng.nextDouble() < 0.18;
    final deg = toRight
        ? (22 + rng.nextDouble() * 18)
        : (140 + rng.nextDouble() * 18);
    return _Meteor(
      startX: toRight
          ? (0.05 + rng.nextDouble() * 0.45)
          : (0.50 + rng.nextDouble() * 0.45),
      startY: 0.04 + rng.nextDouble() * 0.34,
      angleRad: deg * math.pi / 180.0,
      travel: 0.28 + rng.nextDouble() * 0.20,
      length: 70 + rng.nextDouble() * 70,
      brightness: bright ? 1.0 : (0.5 + rng.nextDouble() * 0.3),
    );
  }
}

/// 深空缓慢旋转星野 + 偶发流星 + 行星轨道日出大气弧光背景（对齐 iOS `CosmosBackdrop.swift`）。
/// 遵循系统「减弱动态效果」（`disableAnimations`）与测试环境零无限动画原则。
class McCosmosBackdrop extends StatefulWidget {
  const McCosmosBackdrop({super.key});

  @override
  State<McCosmosBackdrop> createState() => _McCosmosBackdropState();
}

class _McCosmosBackdropState extends State<McCosmosBackdrop>
    with TickerProviderStateMixin {
  AnimationController? _spinCtrl;
  AnimationController? _meteorCtrl;
  Timer? _meteorSchedule;
  _Meteor? _activeMeteor;
  final math.Random _rng = math.Random();
  bool _animActive = false;

  bool get _isTestEnv => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowAnim = !_isTestEnv && !MediaQuery.disableAnimationsOf(context);
    if (allowAnim && !_animActive) {
      _startAnimations();
    } else if (!allowAnim && _animActive) {
      _stopAnimations();
    }
  }

  void _startAnimations() {
    _animActive = true;
    _spinCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2400),
    )..repeat();

    _meteorCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _activeMeteor = null);
          _scheduleNextMeteor(7 + _rng.nextInt(11));
        }
      });

    _scheduleNextMeteor(4 + _rng.nextInt(5));
  }

  void _scheduleNextMeteor(int seconds) {
    _meteorSchedule?.cancel();
    if (!_animActive) return;
    _meteorSchedule = Timer(Duration(seconds: seconds), () {
      if (!mounted || !_animActive) return;
      setState(() => _activeMeteor = _Meteor.random(_rng));
      _meteorCtrl?.forward(from: 0);
    });
  }

  void _stopAnimations() {
    _animActive = false;
    _meteorSchedule?.cancel();
    _meteorSchedule = null;
    _spinCtrl?.stop();
    _meteorCtrl?.stop();
    _activeMeteor = null;
  }

  @override
  void dispose() {
    _meteorSchedule?.cancel();
    _spinCtrl?.dispose();
    _meteorCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spin = _spinCtrl;
    final meteor = _meteorCtrl;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (spin != null && _animActive)
            AnimatedBuilder(
              animation: spin,
              builder: (_, __) => CustomPaint(
                painter: _StarfieldPainter(angleRad: spin.value * 2 * math.pi),
                child: const SizedBox.expand(),
              ),
            )
          else
            const CustomPaint(
              painter: _StarfieldPainter(angleRad: 0),
              child: SizedBox.expand(),
            ),
          if (_activeMeteor != null && meteor != null)
            AnimatedBuilder(
              animation: meteor,
              builder: (_, __) => CustomPaint(
                painter: _MeteorPainter(
                  meteor: _activeMeteor!,
                  linearProgress: meteor.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          const CustomPaint(
            painter: _PlanetHorizonPainter(),
            child: SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter({required this.angleRad});

  final double angleRad;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = McTokens.bg);

    final nebula = const RadialGradient(
      center: Alignment(0.0, -0.55),
      radius: 0.95,
      colors: [
        Color(0x24162238),
        Color(0x0D0D1424),
        Color(0x00000000),
      ],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = nebula);

    canvas.save();
    final cx = size.width * 0.5;
    final cy = size.height * 0.45;
    canvas.translate(cx, cy);
    canvas.rotate(angleRad);
    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    final half = diag * 0.55;

    final rng = math.Random(19690720);
    final starPaint = Paint()..style = PaintingStyle.fill;
    const starCount = 180;
    for (var i = 0; i < starCount; i++) {
      final x = (rng.nextDouble() * 2 - 1) * half;
      final y = (rng.nextDouble() * 2 - 1) * half;
      final mag = math.pow(rng.nextDouble(), 2.8).toDouble();
      final radius = 0.45 + mag * 1.35;
      final alpha = (0.14 + mag * 0.76).clamp(0.0, 0.92);
      final tint = i % 9 == 0
          ? const Color(0xFFD6E6FF)
          : (i % 13 == 0 ? const Color(0xFFFFECD6) : Colors.white);
      starPaint.color = tint.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      (oldDelegate.angleRad - angleRad).abs() > 0.0002;
}

class _MeteorPainter extends CustomPainter {
  const _MeteorPainter({required this.meteor, required this.linearProgress});

  final _Meteor meteor;
  final double linearProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = linearProgress * linearProgress;
    final glow = math.sin(math.pi * math.pow(progress, 0.7));
    if (glow <= 0.01) return;

    final dx = math.cos(meteor.angleRad);
    final dy = math.sin(meteor.angleRad);
    final dist = meteor.travel * size.width * progress;
    final head = Offset(
      meteor.startX * size.width + dx * dist,
      meteor.startY * size.height + dy * dist,
    );
    final tailLen = meteor.length * (0.3 + 0.7 * glow);
    final tail = Offset(head.dx - dx * tailLen, head.dy - dy * tailLen);
    final alpha = (meteor.brightness * glow).clamp(0.0, 1.0);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = meteor.brightness > 0.9 ? 1.6 : 1.1
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          const Color(0xFFE6F0FF).withValues(alpha: 0.85 * alpha),
        ],
      ).createShader(Rect.fromPoints(tail, head));

    canvas.drawLine(tail, head, linePaint);
    canvas.drawCircle(
      head,
      1.1,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _MeteorPainter oldDelegate) =>
      oldDelegate.linearProgress != linearProgress ||
      oldDelegate.meteor != meteor;
}

class _PlanetHorizonPainter extends CustomPainter {
  const _PlanetHorizonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final planetRadius = math.max(size.width * 1.45, 620.0);
    final planetCenter = Offset(
      size.width * 0.5,
      size.height * 0.90 + planetRadius,
    );

    final outerRadius = planetRadius + 56.0;
    final innerStop = ((planetRadius - 6.0) / outerRadius).clamp(0.0, 0.99);
    final peakStop =
        ((planetRadius + 8.0) / outerRadius).clamp(innerStop, 0.995);
    final haloRect = Rect.fromCircle(center: planetCenter, radius: outerRadius);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x00000000),
          Color(0x426BA2FF),
          Color(0x1C4C8DFF),
          Color(0x00000000),
        ],
        stops: [
          innerStop,
          peakStop,
          (peakStop + 0.018).clamp(0.0, 1.0),
          1.0,
        ],
      ).createShader(haloRect);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.65, size.width, size.height * 0.35),
      glowPaint,
    );

    canvas.drawCircle(
      planetCenter,
      planetRadius,
      Paint()..color = const Color(0xFF030407),
    );

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = const LinearGradient(
        colors: [
          Color(0x00FFFFFF),
          Color(0x667FB0FF),
          Color(0xB8EEF2F8),
          Color(0x667FB0FF),
          Color(0x00FFFFFF),
        ],
        stops: [0.08, 0.34, 0.5, 0.66, 0.92],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.75, size.width, size.height * 0.25),
      );
    canvas.drawCircle(planetCenter, planetRadius, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _PlanetHorizonPainter oldDelegate) => false;
}
