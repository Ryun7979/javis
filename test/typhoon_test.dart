// 台風情報（気象庁 bosai/typhoon）の解析・日本付近の判定・ニュース欄の定期切り替えのテスト。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wall_jarvis/models/app_settings.dart';
import 'package:wall_jarvis/models/typhoon.dart';
import 'package:wall_jarvis/providers/core_providers.dart';
import 'package:wall_jarvis/providers/earthquake_controller.dart';
import 'package:wall_jarvis/providers/typhoon_controller.dart';
import 'package:wall_jarvis/services/earthquake_service.dart';
import 'package:wall_jarvis/services/typhoon_service.dart';
import 'package:wall_jarvis/util/aligned_timer.dart';
import 'package:wall_jarvis/util/geo.dart';
import 'package:wall_jarvis/widgets/news_quake_panel.dart';

const target = {
  'tropicalCyclone': 'TC2633',
  'typhoonNumber': '2627',
  'category': 'TY',
  'issue': '2026-10-03T21:45:00+09:00',
};

List<dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as List<dynamic>;

/// 実データ（2026-10-03 21:45発表、台風27号・小笠原近海）。
Typhoon choiwan() => Typhoon.parse(
  target,
  fixture('typhoon_specifications.json'),
  fixture('typhoon_forecast.json'),
)!;

/// 実況だけの最小の台風情報（位置と種別を指定）。
Typhoon simple({
  required double lat,
  required double lon,
  String jp = '台風',
  String en = 'TY',
  String issue = '2026-10-03T12:45:00Z',
}) => Typhoon.parse(
  {'tropicalCyclone': 'TC9999', 'typhoonNumber': '2601', 'category': en},
  [
    {
      'part': 'title',
      'issue': {'UTC': issue},
      'typhoonNumber': en == 'TD' ? '' : '2601',
    },
    {
      'part': {'jp': '実況'},
      'advancedHours': 0,
      'category': {'jp': jp, 'en': en},
      'position': {
        'deg': [lat, lon],
      },
      'speed': {'km/h': 'ゆっくり'},
      'pressure': '1000',
      'validtime': {'UTC': '2026-10-03T12:00:00Z'},
    },
  ],
  [
    {
      'advancedHours': 0,
      'center': [lat, lon],
    },
  ],
)!;

