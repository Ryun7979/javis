import 'package:flutter/material.dart';

/// WMO weather code (Open-Meteo) を日本語の天気表示に変換する。
/// https://open-meteo.com/en/docs (WMO Weather interpretation codes)
class WeatherCodeInfo {
  const WeatherCodeInfo(this.label, this.icon);
  final String label;
  final IconData icon;
}

WeatherCodeInfo describeWeatherCode(int code) {
  switch (code) {
    case 0:
      return const WeatherCodeInfo('快晴', Icons.wb_sunny);
    case 1:
    case 2:
      return const WeatherCodeInfo('晴れ', Icons.wb_sunny_outlined);
    case 3:
      return const WeatherCodeInfo('曇り', Icons.cloud);
    case 45:
    case 48:
      return const WeatherCodeInfo('霧', Icons.foggy);
    case 51:
    case 53:
    case 55:
      return const WeatherCodeInfo('霧雨', Icons.grain);
    case 56:
    case 57:
      return const WeatherCodeInfo('着氷性の霧雨', Icons.ac_unit);
    case 61:
    case 63:
    case 65:
      return const WeatherCodeInfo('雨', Icons.water_drop);
    case 66:
    case 67:
      return const WeatherCodeInfo('着氷性の雨', Icons.ac_unit);
    case 71:
    case 73:
    case 75:
      return const WeatherCodeInfo('雪', Icons.ac_unit);
    case 77:
      return const WeatherCodeInfo('霧雪', Icons.ac_unit);
    case 80:
    case 81:
    case 82:
      return const WeatherCodeInfo('にわか雨', Icons.grain);
    case 85:
    case 86:
      return const WeatherCodeInfo('にわか雪', Icons.ac_unit);
    case 95:
      return const WeatherCodeInfo('雷雨', Icons.thunderstorm);
    case 96:
    case 99:
      return const WeatherCodeInfo('雹を伴う雷雨', Icons.thunderstorm);
    default:
      return const WeatherCodeInfo('不明', Icons.help_outline);
  }
}
