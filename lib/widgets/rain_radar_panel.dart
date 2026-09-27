import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/prefectures.dart';
import '../models/rain_radar.dart';
import '../providers/core_providers.dart';
import '../providers/settings_provider.dart';
import '../services/rain_radar_service.dart';
import '../theme/cyberpunk_colors.dart';
import '../util/app_clock.dart';
import '../util/web_mercator.dart';

/// 選択中の釣り場周辺の雨雲レーダー（気象庁ナウキャスト）を、過去1時間〜1時間先まで
/// アニメーション表示するカード。
///
/// 表示中だけデータを取得・更新し、非表示（dispose）になったらタイマーも止める。
/// 常時表示していないため、気象庁サーバへのアクセスは表示している間に限られる。
class RainRadarPanel extends ConsumerStatefulWidget {
  const RainRadarPanel({super.key, this.headerTrailing});

  /// ヘッダー右端に置くウィジェット（釣り情報への切り替えボタン）。
  final Widget? headerTrailing;

  @override
  ConsumerState<RainRadarPanel> createState() => _RainRadarPanelState();
}

class _RainRadarPanelState extends ConsumerState<RainRadarPanel> {
  /// 地図の縮尺。z8で1タイル（256px）が約110km四方になり、釣り場の周囲
  /// 百数十kmの雨雲の接近が見渡せる。
  static const _zoom = 8;
  static const _tileSize = 256.0;

  /// 気象庁のナウキャストは5分ごとに更新される。
  static const _refreshInterval = Duration(minutes: 5);
  static const _frameDuration = Duration(milliseconds: 450);

  /// 「いま」（最新の実況）のコマと最後のコマでは少し止めて見やすくする。
  static const _holdAtLatest = Duration(milliseconds: 1500);
  static const _holdAtEnd = Duration(milliseconds: 2200);

  /// 広域表示（地方全体）と現状の縮尺を切り替えるときのフェード時間。
  static const _viewFade = Duration(milliseconds: 500);

  /// フェードで縮尺を切り替え終えてから、先頭のコマに戻すまでの間。
  static const _holdAfterFade = Duration(milliseconds: 600);

  /// 同じ縮尺で何回再生してから縮尺を切り替えるか。
  static const _playsPerScale = 2;

  List<RadarFrame> _frames = const [];
  int _index = 0;

  /// true なら釣り場を含む地方全体を見渡す広域表示。同じ縮尺で[_playsPerScale]回再生するたびに切り替える。
  bool _wide = false;

