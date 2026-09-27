import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wiki_trivia.dart';
import '../providers/wiki_trivia_controller.dart';
import '../theme/cyberpunk_colors.dart';

/// 時計の下に置く、Wikipediaの小ネタを1行で順番に流す表示。
///
/// 高さは常に1行分で固定し、件数が多くても領域は広がらない。1件ずつフェードで切り替え、
/// 1行に収まらない文は少し止めてから横にスクロールし、末尾でも少し止めてから次へ進む。
class WikiTriviaTicker extends ConsumerStatefulWidget {
  const WikiTriviaTicker({super.key});

  /// 1行に収まる文を表示しておく時間。
  static const fitDisplay = Duration(seconds: 10);

  /// スクロール前後に止めておく時間。
  static const scrollPause = Duration(milliseconds: 2500);

  /// スクロール速度（論理ピクセル/秒）。
  static const scrollSpeed = 60.0;

  static const height = 28.0;

  @override
  ConsumerState<WikiTriviaTicker> createState() => _WikiTriviaTickerState();
}

class _WikiTriviaTickerState extends ConsumerState<WikiTriviaTicker> {
  int _index = 0;

  /// 同じ項目を続けて表示するとき（1件しかない日など）にも行を作り直すための通し番号。
  int _cycle = 0;

  void _next(int length) {
    if (!mounted) return;
    setState(() {
      _index = length == 0 ? 0 : (_index + 1) % length;
      _cycle++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(wikiTriviaProvider);
    ref.listen(wikiTriviaProvider, (_, _) {
      // 日付が変わるなど内容が差し替わったら先頭から回し直す。
      setState(() {
        _index = 0;
        _cycle++;
      });
    });
    if (items.isEmpty) return const SizedBox.shrink();
    final item = items[_index.clamp(0, items.length - 1)];

    return SizedBox(
      height: WikiTriviaTicker.height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Row(
          key: ValueKey(_cycle),
          children: [
            _KindLabel(item: item),
            const SizedBox(width: 8),
            Expanded(
              child: _MarqueeLine(
                text: item.text,
                onFinished: () => _next(items.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindLabel extends StatelessWidget {
  const _KindLabel({required this.item});

  final WikiTriviaItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.kind == WikiTriviaKind.featured
        ? CyberpunkColors.neonAmber
        : CyberpunkColors.neonCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        item.label,
        style: TextStyle(fontSize: 11, color: color, height: 1.2),
      ),
    );
  }
}

/// 1行のテキスト。収まらなければ「停止 → スクロール → 停止」の後に [onFinished] を呼ぶ。
class _MarqueeLine extends StatefulWidget {
  const _MarqueeLine({required this.text, required this.onFinished});

  final String text;
  final VoidCallback onFinished;

  @override
  State<_MarqueeLine> createState() => _MarqueeLineState();
}

class _MarqueeLineState extends State<_MarqueeLine> {
  final _scroll = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 最初の配置が済んでから（スクロール量が確定してから）動かし始める。
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted || !_scroll.hasClients) return;
    final overflow = _scroll.position.maxScrollExtent;
    if (overflow <= 0) {
      _timer = Timer(WikiTriviaTicker.fitDisplay, _finish);
      return;
    }
    _timer = Timer(WikiTriviaTicker.scrollPause, () async {
      if (!mounted || !_scroll.hasClients) return;
      final ms = (overflow / WikiTriviaTicker.scrollSpeed * 1000).round();
      await _scroll.animateTo(
        overflow,
        duration: Duration(milliseconds: ms),
        curve: Curves.linear,
      );
      if (!mounted) return;
      _timer = Timer(WikiTriviaTicker.scrollPause, _finish);
    });
  }

  void _finish() {
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
