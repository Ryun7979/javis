/// 釣りやすさの目安スコア（独自ヒューリスティック、参考値）。
class FishingScoreBreakdownItem {
  const FishingScoreBreakdownItem({
    required this.label,
    required this.points,
    required this.maxPoints,
    required this.reason,
  });

  final String label;
  final double points;
  final double maxPoints;
  final String reason;
}

class FishingScore {
  const FishingScore({
    required this.stars,
    required this.breakdown,
  });

  /// 1〜5の5段階評価。
  final int stars;
  final List<FishingScoreBreakdownItem> breakdown;
}
