import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 通信断時のフォールバック表示用ローカルキャッシュ。
///
/// Hiveの動的型（Map/String）をそのまま使い、コード生成（build_runner）を
/// 必要としない構成にしている。
class CacheService {
  CacheService._(this._box);

  static const _boxName = 'wall_jarvis_cache';
  final Box<String> _box;

  static Future<CacheService> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(_boxName);
    return CacheService._(box);
  }

  /// テスト用: 既に開いた [Box] から直接生成する（Hive.initFlutterのプラットフォーム
  /// チャンネル呼び出しを避けるため）。
  factory CacheService.withBox(Box<String> box) => CacheService._(box);

  /// [key] にJSONとして保存する。取得日時も一緒に保存する。
  Future<void> writeJson(String key, dynamic data) async {
    final payload = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
    await _box.put(key, payload);
  }

  Future<void> writeRaw(String key, String rawText) async {
    final payload = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'data': rawText,
    });
    await _box.put(key, payload);
  }

  /// 保存されていれば (savedAt, data) を返す。無ければ null。
  (DateTime, dynamic)? read(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(decoded['savedAt'] as String);
      return (savedAt, decoded['data']);
    } catch (_) {
      return null;
    }
  }
}
