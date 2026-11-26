import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../routes.dart' as feat_onboarding;
import '../state/onboarding_controller.dart';
import 'qr_scan_page.dart';

class _WelcomeQuote {
  const _WelcomeQuote({
    required this.line,
    required this.original,
    required this.film,
    required this.year,
  });

  final String line;
  final String original;
  final String film;
  final int year;
}

const _fallbackQuotes = <_WelcomeQuote>[
  _WelcomeQuote(
    line: '不要温和地走进那个良夜。',
    original: 'Do not go gentle into that good night.',
    film: '星际穿越',
    year: 2014,
  ),
  _WelcomeQuote(
    line: '毕竟，明天又是新的一天。',
    original: 'After all, tomorrow is another day.',
    film: '乱世佳人',
    year: 1939,
  ),
  _WelcomeQuote(
    line: '所有那些时刻，终将流失在时间里，一如眼泪消失在雨中。',
    original: 'All those moments will be lost in time, like tears in rain.',
    film: '银翼杀手',
    year: 1982,
  ),
  _WelcomeQuote(
    line: '愿原力与你同在。',
    original: 'May the Force be with you.',
    film: '星球大战',
    year: 1977,
  ),
  _WelcomeQuote(
    line: '生活就像一盒巧克力，你永远不知道下一颗是什么味道。',
    original:
        'Life was like a box of chocolates. You never know what you\'re gonna get.',
    film: '阿甘正传',
    year: 1994,
  ),
];

