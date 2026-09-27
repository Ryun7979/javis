import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/apod.dart';
import 'cache_service.dart';

/// NASA APOD API（`api.nasa.gov/planetary/apod`）から最新の宇宙写真を取得するサービス。
///
/// 日付を指定せずに呼ぶと、その時点で公開済みの最新の1件が返る（公開は米国東部時間の日付単位）。
/// 動画の日はサムネイル画像を使い、サムネイルも無い日は前回の写真を使い続ける。
class NasaApodService {
  NasaApodService(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  final CacheService _cache;
  final http.Client _client;

  static const _cacheKey = 'nasa_apod';

  /// APIキー未設定時に使う共用キー（IPごとに1時間数十回まで。1日数回の取得なら足りる）。
  static const demoApiKey = 'DEMO_KEY';

  /// 前回の取得からこの時間が経つまでは通信せずキャッシュを返す。
  static const Duration _ttl = Duration(hours: 3);

  /// キャッシュ済みの写真（通信しない）。起動直後の即時表示用。
  ApodImage? cached() {
    final entry = _cache.read(_cacheKey);
    if (entry == null) return null;
    try {
      return ApodImage.fromJson(entry.$2 as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 最新の写真を返す。[force] が true ならキャッシュの鮮度によらず取り直す。
  /// 取得に失敗した場合や写真の無い日は、キャッシュ済みの写真（無ければ null）を返す。
  Future<ApodImage?> fetchLatest({
    required String apiKey,
    bool force = false,
  }) async {
    final entry = _cache.read(_cacheKey);
    final previous = cached();
    if (!force &&
        entry != null &&
        previous != null &&
        DateTime.now().difference(entry.$1) < _ttl) {
      return previous;
    }

    final uri = Uri.https('api.nasa.gov', '/planetary/apod', {
      'api_key': apiKey.trim().isEmpty ? demoApiKey : apiKey.trim(),
      'thumbs': 'true',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw NasaApodServiceException('HTTP ${res.statusCode}');
    }
    final image = parseResponse(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
    if (image == null) {
      // 写真の無い日。前回の写真をそのまま使い、TTLの間は問い合わせ直さない。
      if (previous != null) await _cache.writeJson(_cacheKey, previous.toJson());
      return previous;
    }
    await _cache.writeJson(_cacheKey, image.toJson());
    return image;
  }

  /// APIのレスポンスJSONから写真を作る。表示できる画像が無ければ null。
  static ApodImage? parseResponse(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String?;
    String? url;
    String? hdUrl;
    if (mediaType == 'image') {
      url = json['url'] as String?;
      hdUrl = json['hdurl'] as String?;
    } else if (mediaType == 'video') {
      url = json['thumbnail_url'] as String?;
    }
    if (url == null || url.isEmpty) return null;

    // 著作者名は改行を含んで返ることがある（例: "\nJohn Doe\n"）。
    final copyright = (json['copyright'] as String?)
        ?.replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return ApodImage(
      date: json['date'] as String? ?? '',
      title: (json['title'] as String? ?? '').trim(),
      imageUrl: url,
      hdImageUrl: (hdUrl == null || hdUrl.isEmpty) ? url : hdUrl,
      copyright: (copyright == null || copyright.isEmpty) ? null : copyright,
    );
  }
}

class NasaApodServiceException implements Exception {
  NasaApodServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
