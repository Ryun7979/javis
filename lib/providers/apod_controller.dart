import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/apod.dart';
import 'core_providers.dart';
import 'settings_provider.dart';

/// 時計の背景・全画面表示に使うNASAの宇宙写真（APOD）を保持する。null はまだ写真が無い状態。
/// 起動時はキャッシュを即表示し、以後は定期的に最新を確認する（通信はサービス側のTTLで間引かれる）。
class ApodController extends StateNotifier<ApodImage?> {
  ApodController(this._ref)
      : super(_ref.read(nasaApodServiceProvider).cached()) {
    unawaited(refresh());
    _timer = Timer.periodic(
      const Duration(hours: 1),
      (_) => unawaited(refresh()),
    );
  }

  final Ref _ref;
  Timer? _timer;
  bool _loading = false;

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    _loading = true;
    try {
      final image = await _ref.read(nasaApodServiceProvider).fetchLatest(
            apiKey: _ref.read(settingsProvider).nasaApiKey,
            force: force,
          );
      if (!mounted || image == null) return;
      if (state?.date == image.date && state?.imageUrl == image.imageUrl) {
        return;
      }
      state = image;
    } catch (_) {
      // 背景の飾りなので、失敗時は表示中の写真をそのまま残す。
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final apodProvider = StateNotifierProvider<ApodController, ApodImage?>((ref) {
  final controller = ApodController(ref);
  // APIキーを設定し直したら、すぐにそのキーで取り直す。
  ref.listen(
    settingsProvider.select((s) => s.nasaApiKey),
    (_, _) => unawaited(controller.refresh(force: true)),
  );
  return controller;
});