  /// 今の縮尺で最後のコマまで再生し終えた回数。
  int _playsAtScale = 0;
  String? _error;
  bool _loading = true;
  Timer? _refreshTimer;
  Timer? _frameTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _frameTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final frames = await ref.read(rainRadarServiceProvider).fetchFrames();
      if (!mounted) return;
      setState(() {
        _frames = frames;
        _error = frames.isEmpty ? 'レーダーデータがありません' : null;
        _loading = false;
        _index = 0;
      });
      _scheduleNextFrame();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // 取得済みのコマがあれば古いまま表示を続け、エラーは初回のみ表示する。
        if (_frames.isEmpty) _error = '雨雲レーダーを取得できませんでした: $e';
        _loading = false;
      });
    }
  }

  int get _latestPastIndex => _frames.lastIndexWhere((f) => !f.isForecast);

  void _scheduleNextFrame() {
    _frameTimer?.cancel();
    if (_frames.length < 2) return;
    final hold = _index == _frames.length - 1
        ? _holdAtEnd
        : _index == _latestPastIndex
            ? _holdAtLatest
            : _frameDuration;
    _frameTimer = Timer(hold, () {
      if (!mounted) return;
      final atEnd = _index == _frames.length - 1;
      if (atEnd && ++_playsAtScale >= _playsPerScale) {
        // 巻き戻しとフェードが重なるとせわしなく見えるため、最終コマのまま縮尺を切り替え、
        // フェードが終わって少し置いてから先頭に戻して再生する。
        setState(() {
          _wide = !_wide;
          _playsAtScale = 0;
        });
        _frameTimer = Timer(_viewFade + _holdAfterFade, () {
          if (!mounted) return;
          setState(() => _index = 0);
          _scheduleNextFrame();
        });
        return;
      }
      setState(() => _index = atEnd ? 0 : _index + 1);
      _scheduleNextFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final location = settings.location;
    final frame = _frames.isEmpty ? null : _frames[_index];
    final region =
        nearestPrefecture(location.latitude, location.longitude).region;
    final capitals = [
      for (final p in prefectures)
        if (settings.capitalMarkerPrefectures.contains(p.code)) p,
    ];

    Widget map({required bool wide}) => AnimatedOpacity(
          opacity: wide == _wide ? 1 : 0,
          duration: _viewFade,
          child: _RadarMap(
            latitude: location.latitude,
            longitude: location.longitude,
            region: wide ? region : null,
            zoom: _zoom,
            tileSize: _tileSize,
            frames: _frames,
            index: _index,
            capitals: capitals,
          ),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.umbrella, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  '雨雲レーダー',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                Text(
                  _wide ? '${location.name} ・ ${region.label}全域' : location.name,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const Spacer(),
                if (frame != null)
                  _FrameLabel(
                    frame: frame,
                    latest: _frames[_latestPastIndex],
                    useFixedJst: settings.useFixedJst,
                  ),
                if (widget.headerTrailing != null) ...[
                  const SizedBox(width: 4),
                  widget.headerTrailing!,
                ],
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _error != null && _frames.isEmpty
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          // 両方の縮尺のタイルを常に読み込んでおき、切り替え時は重ねてフェードするだけにする。
                          map(wide: false),
                          map(wide: true),
                          const Positioned(
                            right: 6,
                            top: 6,
                            child: _RainLegend(),
                          ),
                          const Positioned(
                            right: 6,
                            bottom: 4,
                            child: Text(
                              '出典：気象庁 / 地理院タイル',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                          if (_loading)
                            const Center(child: CircularProgressIndicator()),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 4),
            _Timeline(frames: _frames, index: _index),
          ],
        ),
      ),
    );
  }
}

/// 地図（地理院タイル）＋全コマ分の雨雲タイル＋雷＋釣り場マーカー。
///
/// 全コマのタイルを最初からウィジェットとして読み込んでおき、表示中のコマ以外は
/// 不透明度0（描画スキップ）にしておく。コマ送りのたびに画像を読み直さないため、
/// アニメーション中のちらつきが起きない。
class _RadarMap extends StatelessWidget {
  const _RadarMap({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.tileSize,
    required this.frames,
    required this.index,
    required this.capitals,
    this.region,
  });

  final double latitude;
  final double longitude;

  /// 現状（釣り場中心）の表示に使うズーム。
  final int zoom;
  final double tileSize;
  final List<RadarFrame> frames;
  final int index;

  /// 県庁所在地のマークを出す都道府県。
  final List<Prefecture> capitals;

  /// 指定されていれば、その地方全体が収まる広域表示にする。
  final JapanRegion? region;

  /// 広域表示のズームの範囲。上限は現状より必ず引いた縮尺になるよう[zoom]未満にする。
  static const _minWideZoom = 4.0;

  /// 地方の範囲の外側に足す余白（範囲の幅・高さに対する割合）。
  static const _wideMargin = 0.06;

  /// 釣り場のマークとこれ以上近い県庁所在地のマークは、釣り場を優先して描かない。
  static const _capitalHideDistance = 12.0;

  /// 地理院タイル（淡色地図）を反転・減光して、ダークテーマに馴染む夜間地図風にする。
  /// 色を変えているため、出典ページでは「加工して作成」と表記している。
  static const _darkMapFilter = ColorFilter.matrix([
    -0.32, 0, 0, 0, 86, //
    0, -0.40, 0, 0, 108, //
    0, 0, -0.50, 0, 140, //
    0, 0, 0, 1, 0, //
  ]);

