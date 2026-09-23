import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/news_models.dart';
import '../util/rfc822_date.dart';
import 'cache_service.dart';

/// RSSフィードを取得・解析するサービス。
///
/// タイトル・リンク・配信元・時刻のみを保持し、本文の複製は行わない。
/// RSS 2.0（`<item>`）とAtom（`<entry>`）の両方に対応する。
class NewsService {
  NewsService(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  final CacheService _cache;
  final http.Client _client;

  static const Duration _cacheTtl = Duration(minutes: 10);

  String _cacheKey(NewsSource source) => 'news_${source.rssUrl}';

  Future<List<NewsArticle>> fetchArticles(NewsSource source) async {
    final key = _cacheKey(source);
    final cached = _cache.read(key);
    if (cached != null) {
      final (savedAt, data) = cached;
      if (DateTime.now().difference(savedAt) < _cacheTtl) {
        return _decode(data as List);
      }
    }
    try {
      final res = await _client
          .get(Uri.parse(source.rssUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw NewsServiceException(
          '${source.name}: HTTP ${res.statusCode}',
        );
      }
      final articles = _parseFeed(utf8.decode(res.bodyBytes), source);
      await _cache.writeJson(
        key,
        articles.map((e) => e.toJson()).toList(),
      );
      return articles;
    } catch (e) {
      if (cached != null) {
        return _decode(cached.$2 as List);
      }
      throw NewsServiceException('${source.name}のニュース取得に失敗しました: $e');
    }
  }

  List<NewsArticle> _decode(List raw) => raw
      .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
      .toList();

  List<NewsArticle> _parseFeed(String body, NewsSource source) {
    final doc = XmlDocument.parse(body);
    final items = doc.findAllElements('item');
    if (items.isNotEmpty) {
      return items.map((item) => _fromRssItem(item, source)).toList();
    }
    final entries = doc.findAllElements('entry');
    return entries.map((entry) => _fromAtomEntry(entry, source)).toList();
  }

  String _text(XmlElement parent, String tag) {
    final el = parent.findElements(tag).firstOrNull;
    return el?.innerText.trim() ?? '';
  }

  NewsArticle _fromRssItem(XmlElement item, NewsSource source) {
    final title = _text(item, 'title');
    final link = _text(item, 'link');
    final pubDateStr = _text(item, 'pubDate');
    return NewsArticle(
      title: title,
      link: link,
      sourceName: source.name,
      category: source.category,
      publishedAt:
          pubDateStr.isEmpty ? null : parseRfc822Date(pubDateStr),
    );
  }

  NewsArticle _fromAtomEntry(XmlElement entry, NewsSource source) {
    final title = _text(entry, 'title');
    final linkEl = entry.findElements('link').firstOrNull;
    final link = linkEl?.getAttribute('href') ?? linkEl?.innerText.trim() ?? '';
    var dateStr = _text(entry, 'published');
    if (dateStr.isEmpty) dateStr = _text(entry, 'updated');
    return NewsArticle(
      title: title,
      link: link,
      sourceName: source.name,
      category: source.category,
      publishedAt: dateStr.isEmpty ? null : DateTime.tryParse(dateStr),
    );
  }
}

class NewsServiceException implements Exception {
  NewsServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
