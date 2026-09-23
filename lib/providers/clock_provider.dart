import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/app_clock.dart';
import 'settings_provider.dart';

/// 1秒ごとに現在時刻を流すプロバイダ（時計ウィジェット専用、再描画範囲を絞るため分離）。
/// 設定の useFixedJst に応じて日本標準時固定/端末ローカル時刻を切り替える。
final clockProvider = StreamProvider<DateTime>((ref) async* {
  DateTime tick() => appNow(ref.read(settingsProvider).useFixedJst);
  yield tick();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => tick());
});
