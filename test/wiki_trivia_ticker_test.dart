import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/models/wiki_trivia.dart';
import 'package:wall_jarvis/providers/wiki_trivia_controller.dart';
import 'package:wall_jarvis/widgets/wiki_trivia_ticker.dart';

/// 通信せずに固定の小ネタを返すテスト用コントローラ。
class _FakeController extends StateNotifier<List<WikiTriviaItem>>
    implements WikiTriviaController {
  _FakeController(super.items);

  @override
  Future<void> refresh() async {}
}

Widget _app(List<WikiTriviaItem> items, {double width = 400}) => ProviderScope(
      overrides: [
        wikiTriviaProvider.overrideWith((ref) => _FakeController(items)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: const WikiTriviaTicker()),
          ),
        ),
      ),
    );

const _a = WikiTriviaItem(kind: WikiTriviaKind.featured, text: '短い記事');
const _b = WikiTriviaItem(kind: WikiTriviaKind.onThisDay, text: '短いできごと');

void main() {
  testWidgets('短い文は一定時間表示したら次の項目へ切り替わる', (tester) async {
    await tester.pumpWidget(_app([_a, _b]));
    await tester.pump();
    expect(find.text('短い記事'), findsOneWidget);
    expect(find.text('秀逸な記事'), findsOneWidget);

    await tester.pump(WikiTriviaTicker.fitDisplay - const Duration(seconds: 1));
    expect(find.text('短いできごと'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('短いできごと'), findsOneWidget);
    expect(find.text('今日は何の日'), findsOneWidget);
  });

  testWidgets('長い文は先頭で止まってからスクロールし、末尾で止まってから次へ進む',
      (tester) async {
    final long = WikiTriviaItem(
      kind: WikiTriviaKind.onThisDay,
      text: 'とても長いできごと' * 20,
    );
    await tester.pumpWidget(_app([long, _a], width: 300));
    await tester.pump();

    final scrollable = find.byType(Scrollable);
    ScrollPosition position() =>
        tester.state<ScrollableState>(scrollable).position;
    expect(position().maxScrollExtent, greaterThan(0));

    // 開始直後の停止中はスクロールしていない。
    await tester.pump(WikiTriviaTicker.scrollPause - const Duration(milliseconds: 100));
    expect(position().pixels, 0);

    // 停止が明けるとスクロールが進む。
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    expect(position().pixels, greaterThan(0));

    // 末尾まで流れ切ったあと、末尾での停止中はまだ次へ進まない。
    final scrollMs =
        (position().maxScrollExtent / WikiTriviaTicker.scrollSpeed * 1000).round();
    await tester.pump(Duration(milliseconds: scrollMs));
    expect(position().pixels, position().maxScrollExtent);
    await tester.pump(WikiTriviaTicker.scrollPause - const Duration(milliseconds: 500));
    expect(find.text('短い記事'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('短い記事'), findsOneWidget);
  });

  testWidgets('項目が無いときは何も表示しない', (tester) async {
    await tester.pumpWidget(_app(const []));
    expect(find.byType(Row), findsNothing);
  });
}
