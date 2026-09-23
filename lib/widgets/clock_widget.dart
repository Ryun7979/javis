import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/clock_provider.dart';
import '../theme/cyberpunk_colors.dart';

/// 大型時計（画面の1/4〜1/3程度を占有する想定）。日付・曜日も併記する。
/// 数字はネオングローで常時発光し、中央の「:」は1秒周期で点滅する。
class ClockWidget extends ConsumerStatefulWidget {
  const ClockWidget({super.key});

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  ConsumerState<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends ConsumerState<ClockWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  static const _digitGlow = [
    Shadow(color: CyberpunkColors.neonCyan, blurRadius: 24),
    Shadow(color: CyberpunkColors.neonCyan, blurRadius: 48),
    Shadow(color: Colors.white, blurRadius: 6),
  ];

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final hourText = DateFormat('HH').format(now);
    final minuteText = DateFormat('mm').format(now);
    final dateText = DateFormat('yyyy年M月d日').format(now);
    final weekday = ClockWidget._weekdayLabels[now.weekday - 1];

    const digitStyle = TextStyle(
      fontSize: 160,
      fontWeight: FontWeight.w800,
      fontFeatures: [FontFeature.tabularFigures()],
      height: 1.0,
      shadows: _digitGlow,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(hourText, style: digitStyle),
                  AnimatedBuilder(
                    animation: _blinkController,
                    builder: (context, _) {
                      final opacity =
                          _blinkController.value < 0.5 ? 1.0 : 0.15;
                      return Opacity(
                        opacity: opacity,
                        child: const Text(':', style: digitStyle),
                      );
                    },
                  ),
                  Text(minuteText, style: digitStyle),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '$dateText($weekday)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                  shadows: [
                    Shadow(color: CyberpunkColors.neonCyan, blurRadius: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
