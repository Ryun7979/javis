/// 雨雲レーダーの広域表示で使う地方の区分と、その地方を見渡すための範囲（緯度経度）。
///
/// 範囲は県庁所在地だけでなく各地方の陸地がおおむね収まるよう手で決めたもの。
/// 沖縄は九州と一緒にすると範囲が広すぎて九州が小さく映るため分けている。
enum JapanRegion {
  hokkaido('北海道', south: 41.3, west: 139.4, north: 45.6, east: 145.9),
  tohoku('東北', south: 36.8, west: 139.2, north: 41.6, east: 142.1),
  kanto('関東', south: 34.8, west: 138.4, north: 37.2, east: 140.9),
  chubu('中部', south: 34.5, west: 135.4, north: 38.6, east: 139.9),
  kinki('近畿', south: 33.4, west: 134.2, north: 35.8, east: 137.0),
  chugoku('中国', south: 33.7, west: 130.8, north: 35.6, east: 134.5),
  shikoku('四国', south: 32.7, west: 132.0, north: 34.5, east: 134.8),
  kyushu('九州', south: 30.9, west: 128.6, north: 34.3, east: 132.1),
  okinawa('沖縄', south: 25.9, west: 126.7, north: 27.1, east: 128.4);

  const JapanRegion(
    this.label, {
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final String label;
  final double south;
  final double west;
  final double north;
  final double east;
}

/// 都道府県と、その県庁所在地（都庁・道庁・府庁・県庁の所在地）の位置。
class Prefecture {
  const Prefecture(
    this.code,
    this.name,
    this.capital,
    this.region,
    this.latitude,
    this.longitude,
  );

  /// JIS X 0401 の都道府県コード（1〜47）。設定の保存に使う。
  final int code;
  final String name;
  final String capital;
  final JapanRegion region;
  final double latitude;
  final double longitude;
}

const List<Prefecture> prefectures = [
  Prefecture(1, '北海道', '札幌', JapanRegion.hokkaido, 43.064, 141.347),
  Prefecture(2, '青森県', '青森', JapanRegion.tohoku, 40.824, 140.740),
  Prefecture(3, '岩手県', '盛岡', JapanRegion.tohoku, 39.704, 141.153),
  Prefecture(4, '宮城県', '仙台', JapanRegion.tohoku, 38.269, 140.872),
  Prefecture(5, '秋田県', '秋田', JapanRegion.tohoku, 39.719, 140.102),
  Prefecture(6, '山形県', '山形', JapanRegion.tohoku, 38.240, 140.363),
  Prefecture(7, '福島県', '福島', JapanRegion.tohoku, 37.750, 140.468),
  Prefecture(8, '茨城県', '水戸', JapanRegion.kanto, 36.342, 140.447),
  Prefecture(9, '栃木県', '宇都宮', JapanRegion.kanto, 36.566, 139.884),
  Prefecture(10, '群馬県', '前橋', JapanRegion.kanto, 36.391, 139.061),
  Prefecture(11, '埼玉県', 'さいたま', JapanRegion.kanto, 35.857, 139.649),
  Prefecture(12, '千葉県', '千葉', JapanRegion.kanto, 35.605, 140.123),
  Prefecture(13, '東京都', '新宿', JapanRegion.kanto, 35.690, 139.692),
  Prefecture(14, '神奈川県', '横浜', JapanRegion.kanto, 35.448, 139.642),
  Prefecture(15, '新潟県', '新潟', JapanRegion.chubu, 37.902, 139.023),
  Prefecture(16, '富山県', '富山', JapanRegion.chubu, 36.695, 137.211),
  Prefecture(17, '石川県', '金沢', JapanRegion.chubu, 36.594, 136.626),
  Prefecture(18, '福井県', '福井', JapanRegion.chubu, 36.065, 136.222),
  Prefecture(19, '山梨県', '甲府', JapanRegion.chubu, 35.664, 138.568),
  Prefecture(20, '長野県', '長野', JapanRegion.chubu, 36.651, 138.181),
  Prefecture(21, '岐阜県', '岐阜', JapanRegion.chubu, 35.391, 136.722),
  Prefecture(22, '静岡県', '静岡', JapanRegion.chubu, 34.977, 138.383),
  Prefecture(23, '愛知県', '名古屋', JapanRegion.chubu, 35.180, 136.907),
  Prefecture(24, '三重県', '津', JapanRegion.kinki, 34.730, 136.509),
  Prefecture(25, '滋賀県', '大津', JapanRegion.kinki, 35.004, 135.869),
  Prefecture(26, '京都府', '京都', JapanRegion.kinki, 35.021, 135.756),
  Prefecture(27, '大阪府', '大阪', JapanRegion.kinki, 34.686, 135.520),
  Prefecture(28, '兵庫県', '神戸', JapanRegion.kinki, 34.691, 135.183),
  Prefecture(29, '奈良県', '奈良', JapanRegion.kinki, 34.685, 135.833),
  Prefecture(30, '和歌山県', '和歌山', JapanRegion.kinki, 34.226, 135.168),
  Prefecture(31, '鳥取県', '鳥取', JapanRegion.chugoku, 35.504, 134.238),
  Prefecture(32, '島根県', '松江', JapanRegion.chugoku, 35.472, 133.051),
  Prefecture(33, '岡山県', '岡山', JapanRegion.chugoku, 34.662, 133.935),
  Prefecture(34, '広島県', '広島', JapanRegion.chugoku, 34.397, 132.460),
  Prefecture(35, '山口県', '山口', JapanRegion.chugoku, 34.186, 131.471),
  Prefecture(36, '徳島県', '徳島', JapanRegion.shikoku, 34.066, 134.559),
  Prefecture(37, '香川県', '高松', JapanRegion.shikoku, 34.340, 134.043),
  Prefecture(38, '愛媛県', '松山', JapanRegion.shikoku, 33.842, 132.766),
  Prefecture(39, '高知県', '高知', JapanRegion.shikoku, 33.560, 133.531),
  Prefecture(40, '福岡県', '福岡', JapanRegion.kyushu, 33.607, 130.418),
  Prefecture(41, '佐賀県', '佐賀', JapanRegion.kyushu, 33.249, 130.299),
  Prefecture(42, '長崎県', '長崎', JapanRegion.kyushu, 32.745, 129.874),
  Prefecture(43, '熊本県', '熊本', JapanRegion.kyushu, 32.790, 130.742),
  Prefecture(44, '大分県', '大分', JapanRegion.kyushu, 33.238, 131.613),
  Prefecture(45, '宮崎県', '宮崎', JapanRegion.kyushu, 31.911, 131.424),
  Prefecture(46, '鹿児島県', '鹿児島', JapanRegion.kyushu, 31.560, 130.558),
  Prefecture(47, '沖縄県', '那覇', JapanRegion.okinawa, 26.212, 127.681),
];

/// 全都道府県のコード（県庁所在地マークの既定の表示対象）。
final Set<int> allPrefectureCodes = {for (final p in prefectures) p.code};

/// 指定地点に最も近い県庁所在地の都道府県。観測地点は都道府県を持たないため、これで地方を決める。
Prefecture nearestPrefecture(double latitude, double longitude) {
  Prefecture? best;
  var bestD = double.infinity;
  for (final p in prefectures) {
    final dLat = p.latitude - latitude;
    final dLon = p.longitude - longitude;
    final d = dLat * dLat + dLon * dLon;
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return best!;
}
