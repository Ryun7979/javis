import 'package:flutter/material.dart';

import '../theme/cyberpunk_colors.dart';

/// 画面全体の背景装飾（ネオングリッド＋ゆっくり流れる走査線）。
/// メインコンテンツの可読性を妨げないよう低輝度に抑え、常時点灯運用でも
/// 一箇所が焼き付かないよう常に位置が動くスキャンラインのみをアニメーションさせる。
class CyberpunkBackground extends StatefulWidget {
  const CyberpunkBackground({super.key, required this.child});

  final Widget child;

  @override
  State<CyberpunkBackground> createState() => _CyberpunkBackgroundState();
}

class _CyberpunkBackgroundState extends State<CyberpunkBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.4,
              colors: [CyberpunkColors.bgPanel, CyberpunkColors.bgDeep],
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _CyberpunkPainter(progress: _controller.value),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _CyberpunkPainter extends CustomPainter {
  _CyberpunkPainter({required this.progress});

  final double progress;

  static const _gridStep = 48.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintScanline(canvas, size);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CyberpunkColors.neonCyan.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += _gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintScanline(Canvas canvas, Size size) {
    final bandHeight = size.height * 0.18;
    final y = progress * (size.height + bandHeight) - bandHeight;
    final rect = Rect.fromLTWH(0, y, size.width, bandHeight);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          CyberpunkColors.neonCyan.withValues(alpha: 0),
          CyberpunkColors.neonCyan.withValues(alpha: 0.06),
          CyberpunkColors.neonCyan.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _CyberpunkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
