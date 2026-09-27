import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/models/app_settings.dart';
import 'package:wall_jarvis/util/aligned_timer.dart';

void main() {
  group('durationUntilNextSlot', () {
    test('15分刻みなら次の00・15・30・45分まで', () {
      expect(
        durationUntilNextSlot(DateTime(2026, 9, 27, 10, 7, 30), 15),
        const Duration(minutes: 7, seconds: 30),
      );
      expect(
        durationUntilNextSlot(DateTime(2026, 9, 27, 10, 52), 15),
        const Duration(minutes: 8),
      );
    });

    test('ちょうど区切りの時刻なら、その次の区切りまで', () {
      expect(
        durationUntilNextSlot(DateTime(2026, 9, 27, 10, 30), 15),
        const Duration(minutes: 15),
      );
      expect(
        durationUntilNextSlot(DateTime(2026, 9, 27, 10, 0), 60),
        const Duration(hours: 1),
      );
    });

    test('ミリ秒まで考慮する', () {
      expect(
        durationUntilNextSlot(DateTime(2026, 9, 27, 10, 2, 59, 900), 3),
        const Duration(milliseconds: 100),
      );
    });

    test('60の約数でない間隔は毎時0分で揃え直す', () {
      expect(
        durationUntilNextSlot(DateTime(2026, 9, 27, 10, 50), 45),
        const Duration(minutes: 10),
      );
    });
  });

  group('AlignedPeriodicTimer', () {
    testWidgets('起動時刻によらず区切りの時刻に呼ばれる', (tester) async {
      var clock = DateTime(2026, 9, 27, 10, 7, 30);
      final ticks = <DateTime>[];
      final timer = AlignedPeriodicTimer(
        intervalMinutes: 15,
        now: () => clock,
        onTick: () => ticks.add(clock),
      );
      Future<void> advance(Duration d) async {
        clock = clock.add(d);
        await tester.pump(d);
      }

      await advance(const Duration(minutes: 7, seconds: 29));
      expect(ticks, isEmpty);
      await advance(const Duration(seconds: 1));
      await advance(const Duration(minutes: 15));
      await advance(const Duration(minutes: 15));
      expect(ticks, [
        DateTime(2026, 9, 27, 10, 15),
        DateTime(2026, 9, 27, 10, 30),
        DateTime(2026, 9, 27, 10, 45),
      ]);
      timer.cancel();
    });

    testWidgets('手動操作の直後の区切りは1回見送る', (tester) async {
      var clock = DateTime(2026, 9, 27, 10, 0);
      final ticks = <DateTime>[];
      final timer = AlignedPeriodicTimer(
        intervalMinutes: 10,
        now: () => clock,
        onTick: () => ticks.add(clock),
      );
      Future<void> advance(Duration d) async {
        clock = clock.add(d);
        await tester.pump(d);
      }

      // 10:08（次の区切りまで2分＝間隔の半分未満）の操作では 10:10 を見送り 10:20 に呼ぶ。
      await advance(const Duration(minutes: 8));
      timer.deferIfSoon();
      await advance(const Duration(minutes: 2));
      expect(ticks, isEmpty);
      await advance(const Duration(minutes: 10));
      expect(ticks, [DateTime(2026, 9, 27, 10, 20)]);

      // 10:23（次の区切りまで7分）の操作では見送らない。
      await advance(const Duration(minutes: 3));
      timer.deferIfSoon();
      await advance(const Duration(minutes: 7));
      expect(ticks.last, DateTime(2026, 9, 27, 10, 30));
      timer.cancel();
    });

    testWidgets('区切りのわずかに手前で発火しても同じ区切りで2回呼ばない', (tester) async {
      var clock = DateTime(2026, 9, 27, 10, 1);
      var skew = Duration.zero;
      var count = 0;
      final timer = AlignedPeriodicTimer(
        intervalMinutes: 5,
        now: () => clock.add(skew),
        onTick: () => count++,
      );
      // 予約したあとで端末の時計が2ミリ秒遅れ、10:05の直前に発火したように見える状況を再現する。
      skew = const Duration(milliseconds: -2);
      clock = clock.add(const Duration(minutes: 4));
      await tester.pump(const Duration(minutes: 4));
      expect(count, 1);
      clock = clock.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(count, 1);
      timer.cancel();
    });
  });

  test('保存済みの潮汐・天気の更新間隔45分は30分に読み替える', () {
    final json = AppSettings.defaults().toJson()
      ..['tideWeatherUpdateIntervalMinutes'] = 45;
    expect(
      AppSettings.fromJson(json).tideWeatherUpdateIntervalMinutes,
      30,
    );
  });
}
