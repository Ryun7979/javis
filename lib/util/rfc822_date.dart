/// RSS 2.0 の pubDate（RFC 822形式）を解析する。
/// 例: "Wed, 24 Sep 2026 01:00:00 +0900"
library;

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

final _rfc822Pattern = RegExp(
  r'(\d{1,2})\s+([A-Za-z]{3})\w*\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|UT|GMT)?',
);

DateTime? parseRfc822Date(String input) {
  final match = _rfc822Pattern.firstMatch(input.trim());
  if (match == null) return DateTime.tryParse(input.trim());
  final day = int.parse(match.group(1)!);
  final month = _months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  var year = int.parse(match.group(3)!);
  if (year < 100) year += 2000;
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = match.group(6) != null ? int.parse(match.group(6)!) : 0;
  final tz = match.group(7);

  var offsetMinutes = 0;
  if (tz != null && tz != 'UT' && tz != 'GMT') {
    final sign = tz.startsWith('-') ? -1 : 1;
    final hh = int.parse(tz.substring(1, 3));
    final mm = int.parse(tz.substring(3, 5));
    offsetMinutes = sign * (hh * 60 + mm);
  }

  // 絶対時刻(UTC)のまま返す。表示用のタイムゾーン変換は呼び出し側(app_clock.dart)で行う。
  return DateTime.utc(year, month, day, hour, minute, second)
      .subtract(Duration(minutes: offsetMinutes));
}
