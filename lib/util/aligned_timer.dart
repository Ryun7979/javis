import 'dart:async';

/// 毎時0分を起点に [intervalMinutes] 分刻みの区切り（秒0）で [onTick] を呼ぶタイマー。
///
/// たとえば15分なら、起動した時刻によらず毎時00・15・30・45分ちょうどに呼ばれる。
/// そのため起動直後の1回目は間隔より短くなることがある。間隔は60の約数を前提とする
/// （約数でない値でも止まりはせず、毎時0分で刻みが揃え直される）。
///
/// 1回ごとに「次の区切りまで」の単発Timerを掛け直すので、長時間動かしても誤差が積み重ならない。
class AlignedPeriodicTimer {
  AlignedPeriodicTimer({
    required this.intervalMinutes,
    required this.onTick,
    DateTime Function()? now,
  })  : assert(intervalMinutes > 0),
        _now = now ?? DateTime.now {
    _schedule(durationUntilNextSlot(_now(), intervalMinutes));
  }

  final int intervalMinutes;
  final void Function() onTick;
  final DateTime Function() _now;
  Timer? _timer;

  Duration get _interval => Duration(minutes: intervalMinutes);

  /// 手動操作の直後に呼ぶ。次の区切りまでが間隔の半分より短ければ、その区切りを1回見送る
  /// （操作した直後に勝手に切り替わってしまわないようにする）。
  void deferIfSoon() {
    final wait = durationUntilNextSlot(_now(), intervalMinutes);
    if (wait * 2 >= _interval) return;
    _schedule(wait + _interval);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _schedule(Duration wait) {
    _timer?.cancel();
    _timer = Timer(wait, _fire);
  }

  void _fire() {
    onTick();
    var wait = durationUntilNextSlot(_now(), intervalMinutes);
    // タイマーが区切りのわずかに手前で発火した場合に、同じ区切りで2回呼ばないようにする。
    if (wait < const Duration(seconds: 1)) wait += _interval;
    _schedule(wait);
  }
}

/// [now] から、毎時0分を起点とする [intervalMinutes] 分刻みの次の区切りまでの時間。
/// ちょうど区切りの時刻なら、その次の区切りまで（=間隔と同じ長さ）を返す。
Duration durationUntilNextSlot(DateTime now, int intervalMinutes) {
  final intoHour = Duration(
    minutes: now.minute,
    seconds: now.second,
    milliseconds: now.millisecond,
    microseconds: now.microsecond,
  );
  final interval = Duration(minutes: intervalMinutes);
  final intoSlot = intoHour.inMicroseconds % interval.inMicroseconds;
  final untilSlot = interval - Duration(microseconds: intoSlot);
  // 60の約数でない間隔では、毎時0分で刻みを揃え直す（例: 45分なら00分・45分）。
  final untilHour = const Duration(hours: 1) - intoHour;
  return untilSlot < untilHour ? untilSlot : untilHour;
}
