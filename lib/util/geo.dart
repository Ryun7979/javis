import 'dart:math' as math;

/// 緯度経度（度）。
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// `[緯度, 経度]` の配列から作る（気象庁の台風情報の形式）。
  static GeoPoint? fromList(dynamic json) {
    if (json is! List || json.length < 2) return null;
    final lat = json[0], lon = json[1];
    if (lat is! num || lon is! num) return null;
    return GeoPoint(lat.toDouble(), lon.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => '($latitude, $longitude)';
}

const _earthRadiusM = 6371000.0;

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// 2点間の大圏距離（km）。
double distanceKm(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(h))) / 1000;
}

/// [from]から方位[bearingDeg]（北を0として時計回り）へ[distanceM]メートル進んだ地点。
GeoPoint destinationPoint(GeoPoint from, double bearingDeg, double distanceM) {
  final d = distanceM / _earthRadiusM;
  final b = _rad(bearingDeg);
  final lat1 = _rad(from.latitude);
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(b),
  );
  final lon2 =
      _rad(from.longitude) +
      math.atan2(
        math.sin(b) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2),
      );
  return GeoPoint(_deg(lat2), _deg(lon2));
}
