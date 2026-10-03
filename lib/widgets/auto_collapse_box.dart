import 'dart:async';

import 'package:flutter/material.dart';

/// 開いてから一定時間たつと自動でたたむ枠。タップで開閉できる。
///
/// 地図に重ねる概要が地図を隠し続けないようにするためのもの。
/// 表示された直後と[resetKey]が変わったときは開いた状態から始める。
class AutoCollapseBox extends StatefulWidget {
  const AutoCollapseBox({
    super.key,
    required this.builder,
    this.resetKey,
    this.alignment = Alignment.topLeft,
    this.expandedDuration = const Duration(seconds: 8),
  });

  /// 中身。expandedがfalseのときは1行に収めた表示を返す。
  final Widget Function(BuildContext context, bool expanded) builder;

  /// 表示する対象が変わったことを伝える値（変わると開き直す）。
  final Object? resetKey;

  /// 伸び縮みするときに動かさない角。
  final Alignment alignment;

  /// 開いてからたたむまでの時間。
  final Duration expandedDuration;

  @override
  State<AutoCollapseBox> createState() => _AutoCollapseBoxState();
}

class _AutoCollapseBoxState extends State<AutoCollapseBox> {
  bool _expanded = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleCollapse();
  }

  @override
  void didUpdateWidget(AutoCollapseBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != oldWidget.resetKey) {
      _expanded = true;
      _scheduleCollapse();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleCollapse() {
    _timer?.cancel();
    _timer = Timer(widget.expandedDuration, () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _scheduleCollapse();
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: widget.alignment,
        child: widget.builder(context, _expanded),
      ),
    );
  }
}
