import '../models/location_point.dart';

/// あらかじめ内蔵しておく観測地点候補。
///
/// 気象庁の潮位表掲載地点コードと緯度経度は
/// https://www.data.jma.go.jp/kaiyou/db/tide/suisan/station.php を基に確認したもの。
const List<LocationPoint> observationPoints = [
  LocationPoint(
    id: 'yokohama',
    name: '横浜',
    jmaStationCode: 'QS',
    latitude: 35.45,
    longitude: 139.65,
  ),
  LocationPoint(
    id: 'tokyo',
    name: '東京',
    jmaStationCode: 'TK',
    latitude: 35.65,
    longitude: 139.77,
  ),
  LocationPoint(
    id: 'yokosuka',
    name: '横須賀',
    jmaStationCode: 'QN',
    latitude: 35.28,
    longitude: 139.67,
  ),
  LocationPoint(
    id: 'chiba_choshi',
    name: '銚子漁港',
    jmaStationCode: 'CS',
    latitude: 35.73,
    longitude: 140.83,
  ),
  LocationPoint(
    id: 'shimizu',
    name: '清水港',
    jmaStationCode: 'SM',
    latitude: 35.02,
    longitude: 138.52,
  ),
  LocationPoint(
    id: 'nagoya',
    name: '名古屋',
    jmaStationCode: 'NG',
    latitude: 35.08,
    longitude: 136.88,
  ),
  LocationPoint(
    id: 'osaka',
    name: '大阪',
    jmaStationCode: 'OS',
    latitude: 34.65,
    longitude: 135.43,
  ),
  LocationPoint(
    id: 'kobe',
    name: '神戸',
    jmaStationCode: 'KB',
    latitude: 34.68,
    longitude: 135.18,
  ),
  LocationPoint(
    id: 'hiroshima',
    name: '広島',
    jmaStationCode: 'Q8',
    latitude: 34.35,
    longitude: 132.45,
  ),
  LocationPoint(
    id: 'takamatsu',
    name: '高松',
    jmaStationCode: 'TA',
    latitude: 34.35,
    longitude: 134.05,
  ),
  LocationPoint(
    id: 'matsuyama',
    name: '松山',
    jmaStationCode: 'MT',
    latitude: 33.83,
    longitude: 132.77,
  ),
  LocationPoint(
    id: 'kochi',
    name: '高知',
    jmaStationCode: 'KC',
    latitude: 33.55,
    longitude: 133.55,
  ),
  LocationPoint(
    id: 'nagasaki',
    name: '長崎',
    jmaStationCode: 'NS',
    latitude: 32.73,
    longitude: 129.87,
  ),
  LocationPoint(
    id: 'kagoshima',
    name: '鹿児島',
    jmaStationCode: 'KG',
    latitude: 31.6,
    longitude: 130.55,
  ),
  LocationPoint(
    id: 'naha',
    name: '那覇',
    jmaStationCode: 'NH',
    latitude: 26.22,
    longitude: 127.68,
  ),
  LocationPoint(
    id: 'hakodate',
    name: '函館',
    jmaStationCode: 'HK',
    latitude: 41.78,
    longitude: 140.72,
  ),
  LocationPoint(
    id: 'kushiro',
    name: '釧路',
    jmaStationCode: 'KR',
    latitude: 42.98,
    longitude: 144.38,
  ),
  LocationPoint(
    id: 'niigata',
    name: '新潟西港',
    jmaStationCode: 'S6',
    latitude: 37.93,
    longitude: 139.03,
  ),
  LocationPoint(
    id: 'sendai_shiogama',
    name: '塩釜',
    jmaStationCode: 'SG',
    latitude: 38.32,
    longitude: 141.02,
  ),
];

LocationPoint findObservationPoint(String id) =>
    observationPoints.firstWhere(
      (p) => p.id == id,
      orElse: () => observationPoints.first,
    );
