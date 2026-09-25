import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  List<RadarFrame> _frames = const [];
  int _index = 0;
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
      setState(() => _index = (_index + 1) % _frames.length);
      _scheduleNextFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final location = settings.location;
    final frame = _frames.isEmpty ? null : _frames[_index];

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
                  location.name,
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
                          _RadarMap(
                            latitude: location.latitude,
                            longitude: location.longitude,
                            zoom: _zoom,
                            tileSize: _tileSize,
                            frames: _frames,
                            index: _index,
                          ),
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
  });

  final double latitude;
  final double longitude;
  final int zoom;
  final double tileSize;
  final List<RadarFrame> frames;
  final int index;

  /// 地理院タイル（淡色地図）を反転・減光して、ダークテーマに馴染む夜間地図風にする。
  /// 色を変えているため、出典ページでは「加工して作成」と表記している。
  static const _darkMapFilter = ColorFilter.matrix([
    -0.32, 0, 0, 0, 86, //
    0, -0.40, 0, 0, 108, //
    0, 0, -0.50, 0, 140, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = WebMercator.project(
          latitude,
          longitude,
          zoom,
          tileSize: tileSize,
        );
        final viewport = Rect.fromCenter(
          center: center,
          width: size.width,
          height: size.height,
        );
        final tiles =
            WebMercator.tilesCovering(viewport, zoom, tileSize: tileSize);

        List<Widget> tileLayer(String Function(TileIndex t) url) => [
              for (final t in tiles)
                Positioned(
                  left: t.x * tileSize - viewport.left,
                  top: t.y * tileSize - viewport.top,
                  width: tileSize,
                  height: tileSize,
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
            for (final s in strikes)
              _positionedAt(
                WebMercator.project(
                      s.latitude,
                      s.longitude,
                      zoom,
                      tileSize: tileSize,
                    ) -
                    viewport.topLeft,
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
            _positionedAt(center - viewport.topLeft, const _SpotMarker(), 28),
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
