import 'dart:math';

import '../models/news_models.dart';

/// はてなブックマーク数と経過時間から求める注目度。
///
/// ブクマ数をそのまま使うと古い記事が上に居座るため、Hacker Newsと同じ考え方で
/// 経過時間に応じて割り引く（`ブクマ数 / (経過時間h + 2)^1.5`）。
/// 配信時刻が不明な記事は24時間経過したものとして扱う。
double popularityScore(int bookmarks, DateTime? publishedAt, DateTime now) {
  if (bookmarks <= 0) return 0;
  final hours = publishedAt == null
      ? 24.0
      : max(0.0, now.difference(publishedAt).inMinutes / 60);
  return bookmarks / pow(hours + 2, 1.5);
}

/// [articles]（新着順）を注目度の高い順に並べ替える。注目度が同じ記事（0件同士など）は
/// 元の新着順を保つ。
List<NewsArticle> sortByPopularity(
  List<NewsArticle> articles,
  Map<String, int> bookmarkCounts,
  DateTime now,
) {
  final indexed = [
    for (var i = 0; i < articles.length; i++)
      (
        i,
        articles[i],
        popularityScore(
          bookmarkCounts[articles[i].link] ?? 0,
          articles[i].publishedAt,
          now,
        ),
      ),
  ];
  indexed.sort((a, b) {
    final c = b.$3.compareTo(a.$3);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
