import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/apod.dart';
import '../providers/apod_controller.dart';
import '../providers/settings_provider.dart';
import '../theme/cyberpunk_colors.dart';
import 'apod_fullscreen_view.dart';

/// 時計の領域の背景を、設定の間隔（既定15分）で「グリッド（画面全体の背景のまま）」と
/// 「NASAの宇宙写真」に切り替える。写真は時計が読みにくくならないよう、設定の不透明度で薄く敷き、
/// 縁をぼかして周囲のグリッドになじませる。
///
/// 写真が取得できているときは右上に全画面表示ボタンを出す。
class ApodClockBackground extends ConsumerStatefulWidget {
  const ApodClockBackground({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ApodClockBackground> createState() =>
      _ApodClockBackgroundState();
}

class _ApodClockBackgroundState extends ConsumerState<ApodClockBackground> {
  bool _showPhoto = false;
  Timer? _switchTimer;

  @override
  void initState() {
    super.initState();
    _restartSwitch(ref.read(settingsProvider).apodSwitchIntervalMinutes);
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    super.dispose();
  }

  void _restartSwitch(int minutes) {
    _switchTimer?.cancel();
    if (minutes <= 0) {
      _switchTimer = null;
      if (_showPhoto) setState(() => _showPhoto = false);
      return;
    }
    _switchTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      if (mounted) setState(() => _showPhoto = !_showPhoto);
    });
  }

  void _openFullscreen(ApodImage apod) {
    final minutes = ref.read(settingsProvider).apodFullscreenAutoCloseMinutes;
    Navigator.of(context)
        .push(ApodFullscreenView.route(apod, Duration(minutes: minutes)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select((s) => s.apodSwitchIntervalMinutes),
      (_, minutes) => _restartSwitch(minutes),
    );
    final apod = ref.watch(apodProvider);
    final opacity =
        ref.watch(settingsProvider.select((s) => s.apodBackgroundOpacity));

    return Stack(
      fit: StackFit.expand,
      children: [
        if (apod != null)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showPhoto ? opacity.clamp(0.0, 1.0) : 0,
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              child: _PhotoLayer(apod: apod),
            ),
          ),
        widget.child,
        if (apod != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.fullscreen, size: 22),
              color: CyberpunkColors.neonCyan.withValues(alpha: 0.7),
              tooltip: '宇宙写真を全画面表示',
              visualDensity: VisualDensity.compact,
              onPressed: () => _openFullscreen(apod),
            ),
          ),
      ],
    );
  }
}

/// 写真本体。四辺をぼかして消すことで、時計の領域の境目がくっきり出ないようにする。
class _PhotoLayer extends StatelessWidget {
  const _PhotoLayer({required this.apod});

  final ApodImage apod;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const RadialGradient(
        radius: 0.9,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.6, 1],
      ).createShader(rect),
      child: Image.network(
        apod.imageUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
