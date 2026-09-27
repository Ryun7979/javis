import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/wiki_trivia.dart';
import '../util/app_clock.dart';
import 'core_providers.dart';
import 'settings_provider.dart';

/// 時計の下に流すWikipediaの小ネタ（秀逸な記事＋今日は何の日）を保持する。
/// 日付が変わったら取り直す（取得自体はサービス側で日付単位にキャッシュされる）。
class WikiTriviaController extends StateNotifier<List<WikiTriviaItem>> {
  WikiTriviaController(this._ref) : super(const []) {
    unawaited(refresh());
    // 日付の切り替わりと、取得失敗時の再試行を兼ねて定期的に確認する。
    _timer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => unawaited(refresh()),
    );
  }

  final Ref _ref;
  Timer? _timer;
  bool _loading = false;

  Future<void> refresh() async {
    if (_loading) return;
    final today = appNow(_ref.read(settingsProvider).useFixedJst);
    _loading = true;
    try {
      final items = await _ref.read(wikipediaServiceProvider).fetchDaily(today);
      // 取得済みで完全ならサービスはキャッシュを即返すので、定期呼び出しでも通信は発生しない。
      // 内容が同じなら state を差し替えず、表示中のローテーションを途切れさせない。
      if (!mounted || _sameItems(state, items)) return;
      state = items;
    } catch (_) {
      // 小ネタ表示なので、失敗時は表示中の内容をそのまま残す。
    } finally {
      _loading = false;
    }
  }

  bool _sameItems(List<WikiTriviaItem> a, List<WikiTriviaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].kind != b[i].kind || a[i].text != b[i].text) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final wikiTriviaProvider =
    StateNotifierProvider<WikiTriviaController, List<WikiTriviaItem>>(
  (ref) => WikiTriviaController(ref),
);
