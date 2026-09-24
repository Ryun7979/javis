import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../util/app_clock.dart';
import '../util/brightness_schedule.dart';
import 'settings_provider.dart';

class BrightnessState {
  const BrightnessState({
    required this.onExternalPower,
    required this.isDim,
    required this.isManual,
  });

  /// 電源供給中か。false（バッテリー駆動）の間は輝度制御を行わず本体設定に従う。
  final bool onExternalPower;

  /// 現在の実効状態（スケジュールまたは手動切り替えの結果）が暗い状態か。
  final bool isDim;

  /// 手動切り替えが有効中か（次の切り替え時刻まで）。
  final bool isManual;
}

/// 時間帯スケジュールと手動切り替えに応じて、アプリ画面の輝度を制御する。
///
/// 輝度はアプリのウィンドウ単位で設定するため、端末全体の輝度設定は変更しない
/// （WRITE_SETTINGS権限も不要）。
class BrightnessController extends StateNotifier<BrightnessState> {
  BrightnessController(this._now, this._levels)
      : super(BrightnessState(
          // バッテリー状態の初回取得前は本体設定に任せるため false で開始する。
          onExternalPower: false,
          isDim: isScheduledDim(_now()),
          isManual: false,
        )) {
    _init();
  }

  final DateTime Function() _now;

  /// 設定画面で指定された（暗い状態, 明るい状態）の輝度。
  final (double, double) Function() _levels;
  final _battery = Battery();
  StreamSubscription<BatteryState>? _batterySub;
  Timer? _timer;

  bool? _manualDim;
  DateTime? _manualSince;
  DateTime? _manualUntil;

  Future<void> _init() async {
    try {
      _onBatteryState(await _battery.batteryState);
      _batterySub = _battery.onBatteryStateChanged.listen(_onBatteryState);
    } catch (_) {
      // バッテリー状態を取得できない環境では輝度制御を行わない（本体設定のまま）。
    }
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _onBatteryState(BatteryState batteryState) {
    // 放電中のみバッテリー駆動とみなす（unknownは電池を持たない据え置き端末を想定し電源供給扱い）。
    final external = batteryState != BatteryState.discharging;
    if (external == state.onExternalPower) return;
    state = BrightnessState(
      onExternalPower: external,
      isDim: state.isDim,
      isManual: state.isManual,
    );
    _refresh();
  }

  /// 明るい⇔暗いを手動で切り替える。次の切り替え時刻（2:00/19:00）で自動に戻る。
  void toggle() {
    if (!state.onExternalPower) return;
    final now = _now();
    _manualDim = !state.isDim;
    _manualSince = now;
    _manualUntil = nextScheduleBoundary(now);
    _refresh();
  }

  void _refresh() {
    final now = _now();
    // 期限切れ、または時計の巻き戻し（切り替えた時刻より前）なら自動に戻す。
    if (_manualUntil != null &&
        (!now.isBefore(_manualUntil!) || now.isBefore(_manualSince!))) {
      _manualDim = null;
      _manualSince = null;
      _manualUntil = null;
    }
    final isManual = _manualDim != null;
    final isDim = _manualDim ?? isScheduledDim(now);
    state = BrightnessState(
      onExternalPower: state.onExternalPower,
      isDim: isDim,
      isManual: isManual,
    );
    _apply();
  }

  /// 設定値の変更後に、現在の状態の輝度を掛け直す。
  void reapply() => _apply();

  /// 設定画面のスライダー操作中に、保存前の値を画面へ即時反映する。
  /// 表示中の状態（暗い/明るい）と異なる側の値や、バッテリー駆動中は反映しない。
  Future<void> preview({required bool forDim, required double value}) async {
    if (!state.onExternalPower || forDim != state.isDim) return;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  Future<void> _apply() async {
    try {
      if (state.onExternalPower) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(
            state.isDim ? _levels().$1 : _levels().$2);
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
    } catch (_) {
      // 輝度APIが使えない環境では何もしない（表示自体は継続する）。
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _batterySub?.cancel();
    super.dispose();
  }
}

final brightnessControllerProvider =
    StateNotifierProvider<BrightnessController, BrightnessState>((ref) {
  final controller = BrightnessController(
    () => appNow(ref.read(settingsProvider).useFixedJst),
    () {
      final s = ref.read(settingsProvider);
      return (s.dimBrightness, s.brightBrightness);
    },
  );
  ref.listen(settingsProvider, (_, _) => controller.reapply());
  return controller;
});
