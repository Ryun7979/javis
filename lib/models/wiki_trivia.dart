/// 時計の下に1行で流すWikipedia由来の小ネタ1件。
enum WikiTriviaKind { onThisDay, featured }

class WikiTriviaItem {
  const WikiTriviaItem({required this.kind, required this.text});

  final WikiTriviaKind kind;
  final String text;

  String get label => switch (kind) {
        WikiTriviaKind.onThisDay => '今日は何の日',
        WikiTriviaKind.featured => '秀逸な記事',
      };

  Map<String, dynamic> toJson() => {'kind': kind.name, 'text': text};

  factory WikiTriviaItem.fromJson(Map<String, dynamic> json) => WikiTriviaItem(
        kind: WikiTriviaKind.values.byName(json['kind'] as String),
        text: json['text'] as String,
      );
}
