import 'package:flutter_riverpod/legacy.dart';

import '../models/app_settings.dart';
import '../services/cache_service.dart';
import 'core_providers.dart';

const _settingsCacheKey = 'app_settings';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._cache) : super(_load(_cache));

  final CacheService _cache;

  static AppSettings _load(CacheService cache) {
    final cached = cache.read(_settingsCacheKey);
    if (cached == null) return AppSettings.defaults();
    try {
      return AppSettings.fromJson(cached.$2 as Map<String, dynamic>);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> update(AppSettings newSettings) async {
    state = newSettings;
    await _cache.writeJson(_settingsCacheKey, newSettings.toJson());
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref.watch(cacheServiceProvider)),
);
