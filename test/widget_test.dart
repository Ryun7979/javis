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

    // 時計は「:」の点滅アニメーションのため時・コロン・分が別々のTextに分かれている。
    final hourFinder = find.byWidgetPredicate(
      (widget) => widget is Text && RegExp(r'^\d{2}$').hasMatch(widget.data ?? ''),
    );
    final colonFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == ':',
    );
    expect(hourFinder, findsNWidgets(2));
    expect(colonFinder, findsOneWidget);
  });
}
