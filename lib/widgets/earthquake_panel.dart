import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/prefectures.dart';
import '../models/earthquake.dart';
import '../models/typhoon.dart';
import '../providers/earthquake_controller.dart';
import '../providers/settings_provider.dart';
import '../providers/typhoon_controller.dart';
import '../theme/cyberpunk_colors.dart';
import '../util/app_clock.dart';
import '../util/geo.dart';
import '../util/web_mercator.dart';
import 'typhoon_map_layer.dart';

/// 震度ごとの表示色（震度が上がるほど 青→緑→黄→橙→赤→マゼンタ→紫）。
Color seismicColor(int scale) => switch (SeismicScale.level(scale)) {
  2 => CyberpunkColors.neonCyan,
  3 => CyberpunkColors.neonGreen,
  4 => const Color(0xFFFFE600),
  5 => const Color(0xFFFFA000),
  6 => const Color(0xFFFF6A00),
  7 => const Color(0xFFFF2E4D),
  8 => CyberpunkColors.neonMagenta,
  9 => const Color(0xFFB026FF),
  _ => const Color(0xFF7FA7C9),
};

/// 日本地図に最新（または一覧で選んだ）地震の震源と震度を表示するパネル。
///
/// 震源には×印を置き、震度が大きいほど遠くまで・多重に広がる同心円を繰り返し描く。
/// 震源がまだ発表されていない（震度速報のみの）間は、最も揺れた都道府県の県庁所在地を中心に
/// 同心円を出し「震源 調査中」と表示する。各都道府県の最大震度は県庁所在地の位置に色付きの点で示す。
///
/// 台風・熱帯低気圧が発表されている間は、同じ地図に経路・現在位置・予報円なども重ねる
/// （地震の表示はそのまま残す）。
class EarthquakePanel extends ConsumerStatefulWidget {
  const EarthquakePanel({
    super.key,
    this.headerTrailing,
    this.quakeFocus = false,
  });

  /// ヘッダー右端に置くウィジェット（ニュースへの切り替えボタン）。
  final Widget? headerTrailing;

  /// 地震を優先して表示するか（震度3以上の地震で自動的に切り替えた間）。
  /// trueの間は、台風に合わせて地図を広げず、地震だけのときと同じ縮尺にする（台風は範囲内の分だけ描く）。
  final bool quakeFocus;

  @override
  ConsumerState<EarthquakePanel> createState() => _EarthquakePanelState();
}

class _EarthquakePanelState extends ConsumerState<EarthquakePanel> {
  /// 一覧で選んだ地震。nullなら最新の地震を表示する。
  String? _selectedKey;

  /// この時間内に起きた地震は、選んでいなくても×印と同心円を描く（それより前は小さな点）。
  static const _recentWindow = Duration(hours: 24);

  /// 地震情報は毎分取り直して再描画されるので、判定の「今」はその時点でよい。
  bool _isRecent(Earthquake q) =>
      DateTime.now().toUtc().difference(q.timeUtc) <= _recentWindow;

