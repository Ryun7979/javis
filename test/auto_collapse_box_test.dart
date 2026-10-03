import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/widgets/auto_collapse_box.dart';

void main() {
  Widget build({Object? resetKey}) => MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: AutoCollapseBox(
        resetKey: resetKey,
        builder: (context, expanded) => Text(expanded ? '詳細' : '1行'),
      ),
    ),
  );

  testWidgets('開いた状態で始まり、8秒後にたたむ', (tester) async {
    await tester.pumpWidget(build());
    expect(find.text('詳細'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('詳細'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('1行'), findsOneWidget);
  });

  testWidgets('タップで開き、また8秒後にたたむ。開いているときのタップではすぐたたむ', (tester) async {
    await tester.pumpWidget(build());
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('1行'), findsOneWidget);

    await tester.tap(find.text('1行'));
    await tester.pumpAndSettle();
    expect(find.text('詳細'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('1行'), findsOneWidget);

    await tester.tap(find.text('1行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('詳細'));
    await tester.pumpAndSettle();
    expect(find.text('1行'), findsOneWidget);
  });

  testWidgets('対象が変わると開き直す', (tester) async {
    await tester.pumpWidget(build(resetKey: 'a'));
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('1行'), findsOneWidget);

    // 同じ対象のまま作り直されても、たたんだまま。
    await tester.pumpWidget(build(resetKey: 'a'));
    await tester.pumpAndSettle();
    expect(find.text('1行'), findsOneWidget);

    await tester.pumpWidget(build(resetKey: 'b'));
    await tester.pumpAndSettle();
    expect(find.text('詳細'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('1行'), findsOneWidget);
  });
}
