import 'dart:math' as math;
import 'dart:ui';

/// Webメルカトル（地図タイル座標系、XYZ方式）の計算ユーティリティ。
///
/// ズームレベル[zoom]で世界全体を 2^zoom × 2^zoom 枚のタイルに分割し、
/// 1タイル [tileSize] ピクセルとしたときの「世界ピクセル座標」を扱う。
class WebMercator {
  WebMercator._();

  /// 緯度経度を、ズーム[zoom]・タイル1辺[tileSize]ピクセルでの世界ピクセル座標に変換する。
  static Offset project(
    double latitude,
    double longitude,
    int zoom, {
    double tileSize = 256,
  }) {
    final scale = tileSize * math.pow(2, zoom);
    final x = (longitude + 180) / 360 * scale;
    final latRad = latitude * math.pi / 180;
    final y = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 *
        scale;
    return Offset(x, y);
  }

  /// 世界ピクセル座標の矩形[viewport]を覆うのに必要なタイル番号の一覧。
  static List<TileIndex> tilesCovering(
    Rect viewport,
    int zoom, {
    double tileSize = 256,
  }) {
    final maxIndex = (1 << zoom) - 1;
    final minX = (viewport.left / tileSize).floor().clamp(0, maxIndex);
    final maxX = ((viewport.right - 1) / tileSize).floor().clamp(0, maxIndex);
    final minY = (viewport.top / tileSize).floor().clamp(0, maxIndex);
    final maxY = ((viewport.bottom - 1) / tileSize).floor().clamp(0, maxIndex);
    return [
      for (var y = minY; y <= maxY; y++)
        for (var x = minX; x <= maxX; x++) TileIndex(zoom, x, y),
    ];
  }
}

/// XYZ方式のタイル番号。
class TileIndex {
  const TileIndex(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileIndex && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => '$z/$x/$y';
}
