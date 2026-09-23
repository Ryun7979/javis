import 'package:flutter/material.dart';

import '../models/fishing_score.dart';

/// 釣りやすさの目安スコアを★表示し、タップで内訳を表示する。
class FishingScoreBadge extends StatelessWidget {
  const FishingScoreBadge({super.key, required this.score});

  final FishingScore score;

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
            Row(
              children: List.generate(5, (i) {
                final filled = i < score.stars;
                return Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: Colors.amberAccent,
                  size: 20,
                );
              }),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.info_outline, size: 16, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context) {
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
