import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// ニュース記事をアプリ内WebViewで表示するパネル。ニュースフィードの上に重ねて使う。
///
/// キオスクで開きっぱなしにならないよう、無操作のまま[autoCloseAfter]経過すると
/// [onClose]で自動的に閉じる。Androidの戻るボタンはページ履歴を戻り、
/// 履歴が尽きたらパネルを閉じる。
class ArticleViewer extends StatefulWidget {
  const ArticleViewer({
    super.key,
    required this.url,
    required this.autoCloseAfter,
    required this.onClose,
  });

  final Uri url;
  final Duration autoCloseAfter;
  final VoidCallback onClose;

  @override
  State<ArticleViewer> createState() => _ArticleViewerState();
}

class _ArticleViewerState extends State<ArticleViewer> {
  late final WebViewController _controller;
  Timer? _idleTimer;
  int _progress = 0;
  String? _title;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) => _restartIdleTimer(),
          onPageFinished: (_) async {
            final title = await _controller.getTitle();
            if (mounted) setState(() => _title = title);
          },
          // intent:// や market:// など http(s) 以外への遷移はWebViewでは開けず
          // エラー画面になるため、アプリ内では遷移させない。
          onNavigationRequest: (request) {
            final scheme = Uri.tryParse(request.url)?.scheme;
            return scheme == 'http' || scheme == 'https'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..setOnScrollPositionChange((_) => _restartIdleTimer())
      ..loadRequest(widget.url);
    _restartIdleTimer();
  }

  @override
  void didUpdateWidget(ArticleViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoCloseAfter != widget.autoCloseAfter) _restartIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(widget.autoCloseAfter, widget.onClose);
  }

  Future<void> _goBackOrClose() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else {
      widget.onClose();
    }
  }

  Future<void> _openExternally() async {
    final current = await _controller.currentUrl();
    final uri = Uri.tryParse(current ?? '') ?? widget.url;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackOrClose();
      },
      child: Listener(
        // WebView上のタップ・スクロールも含め、触れられたら無操作タイマーを延長する。
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _restartIdleTimer(),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '閉じる',
                    iconSize: 20,
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                  IconButton(
                    tooltip: '戻る',
                    iconSize: 20,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _goBackOrClose,
                  ),
                  Expanded(
                    child: Text(
                      _title ?? widget.url.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '再読み込み',
                    iconSize: 20,
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _controller.reload(),
                  ),
                  IconButton(
                    tooltip: '外部ブラウザで開く',
                    iconSize: 20,
                    icon: const Icon(Icons.open_in_new),
                    onPressed: _openExternally,
                  ),
                ],
              ),
              SizedBox(
                height: 2,
                child: _progress < 100
                    ? LinearProgressIndicator(value: _progress / 100)
                    : null,
              ),
              Expanded(child: WebViewWidget(controller: _controller)),
            ],
          ),
        ),
      ),
    );
  }
}
