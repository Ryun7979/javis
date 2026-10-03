import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_controller.dart';
import '../providers/earthquake_controller.dart';
import '../providers/typhoon_controller.dart';
import '../theme/cyberpunk_colors.dart';
import '../util/aligned_timer.dart';
import 'earthquake_panel.dart';
import 'fishing_radar_panel.dart';
import 'news_feed.dart';
import 'update_flash_overlay.dart';

/// ニュースフィードと地震・台風情報を切り替える枠。
///
/// 震度3以上の新しい地震を検出すると自動で地震・台風情報に切り替え、[autoReturnAfter]後に
/// ニュースへ戻す。各ヘッダーのボタンで手動でも切り替えられ、手動で切り替えたときは
/// 自動で戻す予定を取り消す（見ている途中で勝手に戻らないように）。
///
/// 日本付近に台風がある間は、設定の間隔（既定10分、毎時0分を起点にした区切り）で
/// ニュースと地震・台風情報を交互に切り替える。地震で切り替えた30分間はそちらを優先する。
class NewsQuakePanel extends ConsumerStatefulWidget {
  const NewsQuakePanel({
    super.key,
    this.newsBuilder,
    this.quakeBuilder,
    this.clock,
  });

  /// テスト用: ニュース側・地震側の中身を差し替える（引数はヘッダーに置く切り替えボタン）。
  @visibleForTesting
  final Widget Function(Widget switchButton)? newsBuilder;
  @visibleForTesting
  final Widget Function(Widget switchButton)? quakeBuilder;

  /// テスト用: 台風の切り替えの区切りを決める時計。
  @visibleForTesting
  final DateTime Function()? clock;

  static const autoReturnAfter = Duration(minutes: 30);

  @override
  ConsumerState<NewsQuakePanel> createState() => _NewsQuakePanelState();
}

class _NewsQuakePanelState extends ConsumerState<NewsQuakePanel> {
  bool _showQuake = false;
  Timer? _returnTimer;
  AlignedPeriodicTimer? _typhoonTimer;

  /// 台風の定期切り替えで地図を出しているか（台風がなくなったらニュースへ戻すため）。
  bool _shownByTyphoon = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      typhoonSwitchIntervalProvider,
      (_, minutes) => _restartTyphoonTimer(minutes),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    _typhoonTimer?.cancel();
    super.dispose();
  }

  void _restartTyphoonTimer(int minutes) {
    _typhoonTimer?.cancel();
    _typhoonTimer = minutes <= 0
        ? null
        : AlignedPeriodicTimer(
            intervalMinutes: minutes,
            now: widget.clock,
            onTick: _onTyphoonTick,
          );
  }

  bool get _hasTyphoon =>
      ref.read(typhoonControllerProvider).approaching.isNotEmpty;

  void _onTyphoonTick() {
    // 地震で切り替えている間は、地震の表示を優先してそのままにする。
    if (!mounted || _returnTimer != null || !_hasTyphoon) return;
    setState(() {
      _showQuake = !_showQuake;
      _shownByTyphoon = _showQuake;
    });
  }

  void _onTyphoonGone() {
    if (!_shownByTyphoon || _returnTimer != null) return;
    setState(() {
      _showQuake = false;
      _shownByTyphoon = false;
    });
  }

  void _onAlert() {
    _returnTimer?.cancel();
    _returnTimer = Timer(NewsQuakePanel.autoReturnAfter, () {
      _returnTimer = null;
      if (mounted) setState(() => _showQuake = false);
    });
    setState(() {
      _showQuake = true;
      _shownByTyphoon = false;
    });
  }

  void _toggle() {
    _returnTimer?.cancel();
    _returnTimer = null;
    setState(() {
      _showQuake = !_showQuake;
      _shownByTyphoon = false;
    });
    _typhoonTimer?.deferIfSoon();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(earthquakeControllerProvider.select((s) => s.alertSeq), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) _onAlert();
    });
    ref.listen(
      typhoonControllerProvider.select((s) => s.approaching.isNotEmpty),
      (_, has) {
        if (!has) _onTyphoonGone();
      },
    );
    final toQuake = _SwitchButton(
      icon: Icons.sensors,
      tooltip: '地震・台風情報に切り替え',
      onPressed: _toggle,
    );
    final toNews = _SwitchButton(
      icon: Icons.newspaper,
      tooltip: 'ニュースに切り替え',
      onPressed: _toggle,
    );

    return HoloFlipSwitcher(
      showBack: _showQuake,
      front: widget.newsBuilder?.call(toQuake) ?? _News(switchButton: toQuake),
      back:
          widget.quakeBuilder?.call(toNews) ??
          EarthquakePanel(
            headerTrailing: toNews,
            // 地震で切り替えた間（自動で戻すまで）は、地図を地震に合わせた縮尺にする。
            quakeFocus: _returnTimer != null,
          ),
    );
  }
}

class _News extends ConsumerWidget {
  const _News({required this.switchButton});

  final Widget switchButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsLastUpdated = ref.watch(
      dashboardControllerProvider.select((s) => s.newsLastUpdated),
    );
    return UpdateFlashOverlay(
      updateKey: newsLastUpdated,
      child: NewsFeed(headerTrailing: switchButton),
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    iconSize: 18,
    color: CyberpunkColors.neonCyan,
    icon: Icon(icon),
    onPressed: onPressed,
  );
}
