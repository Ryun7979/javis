import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/models/app_settings.dart';
import 'package:wall_jarvis/util/keep_awake_schedule.dart';

KeepAwakeDay range(int startHour, int endHour) => KeepAwakeDay(
      mode: KeepAwakeMode.range,
      startMinute: startHour * 60,
      endMinute: endHour * 60,
    );

const off = KeepAwakeDay(
    mode: KeepAwakeMode.off, startMinute: 0, endMinute: 0);

void main() {
  // 2026-09-28は月曜、10-03は土曜、10-04は日曜。
  group('日をまたがない時間帯', () {
    final schedule = KeepAwakeSchedule(
      weekday: range(7, 23),
      saturday: range(9, 22),
      sunday: off,
    );

    test('開始時刻ちょうどから点灯し、終了時刻ちょうどで解除する', () {
      expect(schedule.isActive(DateTime(2026, 9, 28, 6, 59)), isFalse);
      expect(schedule.isActive(DateTime(2026, 9, 28, 7, 0)), isTrue);
      expect(schedule.isActive(DateTime(2026, 9, 28, 22, 59)), isTrue);
      expect(schedule.isActive(DateTime(2026, 9, 28, 23, 0)), isFalse);
    });

    test('土曜・日曜はそれぞれの設定に従う', () {
      expect(schedule.isActive(DateTime(2026, 10, 3, 8, 0)), isFalse);
      expect(schedule.isActive(DateTime(2026, 10, 3, 9, 0)), isTrue);
      expect(schedule.isActive(DateTime(2026, 10, 4, 12, 0)), isFalse);
    });
  });

  group('日をまたぐ時間帯', () {
    final schedule = KeepAwakeSchedule(
      weekday: range(19, 2),
      saturday: off,
      sunday: KeepAwakeDay.allDayDefault,
    );

    test('開始した日の設定が翌日の終了時刻まで続く', () {
      expect(schedule.isActive(DateTime(2026, 9, 28, 18, 59)), isFalse);
      expect(schedule.isActive(DateTime(2026, 9, 28, 19, 0)), isTrue);
      expect(schedule.isActive(DateTime(2026, 9, 29, 1, 59)), isTrue);
      expect(schedule.isActive(DateTime(2026, 9, 29, 2, 0)), isFalse);
    });

    test('金曜の夜の時間帯は土曜の未明まで続き、土曜の設定では延長されない', () {
      expect(schedule.isActive(DateTime(2026, 10, 3, 1, 0)), isTrue);
      expect(schedule.isActive(DateTime(2026, 10, 3, 2, 0)), isFalse);
      expect(schedule.isActive(DateTime(2026, 10, 3, 20, 0)), isFalse);
    });

    test('日曜の終日の設定は月曜の未明へはみ出さない', () {
      expect(schedule.isActive(DateTime(2026, 10, 4, 23, 59)), isTrue);
      expect(schedule.isActive(DateTime(2026, 10, 5, 0, 0)), isFalse);
      expect(schedule.isActive(DateTime(2026, 10, 5, 19, 0)), isTrue);
    });
  });

  test('開始と終了が同じ時間指定は点灯しない', () {
    final schedule = KeepAwakeSchedule(
      weekday: range(8, 8),
      saturday: off,
      sunday: off,
    );
    expect(schedule.isActive(DateTime(2026, 9, 28, 8, 0)), isFalse);
    expect(schedule.isActive(DateTime(2026, 9, 28, 20, 0)), isFalse);
  });

  test('常時点灯の時間帯はJSONで保存・復元できる', () {
    final settings = AppSettings.defaults().copyWith(
      keepAwakeSchedule: KeepAwakeSchedule(
        weekday: range(19, 2),
        saturday: range(9, 22),
        sunday: off,
      ),
    );
    final restored =
        AppSettings.fromJson(settings.toJson()).keepAwakeSchedule;
    expect(restored.weekday.mode, KeepAwakeMode.range);
    expect(restored.weekday.startMinute, 19 * 60);
    expect(restored.weekday.endMinute, 2 * 60);
    expect(restored.saturday.startMinute, 9 * 60);
    expect(restored.sunday.mode, KeepAwakeMode.off);
  });

  test('常時点灯の時間帯を含まない古い保存データは全曜日とも終日点灯で復元する', () {
    final json = AppSettings.defaults().toJson()..remove('keepAwakeSchedule');
    final restored = AppSettings.fromJson(json).keepAwakeSchedule;
    for (final day in [restored.weekday, restored.saturday, restored.sunday]) {
      expect(day.mode, KeepAwakeMode.allDay);
    }
    expect(restored.isActive(DateTime(2026, 9, 28, 3, 0)), isTrue);
  });
}
