import 'package:workmanager/workmanager.dart';

import '../models/app_settings.dart';
import '../services/cache_service.dart';
import '../services/news_service.dart';
import '../services/tide_service.dart';
import '../services/weather_service.dart';

const String backgroundRefreshTaskName = 'wall_jarvis_background_refresh';
const String backgroundRefreshUniqueName = 'wall_jarvis_background_refresh_periodic';

/// アプリがバックグラウンド/未起動の間の保険としてWorkManagerで定期取得する。
/// キオスク運用ではアプリは常時フォアグラウンドの想定のため、主な更新は
/// [DashboardController] のTimerが担い、これは補助的な役割。
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final cache = await CacheService.open();
      final settings = _loadSettings(cache);

      final tideService = TideService(cache);
      final weatherService = WeatherService(cache);
      final newsService = NewsService(cache);

      await tideService.getTideForDate(
        settings.location.jmaStationCode,
        DateTime.now(),
      );
      await weatherService.getWeather(
        settings.location.latitude,
        settings.location.longitude,
      );
      for (final source in settings.newsSources) {
        await newsService.fetchArticles(source);
      }
    } catch (_) {
      // バックグラウンド更新の失敗はフォアグラウンド復帰時に再取得されるため無視する。
    }
    return true;
  });
}

AppSettings _loadSettings(CacheService cache) {
  final cached = cache.read('app_settings');
  if (cached == null) return AppSettings.defaults();
  try {
    return AppSettings.fromJson(cached.$2 as Map<String, dynamic>);
  } catch (_) {
    return AppSettings.defaults();
  }
}
