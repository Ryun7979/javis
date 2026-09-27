import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/wiki_trivia.dart';
import 'cache_service.dart';

/// 日本語版Wikipediaから「今日は何の日」と「秀逸な記事」を取得するサービス。
///
/// 日本語版は Wikimedia 公式の onthisday フィードが未対応（404）のため、「今日は何の日」は
/// メインページの元データである `Wikipedia:今日は何の日 n月` のwikitextから当日の節を切り出す。
/// 秀逸な記事は REST の featured フィード（`tfa`）の要約文の1文目を使う。
class WikipediaService {
  WikipediaService(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  final CacheService _cache;
  final http.Client _client;

  /// Wikimedia のAPI利用方針で、連絡先の分かるUser-Agentを付けることが求められている。
  static const _headers = {
    'User-Agent':
        'WallJarvis/1.0 (personal desk kiosk; https://github.com/Ryun7979/javis)',
  };

  /// 片方の取得に失敗していたときに取り直すまでの間隔。
  static const Duration _retryAfter = Duration(hours: 1);

  String _cacheKey(DateTime day) =>
      'wiki_trivia_${day.year}${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  /// [day]（年月日のみ使用）の小ネタ一覧を返す。秀逸な記事が先頭、続いて今日は何の日。
  /// 取得できたものが1件も無ければ空リスト。
  Future<List<WikiTriviaItem>> fetchDaily(DateTime day) async {
    final key = _cacheKey(day);
    final cached = _cache.read(key);
    List<WikiTriviaItem> cachedItems = const [];
    if (cached != null) {
      final (savedAt, data) = cached;
      final map = data as Map<String, dynamic>;
      cachedItems = (map['items'] as List)
          .map((e) => WikiTriviaItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final complete = map['complete'] as bool? ?? false;
      if (complete || DateTime.now().difference(savedAt) < _retryAfter) {
        return cachedItems;
      }
    }

    WikiTriviaItem? featured;
    List<WikiTriviaItem> events = const [];
    var complete = true;
    try {
      featured = await _fetchFeatured(day);
    } catch (_) {
      complete = false;
    }
    try {
      events = await _fetchOnThisDay(day);
    } catch (_) {
      complete = false;
    }
    final items = [?featured, ...events];
    if (items.isEmpty) return cachedItems;
    await _cache.writeJson(key, {
      'complete': complete,
      'items': items.map((e) => e.toJson()).toList(),
    });
    return items;
  }

  Future<WikiTriviaItem?> _fetchFeatured(DateTime day) async {
    final path = '${day.year}/${day.month.toString().padLeft(2, '0')}/'
        '${day.day.toString().padLeft(2, '0')}';
    final json = await _getJson(
      Uri.parse('https://ja.wikipedia.org/api/rest_v1/feed/featured/$path'),
    );
    return featuredFromFeed(json);
  }

  Future<List<WikiTriviaItem>> _fetchOnThisDay(DateTime day) async {
    final uri = Uri.https('ja.wikipedia.org', '/w/api.php', {
      'action': 'parse',
      'page': 'Wikipedia:今日は何の日 ${day.month}月',
      'prop': 'wikitext',
      'format': 'json',
      'formatversion': '2',
    });
    final json = await _getJson(uri);
    final wikitext = (json['parse'] as Map<String, dynamic>)['wikitext'] as String;
    return extractOnThisDay(wikitext, day.month, day.day)
        .map((t) => WikiTriviaItem(kind: WikiTriviaKind.onThisDay, text: t))
        .toList();
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw WikipediaServiceException('HTTP ${res.statusCode}: $uri');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// featured フィードのJSONから秀逸な記事の1件を作る。無ければ null。
  static WikiTriviaItem? featuredFromFeed(Map<String, dynamic> json) {
    final tfa = json['tfa'] as Map<String, dynamic>?;
    if (tfa == null) return null;
    final title = (tfa['titles'] as Map<String, dynamic>?)?['normalized']
            as String? ??
        tfa['title'] as String? ??
        '';
    final extract = (tfa['extract'] as String? ?? '').trim();
    // 要約文は記事名から始まるので、1文目だけで「何の記事か」が伝わる。
    final end = extract.indexOf('。');
    final text = end >= 0 ? extract.substring(0, end + 1) : extract;
    final result = text.isNotEmpty ? text : title;
    if (result.isEmpty) return null;
    return WikiTriviaItem(kind: WikiTriviaKind.featured, text: result);
  }

  /// 月ごとのページのwikitextから `== [[m月d日]] ==` の節の箇条書きを整形して返す。
  static List<String> extractOnThisDay(String wikitext, int month, int day) {
    final heading = RegExp('^==\\s*\\[\\[$month月$day日\\]\\]\\s*==\\s*\$',
        multiLine: true);
    final match = heading.firstMatch(wikitext);
    if (match == null) return const [];
    final rest = wikitext.substring(match.end);
    final next = RegExp(r'^==[^=]', multiLine: true).firstMatch(rest);
    final section = next == null ? rest : rest.substring(0, next.start);
    return section
        .split('\n')
        .where((line) => line.startsWith('*'))
        .map((line) => cleanWikitext(line.replaceFirst(RegExp(r'^\*+'), '')))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// 1行分のwikitextから記法を取り除き、表示用のプレーンテキストにする。
  static String cleanWikitext(String input) {
    var s = input
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll(RegExp(r'<ref[^>]*/>'), '')
        .replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');

    // テンプレートは内側から順に展開する。
    final template = RegExp(r'\{\{([^{}]*)\}\}');
    while (template.hasMatch(s)) {
      s = s.replaceAllMapped(template, (m) => _expandTemplate(m.group(1)!));
    }

    // [[ファイル:...]] などの画像は丸ごと落とす。
    s = s.replaceAll(
        RegExp(r'\[\[(?:ファイル|画像|File|Image):[^\]]*\]\]',
            caseSensitive: false),
        '');
    s = s.replaceAllMapped(
        RegExp(r'\[\[[^\[\]|]*\|([^\[\]]*)\]\]'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'\[\[([^\[\]]*)\]\]'), (m) => m.group(1)!);
    // 外部リンク [url 表示名] → 表示名
    s = s.replaceAllMapped(
        RegExp(r'\[https?://\S+\s+([^\]]*)\]'), (m) => m.group(1)!);
    s = s.replaceAll(RegExp(r"'{2,}"), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _expandTemplate(String body) {
    final parts = body.split('|').map((p) => p.trim()).toList();
    final name = parts.first;
    final positional = <String>[];
    final named = <String, String>{};
    for (final p in parts.skip(1)) {
      final eq = p.indexOf('=');
      if (eq > 0) {
        named[p.substring(0, eq).trim()] = p.substring(eq + 1).trim();
      } else {
        positional.add(p);
      }
    }
    switch (name) {
      case '仮リンク':
        return named['label'] ?? (positional.isNotEmpty ? positional[0] : '');
      case 'lang':
      case 'Lang':
        return positional.length >= 2 ? positional[1] : '';
      case 'ruby':
      case 'Ruby':
        return positional.isNotEmpty ? positional[0] : '';
      default:
        // 表示に意味のある既知テンプレート以外（注釈・脚注など）は落とす。
        return '';
    }
  }
}

class WikipediaServiceException implements Exception {
  WikipediaServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
