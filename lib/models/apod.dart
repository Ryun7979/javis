/// NASA Astronomy Picture of the Day（APOD）の1日分の写真。
class ApodImage {
  const ApodImage({
    required this.date,
    required this.title,
    required this.imageUrl,
    required this.hdImageUrl,
    this.copyright,
  });

  /// 公開日（`YYYY-MM-DD`、米国東部時間の日付）。
  final String date;
  final String title;

  /// 通常解像度の画像（960px程度）。時計の背景に使う。
  final String imageUrl;

  /// 高解像度の画像。全画面表示に使う。無い日は [imageUrl] と同じ。
  final String hdImageUrl;

  /// 著作者。無ければパブリックドメイン（NASAの画像）。
  final String? copyright;

  Map<String, dynamic> toJson() => {
        'date': date,
        'title': title,
        'imageUrl': imageUrl,
        'hdImageUrl': hdImageUrl,
        'copyright': copyright,
      };

  factory ApodImage.fromJson(Map<String, dynamic> json) => ApodImage(
        date: json['date'] as String,
        title: json['title'] as String,
        imageUrl: json['imageUrl'] as String,
        hdImageUrl: json['hdImageUrl'] as String,
        copyright: json['copyright'] as String?,
      );
}