/// 星空电影欢迎与服务器接入页（1:1 对齐 iOS `WelcomeView.swift` & Web 欢迎页）：
/// - 深空星点 + 行星日出大气弧线背景（`McCosmosBackdrop`）
/// - 上方 A9 极光标志 + `MovieClaw` 字标；中部 `WelcomeSerif` 宋体轮换经典电影台词
/// - 点击底部「连接服务器」升起圆角液态毛玻璃登录面板（含局域网 UDP 7359 自动发现与扫码连接）
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _sheetOpen = false;
  String? _lanHint;
  List<_WelcomeQuote> _quotes = _fallbackQuotes;
  int _quoteIndex = 0;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
    _startQuoteRotation();
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
            film: film,
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

  void _openLoginCard() {
    HapticFeedback.lightImpact();
    setState(() => _sheetOpen = true);
    _probeLanServer();
  }

  /// 局域网 UDP 7359 广播自动探测（不阻塞 UI，沙盒或无网环境静默跳过）。
  Future<void> _probeLanServer() async {
    if (_hostCtrl.text.trim().isNotEmpty) return;
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final payload = utf8.encode('who is MediaServer?');
      socket.send(payload, InternetAddress('255.255.255.255'), 7359);

      final completer = Completer<String?>();
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket?.receive();
        if (dg == null) return;
        try {
          final text = utf8.decode(dg.data, allowMalformed: true);
          final json = jsonDecode(text);
          if (json is Map) {
            final addr = (json['Address'] ?? json['address'] ?? '').toString();
            if (addr.isNotEmpty && !completer.isCompleted) {
              completer.complete(addr);
              return;
            }
          }
        } catch (_) {}
        final fallbackIp = dg.address.address;
        if (fallbackIp.isNotEmpty && !completer.isCompleted) {
          completer.complete('http://$fallbackIp:8096');
        }
      });

      final found = await completer.future.timeout(
        const Duration(milliseconds: 1400),
        onTimeout: () => null,
      );
      await sub.cancel();
      if (found != null && mounted && _hostCtrl.text.trim().isEmpty) {
        setState(() {
          _hostCtrl.text = found;
          _lanHint = '已自动发现局域网服务器';
        });
      }
    } catch (_) {
      // 权限或网络不支持广播时静默忽略
    } finally {
      socket?.close();
    }
  }

  Future<void> _scanConnect() async {
    final host = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (host != null && host.isNotEmpty && mounted) {
      setState(() {
        _sheetOpen = true;
        _hostCtrl.text = host;
      });
    }
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(onboardingProvider.notifier)
        .login(_hostCtrl.text.trim(), _userCtrl.text.trim(), _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    ref.listen<OnboardingState>(onboardingProvider, (prev, next) {
      if (next.done && (prev?.done != true)) {
        context.go(feat_onboarding.routeOnboarding);
      }
      if (next.error != null && next.error != prev?.error && !_sheetOpen) {
        setState(() => _sheetOpen = true);
      }
    });

    final form = McFormWatch.of(context);
    final cardMaxWidth =
        mcWindowClassOf(form) == McWindowClass.compact ? 440.0 : 480.0;
    final kbHeight = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kbHeight > 80;
    final quote = _quotes[_quoteIndex % _quotes.length];

    return Scaffold(
      backgroundColor: McTokens.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 深空星野与行星日出弧光
          const McCosmosBackdrop(),

          // 打开登录面板时背景轻度压暗聚焦
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            color: _sheetOpen
                ? const Color(0x78000000)
                : const Color(0x00000000),
          ),

          // 舞台主视觉（品牌字标 + 电影台词 + 连接按钮）
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
                  if (!_sheetOpen)
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
                            key: ValueKey(_quoteIndex),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '“${quote.line}”',
                                textAlign: TextAlign.center,
                                style: McText.welcomeSerif(
                                  size: 22,
                                  color: McTokens.text,
                                  height: 1.55,
                                ),
                              ),
                              if (quote.original.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  quote.original,
                                  textAlign: TextAlign.center,
                                  style: McText.sub.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: McTokens.textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Text(
                                quote.year > 0
                                    ? '——《${quote.film}》· ${quote.year}'
                                    : '——《${quote.film}》',
                                style: McText.caption.faint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (!_sheetOpen) ...[
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
                          onTap: _openLoginCard,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    McPressable(
                      onTap: _scanConnect,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              McIcons.scan,
                              size: 15,
                              color: McTokens.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text('扫码快速接入', style: McText.caption.muted),
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

          // 底部升起的圆角液态毛玻璃登录卡
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: _sheetOpen ? Offset.zero : const Offset(0, 1.12),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _sheetOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
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
          ),
        ],
      ),
    );
  }

  Widget _buildLoginSheet(OnboardingState state) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('连接服务器', style: McText.title),
                          SizedBox(height: 2),
                          Text(
                            '输入你的 MovieClaw 媒体服务器地址与账号',
                            style: McText.caption,
                          ),
                        ],
                      ),
                    ),
                    McGlassIconButton(
                      icon: McIcons.scan,
                      size: 36,
                      iconSize: 17,
                      tooltip: '扫码填入地址',
                      onTap: state.busy ? null : _scanConnect,
                    ),
                    const SizedBox(width: 8),
                    McGlassIconButton(
                      icon: McIcons.close2,
                      size: 36,
                      iconSize: 17,
                      tooltip: '收起',
                      onTap: state.busy
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              setState(() => _sheetOpen = false);
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _hostCtrl,
                  keyboardType: TextInputType.url,
                  enabled: !state.busy,
                  style: McText.body,
                  decoration: InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'https://media.example.com',
                    prefixIcon: const Icon(McIcons.server, size: 18),
                    helperText: _lanHint,
                    helperStyle: McText.micro.copyWith(color: McTokens.ok),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userCtrl,
                  enabled: !state.busy,
                  style: McText.body,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: '账号',
                    prefixIcon: Icon(McIcons.user, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  enabled: !state.busy,
                  obscureText: _obscure,
                  style: McText.body,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _connect(),
                  decoration: InputDecoration(
                    labelText: '密码',
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x1FF5C451),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x4DF5C451)),
                    ),
                    child: Text(
                      '该服务器尚未完成首次初始化，请先在浏览器打开服务器地址完成向导。',
                      style: McText.caption.copyWith(color: McTokens.warning),
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
                    label: state.busy ? '正在连接…' : '连接',
                    primary: true,
                    expanded: true,
                    height: 44,
                    busy: state.busy,
                    onTap: state.busy ? null : _connect,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 深空星等星野 + 行星轨道日出大气弧光背景（对齐 iOS `CosmosBackdrop.swift`）。
class McCosmosBackdrop extends StatelessWidget {
  const McCosmosBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: _CosmosPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _CosmosPainter extends CustomPainter {
  const _CosmosPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = McTokens.bg);

    // 顶部极微弱深空星云暗蓝呼吸
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

    // 确定性伪随机真实星等星点（亮星少、暗星多，零帧率开销）
    final rng = math.Random(19690720);
    final starPaint = Paint()..style = PaintingStyle.fill;
    const starCount = 135;
    for (var i = 0; i < starCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.86;
      final mag = math.pow(rng.nextDouble(), 2.6).toDouble();
      final radius = 0.45 + mag * 1.35;
      final alpha = (0.14 + mag * 0.72).clamp(0.0, 0.9);
      final tint = i % 9 == 0
          ? const Color(0xFFD6E6FF)
          : (i % 13 == 0 ? const Color(0xFFFFECD6) : Colors.white);
      starPaint.color = tint.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }

    // 底部行星大气日出弧光（Orbital Sunrise）
    final planetRadius = math.max(size.width * 1.45, 620.0);
    final planetCenter = Offset(
      size.width * 0.5,
      size.height * 0.90 + planetRadius,
    );

    // 大气外层冷青蓝辉光
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 58
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32)
      ..shader = const LinearGradient(
        colors: [
          Color(0x0036E2BD),
          Color(0x384C9DFF),
          Color(0x527FB0FF),
          Color(0x389A6BFF),
          Color(0x0036E2BD),
        ],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
      );
    canvas.drawCircle(planetCenter, planetRadius, glowPaint);

    // 行星暗体遮罩
    canvas.drawCircle(
      planetCenter,
      planetRadius,
      Paint()..color = const Color(0xFF030407),
    );

    // 行星边缘 1.2px 晨昏亮弧线
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
  bool shouldRepaint(covariant _CosmosPainter oldDelegate) => false;
}
