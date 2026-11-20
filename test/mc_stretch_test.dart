import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/effects/mc_stretch.dart';

void main() {
  test('McStretchDynamics 弹簧回零', () {
    final dyn = McStretchDynamics(() {}); // 无 ticker，手动驱动
    dyn.apply(60);
    dyn.apply(60);
    dyn.release(); // 松手
    // 持续 tick：临界阻尼弹簧收敛到 ~0。
    var elapsed = Duration.zero;
    for (var i = 0; i < 1200; i++) {
      elapsed += const Duration(milliseconds: 8);
      dyn.debugTick(elapsed);
    }
    expect(dyn.value.abs(), lessThan(0.5));
  });

  testWidgets('McStretchContainer 越界拉伸后回弹且不崩溃', (tester) async {
    final controller = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: McStretchContainer(
            axis: Axis.vertical,
            child: ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (_, i) => SizedBox(height: 60, child: Text('item $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 在列表顶部向上拉：Clamping 物理下越界输入经 OverscrollNotification
    // 汇入弹簧；拉伸期间布局不崩溃，松手回弹后内容恢复正常命中。
    final gesture = await tester.startGesture(tester.getCenter(find.text('item 0')));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('item 0'), findsOneWidget);
  });
}