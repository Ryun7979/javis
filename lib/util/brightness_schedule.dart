/// 画面輝度の時間帯スケジュール（AM2:00〜19:00は暗く、それ以外は明るく）。
///
/// 日中は卓上ダッシュボードをあまり見ないため輝度を落とし、夜間（19:00〜翌2:00）は
/// 明るく表示する。引数の [now] は `appNow()` の壁時計値を想定する。
library;

const int dimStartHour = 2;
const int dimEndHour = 19;

/// 暗くする時間帯の輝度の既定値（0.0〜1.0）。設定画面で変更できる。
const double defaultDimBrightness = 0.15;

/// 明るくする時間帯の輝度の既定値（0.0〜1.0）。設定画面で変更できる。
const double defaultBrightBrightness = 1.0;

/// スケジュール上、[now] の時刻が暗くする時間帯かどうか。
bool isScheduledDim(DateTime now) =>
    now.hour >= dimStartHour && now.hour < dimEndHour;

/// [now] より後で最初に来る切り替え時刻（2:00 または 19:00）。
/// 手動で切り替えた状態は、この時刻まで維持する。
DateTime nextScheduleBoundary(DateTime now) {
  if (now.hour < dimStartHour) {
    return DateTime(now.year, now.month, now.day, dimStartHour);
  }
  if (now.hour < dimEndHour) {
    return DateTime(now.year, now.month, now.day, dimEndHour);
  }
  return DateTime(now.year, now.month, now.day + 1, dimStartHour);
}
