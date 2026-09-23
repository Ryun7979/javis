import '../models/news_models.dart';

/// 既定のRSS配信元。
///
/// いずれも各メディアが公開しているRSSフィードで、タイトル・配信元・時刻のみを
/// 表示し本文は複製しない（設定画面から変更・追加可能）。
const List<NewsSource> defaultNewsSources = [
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
