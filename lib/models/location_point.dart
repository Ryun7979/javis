/// 潮汐・天気を取得する対象地点。
///
/// [jmaStationCode] は気象庁の潮位表掲載地点コード（2文字英字）。
/// 緯度経度は天気取得（Open-Meteo）に使う。
class LocationPoint {
  const LocationPoint({
    required this.id,
    required this.name,
    required this.jmaStationCode,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String jmaStationCode;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'jmaStationCode': jmaStationCode,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        id: json['id'] as String,
        name: json['name'] as String,
        jmaStationCode: json['jmaStationCode'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}
