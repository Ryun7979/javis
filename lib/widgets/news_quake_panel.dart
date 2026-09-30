import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_controller.dart';
import '../providers/earthquake_controller.dart';
import '../theme/cyberpunk_colors.dart';
import 'earthquake_panel.dart';
import 'fishing_radar_panel.dart';
import 'news_feed.dart';
import 'update_flash_overlay.dart';

/// ニュースフィードと地震情報を切り替える枠。
///
/// 震度3以上の新しい地震を検出すると自動で地震情報に切り替え、[autoReturnAfter]後に
/// ニュースへ戻す。各ヘッダーのボタンで手動でも切り替えられ、手動で切り替えたときは
/// 自動で戻す予定を取り消す（見ている途中で勝手に戻らないように）。
class NewsQuakePanel extends ConsumerStatefulWidget {
  const NewsQuakePanel({super.key, this.newsBuilder, this.quakeBuilder});

  /// テスト用: ニュース側・地震側の中身を差し替える（引数はヘッダーに置く切り替えボタン）。
  @visibleForTesting
  final Widget Function(Widget switchButton)? newsBuilder;
  @visibleForTesting
  final Widget Function(Widget switchButton)? quakeBuilder;

  static const autoReturnAfter = Duration(minutes: 30);

  @override
  ConsumerState<NewsQuakePanel> createState() => _NewsQuakePanelState();
}

class _NewsQuakePanelState extends ConsumerState<NewsQuakePanel> {
  bool _showQuake = false;
  Timer? _returnTimer;

  @override
  void dispose() {
    _returnTimer?.cancel();
    super.dispose();
  }

  void _onAlert() {
    _returnTimer?.cancel();
    _returnTimer = Timer(NewsQuakePanel.autoReturnAfter, () {
      if (mounted) setState(() => _showQuake = false);
    });
    setState(() => _showQuake = true);
  }

  void _toggle() {
    _returnTimer?.cancel();
    _returnTimer = null;
    setState(() => _showQuake = !_showQuake);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(earthquakeControllerProvider.select((s) => s.alertSeq), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) _onAlert();
    });
    final toQuake = _SwitchButton(
      icon: Icons.sensors,
      tooltip: '地震情報に切り替え',
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
          EarthquakePanel(headerTrailing: toNews),
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
