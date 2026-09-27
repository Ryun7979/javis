import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/news_models.dart';
import '../util/rfc822_date.dart';
import 'cache_service.dart';

/// RSSフィードを取得・解析するサービス。
///
/// タイトル・リンク・配信元・時刻のみを保持し、本文の複製は行わない。
/// RSS 1.0/2.0（`<item>`）とAtom（`<entry>`）に対応する。
class NewsService {
  NewsService(this._cache, {http.Client? client})
    : _client = client ?? http.Client();

  final CacheService _cache;
  final http.Client _client;

  // 最短の自動更新間隔（10分）より少し短くする。同じ長さだと、区切りの時刻の更新で
  // 前回取得からわずかに10分未満となりキャッシュが使われ、1回分更新が飛ぶ。
  static const Duration _cacheTtl = Duration(minutes: 9);

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
        throw NewsServiceException('${source.name}: HTTP ${res.statusCode}');
      }
      final articles = parseFeed(utf8.decode(res.bodyBytes), source);
      await _cache.writeJson(key, articles.map((e) => e.toJson()).toList());
      return articles;
    } catch (e) {
      if (cached != null) {
        return _decode(cached.$2 as List);
      }
      throw NewsServiceException('${source.name}のニュース取得に失敗しました: $e');
    }
  }

  static const _bookmarkCacheKey = 'hatena_bookmark_counts';
  static const Duration _bookmarkCacheTtl = Duration(minutes: 60);

  /// はてなブックマーク数を取得する（「総合」の注目度順に使う）。
  ///
  /// APIは1回50件までなので分割して問い合わせる。失敗しても例外は投げず、
  /// 取れた分（なければ前回のキャッシュ）を返す。注目度は並べ替えの補助なので、
  /// 取れないときは新着順のまま表示できれば十分。
  Future<Map<String, int>> fetchBookmarkCounts(List<String> urls) async {
    final cached = _cache.read(_bookmarkCacheKey);
    final cachedCounts = cached == null
        ? <String, int>{}
        : (cached.$2 as Map).map((k, v) => MapEntry(k as String, v as int));
    final targets = urls.where((u) => u.startsWith('http')).toSet().toList();
    if (cached != null &&
        DateTime.now().difference(cached.$1) < _bookmarkCacheTtl &&
        targets.every(cachedCounts.containsKey)) {
      return cachedCounts;
    }

    final counts = <String, int>{};
    for (var i = 0; i < targets.length; i += 50) {
      final chunk = targets.sublist(i, min(i + 50, targets.length));
      final query = chunk.map((u) => 'url=${Uri.encodeComponent(u)}').join('&');
      try {
        final res = await _client
            .get(
              Uri.parse('https://bookmark.hatenaapis.com/count/entries?$query'),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) continue;
        counts.addAll(parseBookmarkCounts(res.body));
      } catch (_) {
        // 1回分が失敗しても残りは続ける。
      }
    }
    if (counts.isEmpty) return cachedCounts;
    // 一部の問い合わせだけ失敗した分は前回の値で補う（今の記事の分だけ残し、キャッシュを肥大させない）。
    for (final u in targets) {
      final old = cachedCounts[u];
      if (old != null) counts.putIfAbsent(u, () => old);
    }
    await _cache.writeJson(_bookmarkCacheKey, counts);
    return counts;
  }

  /// `{"URL": 件数, ...}` 形式の応答を読む。
  static Map<String, int> parseBookmarkCounts(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries)
        if (e.value is num) e.key as String: (e.value as num).toInt(),
    };
  }

  List<NewsArticle> _decode(List raw) =>
      raw.map((e) => NewsArticle.fromJson(e as Map<String, dynamic>)).toList();

  static List<NewsArticle> parseFeed(String body, NewsSource source) {
    final doc = XmlDocument.parse(body);
    final items = doc.findAllElements('item');
    if (items.isNotEmpty) {
      return items.map((item) => _fromRssItem(item, source)).toList();
    }
    final entries = doc.findAllElements('entry');
    return entries.map((entry) => _fromAtomEntry(entry, source)).toList();
  }

  static String _text(XmlElement parent, String tag) {
    final el = parent.findElements(tag).firstOrNull;
    return el?.innerText.trim() ?? '';
  }

  static NewsArticle _fromRssItem(XmlElement item, NewsSource source) {
    final title = _text(item, 'title');
    final link = _text(item, 'link');
    final pubDateStr = _text(item, 'pubDate');
    DateTime? publishedAt;
    if (pubDateStr.isNotEmpty) {
      publishedAt = parseRfc822Date(pubDateStr);
    } else {
      // RSS 1.0（RDF）はpubDateがなく、Dublin Coreのdc:date（ISO 8601）で日時を持つ。
      final dcDate = _text(item, 'dc:date');
      if (dcDate.isNotEmpty) publishedAt = DateTime.tryParse(dcDate)?.toUtc();
    }
    return NewsArticle(
      title: title,
      link: link,
      sourceName: source.name,
      category: source.category,
      publishedAt: publishedAt,
    );
  }

  static NewsArticle _fromAtomEntry(XmlElement entry, NewsSource source) {
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
