import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/services/rain_radar_service.dart';
import 'package:wall_jarvis/util/web_mercator.dart';

Map<String, dynamic> _entry(String base, String valid,
        [List<String> elements = const ['hrpns', 'hrpns_nd']]) =>
    {'basetime': base, 'validtime': valid, 'elements': elements};

String _t(int hour, int minute) =>
    '20260925${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}00';

void main() {
  group('RainRadarService.buildFrames', () {
    // 実況: 13:30〜15:30 を5分おき（新しい順、気象庁の並びどおり）。
    final n1 = [
      for (var m = 15 * 60 + 30; m >= 13 * 60 + 30; m -= 5)
        _entry(_t(m ~/ 60, m % 60), _t(m ~/ 60, m % 60)),
    ];
    // 予報: 最新basetime(15:30)で 15:35〜16:30、古いbasetime(15:25)の予報も混在。
    final n2 = [
      for (var m = 16 * 60 + 30; m >= 15 * 60 + 35; m -= 5)
        _entry(_t(15, 30), _t(m ~/ 60, m % 60)),
      _entry(_t(15, 25), _t(16, 25)),
    ];

    final frames = RainRadarService.buildFrames(n1: n1, n2: n2);

    test('過去1時間の実況のあとに1時間先までの予報が古い順に並ぶ', () {
      final past = frames.where((f) => !f.isForecast).toList();
      final forecast = frames.where((f) => f.isForecast).toList();
      expect(past.length, 13); // 14:30〜15:30
      expect(past.first.validtime, _t(14, 30));
      expect(past.last.validtime, _t(15, 30));
      expect(forecast.length, 12); // 15:35〜16:30
      expect(forecast.first.validtime, _t(15, 35));
      expect(forecast.last.validtime, _t(16, 30));
      expect(frames.indexOf(past.last) + 1, frames.indexOf(forecast.first));
    });

    test('予報は最新のbasetimeのものだけを使う', () {
      expect(
        frames.where((f) => f.isForecast).every((f) => f.basetime == _t(15, 30)),
        isTrue,
      );
    });

    test('予報の更新が実況より遅れていても、1つ前のbasetimeの予報で補う', () {
      // 実況は15:35まで出ているが、予報はまだbasetime 15:30のまま。
      final lagged = RainRadarService.buildFrames(
        n1: [_entry(_t(15, 35), _t(15, 35)), ...n1],
        n2: n2,
      );
      final forecast = lagged.where((f) => f.isForecast).toList();
      expect(forecast.first.validtime, _t(15, 40));
      expect(forecast.last.validtime, _t(16, 30));
      expect(forecast.every((f) => f.basetime == _t(15, 30)), isTrue);
    });

    test('時刻はUTCとして読む', () {
      expect(frames.last.validTimeUtc, DateTime.utc(2026, 9, 25, 16, 30));
    });

    test('hrpnsを含まない時刻は除外する', () {
      final result = RainRadarService.buildFrames(
        n1: [_entry(_t(15, 30), _t(15, 30), ['liden'])],
        n2: const [],
      );
      expect(result, isEmpty);
    });
  });

  test('雷は実況（basetime==validtime）でlidenを含む時刻だけを対象にする', () {
    final times = RainRadarService.lightningTimes([
      _entry(_t(15, 30), _t(15, 30), ['thns', 'liden']),
      _entry(_t(15, 25), _t(15, 25), ['liden']),
      _entry(_t(15, 30), _t(16, 0), ['thns']),
      _entry(_t(15, 20), _t(15, 20), ['thns']),
    ]);
    expect(times, {_t(15, 30), _t(15, 25)});
  });

  test('雷のGeoJSONから緯度経度を読む', () {
    final strikes = RainRadarService.parseStrikes({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [139.65, 35.45],
          },
          'properties': {'type': 4},
        },
      ],
    });
    expect(strikes.single.latitude, 35.45);
    expect(strikes.single.longitude, 139.65);
  });

  group('WebMercator', () {
    test('経度0・緯度0はズーム0で世界の中心になる', () {
      expect(WebMercator.project(0, 0, 0), const Offset(128, 128));
    });

    test('横浜はズーム8でタイル(227, 101)に入る', () {
      final p = WebMercator.project(35.45, 139.65, 8);
      expect((p.dx / 256).floor(), 227);
      expect((p.dy / 256).floor(), 101);
    });

    test('表示範囲を覆うタイルを過不足なく列挙する', () {
      final tiles = WebMercator.tilesCovering(
        const Rect.fromLTWH(300, 100, 300, 200),
        8,
      );
      expect(tiles, const [
        TileIndex(8, 1, 0),
        TileIndex(8, 2, 0),
        TileIndex(8, 1, 1),
        TileIndex(8, 2, 1),
      ]);
    });
  });
}