void main() {
  group('geo', () {
    test('北へ111.19km進むと緯度が約1度増える', () {
      final p = destinationPoint(const GeoPoint(30, 140), 0, 111195);
      expect(p.latitude, closeTo(31, 0.001));
      expect(p.longitude, closeTo(140, 0.001));
    });

    test('東へ進むと経度が増え、距離は元に戻る', () {
      const from = GeoPoint(21.9, 146.9);
      final p = destinationPoint(from, 90, 222240);
      expect(p.longitude, greaterThan(146.9));
      expect(distanceKm(from, p), closeTo(222.24, 0.1));
    });
  });

  group('Typhoon.parse', () {
    test('実況の内容を読む', () {
      final t = choiwan();
      expect(t.id, 'TC2633');
      expect(t.number, 27);
      expect(t.label, '台風27号');
      expect(t.name, 'チョーイワン');
      expect(t.isTyphoon, isTrue);
      expect(t.scale, '大型');
      expect(t.intensity, '強い');
      expect(t.location, '小笠原近海');
      expect(t.course, '北北東');
      expect(t.speed, '15km/h');
      expect(t.pressureHpa, 960);
      expect(t.maxWindMs, 40);
      expect(t.maxGustMs, 55);
      expect(t.center, const GeoPoint(20.3, 146.2));
      expect(t.issuedAtUtc, DateTime.utc(2026, 10, 3, 12, 45));
      expect(t.validTimeUtc, DateTime.utc(2026, 10, 3, 12));
    });

    test('経路・強風域・暴風域・暴風警戒域を読む', () {
      final t = choiwan();
      // 台風になる前の3点＋台風になってからの23点。最後が現在位置。
      expect(t.track, hasLength(26));
      expect(t.track.last, t.center);
      expect(t.galeArea.circles.single.radiusM, 666720);
      expect(t.galeArea.circles.single.center, const GeoPoint(18.79, 146.2));
      expect(t.stormArea.arcs.single.radiusM, 129640);
      expect(t.stormArea.arcs.single.endDeg, 360);
      // 暴風警戒域は最後（96時間後）の予報に付いた形を使う。
      expect(t.stormWarningArea.arcs, hasLength(7));
      expect(t.stormWarningArea.lines, hasLength(10));
    });

    test('予報円を読む', () {
      final t = choiwan();
      expect(t.forecasts.map((f) => f.advancedHours), [12, 24, 48, 72, 96]);
      final f = t.forecasts[1];
      expect(f.center, const GeoPoint(23.2, 146.8));
      expect(f.probabilityRadiusM, 77784);
      expect(f.tangents, hasLength(2));
      expect(f.validTimeUtc, DateTime.utc(2026, 10, 4, 12));
      expect(f.pressureHpa, 925);
      expect(f.maxWindMs, 50);
      expect(t.forecasts.last.categoryJp, '温帯低気圧');
    });

    test('数字でない速さ・該当なしの項目', () {
      final t = simple(lat: 20, lon: 140);
      expect(t.speed, 'ゆっくり');
      expect(t.scale, isNull);
      expect(t.forecasts, isEmpty);
      expect(t.galeArea.isEmpty, isTrue);
    });

    test('熱帯低気圧は台風として扱わない', () {
      final t = simple(lat: 25, lon: 135, jp: '熱帯低気圧', en: 'TD');
      expect(t.isTyphoon, isFalse);
      expect(t.number, isNull);
      expect(t.label, '熱帯低気圧');
    });

    test('位置が読めなければnull', () {
      expect(Typhoon.parse(target, const [], const []), isNull);
    });
  });

  group('日本付近の判定', () {
    test('現在は遠くても、予報円が日本付近に入れば対象', () {
      final t = choiwan();
      // 現在位置（北緯20.3度）は父島から800km以上離れているが、48時間後に父島付近を通る。
      expect(distanceKm(t.center, const GeoPoint(27.09, 142.19)), greaterThan(800));
      expect(t.closestApproachKm, lessThan(Typhoon.approachThresholdKm));
      expect(t.approachesJapan, isTrue);
    });

    test('日本から遠い台風は対象外', () {
      expect(simple(lat: 10, lon: 165).approachesJapan, isFalse);
      expect(simple(lat: 14, lon: 112).approachesJapan, isFalse);
    });

    test('沖縄・本州の近くは対象', () {
      expect(simple(lat: 23, lon: 126).approachesJapan, isTrue);
      expect(simple(lat: 31, lon: 136).approachesJapan, isTrue);
    });
  });

  group('TyphoonController', () {
    test('日本付近の台風だけを切り替えの対象にする', () async {
      final service = _FakeTyphoonService([
        choiwan(),
        simple(lat: 10, lon: 165),
        simple(lat: 25, lon: 135, jp: '熱帯低気圧', en: 'TD'),
      ]);
      final c = TyphoonController(service);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.typhoons, hasLength(3));
      expect(c.state.approaching.map((t) => t.id), ['TC2633']);
      c.dispose();
    });

    test('取得に失敗しても表示は残し、発表から12時間を過ぎたら消す', () async {
      var now = DateTime.utc(2026, 10, 3, 13);
      final service = _FakeTyphoonService([choiwan()]);
      final c = TyphoonController(service, now: () => now);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.typhoons, hasLength(1));

      service.fail = true;
      await c.refresh();
      expect(c.state.typhoons, hasLength(1));
      expect(c.state.error, isNotNull);

      now = DateTime.utc(2026, 10, 4, 1);
      await c.refresh();
      expect(c.state.typhoons, isEmpty);
      c.dispose();
    });
  });

  test('切り替え間隔の設定は保存・復元でき、古い設定では既定値（10分）になる', () {
    final s = AppSettings.defaults().copyWith(typhoonSwitchIntervalMinutes: 30);
    expect(AppSettings.fromJson(s.toJson()).typhoonSwitchIntervalMinutes, 30);
    final old = AppSettings.defaults().toJson()
      ..remove('typhoonSwitchIntervalMinutes');
    expect(AppSettings.fromJson(old).typhoonSwitchIntervalMinutes, 10);
  });

  group('NewsQuakePanel の台風による切り替え', () {
    Future<(ProviderContainer, _FakeTyphoonService)> pumpPanel(
      WidgetTester tester,
      List<Typhoon> typhoons, {
      int minutes = 10,
    }) async {
      final service = _FakeTyphoonService(typhoons);
      final container = ProviderContainer(
        overrides: [
          earthquakeServiceProvider.overrideWithValue(_NoQuakeService()),
          typhoonServiceProvider.overrideWithValue(service),
          typhoonSwitchIntervalProvider.overrideWithValue(minutes),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: NewsQuakePanel(
                clock: () => tester.binding.clock.now(),
                newsBuilder: (b) => Row(children: [const Text('NEWS'), b]),
                quakeBuilder: (b) => Row(children: [const Text('MAP'), b]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (container, service);
    }

    /// 次の区切り（毎時0分起点）の直後まで進める。
    Future<void> toNextSlot(WidgetTester tester, int minutes) async {
      await tester.pump(
        durationUntilNextSlot(tester.binding.clock.now(), minutes) +
            const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester, ProviderContainer c) async {
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }

    testWidgets('日本付近に台風がある間、区切りごとにニュースと地図を交互に表示する', (tester) async {
      final (container, service) = await pumpPanel(tester, [choiwan()]);
      expect(find.text('NEWS'), findsOneWidget);

      await toNextSlot(tester, 10);
      expect(find.text('MAP'), findsOneWidget);
      await toNextSlot(tester, 10);
      expect(find.text('NEWS'), findsOneWidget);
      await toNextSlot(tester, 10);
      expect(find.text('MAP'), findsOneWidget);

      // 台風がなくなったら、区切りを待たずにニュースへ戻り、以後は切り替えない。
      service.typhoons = [];
      await container.read(typhoonControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.text('NEWS'), findsOneWidget);
      await toNextSlot(tester, 10);
      expect(find.text('NEWS'), findsOneWidget);

      await close(tester, container);
    });

    testWidgets('遠い台風・熱帯低気圧だけなら切り替えない', (tester) async {
      final (container, _) = await pumpPanel(tester, [
        simple(lat: 10, lon: 165),
        simple(lat: 25, lon: 135, jp: '熱帯低気圧', en: 'TD'),
      ]);
      await toNextSlot(tester, 10);
      expect(find.text('NEWS'), findsOneWidget);
      await close(tester, container);
    });

    testWidgets('間隔が0なら切り替えない', (tester) async {
      final (container, _) = await pumpPanel(tester, [choiwan()], minutes: 0);
      await tester.pump(const Duration(minutes: 31));
      await tester.pumpAndSettle();
      expect(find.text('NEWS'), findsOneWidget);
      await close(tester, container);
    });

    testWidgets('地震で切り替えた30分間は、台風の区切りでもニュースに戻さない', (tester) async {
      final (container, _) = await pumpPanel(tester, [choiwan()]);
      final quake = container.read(earthquakeControllerProvider.notifier);
      // 地震の合図（震度3以上の新しい地震を検出したときと同じ状態の変化）。
      quake.state = quake.state.copyWith(alertSeq: 1);
      await tester.pumpAndSettle();
      expect(find.text('MAP'), findsOneWidget);

      await toNextSlot(tester, 10);
      expect(find.text('MAP'), findsOneWidget);
      await toNextSlot(tester, 10);
      expect(find.text('MAP'), findsOneWidget);

      // 30分たつとニュースへ戻り、その後は台風の区切りでまた切り替わる。
      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();
      expect(find.text('NEWS'), findsOneWidget);
      await toNextSlot(tester, 10);
      expect(find.text('MAP'), findsOneWidget);

      await close(tester, container);
    });
  });
}

class _FakeTyphoonService extends TyphoonService {
  _FakeTyphoonService(this.typhoons);

  List<Typhoon> typhoons;
  bool fail = false;

  @override
  Future<List<Typhoon>> fetchAll() async {
    if (fail) throw Exception('offline');
    return typhoons;
  }
}

class _NoQuakeService extends EarthquakeService {
  @override
  Future<List<dynamic>> fetchHistory() async => const [];

  @override
  Future<List<dynamic>> fetchLatest() async => const [];
}
