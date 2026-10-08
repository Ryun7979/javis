import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/apod.dart';
import 'cache_service.dart';

/// NASA Scienceのサイト（`science.nasa.gov`）から最新の宇宙写真（APOD）を取得するサービス。
///
/// APODは `apod.nasa.gov` から `science.nasa.gov/apod/` へ移転し、従来の `api.nasa.gov/planetary/apod` は
/// どの日付でもサイトのロゴを返すようになった（2026-10-09確認）。そのため、移転先のサイトが出している
/// 記事一覧（WordPress REST API、キー不要・非公式）を使う。
/// 新しい順に数件を取り、APODの写真を持つ最初の記事を使う。写真のある記事が無ければ前回の写真を使い続ける。
class NasaApodService {
  NasaApodService(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  final CacheService _cache;
  final http.Client _client;

  static const _cacheKey = 'nasa_apod';

  /// 前回の取得からこの時間が経つまでは通信せずキャッシュを返す。
  static const Duration _ttl = Duration(hours: 3);

  /// 写真の配信元。これ以外の画像（サイトのロゴ等）は写真として扱わない。
  static const _imageHost = 'assets.science.nasa.gov';

  /// 時計の背景に使う縮小版の幅（px）。
  static const _backgroundWidth = 1280;

  /// キャッシュ済みの写真（通信しない）。起動直後の即時表示用。
  /// 旧APIが返したロゴなど、APODの写真でないものは捨てる。
  ApodImage? cached() {
    final entry = _cache.read(_cacheKey);
    if (entry == null) return null;
    try {
      final image = ApodImage.fromJson(entry.$2 as Map<String, dynamic>);
      return isApodImageUrl(image.hdImageUrl) ? image : null;
    } catch (_) {
      return null;
    }
  }

  /// 最新の写真を返す。[force] が true ならキャッシュの鮮度によらず取り直す。
  /// 取得に失敗した場合や写真のある記事が無い場合は、キャッシュ済みの写真（無ければ null）を返す。
  Future<ApodImage?> fetchLatest({bool force = false}) async {
    final entry = _cache.read(_cacheKey);
    final previous = cached();
    if (!force &&
        entry != null &&
        previous != null &&
        DateTime.now().difference(entry.$1) < _ttl) {
      return previous;
    }

    final uri = Uri.https('science.nasa.gov', '/wp-json/wp/v2/image-article', {
      'search': 'apod',
      'per_page': '5',
      // search を付けると既定の並びが関連度順になるため、日付順を明示する。
      'orderby': 'date',
      'order': 'desc',
      '_embed': 'wp:featuredmedia',
      '_fields': 'date,title,_links.wp:featuredmedia,_embedded',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw NasaApodServiceException('HTTP ${res.statusCode}');
    }
    final image = parseResponse(jsonDecode(utf8.decode(res.bodyBytes)));
    if (image == null) {
      // 写真のある記事が無い。前回の写真をそのまま使い、TTLの間は問い合わせ直さない。
      if (previous != null) await _cache.writeJson(_cacheKey, previous.toJson());
      return previous;
    }
    await _cache.writeJson(_cacheKey, image.toJson());
    return image;
  }

  /// APODの写真のURLかどうか（配信元のホストで、パスに `/apod/` を含む）。
  static bool isApodImageUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == _imageHost &&
        uri.path.contains('/apod/');
  }

  /// 記事一覧のJSON（新しい順）から、APODの写真を持つ最初の記事を写真にする。無ければ null。
  static ApodImage? parseResponse(Object? json) {
    if (json is! List) return null;
    for (final article in json) {
      if (article is! Map<String, dynamic>) continue;
      final image = _parseArticle(article);
      if (image != null) return image;
    }
    return null;
  }

  // 題名は「APOD: 2026 October 8 – The Saturn System Smörgåsbord」の形。
  static final _titlePrefix = RegExp(r'^APOD:\s*[^–\-]*[–\-]\s*');

  static ApodImage? _parseArticle(Map<String, dynamic> article) {
    final rawTitle = _text((article['title'] as Map?)?['rendered']);
    if (rawTitle == null || !rawTitle.startsWith('APOD:')) return null;

    final embedded = (article['_embedded'] as Map?)?['wp:featuredmedia'];
    final media = (embedded is List && embedded.isNotEmpty) ? embedded.first : null;
    if (media is! Map || media['media_type'] != 'image') return null;
    final source = media['source_url'];
    if (source is! String || !isApodImageUrl(source)) return null;

    final date = article['date'];
    return ApodImage(
      date: (date is String && date.length >= 10) ? date.substring(0, 10) : '',
      title: rawTitle.replaceFirst(_titlePrefix, ''),
      // 原寸は4000px超・数MBになることがあるので、背景には縮小版を使う。
      imageUrl: Uri.parse(source)
          .replace(queryParameters: {'w': '$_backgroundWidth'}).toString(),
      hdImageUrl: source,
      copyright: _text(media['credits']),
    );
  }

  /// HTMLの実体参照を戻し、改行・余分な空白を詰める。空なら null。
  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value
        .replaceAllMapped(RegExp(r'&#(\d+);'),
            (m) => String.fromCharCode(int.parse(m[1]!)))
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? null : text;
  }
}

class NasaApodServiceException implements Exception {
  NasaApodServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
