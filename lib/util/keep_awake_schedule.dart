/// 画面を常時点灯にする時間帯のスケジュール（平日・土曜・日曜で個別）。
///
/// 時間帯の外では常時点灯をやめ、本体の「画面消灯までの時間」の設定に従って消えるようにする
/// （液晶の焼き付き防止と節電のため）。祝日は曜日どおりに扱う（ユーザー承認済み）。
/// 引数の時刻は `appNow()` の壁時計値を想定する。
library;

enum KeepAwakeMode {
  allDay('終日'),
  range('時間指定'),
  off('なし');

  const KeepAwakeMode(this.label);
  final String label;
}

/// 1日分の常時点灯の設定。時刻は0時からの分（0〜1439）。
///
/// [range] で開始が終了より遅いときは日をまたぐ（例: 19:00〜翌2:00）。日をまたいだ部分も
/// 開始した日の設定に従う。開始と終了が同じときは点灯する時間がない扱い。
class KeepAwakeDay {
  const KeepAwakeDay({
    required this.mode,
    required this.startMinute,
    required this.endMinute,
  });

  final KeepAwakeMode mode;
  final int startMinute;
  final int endMinute;

  bool get crossesMidnight =>
      mode == KeepAwakeMode.range && startMinute > endMinute;

  /// この日の設定で、同じ日の [minute]（0時からの分）に点灯しているか（翌日へはみ出す分は含まない）。
  bool coversSameDay(int minute) => switch (mode) {
        KeepAwakeMode.allDay => true,
        KeepAwakeMode.off => false,
        KeepAwakeMode.range => startMinute < endMinute
            ? minute >= startMinute && minute < endMinute
            : startMinute > endMinute && minute >= startMinute,
      };

  /// この日の設定が翌日の [minute] まではみ出して点灯しているか。
  bool coversNextDay(int minute) => crossesMidnight && minute < endMinute;

  KeepAwakeDay copyWith({
    KeepAwakeMode? mode,
    int? startMinute,
    int? endMinute,
  }) =>
      KeepAwakeDay(
        mode: mode ?? this.mode,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'start': startMinute,
        'end': endMinute,
      };

  factory KeepAwakeDay.fromJson(Map<String, dynamic> json) => KeepAwakeDay(
        mode: KeepAwakeMode.values.asNameMap()[json['mode']] ??
            KeepAwakeMode.allDay,
        startMinute: json['start'] as int? ?? defaultStartMinute,
        endMinute: json['end'] as int? ?? defaultEndMinute,
      );

  /// 「時間指定」に切り替えたときに最初に入っている時間帯（7:00〜23:00）。
  static const defaultStartMinute = 7 * 60;
  static const defaultEndMinute = 23 * 60;

  /// 機能追加前と同じ動き（終日点灯）。
  static const allDayDefault = KeepAwakeDay(
    mode: KeepAwakeMode.allDay,
    startMinute: defaultStartMinute,
    endMinute: defaultEndMinute,
  );
}

class KeepAwakeSchedule {
  const KeepAwakeSchedule({
    required this.weekday,
    required this.saturday,
    required this.sunday,
  });

  final KeepAwakeDay weekday;
  final KeepAwakeDay saturday;
  final KeepAwakeDay sunday;

  /// 既存の端末でも今までどおり動くよう、既定は全曜日とも終日点灯。
  static const defaults = KeepAwakeSchedule(
    weekday: KeepAwakeDay.allDayDefault,
    saturday: KeepAwakeDay.allDayDefault,
    sunday: KeepAwakeDay.allDayDefault,
  );

  KeepAwakeDay forDate(DateTime date) => switch (date.weekday) {
        DateTime.saturday => saturday,
        DateTime.sunday => sunday,
        _ => weekday,
      };

  /// [now] の時刻に常時点灯にするか。前日の設定が日をまたいで続いている分も含める。
  bool isActive(DateTime now) {
    final minute = now.hour * 60 + now.minute;
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return forDate(now).coversSameDay(minute) ||
        forDate(yesterday).coversNextDay(minute);
  }

  KeepAwakeSchedule copyWith({
    KeepAwakeDay? weekday,
    KeepAwakeDay? saturday,
    KeepAwakeDay? sunday,
  }) =>
      KeepAwakeSchedule(
        weekday: weekday ?? this.weekday,
        saturday: saturday ?? this.saturday,
        sunday: sunday ?? this.sunday,
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday.toJson(),
        'saturday': saturday.toJson(),
        'sunday': sunday.toJson(),
      };

  factory KeepAwakeSchedule.fromJson(Map<String, dynamic> json) {
    KeepAwakeDay day(String key) => json[key] is Map<String, dynamic>
        ? KeepAwakeDay.fromJson(json[key] as Map<String, dynamic>)
        : KeepAwakeDay.allDayDefault;
    return KeepAwakeSchedule(
      weekday: day('weekday'),
      saturday: day('saturday'),
      sunday: day('sunday'),
    );
  }
}
