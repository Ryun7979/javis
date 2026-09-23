import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_controller.dart';
import '../widgets/clock_widget.dart';
import '../widgets/fishing_card.dart';
import '../widgets/news_feed.dart';
import 'settings_screen.dart';

/// 卓上ダッシュボードのメイン画面。
/// 左側3割: 大型時計、右側7割: 釣り情報カード + ニュースフィードの2カラム。
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Expanded(child: ClockWidget()),
                      if (state.lastUpdated != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '最終更新 '
                            '${state.lastUpdated!.hour.toString().padLeft(2, '0')}:'
                            '${state.lastUpdated!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Expanded(flex: 4, child: FishingCard()),
                const Expanded(flex: 3, child: NewsFeed()),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white54),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
