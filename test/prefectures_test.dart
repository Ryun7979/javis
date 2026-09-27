import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/data/observation_points.dart';
import 'package:wall_jarvis/data/prefectures.dart';
import 'package:wall_jarvis/models/app_settings.dart';
import 'package:wall_jarvis/util/web_mercator.dart';

void main() {
  test('都道府県は47件でコードの重複がなく、県庁所在地は地方の範囲内にある', () {
    expect(prefectures.length, 47);
    expect(allPrefectureCodes.length, 47);
    for (final p in prefectures) {
      final r = p.region;
      expect(p.latitude, inInclusiveRange(r.south, r.north), reason: p.name);
      expect(p.longitude, inInclusiveRange(r.west, r.east), reason: p.name);
    }
  });

  test('観測地点から最も近い県庁所在地で地方を決める', () {
    JapanRegion regionOf(String id) {
      final p = findObservationPoint(id);
      return nearestPrefecture(p.latitude, p.longitude).region;
    }

    expect(regionOf('yokohama'), JapanRegion.kanto);
    expect(regionOf('chiba_choshi'), JapanRegion.kanto);
    expect(regionOf('shimizu'), JapanRegion.chubu);
    expect(regionOf('osaka'), JapanRegion.kinki);
    // 全観測地点について、決めた地方の範囲に観測地点が入っていること。
    for (final p in observationPoints) {
      final r = nearestPrefecture(p.latitude, p.longitude).region;
      expect(p.latitude, inInclusiveRange(r.south - 0.5, r.north + 0.5),
          reason: p.name);
      expect(p.longitude, inInclusiveRange(r.west - 0.5, r.east + 0.5),
          reason: p.name);
    }
  });

  test('fitZoom で求めたズームなら範囲がちょうど画面に収まる', () {
    const size = Size(800, 400);
    const r = JapanRegion.kanto;
    final z = WebMercator.fitZoom(
      south: r.south,
      west: r.west,
      north: r.north,
      east: r.east,
      size: size,
    );
    final zi = z.floor();
    final scale = math.pow(2, z - zi).toDouble();
    final sw = WebMercator.project(r.south, r.west, zi) * scale;
    final ne = WebMercator.project(r.north, r.east, zi) * scale;
    final w = ne.dx - sw.dx;
    final h = sw.dy - ne.dy;
    expect(w, lessThanOrEqualTo(size.width + 0.01));
    expect(h, lessThanOrEqualTo(size.height + 0.01));
    // 縦横のどちらかは画面いっぱいになっている。
    expect(
      (w - size.width).abs() < 0.01 || (h - size.height).abs() < 0.01,
      isTrue,
    );
  });

  test('県庁所在地マークの設定はJSONで保存・復元でき、古い保存データでは全都道府県になる', () {
    final settings =
        AppSettings.defaults().copyWith(capitalMarkerPrefectures: {13, 14});
    expect(AppSettings.fromJson(settings.toJson()).capitalMarkerPrefectures,
        {13, 14});

    final json = AppSettings.defaults().toJson()
      ..remove('capitalMarkerPrefectures');
    expect(AppSettings.fromJson(json).capitalMarkerPrefectures,
        allPrefectureCodes);
  });
}
