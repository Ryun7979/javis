/// 月齢と潮回り（大潮・中潮・小潮など）の概算計算。
///
/// 気象庁の潮位表テキストには潮回りの区分が含まれていないため、天文学的な
/// 月齢から一般的に使われる対応表で概算する。地域や資料によって多少の差が
/// あるため、あくまで目安表示として扱う。
library;

const double _synodicMonthDays = 29.530588853;

/// 既知の新月（2000-01-06 18:14 UTC）を起点に月齢を計算する。
double moonAgeForDate(DateTime date) {
  final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
  final diffDays =
      date.toUtc().difference(knownNewMoon).inMinutes / (60 * 24);
  var age = diffDays % _synodicMonthDays;
  if (age < 0) age += _synodicMonthDays;
  return age;
}

/// 月齢から旧暦日（1〜30の目安）に丸め、潮回り名を返す。
String tidePhaseNameForMoonAge(double moonAge) {
  final lunarDay = moonAge.floor() + 1; // 1〜30程度
  if ([1, 2, 3, 26, 27, 28, 29, 30].contains(lunarDay)) return '大潮';
  if ([14, 15, 16].contains(lunarDay)) return '大潮';
  if ([4, 5, 6, 12, 13, 17, 18, 19, 24, 25].contains(lunarDay)) return '中潮';
  if ([7, 8, 9, 20, 21].contains(lunarDay)) return '小潮';
  if ([10, 22].contains(lunarDay)) return '長潮';
  if ([11, 23].contains(lunarDay)) return '若潮';
  return '中潮';
}
