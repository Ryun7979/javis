import 'dart:math' as math;

/// 日の出・日没時刻の概算計算（均時差は無視した簡易版、誤差は数十分程度）。
/// マズメ時（釣りやすいとされる時間帯）の判定に使うための目安。
class SunTimes {
  const SunTimes({required this.sunrise, required this.sunset});
  final DateTime sunrise;
  final DateTime sunset;
}

SunTimes calculateSunTimes(DateTime localDate, double latitude, double longitude) {
  final dayOfYear =
      localDate.difference(DateTime(localDate.year, 1, 1)).inDays + 1;

  final declinationDeg =
      -23.44 * math.cos(_deg2rad(360 / 365 * (dayOfYear + 10)));
  final latRad = _deg2rad(latitude);
  final declRad = _deg2rad(declinationDeg);

  var cosHourAngle = -math.tan(latRad) * math.tan(declRad);
  cosHourAngle = cosHourAngle.clamp(-1.0, 1.0);
  final hourAngleDeg = _rad2deg(math.acos(cosHourAngle));

  // 日本標準時（UTC+9）を基準に、経度差分のみで補正する簡易計算。
  const jstOffsetHours = 9.0;
  final solarNoonJst =
      12.0 - (longitude - jstOffsetHours * 15) / 15.0;
  final halfDayHours = hourAngleDeg / 15.0;

  final sunriseHour = solarNoonJst - halfDayHours;
  final sunsetHour = solarNoonJst + halfDayHours;

  return SunTimes(
    sunrise: _addHours(localDate, sunriseHour),
    sunset: _addHours(localDate, sunsetHour),
  );
}

DateTime _addHours(DateTime date, double hours) {
  final base = DateTime(date.year, date.month, date.day);
  final minutes = (hours * 60).round();
  return base.add(Duration(minutes: minutes));
}

double _deg2rad(double deg) => deg * math.pi / 180;
double _rad2deg(double rad) => rad * 180 / math.pi;
