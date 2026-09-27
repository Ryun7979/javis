import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/models/wiki_trivia.dart';
import 'package:wall_jarvis/services/wikipedia_service.dart';

void main() {
  group('WikipediaService.extractOnThisDay', () {
    // 実際の `Wikipedia:今日は何の日 9月` の書式（2026-09-27取得）を縮めたもの。
    const wikitext = '''
== [[9月26日]] ==
* [[袴田事件]]：再審で[[静岡地方裁判所|静岡地裁]]が無罪判決（2024年）

== [[9月27日]] ==
* [[世界観光の日]]
* [[イエズス会]]が[[ローマ教皇]][[パウルス3世 (ローマ教皇)|パウルス3世]]から修道会として正式に認可（[[1540年]]）
* [[アルベルト・アインシュタイン]]による、[[E=mc2|E=mc²]]の式が記載された論文が掲載される（[[1905年]]）

== [[9月28日]] ==
* [[ロンドン]]の{{仮リンク|ドルリー・レーン王立劇場|en|Theatre Royal, Drury Lane}}で初演奏（[[1745年]]）
''';

    test('指定日の節の箇条書きだけを記法を除いて返す', () {
      expect(WikipediaService.extractOnThisDay(wikitext, 9, 27), [
        '世界観光の日',
        'イエズス会がローマ教皇パウルス3世から修道会として正式に認可（1540年）',
        'アルベルト・アインシュタインによる、E=mc²の式が記載された論文が掲載される（1905年）',
      ]);
    });

    test('月末の節（次の見出しが無い）も最後まで読む', () {
      expect(WikipediaService.extractOnThisDay(wikitext, 9, 28), [
        'ロンドンのドルリー・レーン王立劇場で初演奏（1745年）',
      ]);
    });

    test('9月2日の見出しで9月27日などを誤って拾わない', () {
      expect(WikipediaService.extractOnThisDay(wikitext, 9, 2), isEmpty);
    });
  });

  group('WikipediaService.cleanWikitext', () {
    test('脚注・コメント・未知テンプレートを落とし、仮リンクのlabelを使う', () {
      expect(
        WikipediaService.cleanWikitext(
          "'''太字'''と{{仮リンク|キルコルムの戦い|en|Battle of Kircholm|label=戦い}}"
          '<ref>{{Cite web |url=https://example.com |title=x}}</ref><!-- メモ -->'
          '{{要出典|date=2024年1月}}。',
        ),
        '太字と戦い。',
      );
    });

    test('lang テンプレートと外部リンクは表示文字列を残す', () {
      expect(
        WikipediaService.cleanWikitext(
          '{{lang|en|Annalen der Physik}}誌 [https://example.com 公式]',
        ),
        'Annalen der Physik誌 公式',
      );
    });

    test('HTMLの実体参照を文字に戻す', () {
      expect(
        WikipediaService.cleanWikitext('515.3&nbsp;km/h &amp; TGV'),
        '515.3 km/h & TGV',
      );
    });
  });

  group('WikipediaService.featuredFromFeed', () {
    test('要約文の1文目を秀逸な記事として返す', () {
      final item = WikipediaService.featuredFromFeed({
        'tfa': {
          'titles': {'normalized': '神戸外国人居留地'},
          'extract': '神戸外国人居留地は、神戸村に設けられた外国人居留地である。神戸居留地とも略称される。',
        },
      });
      expect(item?.kind, WikiTriviaKind.featured);
      expect(item?.text, '神戸外国人居留地は、神戸村に設けられた外国人居留地である。');
    });

    test('要約が無ければ記事名、tfa自体が無ければ null', () {
      expect(
        WikipediaService.featuredFromFeed({
          'tfa': {'title': '神戸外国人居留地'},
        })?.text,
        '神戸外国人居留地',
      );
      expect(WikipediaService.featuredFromFeed({'mostread': {}}), isNull);
    });
  });
}
