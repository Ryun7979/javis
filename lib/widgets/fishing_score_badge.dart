import 'package:flutter/material.dart';

import '../models/fishing_score.dart';
import '../theme/cyberpunk_colors.dart';

/// 釣りやすさの目安スコアを★表示し、タップで内訳を表示する。
/// スコアが更新される（★の数が変わる）瞬間だけ、星が左から順に
/// 光りながらポップインする演出を入れる。通常表示中はアニメーションしない。
class FishingScoreBadge extends StatefulWidget {
  const FishingScoreBadge({super.key, required this.score});

  final FishingScore score;

  @override
  State<FishingScoreBadge> createState() => _FishingScoreBadgeState();
}

class _FishingScoreBadgeState extends State<FishingScoreBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void didUpdateWidget(covariant FishingScoreBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score.stars != widget.score.stars) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showBreakdown(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '釣りやすさの目安 ',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  children: List.generate(5, (i) {
                    final filled = i < widget.score.stars;
                    // 星ごとにタイミングをずらし、左から順に光りながら現れる。
                    final start = i * 0.12;
                    final localT =
                        ((_controller.value - start) / 0.4).clamp(0.0, 1.0);
                    final pop = filled
                        ? 0.6 + 0.4 * Curves.easeOutBack.transform(localT)
                        : 1.0;
                    final glow = filled ? localT : 0.0;
                    return Transform.scale(
                      scale: pop,
                      child: Icon(
                        filled ? Icons.star : Icons.star_border,
                        color: filled ? Colors.amberAccent : Colors.white24,
                        size: 20,
                        shadows: glow > 0
                            ? [
                                Shadow(
                                  color: CyberpunkColors.neonAmber
                                      .withValues(alpha: glow * 0.9),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 4),
            const Icon(Icons.info_outline, size: 16, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context) {
    final score = widget.score;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '釣りやすさの目安（★${score.stars}）',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                '※ 天気・気圧・風速・潮回り・時間帯から算出した独自の参考値です。'
                '科学的に検証された釣果予測ではありません。',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              for (final item in score.breakdown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(item.label),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: item.points / item.maxPoints,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.reason,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
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
