import '../models/news_models.dart';

/// 既定のRSS配信元の版。既定の配信元を増やしたら上げ、
/// [newsSourcesAddedByVersion] に追加分を登録する（保存済み設定への自動追加に使う）。
const int currentNewsSourcesVersion = 2;

const List<NewsSource> _newsSourcesV1 = [
  NewsSource(
    name: '4Gamer.net',
    category: NewsCategory.game,
    rssUrl: 'https://www.4gamer.net/rss/index.xml',
  ),
  NewsSource(
    name: 'ITmedia AI+',
    category: NewsCategory.ai,
    rssUrl: 'https://rss.itmedia.co.jp/rss/2.0/aiplus.xml',
  ),
  NewsSource(
    name: 'ITmedia NEWS',
    category: NewsCategory.it,
    rssUrl: 'https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml',
  ),
];

/// 版2で追加: ゲームの配信元の拡充と、映画・アウトドアのジャンル。
const List<NewsSource> _newsSourcesV2 = [
  NewsSource(
    name: 'GAME Watch',
    category: NewsCategory.game,
    rssUrl: 'https://game.watch.impress.co.jp/data/rss/1.0/gmw/feed.rdf',
  ),
  NewsSource(
    name: 'Game*Spark',
    category: NewsCategory.game,
    rssUrl: 'https://www.gamespark.jp/rss/index.rdf',
  ),
  NewsSource(
    name: 'AUTOMATON',
    category: NewsCategory.game,
    rssUrl: 'https://automaton-media.com/feed/',
  ),
  NewsSource(
    name: 'cinemacafe.net',
    category: NewsCategory.movie,
    rssUrl: 'https://www.cinemacafe.net/rss/index.rdf',
  ),
  NewsSource(
    name: '映画ナタリー',
    category: NewsCategory.movie,
    rssUrl: 'https://natalie.mu/eiga/feed/news',
  ),
  NewsSource(
    name: 'BE-PAL',
    category: NewsCategory.outdoor,
    rssUrl: 'https://www.bepal.net/feed',
  ),
  NewsSource(
    name: 'CAMP HACK',
    category: NewsCategory.outdoor,
    rssUrl: 'https://camphack.nap-camp.com/feed',
  ),
  NewsSource(
    name: 'YAMA HACK',
    category: NewsCategory.outdoor,
    rssUrl: 'https://yamahack.com/feed',
  ),
  NewsSource(
    name: 'TSURINEWS',
    category: NewsCategory.outdoor,
    rssUrl: 'https://tsurinews.jp/feed/',
  ),
];

/// 版ごとに追加された既定の配信元。
const Map<int, List<NewsSource>> newsSourcesAddedByVersion = {
  2: _newsSourcesV2,
};

/// 既定のRSS配信元。
///
/// いずれも各メディアが公開しているRSSフィードで、タイトル・配信元・時刻のみを
/// 表示し本文は複製しない（設定画面から変更・追加可能）。
const List<NewsSource> defaultNewsSources = [
  ..._newsSourcesV1,
  ..._newsSourcesV2,
];

/// [fromVersion] の版で保存された配信元一覧に、それ以降に増えた既定の配信元を追加する。
/// ユーザーが追加・削除した配信元は残し、同じURLが既にあるものは追加しない。
List<NewsSource> migrateNewsSources(
  List<NewsSource> sources,
  int fromVersion,
) {
  final result = [...sources];
  final urls = sources.map((s) => s.rssUrl).toSet();
  for (var v = fromVersion + 1; v <= currentNewsSourcesVersion; v++) {
    for (final s in newsSourcesAddedByVersion[v] ?? const <NewsSource>[]) {
      if (urls.add(s.rssUrl)) result.add(s);
    }
  }
  return result;
}
