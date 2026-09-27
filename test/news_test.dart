import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/data/default_news_sources.dart';
import 'package:wall_jarvis/models/app_settings.dart';
import 'package:wall_jarvis/models/news_models.dart';
import 'package:wall_jarvis/providers/dashboard_state.dart';
import 'package:wall_jarvis/services/news_service.dart';
import 'package:wall_jarvis/util/news_ranking.dart';

const _source = NewsSource(
  name: 'テスト',
  category: NewsCategory.game,
  rssUrl: 'https://example.com/rss',
);

void main() {
  group('NewsService.parseFeed', () {
    test('RSS 1.0（RDF）のdc:dateを日時として読む', () {
      const rdf = '''<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns="http://purl.org/rss/1.0/" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel rdf:about="https://example.com/"><title>t</title></channel>
  <item rdf:about="https://example.com/1">
    <title>記事1</title><link>https://example.com/1</link>
    <dc:date>2026-09-27T15:00:00+09:00</dc:date>
  </item>
</rdf:RDF>''';
      final articles = NewsService.parseFeed(rdf, _source);
      expect(articles, hasLength(1));
      expect(articles.single.title, '記事1');
      expect(articles.single.publishedAt, DateTime.utc(2026, 9, 27, 6));
    });

    test('RSS 2.0のpubDateは従来どおり読む', () {
      const rss = '''<rss version="2.0"><channel><item>
<title>記事2</title><link>https://example.com/2</link>
<pubDate>Sun, 27 Sep 2026 06:00:00 +0000</pubDate>
</item></channel></rss>''';
      final articles = NewsService.parseFeed(rss, _source);
      expect(articles.single.publishedAt, DateTime.utc(2026, 9, 27, 6));
    });
  });

  group('配信元の移行', () {
    test('版の記録がない古い設定には版2の既定配信元を追加し、ユーザーの配信元は残す', () {
      const custom = NewsSource(
        name: '自分で追加',
        category: NewsCategory.it,
        rssUrl: 'https://example.com/custom',
      );
      final json = AppSettings.defaults().toJson()
        ..remove('newsSourcesVersion')
        ..['newsSources'] = [
          defaultNewsSources.first.toJson(),
          custom.toJson(),
        ];
      final urls = AppSettings.fromJson(json)
          .newsSources
          .map((s) => s.rssUrl)
          .toList();
      expect(urls, contains(custom.rssUrl));
      for (final s in newsSourcesAddedByVersion[2]!) {
        expect(urls.where((u) => u == s.rssUrl), hasLength(1));
      }
      // 版1の既定配信元のうち、ユーザーが削除したものは復活させない。
      expect(urls, isNot(contains(defaultNewsSources[1].rssUrl)));
    });

    test('現在の版で保存された設定では、削除した既定配信元を戻さない', () {
      final kept = defaultNewsSources.skip(1).toList();
      final settings = AppSettings.defaults().copyWith(newsSources: kept);
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.newsSources.map((s) => s.rssUrl),
          kept.map((s) => s.rssUrl));
    });

    test('既定の配信元に映画とアウトドアが含まれる', () {
      final categories = defaultNewsSources.map((s) => s.category).toSet();
      expect(categories, containsAll(NewsCategory.values));
    });
  });

  test('総合は配信元ごとに上限件数までに絞り、タイトル重複を除く', () {
    final base = DateTime.utc(2026, 9, 27);
    NewsArticle article(String source, int i, NewsCategory c) => NewsArticle(
          title: '$source-$i',
          link: 'https://example.com/$source/$i',
          sourceName: source,
          category: c,
          publishedAt: base.subtract(Duration(minutes: i)),
        );
    final state = DashboardState(
      isLoading: false,
      newsByCategory: {
        NewsCategory.game: [
          for (var i = 0; i < 40; i++) article('多い', i, NewsCategory.game),
        ],
        NewsCategory.movie: [
          for (var i = 0; i < 3; i++) article('映画', i, NewsCategory.movie),
          article('多い', 0, NewsCategory.movie), // 同じタイトル
        ],
      },
    );
    final all = state.allNewsSorted;
    expect(all.where((a) => a.sourceName == '多い'),
        hasLength(DashboardState.allNewsPerSourceLimit));
    expect(all.where((a) => a.sourceName == '映画'), hasLength(3));
    expect(all.map((a) => a.title).toSet(), hasLength(all.length));
  });

  group('注目度順', () {
    final now = DateTime.utc(2026, 9, 27, 12);
    NewsArticle article(String id, int hoursAgo) => NewsArticle(
          title: id,
          link: 'https://example.com/$id',
          sourceName: 'テスト',
          category: NewsCategory.it,
          publishedAt: now.subtract(Duration(hours: hoursAgo)),
        );

    test('同じブクマ数なら新しい記事ほど注目度が高い', () {
      expect(
        popularityScore(100, now.subtract(const Duration(hours: 1)), now),
        greaterThan(
            popularityScore(100, now.subtract(const Duration(hours: 24)), now)),
      );
      expect(popularityScore(0, now, now), 0);
    });

    test('ブクマ数と経過時間で並べ、0件同士は新着順を保つ', () {
      final articles = [
        article('新しい0件A', 0),
        article('新しい0件B', 1),
        article('少し前の人気', 3),
        article('昨日の超人気', 24),
      ];
      final sorted = sortByPopularity(
        articles,
        {
          'https://example.com/少し前の人気': 50,
          'https://example.com/昨日の超人気': 200,
        },
        now,
      );
      // 50/(5^1.5)≈4.5 > 200/(26^1.5)≈1.5
      expect(sorted.map((a) => a.title), [
        '少し前の人気',
        '昨日の超人気',
        '新しい0件A',
        '新しい0件B',
      ]);
    });

    test('はてなブックマーク件数APIの応答を読む', () {
      expect(
        NewsService.parseBookmarkCounts(
            '{"https://a.example/1":114,"https://a.example/2":0}'),
        {'https://a.example/1': 114, 'https://a.example/2': 0},
      );
    });

    test('ページ送り間隔の設定は保存・復元でき、古い設定では既定値になる', () {
      final s = AppSettings.defaults().copyWith(newsPageScrollMinutes: 5);
      expect(AppSettings.fromJson(s.toJson()).newsPageScrollMinutes, 5);
      final old = AppSettings.defaults().toJson()..remove('newsPageScrollMinutes');
      expect(AppSettings.fromJson(old).newsPageScrollMinutes,
          AppSettings.defaultNewsPageScrollMinutes);
    });
  });
}
