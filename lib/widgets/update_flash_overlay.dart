import 'package:flutter/material.dart';

import '../theme/cyberpunk_colors.dart';

/// [updateKey] が変化するたび、子ウィジェットの周囲に一瞬だけネオンの光が
/// 走るフラッシュ演出を重ねる。データ更新の「動いた感」を出す用途で、
/// 通常表示時（キーが変わらない間）は一切アニメーションしない。
class UpdateFlashOverlay extends StatefulWidget {
  const UpdateFlashOverlay({
    super.key,
    required this.updateKey,
    required this.child,
    this.color = CyberpunkColors.neonCyan,
    this.borderRadius = 10,
  });

  final Object? updateKey;
  final Widget child;
  final Color color;
  final double borderRadius;

  @override
  State<UpdateFlashOverlay> createState() => _UpdateFlashOverlayState();
}

class _UpdateFlashOverlayState extends State<UpdateFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late Object? _lastKey = widget.updateKey;

  @override
  void didUpdateWidget(covariant UpdateFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.updateKey != _lastKey) {
      _lastKey = widget.updateKey;
      if (_lastKey != null) {
        _controller.forward(from: 0);
      }
    }
  }

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
                final fade = 1 - _controller.value;
                if (_controller.status == AnimationStatus.dismissed) {
                  return const SizedBox.shrink();
                }
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.8 * fade),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5 * fade),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
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
