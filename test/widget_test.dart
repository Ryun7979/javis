// 時計ウィジェットが時刻表示を描画できることを確認するスモークテスト。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wall_jarvis/widgets/clock_widget.dart';

void main() {
  testWidgets('ClockWidget renders a HH:mm style time', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ClockWidget())),
      ),
    );
    await tester.pump();

    final timeFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
    );
    expect(timeFinder, findsOneWidget);
  });
}
