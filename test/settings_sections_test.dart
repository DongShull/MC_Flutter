import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/features/settings/state/sections.dart';
import 'package:mc_flutter/features/settings/widgets/admin_widgets.dart';

void main() {
  test('settings registry covers all 25 parity sections', () {
    expect(sectionsCoverParity25(), isTrue);
    final ids = settingsSections.map((s) => s.id).toSet();
    expect(ids.length, settingsSections.length, reason: 'no duplicate ids');
    final routes = settingsSections.map((s) => s.route).toSet();
    expect(routes.length, settingsSections.length,
        reason: 'no duplicate routes');
    for (final s in settingsSections) {
      expect(s.route, startsWith('/settings/'));
    }
  });

  test('members only see personal sections', () {
    final visible = visibleSections(false).map((s) => s.id).toSet();
    expect(
        visible,
        {'profile', 'devices', 'activate', 'notifications', 'appearance', 'playback'});
    expect(visibleSections(true).length, settingsSections.length);
  });

  test('comma list helpers round-trip', () {
    expect(parseCommaList('zh-CN, en,, zh-TW '), ['zh-CN', 'en', 'zh-TW']);
    expect(parseCommaList(''), isEmpty);
    expect(formatCommaList(['a', 'b']), 'a, b');
  });
}