  @override
  Widget build(BuildContext context) {
    // 自動で切り替わったときは、選んでいた地震をやめて最新の地震を表示する。
    ref.listen(
      earthquakeControllerProvider.select((s) => s.alertSeq),
      (_, _) => setState(() => _selectedKey = null),
    );
    final state = ref.watch(earthquakeControllerProvider);
    final useFixedJst = ref.watch(
      settingsProvider.select((s) => s.useFixedJst),
    );
    final felt = state.felt;
    final typhoonState = ref.watch(typhoonControllerProvider);
    // 日本付近の台風を先に並べる（概要の表示と、地図の範囲を決めるのに使う）。
    final approaching = typhoonState.approaching;
    final typhoons = [
      ...approaching,
      for (final t in typhoonState.typhoons)
        if (!approaching.contains(t)) t,
    ];
    final selected = felt.isEmpty
        ? null
        : felt.firstWhere(
            (q) => q.key == _selectedKey,
            orElse: () => felt.first,
          );
    final lastUpdated = state.lastUpdated;

    return Card(
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text('地震・台風情報', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                if (lastUpdated != null)
                  Text(
                    '最終確認 ${DateFormat('HH:mm').format(appLocalize(lastUpdated, useFixedJst))}',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: '今すぐ確認',
                  iconSize: 18,
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.read(earthquakeControllerProvider.notifier).refresh();
                    ref.read(typhoonControllerProvider.notifier).refresh();
                  },
                ),
                ?widget.headerTrailing,
              ],
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _QuakeMap(
                      selected: selected,
                      recent: [
                        for (final q in felt)
                          if (q.key != selected?.key &&
                              q.hasHypocenter &&
                              _isRecent(q))
                            q,
                      ],
                      older: [
                        for (final q in felt.take(20))
                          if (q.key != selected?.key &&
                              q.hasHypocenter &&
                              !_isRecent(q))
                            q,
                      ],
                      typhoons: typhoons,
                      focusTyphoons: widget.quakeFocus
                          ? const []
                          : approaching,
                      useFixedJst: useFixedJst,
                    ),
                    // 台風の概要は左下に置く（右側は台風の進路と、左上〜中央は日本の震源と重なりやすい）。
                    if (typhoons.isNotEmpty)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6,
                          children: [
                            for (final t in typhoons.take(2))
                              TyphoonInfoBox(
                                typhoon: t,
                                useFixedJst: useFixedJst,
                              ),
                          ],
                        ),
                      ),
                    if (selected != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _QuakeInfo(
                          quake: selected,
                          useFixedJst: useFixedJst,
                        ),
                      )
                    else if (state.error != null)
                      Center(
                        child: Text(
                          state.error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      )
                    else if (lastUpdated == null)
                      const Center(child: CircularProgressIndicator()),
                    Positioned(
                      right: 6,
                      bottom: 4,
                      child: Text(
                        typhoons.isEmpty
                            ? '出典：P2P地震情報（気象庁の地震情報） / 地理院タイル'
                            : '出典：P2P地震情報（気象庁の地震情報） / 気象庁（台風情報） / 地理院タイル',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 132,
              child: _QuakeList(
                quakes: felt,
                typhoons: typhoons,
                selectedKey: selected?.key,
                useFixedJst: useFixedJst,
                onSelect: (q) => setState(() => _selectedKey = q.key),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 左上に重ねる、選択中の地震の概要（最大震度を大きく）。
class _QuakeInfo extends StatelessWidget {
  const _QuakeInfo({required this.quake, required this.useFixedJst});

  final Earthquake quake;
  final bool useFixedJst;

  @override
  Widget build(BuildContext context) {
    final color = seismicColor(quake.maxScale);
    final time = DateFormat('M/d HH:mm')
        .format(appLocalize(quake.timeUtc, useFixedJst));
    final depth = quake.depthKm;
    final mag = quake.magnitude;
    const sub = TextStyle(fontSize: 12, color: Colors.white70);

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: CyberpunkColors.bgDeep.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('最大震度', style: sub),
              const SizedBox(width: 6),
              Text(
                SeismicScale.label(quake.maxScale),
                style: TextStyle(
                  fontSize: 44,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: color,
                  shadows: [Shadow(color: color, blurRadius: 12)],
                ),
              ),
              const SizedBox(width: 12),
              if (mag != null)
                Text(
                  'M${mag.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          Text(
            quake.hypocenterName ?? '震源 調査中',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            [
              '$time 発生',
              if (depth != null) depth == 0 ? 'ごく浅い' : '深さ ${depth}km',
            ].join('  ・  '),
            style: sub,
          ),
          const SizedBox(height: 2),
          Text(
            quake.tsunamiLabel,
            style: TextStyle(
              fontSize: 12,
              color: quake.tsunamiAlert
                  ? CyberpunkColors.neonRed
                  : Colors.white70,
              fontWeight: quake.tsunamiAlert ? FontWeight.bold : null,
            ),
          ),
          if (quake.topPoints.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final p in quake.topPoints.take(3))
              Text(
                '震度${SeismicScale.label(p.scale)}  ${p.addr}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: seismicColor(p.scale)),
              ),
          ],
        ],
      ),
    );
  }
}

