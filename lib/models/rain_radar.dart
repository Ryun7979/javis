/// 雨雲レーダー（気象庁 高解像度降水ナウキャスト）の1コマ分。
///
/// [basetime]/[validtime] は気象庁の時刻文字列（UTC、`yyyyMMddHHmmss`）で、
/// タイルURLの組み立てにそのまま使う。
class RadarFrame {
  const RadarFrame({
    required this.basetime,
    required this.validtime,
    required this.validTimeUtc,
    required this.isForecast,
    this.strikes = const [],
  });

  final String basetime;
  final String validtime;
  final DateTime validTimeUtc;

  /// true なら予報（N2）、false なら実況（N1）。
  final bool isForecast;

  /// このコマの5分間に観測された雷（実況のみ。予報コマは常に空）。
  final List<LightningStrike> strikes;

  RadarFrame withStrikes(List<LightningStrike> strikes) => RadarFrame(
        basetime: basetime,
        validtime: validtime,
        validTimeUtc: validTimeUtc,
        isForecast: isForecast,
        strikes: strikes,
      );
}

/// 気象庁の雷監視（liden）で観測された1件の雷。
class LightningStrike {
  const LightningStrike({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
