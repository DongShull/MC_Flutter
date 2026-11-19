// IMPLEMENTED — 1:1 重写自 MovieClaw feature/onboarding（非占位页，勿被生成器覆盖）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/theme.dart';
import '../state/onboarding_controller.dart';
import '../routes.dart' as feat_onboarding;

/// 登录/接入页：输入服务器地址 → 探测 → bootstrap → device login。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _hostCtrl = TextEditingController();

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await ref
        .read(onboardingProvider.notifier)
        .login(_hostCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    ref.listen<OnboardingState>(onboardingProvider, (prev, next) {
      if (next.done && (prev?.done != true)) {
        context.go(feat_onboarding.routeOnboarding);
      }
    });

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [McColors.bgDark, McColors.surfaceDark],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'MovieClaw',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: McColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '连接你的 MediaCloud 服务器',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: McColors.accent.withOpacity(0.7)),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _hostCtrl,
                  keyboardType: TextInputType.url,
                  enabled: !state.busy,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'https://example.com',
                    prefixIcon: Icon(Icons.dns),
                  ),
                ),
                const SizedBox(height: 16),
                if (state.error != null) ...[
                  Text(
                    state.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: state.busy ? null : _connect,
                  child: state.busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('连接'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