  /// 白地図（白地に灰色#444の線）を、白は透明・線は半透明の明るい灰色にする。
  /// 線の不透明度は約45%（暗い地図の上で「少しだけ明るく」見える程度）。
  static const _wideOutlineFilter = ColorFilter.matrix([
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
        // 読み込むタイルの整数ズーム[tileZoom]と、それを画面に並べるときの拡大率[scale]。
        // 広域表示では地方の範囲が収まる小数ズームを求め、切り捨てた整数ズームのタイルを拡大して使う。
        final int tileZoom;
        final double scale;
        final Offset center;
        final r = region;
        if (r == null) {
          tileZoom = zoom;
          scale = 1;
          center = WebMercator.project(latitude, longitude, zoom,
              tileSize: tileSize);
        } else {
          // 釣り場が地方の範囲の端にある場合も含め、釣り場が必ず入るようにする。
          final south = math.min(r.south, latitude);
          final north = math.max(r.north, latitude);
          final west = math.min(r.west, longitude);
          final east = math.max(r.east, longitude);
          final mLat = (north - south) * _wideMargin;
          final mLon = (east - west) * _wideMargin;
          final z = WebMercator.fitZoom(
            south: south - mLat,
            west: west - mLon,
            north: north + mLat,
            east: east + mLon,
            size: size,
            tileSize: tileSize,
          ).clamp(_minWideZoom, zoom - 1.0);
          tileZoom = z.floor();
          scale = math.pow(2, z - tileZoom).toDouble();
          final sw =
              WebMercator.project(south, west, tileZoom, tileSize: tileSize);
          final ne =
              WebMercator.project(north, east, tileZoom, tileSize: tileSize);
          center = Offset.lerp(sw, ne, 0.5)!;
        }
        final viewport = Rect.fromCenter(
          center: center,
          width: size.width / scale,
          height: size.height / scale,
        );
        final tiles =
            WebMercator.tilesCovering(viewport, tileZoom, tileSize: tileSize);

        /// 緯度経度を、このウィジェット内の画面座標に変換する。
        Offset toScreen(double lat, double lon) =>
            (WebMercator.project(lat, lon, tileZoom, tileSize: tileSize) -
                viewport.topLeft) *
            scale;

        final spot = toScreen(latitude, longitude);
        final bounds = (Offset.zero & size).inflate(8);
        final capitalPoints = [
          for (final p in capitals)
            if (toScreen(p.latitude, p.longitude) case final pos
                when bounds.contains(pos) &&
                    (pos - spot).distance >= _capitalHideDistance)
              pos,
        ];

        List<Widget> tileLayer(String Function(TileIndex t) url) => [
              for (final t in tiles)
                Positioned(
                  left: (t.x * tileSize - viewport.left) * scale,
                  top: (t.y * tileSize - viewport.top) * scale,
                  width: tileSize * scale,
                  height: tileSize * scale,
                  child: Image.network(
                    url(t),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
            ];

        final strikes = index < frames.length
            ? frames[index].strikes
            : const <LightningStrike>[];

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(
              child: ColoredBox(color: CyberpunkColors.bgDeep),
            ),
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: _darkMapFilter,
                child: Stack(
                  children: tileLayer(
                    (t) => 'https://cyberjapandata.gsi.go.jp/xyz/pale/'
                        '${t.z}/${t.x}/${t.y}.png',
                  ),
                ),
              ),
            ),
            for (var i = 0; i < frames.length; i++)
              Positioned.fill(
                child: Opacity(
                  opacity: i == index ? 0.85 : 0,
                  child: Stack(
                    children: tileLayer(
                      (t) => RainRadarService.radarTileUrl(frames[i], t),
                    ),
                  ),
                ),
              ),
            // 淡色地図の海岸線は暗く細くて見えにくいため、白地図（海岸線と都道府県境だけの地図）の線を
            // 明るい灰色にして雨雲の上に重ねる。白地図では海岸線と県境が同じ色で区別できないので、
            // 県境も同じように明るくなる。
            Positioned.fill(
                child: ColorFiltered(
                  colorFilter: _wideOutlineFilter,
                  child: Stack(
                    children: tileLayer(
                      (t) => 'https://cyberjapandata.gsi.go.jp/xyz/blank/'
                          '${t.z}/${t.x}/${t.y}.png',
                    ),
                  ),
                ),
              ),
            for (final s in strikes)
              _positionedAt(
                toScreen(s.latitude, s.longitude),
                const Icon(
                  Icons.bolt,
                  size: 18,
                  color: CyberpunkColors.neonAmber,
                  shadows: [
                    Shadow(color: CyberpunkColors.neonAmber, blurRadius: 8),
                  ],
                ),
                18,
              ),
            for (final pos in capitalPoints)
              _positionedAt(pos, const _CapitalMarker(), 14),
            _positionedAt(spot, const _SpotMarker(), 28),
          ],
        );
      },
    );
  }

  Widget _positionedAt(Offset p, Widget child, double size) => Positioned(
        left: p.dx - size / 2,
        top: p.dy - size / 2,
        width: size,
        height: size,
        child: child,
      );
}

