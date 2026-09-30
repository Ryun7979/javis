import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/news_models.dart';
import '../providers/brightness_controller.dart';
import '../providers/dashboard_controller.dart';
import '../providers/dashboard_state.dart';
import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import '../util/aligned_timer.dart';
import '../util/app_clock.dart';
import 'article_viewer.dart';

/// ニュースフィード（総合＋ゲーム/AI/IT/映画/アウトドアをタブ切り替え）。
/// RSSは設定された間隔（既定30分）で自動的に再取得され、随時更新される。
///
/// 設定の間隔（既定3分、毎時0分を起点にした区切り）ごとに表示中の一覧を1ページ送り、最後まで送ったら
/// 先頭に戻る。「総合」は戻るたびに新着順⇔注目度順（はてなブックマーク数）を切り替える。
class NewsFeed extends ConsumerStatefulWidget {
  const NewsFeed({super.key, this.headerTrailing});

  /// ヘッダー右端に置くウィジェット（地震情報への切り替えボタン）。
  final Widget? headerTrailing;

  @override
  ConsumerState<NewsFeed> createState() => _NewsFeedState();
}

class _NewsFeedState extends ConsumerState<NewsFeed>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<ScrollController> _scrollControllers;

  /// アプリ内WebViewで表示中の記事URL（nullなら一覧を表示）。
  Uri? _openArticle;

  /// 「総合」を注目度順で表示中か（false なら新着順）。
  bool _popularOrder = false;

  AlignedPeriodicTimer? _pageTimer;

  int get _tabCount => NewsCategory.values.length + 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this)
      ..addListener(_onTabChanged);
    _scrollControllers = List.generate(_tabCount, (_) => ScrollController());
    ref.listenManual(
      settingsProvider.select((s) => s.newsPageScrollMinutes),
      (_, _) => _restartPageTimer(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _pageTimer?.cancel();
    _tabController.dispose();
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _pageTimer?.deferIfSoon();
    setState(() {}); // ヘッダーの並び順ボタンは「総合」のときだけ出す。
  }

  /// ページ送りのタイマーを作り直す（設定の間隔が変わったときに呼ぶ）。
  /// 送るのは毎時0分を起点にした区切り（3分なら毎時00・03・06…分）。
  void _restartPageTimer() {
    _pageTimer?.cancel();
    _pageTimer = null;
    final minutes = ref.read(settingsProvider).newsPageScrollMinutes;
    if (minutes <= 0) return;
    _pageTimer = AlignedPeriodicTimer(
      intervalMinutes: minutes,
      now: () => appNow(ref.read(settingsProvider).useFixedJst),
      onTick: _turnPage,
    );
  }

  void _turnPage() {
    if (!mounted || _openArticle != null) return;
    final index = _tabController.index;
    final controller = _scrollControllers[index];
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - 1) {
      if (index == 0) {
        // 並び順が変わると中身が入れ替わるので、アニメーションせずに先頭へ戻す。
        setState(() => _popularOrder = !_popularOrder);
        _jumpToTop(controller);
      } else {
        controller
            .animateTo(
              0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            )
            .then((_) => _jumpToTop(controller));
      }
      return;
    }
    // 前のページの最後の行が少し見えるよう、1画面分より少しだけ手前まで送る。
    controller.animateTo(
      min(
        position.pixels + position.viewportDimension - _pageOverlap,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  static const _pageOverlap = 32.0;

  void _toggleOrder() {
    setState(() => _popularOrder = !_popularOrder);
    final controller = _scrollControllers[0];
    _jumpToTop(controller);
    _pageTimer?.deferIfSoon();
  }

  /// 一覧の先頭へ戻す。行の高さが記事ごとに違うため、末尾から一気に戻ると
  /// 並べ直し時の位置補正で少しずれて止まることがある（実機で1行弱ずれた）。
  /// 描画し直した次のフレームでもう一度合わせる。
  void _jumpToTop(ScrollController controller) {
    if (controller.hasClients) controller.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients && controller.offset != 0) {
        controller.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final settings = ref.watch(settingsProvider);
    final useFixedJst = settings.useFixedJst;
    final formatter = DateFormat('HH:mm');
    final openArticle = _openArticle;

    return Card(
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      // 触った直後に勝手に送られないよう、次の区切りが近ければ1回見送る。
      child: Listener(
        onPointerDown: (_) => _pageTimer?.deferIfSoon(),
        child: Stack(
          children: [
            _buildFeed(state, useFixedJst, formatter),
            if (openArticle != null)
              Positioned.fill(
                child: ArticleViewer(
                  key: ValueKey(openArticle),
                  url: openArticle,
                  autoCloseAfter: Duration(
                    minutes: settings.articleAutoCloseMinutes,
                  ),
                  onClose: () => setState(() => _openArticle = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showArticle(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('記事を開けませんでした')));
      return;
    }
    setState(() => _openArticle = uri);
  }

  Widget _buildFeed(
    DashboardState state,
    bool useFixedJst,
    DateFormat formatter,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              if (state.newsLastUpdated != null)
                Text(
                  '最終更新 ${formatter.format(state.newsLastUpdated!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              const Spacer(),
              if (_tabController.index == 0)
                TextButton.icon(
                  onPressed: _toggleOrder,
                  icon: Icon(
                    _popularOrder
                        ? Icons.local_fire_department
                        : Icons.schedule,
                    size: 16,
                  ),
                  label: Text(
                    _popularOrder ? '注目度順' : '新着順',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              _BrightnessToggleButton(),
              IconButton(
                tooltip: '今すぐ更新',
                iconSize: 18,
                icon: const Icon(Icons.refresh),
                onPressed: () => ref
                    .read(dashboardControllerProvider.notifier)
                    .refreshNews(),
              ),
              IconButton(
                tooltip: '設定',
                iconSize: 18,
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              ?widget.headerTrailing,
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: '総合'),
            for (final c in NewsCategory.values) Tab(text: c.label),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _NewsList(
                controller: _scrollControllers[0],
                articles: _popularOrder
                    ? state.allNewsByPopularity(DateTime.now())
                    : state.allNewsSorted,
                bookmarkCounts: _popularOrder ? state.newsBookmarkCounts : null,
                error: null,
                showCategory: true,
                useFixedJst: useFixedJst,
                onOpen: _showArticle,
              ),
              for (final category in NewsCategory.values)
                _NewsList(
                  controller: _scrollControllers[1 + category.index],
                  articles: state.newsByCategory[category] ?? const [],
                  error: state.newsErrors[category],
                  showCategory: false,
                  useFixedJst: useFixedJst,
                  onOpen: _showArticle,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewsList extends StatelessWidget {
  const _NewsList({
    required this.controller,
    required this.articles,
    this.bookmarkCounts,
    required this.error,
    required this.showCategory,
    required this.useFixedJst,
    required this.onOpen,
  });

  final ScrollController controller;
  final List<NewsArticle> articles;

  /// 記事ごとのはてなブックマーク数。null のときは表示しない（注目度順のときだけ渡す）。
  final Map<String, int>? bookmarkCounts;
  final String? error;
  final bool showCategory;
  final bool useFixedJst;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      if (error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'ニュースを取得できませんでした\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final formatter = DateFormat('M/d HH:mm');
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: articles.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final article = articles[index];
        final bookmarks = bookmarkCounts?[article.link] ?? 0;
        return ListTile(
          dense: true,
          title: Text(
            article.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              if (showCategory) ...[
                _CategoryChip(category: article.category),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  '${article.sourceName}'
                  '${article.publishedAt != null ? ' ・ ${formatter.format(appLocalize(article.publishedAt!, useFixedJst))}' : ''}',
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (bookmarks > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$bookmarks users',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ],
          ),
          onTap: () => onOpen(article.link),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final NewsCategory category;

  Color get _color => switch (category) {
    NewsCategory.game => Colors.lightBlueAccent,
    NewsCategory.ai => Colors.purpleAccent,
    NewsCategory.it => Colors.greenAccent,
    NewsCategory.movie => Colors.amberAccent,
    NewsCategory.outdoor => Colors.lightGreenAccent,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: _color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.label,
        style: TextStyle(fontSize: 10, color: _color),
      ),
    );
  }
}

/// 画面の明るさ（明るい⇔暗い）を手動で切り替えるボタン。
/// バッテリー駆動中は本体設定に従うため無効化する。
class _BrightnessToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessControllerProvider);
    final String tooltip;
    if (!brightness.onExternalPower) {
      tooltip = 'バッテリー駆動中は本体の明るさ設定に従います';
    } else {
      tooltip = brightness.isDim ? '明るくする' : '暗くする';
    }
    return IconButton(
      tooltip: tooltip,
      iconSize: 18,
      icon: Icon(
        brightness.isDim && brightness.onExternalPower
            ? Icons.lightbulb_outline
            : Icons.lightbulb,
      ),
      onPressed: brightness.onExternalPower
          ? () => ref.read(brightnessControllerProvider.notifier).toggle()
          : null,
    );
  }
}
