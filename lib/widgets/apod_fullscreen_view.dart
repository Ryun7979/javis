import 'dart:async';

import 'package:flutter/material.dart';

import '../models/apod.dart';

/// NASAの宇宙写真を画面全体に表示する。どこかをタッチすると通常表示に戻る。
/// 常時点灯のキオスクで静止画を出し続けないよう、[autoCloseAfter]（設定、既定10分）が経つと自動でも戻る。
class ApodFullscreenView extends StatefulWidget {
  const ApodFullscreenView({
    super.key,
    required this.apod,
    required this.autoCloseAfter,
  });

  final ApodImage apod;
  final Duration autoCloseAfter;

  static Route<void> route(ApodImage apod, Duration autoCloseAfter) =>
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            ApodFullscreenView(apod: apod, autoCloseAfter: autoCloseAfter),
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  State<ApodFullscreenView> createState() => _ApodFullscreenViewState();
}

class _ApodFullscreenViewState extends State<ApodFullscreenView> {
  Timer? _autoCloseTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _autoCloseTimer = Timer(widget.autoCloseAfter, _close);
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _close() {
    // 自動クローズとタッチが重なっても二重にpopしない。
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final apod = widget.apod;
    final media = MediaQuery.of(context);
    // 高解像度画像は数千px・数MBになるので、画面の実ピクセル程度に縮小してデコードする。
    final decodeWidth = (media.size.width * media.devicePixelRatio).round();
    final decodeHeight = (media.size.height * media.devicePixelRatio).round();
    final credit = apod.copyright != null
        ? '© ${apod.copyright}'
        : 'Image Credit: NASA';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      // ルート直下に置くので、Materialで既定の文字スタイルを与える（無いと黄色の下線付きになる）。
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 高解像度版の読み込み中は、背景で使っている通常版を先に見せておく。
            Image.network(
              apod.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            Image(
              image: ResizeImage(
                NetworkImage(apod.hdImageUrl),
                width: decodeWidth,
                height: decodeHeight,
                policy: ResizeImagePolicy.fit,
              ),
              fit: BoxFit.contain,
              frameBuilder: (_, child, frame, wasSync) => AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 800),
                child: child,
              ),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 16,
              child: Text(
                '${apod.title}　$credit　NASA Astronomy Picture of the Day (${apod.date})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
            const Positioned(
              top: 16,
              right: 24,
              child: Text(
                'タッチで戻る',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white38,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