/// 県庁所在地を示すマゼンタの小さな点。釣り場のマークより控えめにする。
class _CapitalMarker extends StatelessWidget {
  const _CapitalMarker();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _CapitalMarkerPainter());
}

class _CapitalMarkerPainter extends CustomPainter {
  const _CapitalMarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      5,
      Paint()
        ..color = CyberpunkColors.neonMagenta.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(c, 2.6, Paint()..color = CyberpunkColors.neonMagenta);
    canvas.drawCircle(
      c,
      2.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white70,
    );
  }

  @override
  bool shouldRepaint(_CapitalMarkerPainter old) => false;
}

/// 釣り場の位置を示す、ゆっくり広がるネオンのリング。
class _SpotMarker extends StatefulWidget {
  const _SpotMarker();

  @override
  State<_SpotMarker> createState() => _SpotMarkerState();
}

class _SpotMarkerState extends State<_SpotMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
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
        painter: _SpotMarkerPainter(_controller.value),
      ),
    );
  }
}

class _SpotMarkerPainter extends CustomPainter {
  _SpotMarkerPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      4 + (maxR - 4) * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = CyberpunkColors.neonCyan.withValues(alpha: 1 - t),
    );
    canvas.drawCircle(c, 3.5, Paint()..color = CyberpunkColors.neonCyan);
    canvas.drawCircle(
      c,
      3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SpotMarkerPainter old) => old.t != t;
}

/// 表示中のコマの時刻（「実況 15:25」「予報 +30分 16:05」）。
class _FrameLabel extends StatelessWidget {
  const _FrameLabel({
    required this.frame,
    required this.latest,
    required this.useFixedJst,
  });

  final RadarFrame frame;
  final RadarFrame latest;
  final bool useFixedJst;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm')
        .format(appLocalize(frame.validTimeUtc, useFixedJst));
    final String kind;
    final Color color;
    if (frame.isForecast) {
      final ahead =
          frame.validTimeUtc.difference(latest.validTimeUtc).inMinutes;
      kind = '予報 +$ahead分';
      color = CyberpunkColors.neonMagenta;
    } else if (identical(frame, latest)) {
      kind = '現在';
      color = CyberpunkColors.neonGreen;
    } else {
      kind = '実況';
      color = CyberpunkColors.neonCyan;
    }
    return Text(
      '$kind  $time',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// 下部のタイムライン。実況（シアン）と予報（マゼンタ）のコマを並べ、表示中のコマを光らせる。
class _Timeline extends StatelessWidget {
  const _Timeline({required this.frames, required this.index});

  final List<RadarFrame> frames;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (frames.isEmpty) return const SizedBox(height: 6);
    return SizedBox(
      height: 6,
      child: Row(
        children: [
          for (var i = 0; i < frames.length; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: (frames[i].isForecast
                          ? CyberpunkColors.neonMagenta
                          : CyberpunkColors.neonCyan)
                      .withValues(alpha: i == index ? 1 : (i < index ? 0.45 : 0.18)),
                  boxShadow: i == index
                      ? [
                          BoxShadow(
                            color: frames[i].isForecast
                                ? CyberpunkColors.neonMagenta
                                : CyberpunkColors.neonCyan,
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 降水強度の凡例（気象庁の配色）。
class _RainLegend extends StatelessWidget {
  const _RainLegend();

  static const _steps = [
    (80, Color(0xFFB40068)),
    (50, Color(0xFFFF2800)),
    (30, Color(0xFFFF9900)),
    (20, Color(0xFFFAF500)),
    (10, Color(0xFF0041FF)),
    (5, Color(0xFF218CFF)),
    (1, Color(0xFFA0D2FF)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('mm/h', style: TextStyle(fontSize: 8, color: Colors.white60)),
          for (final (mm, color) in _steps)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 7, color: color),
                const SizedBox(width: 3),
                SizedBox(
                  width: 14,
                  child: Text(
                    '$mm',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 8, color: Colors.white70),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bolt, size: 9, color: CyberpunkColors.neonAmber),
              Text('雷', style: TextStyle(fontSize: 8, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}
