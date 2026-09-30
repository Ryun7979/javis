import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../models/earthquake.dart';
import '../services/earthquake_service.dart';
import 'core_providers.dart';

class EarthquakeState {
  const EarthquakeState({
    required this.quakes,
    required this.lastUpdated,
    required this.error,
    required this.alertKey,
    required this.alertSeq,
  });

  /// 取得済みの地震（発生時刻の新しい順）。震度情報のないものも含む。
  final List<Earthquake> quakes;
  final DateTime? lastUpdated;
  final String? error;

  /// ニュース欄を自動で切り替えるきっかけになった地震のキー。
  final String? alertKey;

  /// 自動切り替えの合図。新しい地震で切り替えるたびに1増える。
  final int alertSeq;

  /// 一覧に出す地震（震度1以上を観測したもの）。
  List<Earthquake> get felt =>
      quakes.where((q) => q.maxScale >= SeismicScale.s1).toList();

  EarthquakeState copyWith({
    List<Earthquake>? quakes,
    DateTime? lastUpdated,
    String? error,
    bool clearError = false,
    String? alertKey,
    int? alertSeq,
  }) => EarthquakeState(
    quakes: quakes ?? this.quakes,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    error: clearError ? null : (error ?? this.error),
    alertKey: alertKey ?? this.alertKey,
    alertSeq: alertSeq ?? this.alertSeq,
  );

  static const initial = EarthquakeState(
    quakes: [],
    lastUpdated: null,
    error: null,
    alertKey: null,
    alertSeq: 0,
  );
}

/// 地震情報を毎分確認し、震度3以上の新しい地震があればニュース欄を切り替える合図を出す。
///
/// ダッシュボード表示中は常に動かしておく（地震表示が裏にあっても検出できるように）。
class EarthquakeController extends StateNotifier<EarthquakeState> {
  EarthquakeController(this._service, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(EarthquakeState.initial) {
    unawaited(_refresh(history: true));
    _pollTimer = Timer.periodic(pollInterval, (_) {
      final history = ++_polls % _historyEvery == 0;
      unawaited(_refresh(history: history));
    });
  }

  final EarthquakeService _service;
  final DateTime Function() _now;
  Timer? _pollTimer;
  int _polls = 0;

  /// 自動で切り替える最小の震度（震度3）。
  static const alertMinScale = SeismicScale.s3;

  /// 発生からこの時間を過ぎた地震では自動で切り替えない（起動直後に古い地震で切り替えないため）。
  static const alertFreshness = Duration(minutes: 30);

  static const pollInterval = Duration(minutes: 1);

  /// この回数の確認ごとに、一覧をさかのぼって取り直す（取りこぼしの補完）。
  static const _historyEvery = 30;

  /// 動作確認用: `--dart-define=QUAKE_ALERT_TEST=true` でビルドすると、起動時に最新の
  /// 震度1以上の地震を、発生からの時間によらず「新しい地震」として扱い切り替える。
  static const _alertTest = bool.fromEnvironment('QUAKE_ALERT_TEST');

  /// 切り替え済みの地震のキー（同じ地震で何度も切り替えないため）。
  final Set<String> _alerted = {};

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh() => _refresh(history: true);

  Future<void> _refresh({required bool history}) async {
    try {
      final reports = history
          ? await _service.fetchHistory()
          : await _service.fetchLatest();
      if (!mounted) return;
      final quakes = EarthquakeService.apply(state.quakes, reports);
      state = state.copyWith(
        quakes: quakes,
        lastUpdated: _now(),
        clearError: true,
      );
      _checkAlert(quakes);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: '地震情報を取得できませんでした: $e');
    }
  }

  void _checkAlert(List<Earthquake> quakes) {
    final now = _now().toUtc();
    Earthquake? target;
    for (final q in quakes) {
      if (_alerted.contains(q.key)) continue;
      final testHit =
          _alertTest && _alerted.isEmpty && q.maxScale >= SeismicScale.s1;
      final hit =
          q.maxScale >= alertMinScale &&
          now.difference(q.timeUtc) <= alertFreshness;
      if (hit || testHit) {
        _alerted.add(q.key);
        target ??= q; // 一覧は新しい順なので、最初に当たったものが最新。
      }
    }
    if (target != null) {
      state = state.copyWith(
        alertKey: target.key,
        alertSeq: state.alertSeq + 1,
      );
    }
  }
}

final earthquakeControllerProvider =
    StateNotifierProvider<EarthquakeController, EarthquakeState>(
      (ref) => EarthquakeController(ref.watch(earthquakeServiceProvider)),
    );
