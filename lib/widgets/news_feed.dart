import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_models.dart';
import '../providers/dashboard_controller.dart';

/// ニュースフィード（ゲーム/AI/ITをタブ切り替え）。
class NewsFeed extends ConsumerStatefulWidget {
  const NewsFeed({super.key});

  @override
  ConsumerState<NewsFeed> createState() => _NewsFeedState();
}

class _NewsFeedState extends ConsumerState<NewsFeed>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: NewsCategory.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [for (final c in NewsCategory.values) Tab(text: c.label)],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final category in NewsCategory.values)
                  _NewsList(
                    articles: state.newsByCategory[category] ?? const [],
                    error: state.newsErrors[category],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsList extends StatelessWidget {
  const _NewsList({required this.articles, required this.error});

  final List<NewsArticle> articles;
  final String? error;

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
          subtitle: Text(
            '${article.sourceName}'
            '${article.publishedAt != null ? ' ・ ${formatter.format(article.publishedAt!)}' : ''}',
            style: const TextStyle(fontSize: 11),
          ),
          onTap: () => _openArticle(context, article.link),
        );
      },
    );
  }

  Future<void> _openArticle(BuildContext context, String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記事を開けませんでした')),
      );
    }
  }
}
