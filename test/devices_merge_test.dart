import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/features/account/routes.dart' as feat_account;
import 'package:mc_flutter/features/settings/routes.dart' as feat_settings;

void main() {
  test('devices merge: only one devices route, in settings', () {
    final accountPaths =
        feat_account.routes.map((r) => r.path).toList();
    expect(accountPaths, ['/account']);
    expect(accountPaths.any((p) => p.contains('devices')), isFalse);

    final settingsPaths =
        feat_settings.routes.map((r) => r.path).toList();
    expect(
        settingsPaths.where((p) => p == '/settings/devices').length, 1);
  });

  test('settings routes cover every registry section', () {
    final paths = feat_settings.routes.map((r) => r.path).toSet();
    const expected = {
      '/settings/overview',
      '/settings/profile',
      '/settings/devices',
      '/settings/activate',
      '/settings/notifications',
      '/settings/appearance',
      '/settings/members',
      '/settings/subscription',
      '/settings/rule-sets',
      '/settings/sites',
      '/settings/downloaders',
      '/settings/import-watch',
      '/settings/scrape',
      '/settings/playback',
      '/settings/drives',
      '/settings/app-push',
      '/settings/im-push',
      '/settings/webhook',
      '/settings/llm',
      '/settings/mcp',
      '/settings/ai',
      '/settings/cloud',
      '/settings/app',
      '/settings/plugins',
      '/settings/network',
      '/settings/logs',
      '/settings/scheduled-tasks',
      '/settings/external-access',
      '/settings/maintenance',
    };
    expect(expected.difference(paths), isEmpty);
  });
}
