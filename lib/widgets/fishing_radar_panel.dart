import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_controller.dart';
import '../providers/settings_provider.dart';
import '../theme/cyberpunk_colors.dart';
import 'fishing_card.dart';
import 'rain_radar_panel.dart';
import 'update_flash_overlay.dart';

/// 釣り情報カードと雨雲レーダーを、設定の間隔（既定10分）で自動的に切り替える枠。
///
/// 各カードのヘッダーにある切り替えボタンで手動でも切り替えられる。手動で切り替えた
/// 場合は、その時点から改めて設定の間隔が経つまで自動切り替えを待つ。
class FishingRadarPanel extends ConsumerStatefulWidget {
  const FishingRadarPanel({super.key});

  @override
  ConsumerState<FishingRadarPanel> createState() => _FishingRadarPanelState();
}

class _FishingRadarPanelState extends ConsumerState<FishingRadarPanel> {
  bool _showRadar = false;
  Timer? _autoSwitchTimer;

  @override
  void initState() {
    super.initState();
    _restartAutoSwitch(ref.read(settingsProvider).panelSwitchIntervalMinutes);
  }

  @override
  void dispose() {
    _autoSwitchTimer?.cancel();
    super.dispose();
  }

  void _restartAutoSwitch(int minutes) {
    _autoSwitchTimer?.cancel();
    _autoSwitchTimer = minutes <= 0
        ? null
        : Timer.periodic(Duration(minutes: minutes), (_) {
            if (mounted) setState(() => _showRadar = !_showRadar);
          });
  }

  void _toggle() {
    setState(() => _showRadar = !_showRadar);
    _restartAutoSwitch(ref.read(settingsProvider).panelSwitchIntervalMinutes);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select((s) => s.panelSwitchIntervalMinutes),
      (_, minutes) => _restartAutoSwitch(minutes),
    );
    final lastUpdated =
        ref.watch(dashboardControllerProvider.select((s) => s.lastUpdated));

    return HoloFlipSwitcher(
      showBack: _showRadar,
      front: UpdateFlashOverlay(
        updateKey: lastUpdated,
        child: FishingCard(
          headerTrailing: _PanelToggleButton(
            icon: Icons.umbrella,
            tooltip: '雨雲レーダーに切り替え',
            onPressed: _toggle,
          ),
        ),
      ),
      back: RainRadarPanel(
        headerTrailing: _PanelToggleButton(
          icon: Icons.phishing,
          tooltip: '釣り情報に切り替え',
          onPressed: _toggle,
        ),
      ),
    );
  }
}

class _PanelToggleButton extends StatelessWidget {
  const _PanelToggleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: CyberpunkColors.neonCyan,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 26),
      onPressed: onPressed,
    );
  }
}

/// [front]と[back]を、ホログラム風の3Dフリップで切り替える。
///
/// 前半で今のカードを奥へ傾けながら（Y軸回転）縮めてネオンの縁を光らせ、
/// 真横を向いた瞬間に中身を入れ替え、後半で新しいカードを起こしつつ
/// 上から下へ走査線を走らせる。フリップ中以外は子をそのまま表示するため、
/// 通常時の描画コストは増えない。
class HoloFlipSwitcher extends StatefulWidget {
  const HoloFlipSwitcher({
    super.key,
    required this.showBack,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 1100),
  });

  final bool showBack;
  final Widget front;
  final Widget back;
  final Duration duration;

  @override
  State<HoloFlipSwitcher> createState() => _HoloFlipSwitcherState();
}

class _HoloFlipSwitcherState extends State<HoloFlipSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration, value: 1);

  /// 回転の向き。表→裏と裏→表で逆に回すと「めくって戻す」動きに見える。
  double _direction = 1;

  @override
  void didUpdateWidget(covariant HoloFlipSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showBack != widget.showBack) {
      _direction = widget.showBack ? 1 : -1;
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final firstHalf = t < 0.5;
        // 前半は切り替え前のカード、後半は切り替え後のカードを描く。
        final showingBack = firstHalf ? !widget.showBack : widget.showBack;
        final child = KeyedSubtree(
          key: ValueKey(showingBack),
          child: showingBack ? widget.back : widget.front,
        );
        if (!_controller.isAnimating) return child;

        // 0 → π/2（真横）で入れ替え → -π/2 → 0。
        final angle = (firstHalf ? t : t - 1) * math.pi * _direction;
        final edge = math.sin(t * math.pi); // 真横のとき1になる強さ
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0006)
          ..rotateY(angle)
          ..scaleByDouble(1 - 0.12 * edge, 1 - 0.12 * edge, 1, 1);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              IgnorePointer(child: child),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _HoloFlipPainter(
                      edge: edge,
                      scan: firstHalf ? null : (t - 0.5) * 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HoloFlipPainter extends CustomPainter {
  _HoloFlipPainter({required this.edge, required this.scan});

  /// 0〜1。カードが真横を向くほど大きい（暗転・縁の発光に使う）。
  final double edge;

  /// 後半の走査線の位置（0=上端〜1=下端）。前半はnull。
  final double? scan;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(8);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // 横を向くにつれて面を暗くし、回転の立体感を出す。
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withValues(alpha: 0.55 * edge),
    );
    // ネオンの縁取り（ぼかし＋芯線）。
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = CyberpunkColors.neonCyan.withValues(alpha: 0.8 * edge),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = CyberpunkColors.neonCyan.withValues(alpha: edge),
    );

    final s = scan;
    if (s == null) return;
    canvas.save();
    canvas.clipRRect(rrect);
    // 走査線より上は「描き込み済み」、下はまだ半透明のホログラムのように見せる。
    final y = rect.top + rect.height * s;
    canvas.drawRect(
      Rect.fromLTRB(rect.left, y, rect.right, rect.bottom),
      Paint()
        ..color = CyberpunkColors.bgDeep.withValues(alpha: 0.6 * (1 - s)),
    );
    const band = 28.0;
    canvas.drawRect(
      Rect.fromLTRB(rect.left, y - band, rect.right, y),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CyberpunkColors.neonCyan.withValues(alpha: 0),
            CyberpunkColors.neonCyan.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromLTRB(rect.left, y - band, rect.right, y)),
    );
    canvas.drawLine(
      Offset(rect.left, y),
      Offset(rect.right, y),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HoloFlipPainter old) =>
      old.edge != edge || old.scan != scan;
}
