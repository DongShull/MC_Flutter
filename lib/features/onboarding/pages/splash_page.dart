import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/session_store.dart';
import '../../root/routes.dart' as feat_root;

/// 启动页（对齐飞牛 App）：已登录时短暂展示「用户名 + 设备名 + 跳动省略号」，
/// 预热完成后进主界面；未登录由路由重定向回登录页。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    // 省略号三点上下跳动：单控制器 + 三段错相 interval。
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    // 最短停留：让用户看到启动页（对齐飞牛的「正在连接…」仪式感）。
    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) context.go(feat_root.routeRoot);
    });
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = appSession.username;
    final deviceName = appSession.deviceName;
    return Scaffold(
      backgroundColor: McColors.bgDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              McStrings.appName,
              style: TextStyle(
                color: McColors.accent,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              username.isEmpty ? McStrings.welcomeBack : username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (deviceName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                deviceName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 26),
            _BouncingDots(controller: _dots),
          ],
        ),
      ),
    );
  }
}

/// 三个圆点依次上下跳动（省略号动效）。
class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        // 每个点错开 0.18 相位；仅前 45% 时间上跳，其余回落。
        final phase = (i * 0.18) % 1.0;
        final t = CurvedAnimation(
          parent: controller,
          curve: Interval(phase, (phase + 0.45).clamp(0.0, 1.0),
              curve: Curves.easeOutQuad),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(t),
            child: SlideTransition(
              position: Tween(
                begin: Offset.zero,
                end: const Offset(0, -0.45),
              ).animate(t),
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: McColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
