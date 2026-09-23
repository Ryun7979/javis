import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/clock_provider.dart';

/// 大型時計（画面の1/4〜1/3程度を占有する想定）。日付・曜日も併記する。
class ClockWidget extends ConsumerWidget {
  const ClockWidget({super.key});

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final timeText = DateFormat('HH:mm').format(now);
    final dateText = DateFormat('yyyy年M月d日').format(now);
    final weekday = _weekdayLabels[now.weekday - 1];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 160,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$dateText（$weekday）',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
