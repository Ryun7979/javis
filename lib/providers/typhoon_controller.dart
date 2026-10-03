import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/typhoon.dart';
import '../services/typhoon_service.dart';
import '../util/aligned_timer.dart';
import 'core_providers.dart';
import 'settings_provider.dart';

class TyphoonState {
  const TyphoonState({
    required this.typhoons,
    required this.lastUpdated,
    required this.error,
  });

  /// 発表中の台風・熱帯低気圧（日本から遠いものも含む）。
  final List<Typhoon> typhoons;
  final DateTime? lastUpdated;
  final String? error;

  /// 日本付近の台風（ニュース欄を定期的に切り替える対象）。熱帯低気圧と遠い台風は含めない。
  List<Typhoon> get approaching => [
    for (final t in typhoons)
      if (TyphoonController.treatAllAsApproaching ||
          (t.isTyphoon && t.approachesJapan))
        t,
  ];

  static const initial = TyphoonState(
    typhoons: [],
    lastUpdated: null,
    error: null,
  );
}

/// 台風情報を10分ごと（毎時0分起点の区切り）に確認する。
///
/// ダッシュボード表示中は常に動かしておく（地図が裏にあっても、台風の発生を検出できるように）。
class TyphoonController extends StateNotifier<TyphoonState> {
  TyphoonController(this._service, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(TyphoonState.initial) {
    unawaited(refresh());
    _pollTimer = AlignedPeriodicTimer(
      intervalMinutes: pollIntervalMinutes,
      now: _now,
      onTick: () => unawaited(refresh()),
    );
  }

  final TyphoonService _service;
  final DateTime Function() _now;
  AlignedPeriodicTimer? _pollTimer;

  static const pollIntervalMinutes = 10;

  /// 取得に失敗し続けたとき、発表からこの時間を過ぎた台風は表示をやめる
  /// （消えた台風が残り続けて、切り替えが止まらなくなるのを防ぐ）。
  static const staleAfter = Duration(hours: 12);

  /// 動作確認用: `--dart-define=TYPHOON_TEST=true` でビルドすると、日本から遠い台風や
  /// 熱帯低気圧も「日本付近の台風」として扱い、切り替えの対象にする。
  static const treatAllAsApproaching = bool.fromEnvironment('TYPHOON_TEST');

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final typhoons = await _service.fetchAll();
      if (!mounted) return;
      state = TyphoonState(
        typhoons: typhoons,
        lastUpdated: _now(),
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      final now = _now().toUtc();
      state = TyphoonState(
        typhoons: [
          for (final t in state.typhoons)
            if (now.difference(t.issuedAtUtc) <= staleAfter) t,
        ],
        lastUpdated: state.lastUpdated,
        error: '台風情報を取得できませんでした: $e',
      );
    }
  }
}

final typhoonControllerProvider =
    StateNotifierProvider<TyphoonController, TyphoonState>(
      (ref) => TyphoonController(ref.watch(typhoonServiceProvider)),
    );

/// 台風が日本付近にある間、ニュースと地図を切り替える間隔（分）。0なら切り替えない。
final typhoonSwitchIntervalProvider = Provider<int>(
  (ref) => ref.watch(
    settingsProvider.select((s) => s.typhoonSwitchIntervalMinutes),
  ),
);
