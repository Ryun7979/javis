import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wall_jarvis/services/cache_service.dart';
import 'package:wall_jarvis/services/nasa_apod_service.dart';

// 実際のAPIレスポンス（2026-09-27取得）を縮めたもの。
const _image = {
  'date': '2026-09-27',
  'hdurl': 'https://apod.nasa.gov/apod/image/2609/M31Before_Scherer_4298.jpg',
  'media_type': 'image',
  'title': 'Andromeda before Photoshop',
  'url': 'https://apod.nasa.gov/apod/image/2609/M31Before_Scherer_960.jpg',
};

const _video = {
  'date': '2026-09-28',
  'media_type': 'video',
  'title': 'A Video Day',
  'url': 'https://www.youtube.com/embed/xxxx',
  'thumbnail_url': 'https://img.youtube.com/vi/xxxx/0.jpg',
};

void main() {
  group('NasaApodService.parseResponse', () {
    test('画像の日は通常版と高解像度版のURLを取り、著作者の無い日はnull', () {
      final apod = NasaApodService.parseResponse(_image)!;
      expect(apod.date, '2026-09-27');
      expect(apod.title, 'Andromeda before Photoshop');
      expect(apod.imageUrl, endsWith('_960.jpg'));
      expect(apod.hdImageUrl, endsWith('_4298.jpg'));
      expect(apod.copyright, isNull);
    });

    test('著作者名の改行・余分な空白を詰める', () {
      final apod = NasaApodService.parseResponse(
          {..._image, 'copyright': '\nGiuseppe  Petricca\n'})!;
      expect(apod.copyright, 'Giuseppe Petricca');
    });

    test('hdurl が無い日は通常版を全画面にも使う', () {
      final apod =
          NasaApodService.parseResponse({..._image}..remove('hdurl'))!;
      expect(apod.hdImageUrl, apod.imageUrl);
    });

    test('動画の日はサムネイルを使う', () {
      final apod = NasaApodService.parseResponse(_video)!;
      expect(apod.imageUrl, 'https://img.youtube.com/vi/xxxx/0.jpg');
      expect(apod.hdImageUrl, apod.imageUrl);
    });

    test('サムネイルの無い動画や、その他の種類は写真なし', () {
      expect(
          NasaApodService.parseResponse({..._video}..remove('thumbnail_url')),
          isNull);
      expect(
          NasaApodService.parseResponse({'media_type': 'other', 'title': 'x'}),
          isNull);
    });
  });

  group('NasaApodService.fetchLatest', () {
    late Box<String> box;

    setUp(() async {
      Hive.init('${Directory.systemTemp.path}/wall_jarvis_apod_test_'
          '${DateTime.now().microsecondsSinceEpoch}');
      box = await Hive.openBox<String>('test_cache');
    });

    tearDown(() async {
      await box.deleteFromDisk();
    });

    NasaApodService serviceReturning(
      List<http.Response> responses,
      List<Uri> requests,
    ) {
      var i = 0;
      return NasaApodService(
        CacheService.withBox(box),
        client: MockClient((request) async {
          requests.add(request.url);
          return responses[i++];
        }),
      );
    }

    test('APIキー未設定ならDEMO_KEYで取得し、TTL内は通信せずキャッシュを返す', () async {
      final requests = <Uri>[];
      final service =
          serviceReturning([http.Response(jsonEncode(_image), 200)], requests);

      final first = await service.fetchLatest(apiKey: '');
      final second = await service.fetchLatest(apiKey: '');

      expect(first!.date, '2026-09-27');
      expect(second!.date, '2026-09-27');
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['api_key'], 'DEMO_KEY');
      expect(requests.single.queryParameters['thumbs'], 'true');
    });

    test('APIキー設定時はそのキーを使う', () async {
      final requests = <Uri>[];
      final service =
          serviceReturning([http.Response(jsonEncode(_image), 200)], requests);
      await service.fetchLatest(apiKey: ' my-key ');
      expect(requests.single.queryParameters['api_key'], 'my-key');
    });

    test('写真の無い日は前回の写真を使い続ける', () async {
      final requests = <Uri>[];
      final service = serviceReturning([
        http.Response(jsonEncode(_image), 200),
        http.Response(
            jsonEncode({..._video}..remove('thumbnail_url')), 200),
      ], requests);

      await service.fetchLatest(apiKey: '');
      final result = await service.fetchLatest(apiKey: '', force: true);

      expect(requests, hasLength(2));
      expect(result!.date, '2026-09-27');
      expect(service.cached()!.date, '2026-09-27');
    });

    test('取得失敗は例外になり、キャッシュは残る', () async {
      final requests = <Uri>[];
      final service = serviceReturning([
        http.Response(jsonEncode(_image), 200),
        http.Response('rate limited', 429),
      ], requests);

      await service.fetchLatest(apiKey: '');
      await expectLater(
        service.fetchLatest(apiKey: '', force: true),
        throwsA(isA<NasaApodServiceException>()),
      );
      expect(service.cached()!.date, '2026-09-27');
    });
  });
}
