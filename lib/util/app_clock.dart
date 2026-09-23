/// 設定（[useFixedJst]）に応じた「現在時刻」「表示用時刻」を提供するユーティリティ。
///
/// useFixedJst が true のとき、端末のシステムタイムゾーン設定によらず常に
/// 日本標準時(UTC+9)の壁時計値を持つ DateTime（isUtc は false）を返す。
/// これにより、時刻フィールド(year/month/day/hour...)を読むだけの用途
/// （表示フォーマットや「今日」の日付抽出）に対しては、端末のTZ設定が
/// 誤っていても正しい日本時間として扱える。
library;

const _jstOffset = Duration(hours: 9);

DateTime appNow(bool useFixedJst) {
  if (!useFixedJst) return DateTime.now();
  return _asJstWallClock(DateTime.now().toUtc());
}

/// 絶対時刻（RSSのpubDateなど）を表示用のタイムゾーンに変換する。
DateTime appLocalize(DateTime instant, bool useFixedJst) {
  final utc = instant.toUtc();
  return useFixedJst ? _asJstWallClock(utc) : utc.toLocal();
}

DateTime _asJstWallClock(DateTime utc) {
  final jst = utc.add(_jstOffset);
  return DateTime(
    jst.year,
    jst.month,
    jst.day,
    jst.hour,
    jst.minute,
    jst.second,
    jst.millisecond,
    jst.microsecond,
  );
}
