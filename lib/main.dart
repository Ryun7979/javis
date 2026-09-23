import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'background/workmanager_callback.dart';
import 'providers/core_providers.dart';
import 'screens/dashboard_screen.dart';
import 'services/cache_service.dart';
import 'theme/cyberpunk_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 常時点灯キオスク運用のため、起動直後から画面スリープを禁止する。
  await WakelockPlus.enable();

  // 卓上設置を想定し、ランドスケープ固定・全画面表示にする。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final cacheService = await CacheService.open();

  await _initBackgroundRefresh();

  runApp(
    ProviderScope(
      overrides: [cacheServiceProvider.overrideWithValue(cacheService)],
      child: const WallJarvisApp(),
    ),
  );
}

Future<void> _initBackgroundRefresh() async {
  try {
    await Workmanager().initialize(backgroundCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundRefreshUniqueName,
      backgroundRefreshTaskName,
      frequency: const Duration(minutes: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (_) {
    // WorkManagerはAndroid以外や一部環境では利用できないため、失敗してもアプリ本体は継続する。
    // フォアグラウンド更新（DashboardController）は影響を受けない。
  }
}

class WallJarvisApp extends StatelessWidget {
  const WallJarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '釣り・ニュース・時計ダッシュボード',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.dark,
      home: const DashboardScreen(),
    );
  }

  ThemeData _buildDarkTheme() {
    // 常時点灯運用のため焼き付き・消費電力対策と夜間の視認性を優先し、
    // ダークテーマを基調とする（仕様書「画面構成・UI仕様」）。
    // サイバーパンク装飾の一環でアクセントカラーをネオンシアンに変更しているが、
    // 本文テキストの可読性を優先し、カードの枠線は細く控えめにとどめている。
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CyberpunkColors.neonCyan,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: 'sans-serif',
    );
    return base.copyWith(
      scaffoldBackgroundColor: CyberpunkColors.bgDeep,
      cardTheme: base.cardTheme.copyWith(
        color: CyberpunkColors.bgPanel,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: CyberpunkColors.neonCyan.withValues(alpha: 0.28),
          ),
        ),
      ),
    );
  }
}
