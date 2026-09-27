import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/models/apod.dart';
import 'package:wall_jarvis/widgets/apod_fullscreen_view.dart';

const _apod = ApodImage(
  date: '2026-09-27',
  title: 'Andromeda before Photoshop',
  imageUrl: 'https://example.com/a_960.jpg',
  hdImageUrl: 'https://example.com/a_4298.jpg',
);

/// ボタンを押すと全画面表示を開くだけの画面。
Widget _app(Duration autoClose) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(ApodFullscreenView.route(_apod, autoClose)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('画面のどこかをタッチすると通常表示に戻る', (tester) async {
    await tester.pumpWidget(_app(const Duration(minutes: 10)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ApodFullscreenView), findsOneWidget);
    expect(find.textContaining('Andromeda before Photoshop'), findsOneWidget);
    expect(find.textContaining('Image Credit: NASA'), findsOneWidget);

    // 文字の無い隅をタッチしても閉じる。
    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();
    expect(find.byType(ApodFullscreenView), findsNothing);
  });

  testWidgets('一定時間タッチされなければ自動で通常表示に戻る', (tester) async {
    await tester.pumpWidget(_app(const Duration(minutes: 10)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(minutes: 9));
    expect(find.byType(ApodFullscreenView), findsOneWidget);

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.byType(ApodFullscreenView), findsNothing);
  });
}