/// 最近の地震（震度1以上）の一覧。タップするとその地震を地図に表示する。
/// 台風・熱帯低気圧が発表されている間は、その行を先頭に並べる。
class _QuakeList extends StatelessWidget {
  const _QuakeList({
    required this.quakes,
    required this.typhoons,
    required this.selectedKey,
    required this.useFixedJst,
    required this.onSelect,
  });

  final List<Earthquake> quakes;
  final List<Typhoon> typhoons;
  final String? selectedKey;
  final bool useFixedJst;
  final ValueChanged<Earthquake> onSelect;

  @override
  Widget build(BuildContext context) {
    if (quakes.isEmpty && typhoons.isEmpty) return const SizedBox.shrink();
    final formatter = DateFormat('M/d HH:mm');
    return ListView.builder(
      itemCount: typhoons.length + quakes.length,
      itemExtent: 26,
      itemBuilder: (context, i) {
        if (i < typhoons.length) {
          return _TyphoonRow(
            typhoon: typhoons[i],
            time: formatter.format(
              appLocalize(typhoons[i].validTimeUtc, useFixedJst),
            ),
          );
        }
        final q = quakes[i - typhoons.length];
        final color = seismicColor(q.maxScale);
        final selected = q.key == selectedKey;
        return InkWell(
          onTap: () => onSelect(q),
          child: Container(
            color: selected ? color.withValues(alpha: 0.12) : null,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: color.withValues(alpha: 0.8)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '震度${SeismicScale.label(q.maxScale)}',
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  child: Text(
                    formatter.format(appLocalize(q.timeUtc, useFixedJst)),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    q.hypocenterName ?? '震源 調査中',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (q.magnitude != null)
                  Text(
                    'M${q.magnitude!.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 一覧の先頭に並べる台風の行（号数・実況の時刻・位置と勢力・気圧）。
class _TyphoonRow extends StatelessWidget {
  const _TyphoonRow({required this.typhoon, required this.time});

  final Typhoon typhoon;
  final String time;

  @override
  Widget build(BuildContext context) {
    final t = typhoon;
    final color = t.isTyphoon ? CyberpunkColors.neonAmber : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.8)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                t.isTyphoon ? t.label : '熱低',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              [
                ?t.name,
                ?t.location,
                [?t.scale, ?t.intensity].join('・'),
                [?t.course, ?t.speed].join(' '),
              ].where((s) => s.isNotEmpty).join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (t.pressureHpa != null)
            Text(
              '${t.pressureHpa}hPa',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

/// 日本全体の地図（地理院タイル）＋震源・同心円・都道府県ごとの震度＋台風。
class _QuakeMap extends StatelessWidget {
  const _QuakeMap({
    required this.selected,
    required this.recent,
    required this.older,
    required this.typhoons,
    required this.focusTyphoons,
    required this.useFixedJst,
  });

  final Earthquake? selected;

  /// 選んでいない直近の地震（×印と同心円を少し控えめに表示）。
  final List<Earthquake> recent;

  /// それより前の地震（小さな点で表示）。
  final List<Earthquake> older;

  /// 地図に描く台風・熱帯低気圧。
  final List<Typhoon> typhoons;

  /// 地図の範囲に収める台風（日本付近の台風）。遠い台風まで収めると日本が小さくなりすぎる。
  final List<Typhoon> focusTyphoons;
  final bool useFixedJst;

  /// 台風に合わせて地図を広げる限度。
  static const _typhoonSouth = 8.0;
  static const _typhoonNorth = 50.0;
  static const _typhoonWest = 112.0;
  static const _typhoonEast = 160.0;

  static const _tileSize = 256.0;
  static const _minTileZoom = 5;

  /// 日本全体（与那国島〜北海道東端）が収まる範囲。震源が外にあれば広げる。
  static const _south = 24.0;
  static const _north = 45.6;
  static const _west = 122.8;
  static const _east = 146.0;

  /// 地理院タイル（淡色地図）を反転・減光した夜間地図風の配色（雨雲レーダーと同じ）。
  static const _darkMapFilter = ColorFilter.matrix([
    -0.32, 0, 0, 0, 86, //
    0, -0.40, 0, 0, 108, //
    0, 0, -0.50, 0, 140, //
    0, 0, 0, 1, 0, //
  ]);

  /// 淡色地図の海の色（フィルターをかける前）。
  static const _seaColor = Color(0xFFBED2FF);

  /// 白地図の線（海岸線・県境）だけを明るい灰色にする（雨雲レーダーと同じ）。
  static const _outlineFilter = ColorFilter.matrix([
    0, 0, 0, 0, 140, //
    0, 0, 0, 0, 165, //
    0, 0, 0, 0, 180, //
    -0.62, 0, 0, 0, 158, //
  ]);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final q = selected;
        var south = _south, north = _north, west = _west, east = _east;
        // ×印を描く地震（選んだ地震と直近の地震）が、すべて端で切れずに収まるよう広げる。
        for (final m in [?q, ...recent]) {
          if (!m.hasHypocenter) continue;
          south = math.min(south, m.latitude! - 1);
          north = math.max(north, m.latitude! + 1);
          west = math.min(west, m.longitude! - 1);
          east = math.max(east, m.longitude! + 1);
        }
        // 日本付近の台風は、現在位置と予報円の中心が収まるよう広げる（限度あり）。
        for (final t in focusTyphoons) {
          final points = [
            t.center,
            for (final f in t.forecasts) f.center,
            // 強風域の円は端まで収める。
            for (final c in t.galeArea.circles)
              for (final bearing in const [0.0, 90.0, 180.0, 270.0])
                destinationPoint(c.center, bearing, c.radiusM),
          ];
          for (final p in points) {
            south = math.min(
              south,
              math.max(_typhoonSouth, p.latitude - 1.5),
            );
            north = math.max(
              north,
              math.min(_typhoonNorth, p.latitude + 1.5),
            );
            west = math.min(west, math.max(_typhoonWest, p.longitude - 1.5));
            east = math.max(east, math.min(_typhoonEast, p.longitude + 1.5));
          }
        }
        final z = WebMercator.fitZoom(
          south: south,
          west: west,
          north: north,
          east: east,
          size: size,
          tileSize: _tileSize,
        ).clamp(2.0, 8.0);
        // 白地図（海岸線・県境）はz5からしか無く、z4以下の淡色地図は外国の地名が目立つため、
        // 日本全体が収まるズームがz5未満でもz5のタイルを縮小して並べる。
        final tileZoom = math.max(z.floor(), _minTileZoom);
        final scale = math.pow(2, z - tileZoom).toDouble();
        final center = Offset.lerp(
          WebMercator.project(south, west, tileZoom, tileSize: _tileSize),
          WebMercator.project(north, east, tileZoom, tileSize: _tileSize),
          0.5,
        )!;
        final viewport = Rect.fromCenter(
          center: center,
          width: size.width / scale,
          height: size.height / scale,
        );
        final tiles = WebMercator.tilesCovering(
          viewport,
          tileZoom,
          tileSize: _tileSize,
        );

        Offset toScreen(double lat, double lon) =>
            (WebMercator.project(lat, lon, tileZoom, tileSize: _tileSize) -
                viewport.topLeft) *
            scale;

        List<Widget> tileLayer(String kind) => [
          for (final t in tiles)
            Positioned(
              left: (t.x * _tileSize - viewport.left) * scale,
              top: (t.y * _tileSize - viewport.top) * scale,
              width: _tileSize * scale,
              height: _tileSize * scale,
              child: Image.network(
                'https://cyberjapandata.gsi.go.jp/xyz/$kind/'
                '${t.z}/${t.x}/${t.y}.png',
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
        ];

        // 都道府県ごとの最大震度（県庁所在地の位置に置く）。弱い順に描き、強い点を上に重ねる。
        final prefMarks = <(Offset, int)>[];
        if (q != null) {
          for (final p in prefectures) {
            final s = q.prefScales[p.name];
            if (s != null) {
              prefMarks.add((toScreen(p.latitude, p.longitude), s));
            }
          }
          prefMarks.sort((a, b) => a.$2.compareTo(b.$2));
        }

        // 同心円の中心。震源が未発表なら最も揺れた都道府県の県庁所在地。
        Offset? rippleCenter;
        if (q != null) {
          if (q.hasHypocenter) {
            rippleCenter = toScreen(q.latitude!, q.longitude!);
          } else if (prefMarks.isNotEmpty) {
            rippleCenter = prefMarks.last.$1;
          }
        }
        final rippleSpec = q == null
            ? null
            : QuakeRippleSpec.forScale(q.maxScale);
        final rippleRadius = rippleSpec == null
            ? 0.0
            : size.shortestSide * rippleSpec.maxRadiusRatio;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(
              child: ColoredBox(color: CyberpunkColors.bgDeep),
            ),
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: _darkMapFilter,
                // 地理院タイルの無い範囲（東経157.5度より東など）は、海と同じ色で埋める。
                child: Stack(
                  children: [
                    const Positioned.fill(child: ColoredBox(color: _seaColor)),
                    ...tileLayer('pale'),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: _outlineFilter,
                // タイルの無い範囲がフィルターで灰色にならないよう、白（=透明になる）で埋める。
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.white),
                    ),
                    ...tileLayer('blank'),
                  ],
                ),
              ),
            ),
            // 台風は地震のマークより下に描く（震源や震度が隠れないように）。
            if (typhoons.isNotEmpty)
              Positioned.fill(
                child: TyphoonMapLayer(
                  typhoons: typhoons,
                  project: toScreen,
                  useFixedJst: useFixedJst,
                ),
              ),
            for (final o in older)
              _at(
                toScreen(o.latitude!, o.longitude!),
                8,
                _Dot(color: seismicColor(o.maxScale).withValues(alpha: 0.55)),
              ),
            // 選んでいない直近の地震。同心円は選んだ地震より淡くし、×印も小さくする。
            for (final o in recent)
              _at(
                toScreen(o.latitude!, o.longitude!),
                size.shortestSide *
                    QuakeRippleSpec.forScale(o.maxScale).maxRadiusRatio *
                    2,
                QuakeRipple(
                  key: ValueKey('ripple-${o.key}-${o.maxScale}'),
                  spec: QuakeRippleSpec.forScale(o.maxScale),
                  color: seismicColor(o.maxScale).withValues(alpha: 0.55),
                  phase: _phaseOf(o),
                ),
              ),
            if (rippleCenter != null && rippleSpec != null)
              _at(
                rippleCenter,
                rippleRadius * 2,
                QuakeRipple(
                  key: ValueKey('ripple-${q!.key}-${q.maxScale}'),
                  spec: rippleSpec,
                  color: seismicColor(q.maxScale),
                  phase: _phaseOf(q),
                ),
              ),
            for (final (pos, s) in prefMarks)
              _at(pos, 18, _PrefScaleMark(scale: s)),
            for (final o in recent)
              _at(
                toScreen(o.latitude!, o.longitude!),
                20,
                _EpicenterMark(color: seismicColor(o.maxScale)),
              ),
            if (q != null && q.hasHypocenter)
              _at(
                rippleCenter!,
                30,
                _EpicenterMark(color: seismicColor(q.maxScale)),
              ),
            // 各マークの右上に、その地震の震度を小さく添える（ほかのマークより上に描く）。
            for (final o in older)
              _scaleTag(toScreen(o.latitude!, o.longitude!), 8, o.maxScale),
            for (final o in recent)
              _scaleTag(toScreen(o.latitude!, o.longitude!), 20, o.maxScale),
            if (q != null && q.hasHypocenter)
              _scaleTag(rippleCenter!, 30, q.maxScale, emphasized: true),
            if (q != null && !q.hasHypocenter && rippleCenter != null)
              Positioned(
                left: rippleCenter.dx + 12,
                top: rippleCenter.dy - 8,
                child: const Text(
                  '震源 調査中',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 同心円の広がり始めを地震ごとにずらし、重なっても一斉に点滅して見えないようにする。
  static double _phaseOf(Earthquake q) => (q.key.hashCode % 1000) / 1000;

  /// マーク（中心[p]、大きさ[markSize]）の右上に置く、震度の小さな札。
  Widget _scaleTag(
    Offset p,
    double markSize,
    int scale, {
    bool emphasized = false,
  }) {
    final color = seismicColor(scale);
    return Positioned(
      left: p.dx + markSize * 0.35,
      top: p.dy - markSize * 0.35 - (emphasized ? 16 : 13),
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: CyberpunkColors.bgDeep.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.8), width: 0.8),
          ),
          child: Text(
            SeismicScale.label(scale),
            style: TextStyle(
              fontSize: emphasized ? 12 : 9,
              height: 1.2,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _at(Offset p, double size, Widget child) => Positioned(
    left: p.dx - size / 2,
    top: p.dy - size / 2,
    width: size,
    height: size,
    child: IgnorePointer(child: child),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// 都道府県の最大震度を示す小さな四角（中に震度の数字）。
class _PrefScaleMark extends StatelessWidget {
  const _PrefScaleMark({required this.scale});
  final int scale;

  @override
  Widget build(BuildContext context) {
    final color = seismicColor(scale);
    final label = SeismicScale.label(scale);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black54, width: 0.8),
      ),
      child: Text(
        // 「5弱」「6強」は枠に収まらないので数字と記号にする。
        label.length > 1 ? '${label[0]}${label[1] == '強' ? '+' : '-'}' : label,
        style: const TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// 震源の×印（発光）。
class _EpicenterMark extends StatelessWidget {
  const _EpicenterMark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _EpicenterPainter(color));
}

class _EpicenterPainter extends CustomPainter {
  _EpicenterPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.32;
    void cross(Paint p) {
      canvas.drawLine(c + Offset(-r, -r), c + Offset(r, r), p);
      canvas.drawLine(c + Offset(-r, r), c + Offset(r, -r), p);
    }

    cross(
      Paint()
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    cross(
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
    cross(
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_EpicenterPainter old) => old.color != color;
}

/// 震源から同心円が繰り返し広がる演出。大きさ・本数・速さは[QuakeRippleSpec]（震度で決まる）。
class QuakeRipple extends StatefulWidget {
  const QuakeRipple({
    super.key,
    required this.spec,
    required this.color,
    this.phase = 0,
  });

  final QuakeRippleSpec spec;

  /// 円の色。不透明度を下げて渡すと全体が淡くなる。
  final Color color;

  /// 広がり始めの位置（0〜1）。複数の震源の円が同時に広がらないようずらす。
  final double phase;

  @override
  State<QuakeRipple> createState() => _QuakeRippleState();
}

class _QuakeRippleState extends State<QuakeRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.spec.period,
    value: widget.phase,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _RipplePainter(
          t: _controller.value,
          rings: widget.spec.rings,
          color: widget.color,
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.t, required this.rings, required this.color});

  final double t;
  final int rings;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    // 中心の淡い光。
    canvas.drawCircle(
      c,
      maxR * 0.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: color.a * 0.35),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: maxR * 0.25)),
    );
    for (var i = 0; i < rings; i++) {
      final phase = (t + i / rings) % 1.0;
      final r = maxR * phase;
      if (r < 1) continue;
      final fade = math.pow(1 - phase, 1.4).toDouble();
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = color.withValues(alpha: color.a * 0.35 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: color.a * 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.t != t || old.rings != rings || old.color != color;
}
