import 'package:flutter/material.dart';

/// サイバーパンク装飾で使うネオンカラーパレット。
/// メインコンテンツ（テキスト本体）には使わず、背景装飾・枠線・
/// グラフ・更新演出など「動く/光る」部分に限定して使う。
class CyberpunkColors {
  CyberpunkColors._();

  static const neonCyan = Color(0xFF00E5FF);
  static const neonMagenta = Color(0xFFFF2E9A);
  static const neonPurple = Color(0xFF8B5CF6);
  static const neonGreen = Color(0xFF39FF6A);
  static const neonRed = Color(0xFFFF3860);
  static const neonAmber = Color(0xFFFFC400);

  static const bgDeep = Color(0xFF05070C);
  static const bgPanel = Color(0xFF0B1220);
}
