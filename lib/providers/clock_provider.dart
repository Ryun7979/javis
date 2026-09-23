import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 1秒ごとに現在時刻を流すプロバイダ（時計ウィジェット専用、再描画範囲を絞るため分離）。
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
