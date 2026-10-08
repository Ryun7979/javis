import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wall_jarvis/models/apod.dart';
import 'package:wall_jarvis/services/cache_service.dart';
import 'package:wall_jarvis/services/nasa_apod_service.dart';

// 実際のレスポンス（2026-10-09取得、新しい順に3件）から使う項目だけ残したもの。
final String _fixture =
    File('test/fixtures/apod_image_articles.json').readAsStringSync();

List<dynamic> _articles() => jsonDecode(_fixture) as List<dynamic>;

// 移転後に旧API（api.nasa.gov）が返していたロゴ。キャッシュに残っている端末がある。
const _logo = ApodImage(
  date: '2026-10-08',
  title: 'NASA Science',
  imageUrl:
      'https://science.nasa.gov/wp-content/themes/nasa-child/assets/images/nasa-logo@2x.png',
  hdImageUrl:
      'https://science.nasa.gov/wp-content/themes/nasa-child/assets/images/nasa-logo@2x.png',
);

http.Response _json(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json; charset=UTF-8'},
    );

void main() {
  group('NasaApodService.parseResponse', () {
    test('最新の記事から日付・題名・縮小版と原寸のURL・著作者を取る', () {
      final apod = NasaApodService.parseResponse(_articles())!;
      expect(apod.date, '2026-10-08');
      expect(apod.title, 'The Saturn System Smörgåsbord');
      expect(apod.hdImageUrl,
          endsWith('/apod/apod/2026/october/2026-09-21-2349_3-TW-RGB-Sat2_1.5x_Labelled.png'));
      expect(apod.imageUrl, '${apod.hdImageUrl}?w=1280');
      expect(apod.copyright, 'Tom Williams');
    });

    test('著作者の実体参照を戻す', () {
      final apod = NasaApodService.parseResponse(_articles().sublist(1))!;
      expect(apod.title, 'Supernova Remnant Pa 30');
      expect(apod.copyright, contains('Harvard & Smithsonian'));
      expect(apod.copyright, isNot(contains('&amp;')));
    });

    test('著作者が空ならnull', () {
      final articles = _articles();
      articles[0]['_embedded']['wp:featuredmedia'][0]['credits'] = '';
      expect(NasaApodService.parseResponse(articles)!.copyright, isNull);
    });

    test('写真の無い記事・APOD以外の記事・ロゴは飛ばして、次の記事を使う', () {
      final articles = _articles();
      // 1件目: 画像なし（動画の日など）
      articles[0]['_embedded'] = <String, dynamic>{};
      // 2件目: 検索に掛かったAPOD以外の記事
      articles[1]['title']['rendered'] = 'Hubble Spots an Apod-like Galaxy';
      final apod = NasaApodService.parseResponse(articles)!;
      expect(apod.date, '2026-10-06');
      expect(apod.title, 'A Complete Auroral Oval from SMILE');

      articles[2]['_embedded']['wp:featuredmedia'][0]['source_url'] =
          _logo.imageUrl;
      expect(NasaApodService.parseResponse(articles), isNull);
    });

    test('一覧でない応答は写真なし', () {
      expect(NasaApodService.parseResponse({'code': 'rest_no_route'}), isNull);
      expect(NasaApodService.parseResponse(const []), isNull);
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

    test('NASA Scienceの記事一覧を日付の新しい順で取得し、TTL内は通信せずキャッシュを返す', () async {
      final requests = <Uri>[];
      final service = serviceReturning([_json(_articles())], requests);

      final first = await service.fetchLatest();
      final second = await service.fetchLatest();

      expect(first!.date, '2026-10-08');
      expect(second!.date, '2026-10-08');
      expect(requests, hasLength(1));
      expect(requests.single.host, 'science.nasa.gov');
      expect(requests.single.path, '/wp-json/wp/v2/image-article');
      expect(requests.single.queryParameters['search'], 'apod');
      expect(requests.single.queryParameters['orderby'], 'date');
      expect(requests.single.queryParameters['order'], 'desc');
    });

    test('写真のある記事が無ければ前回の写真を使い続ける', () async {
      final requests = <Uri>[];
      final service = serviceReturning([
        _json(_articles()),
        _json(const []),
      ], requests);

      await service.fetchLatest();
      final result = await service.fetchLatest(force: true);

      expect(requests, hasLength(2));
      expect(result!.date, '2026-10-08');
      expect(service.cached()!.date, '2026-10-08');
    });

    test('取得失敗は例外になり、キャッシュは残る', () async {
      final requests = <Uri>[];
      final service = serviceReturning([
        _json(_articles()),
        http.Response('error', 500),
      ], requests);

      await service.fetchLatest();
      await expectLater(
        service.fetchLatest(force: true),
        throwsA(isA<NasaApodServiceException>()),
      );
      expect(service.cached()!.date, '2026-10-08');
    });

    test('キャッシュに残った旧APIのロゴは捨て、TTL内でも取り直す', () async {
      await CacheService.withBox(box).writeJson('nasa_apod', _logo.toJson());
      final requests = <Uri>[];
      final service = serviceReturning([_json(_articles())], requests);

      expect(service.cached(), isNull);
      final result = await service.fetchLatest();

      expect(requests, hasLength(1));
      expect(result!.title, 'The Saturn System Smörgåsbord');
    });
  });
}
