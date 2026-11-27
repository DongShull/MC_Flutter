import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/session_store.dart';
import 'onboarding_page.dart';

/// 启动欢迎页：显式跳转时快速过渡进入主界面（<= 120ms，消除冷启动阻塞）。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _navTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = appSession.username;
    final deviceName = appSession.deviceName;
    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const McCosmosBackdrop(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const McBrandMark(size: 56),
                const SizedBox(height: 16),
                Text(
                  McStrings.appName,
                  style: McText.display.copyWith(letterSpacing: -0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  username.isEmpty ? McStrings.welcomeBack : username,
                  style: McText.titleSm,
                ),
                if (deviceName.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(deviceName, style: McText.caption.muted),
                ],
                const SizedBox(height: 26),
                _BouncingDots(controller: _dots),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value - i * 0.18) % 1.0;
            final wave = phase < 0.5 ? math.sin(phase * 2 * math.pi) : 0.0;
            final lift = wave.clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.5),
              child: Transform.translate(
                offset: Offset(0, -3.5 * lift),
                child: Opacity(
                  opacity: 0.30 + 0.65 * lift,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: McTokens.accentStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
