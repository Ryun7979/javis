import 'package:flutter_riverpod/legacy.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../util/aligned_timer.dart';
import '../util/app_clock.dart';
import '../util/keep_awake_schedule.dart';
import 'settings_provider.dart';

/// 設定された時間帯だけ画面を常時点灯にする。state は常時点灯中かどうか。
///
/// 時間帯の外では常時点灯を解除するだけなので、画面は本体の「画面消灯までの時間」に従って消える。
/// 消えた画面を開始時刻に自動でつけ直すことはしない（ユーザー承認済み。点灯は電源ボタンやタッチで行う）。
class KeepAwakeController extends StateNotifier<bool> {
  KeepAwakeController(this._now, this._schedule) : super(false) {
    _refresh(force: true);
    // 時間帯の境目は分単位なので、毎分0秒に判定し直す。
    _timer = AlignedPeriodicTimer(
      intervalMinutes: 1,
      onTick: _refresh,
      now: _now,
    );
  }

  final DateTime Function() _now;
  final KeepAwakeSchedule Function() _schedule;
  late final AlignedPeriodicTimer _timer;

  /// 設定の変更後に判定し直す。
  void reapply() => _refresh();

  Future<void> _refresh({bool force = false}) async {
    final active = _schedule().isActive(_now());
    if (!force && active == state) return;
    state = active;
    try {
      await WakelockPlus.toggle(enable: active);
    } catch (_) {
      // 常時点灯のAPIが使えない環境では何もしない（表示自体は継続する）。
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final keepAwakeControllerProvider =
    StateNotifierProvider<KeepAwakeController, bool>((ref) {
  final controller = KeepAwakeController(
    () => appNow(ref.read(settingsProvider).useFixedJst),
    () => ref.read(settingsProvider).keepAwakeSchedule,
  );
  ref.listen(settingsProvider, (_, _) => controller.reapply());
  return controller;
});
