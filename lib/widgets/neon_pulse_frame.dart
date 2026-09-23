import 'package:flutter/material.dart';

import '../theme/cyberpunk_colors.dart';

/// 子ウィジェット（カード）の縁に、ゆっくり強弱がつく「呼吸するような」
/// ネオングローを常時重ねる。`BoxShadow`はカードと同じ形を塗りつぶして
/// しまうため使わず、ぼかしを掛けたストロークで縁だけを光らせている。
class NeonPulseFrame extends StatefulWidget {
  const NeonPulseFrame({
    super.key,
    required this.child,
    this.color = CyberpunkColors.neonCyan,
    this.borderRadius = 10,
  });

  final Widget child;
  final Color color;
  final double borderRadius;

  @override
  State<NeonPulseFrame> createState() => _NeonPulseFrameState();
}

class _NeonPulseFrameState extends State<NeonPulseFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_controller.value);
                return CustomPaint(
                  painter: _NeonPulsePainter(
                    color: widget.color,
                    t: t,
                    radius: widget.borderRadius,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _NeonPulsePainter extends CustomPainter {
  _NeonPulsePainter({required this.color, required this.t, required this.radius});

  final Color color;
  final double t;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.75);

    // ぼかしたストロークで縁の外側にじわっと広がるグローを作る（塗りつぶさない）。
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.28 + 0.32 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + 5 * t
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 9 * t);
    canvas.drawRRect(rrect, glowPaint);

    // 芯になるくっきりした細いラインを重ねる。
    final corePaint = Paint()
      ..color = color.withValues(alpha: 0.55 + 0.35 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(rrect, corePaint);
  }

  @override
  bool shouldRepaint(covariant _NeonPulsePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
