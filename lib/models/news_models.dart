enum NewsCategory { game, ai, it }

extension NewsCategoryLabel on NewsCategory {
  String get label => switch (this) {
        NewsCategory.game => 'ゲーム',
        NewsCategory.ai => 'AI',
        NewsCategory.it => 'IT',
      };
}

/// RSS配信元の設定。
class NewsSource {
  const NewsSource({
    required this.name,
    required this.category,
    required this.rssUrl,
  });

  final String name;
  final NewsCategory category;
  final String rssUrl;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category.name,
        'rssUrl': rssUrl,
      };

  factory NewsSource.fromJson(Map<String, dynamic> json) => NewsSource(
        name: json['name'] as String,
        category: NewsCategory.values.byName(json['category'] as String),
        rssUrl: json['rssUrl'] as String,
      );
}

class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.link,
    required this.sourceName,
    required this.category,
    required this.publishedAt,
  });

  final String title;
  final String link;
  final String sourceName;
  final NewsCategory category;
  final DateTime? publishedAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'sourceName': sourceName,
        'category': category.name,
        'publishedAt': publishedAt?.toIso8601String(),
      };

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
        title: json['title'] as String,
        link: json['link'] as String,
        sourceName: json['sourceName'] as String,
        category: NewsCategory.values.byName(json['category'] as String),
        publishedAt: json['publishedAt'] == null
            ? null
            : DateTime.parse(json['publishedAt'] as String),
      );
}
