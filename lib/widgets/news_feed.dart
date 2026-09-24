import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/news_models.dart';
import '../providers/brightness_controller.dart';
import '../providers/dashboard_controller.dart';
import '../providers/dashboard_state.dart';
import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import '../util/app_clock.dart';
import 'article_viewer.dart';

/// ニュースフィード（総合＋ゲーム/AI/ITをタブ切り替え）。
/// RSSは設定された間隔（既定30分）で自動的に再取得され、随時更新される。
class NewsFeed extends ConsumerStatefulWidget {
  const NewsFeed({super.key});

  @override
  ConsumerState<NewsFeed> createState() => _NewsFeedState();
}

class _NewsFeedState extends ConsumerState<NewsFeed>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// アプリ内WebViewで表示中の記事URL（nullなら一覧を表示）。
  Uri? _openArticle;

  int get _tabCount => NewsCategory.values.length + 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                articles: state.allNewsSorted,
                error: null,
                showCategory: true,
                useFixedJst: useFixedJst,
                onOpen: _showArticle,
              ),
              for (final category in NewsCategory.values)
                _NewsList(
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
    required this.articles,
    required this.error,
    required this.showCategory,
    required this.useFixedJst,
    required this.onOpen,
  });

  final List<NewsArticle> articles;
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: articles.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final article = articles[index];
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
      icon: Icon(brightness.isDim && brightness.onExternalPower
          ? Icons.lightbulb_outline
          : Icons.lightbulb),
      onPressed: brightness.onExternalPower
          ? () => ref.read(brightnessControllerProvider.notifier).toggle()
          : null,
    );
  }
}
