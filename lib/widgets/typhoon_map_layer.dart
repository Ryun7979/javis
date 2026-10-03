import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/typhoon.dart';
import '../theme/cyberpunk_colors.dart';
import '../util/app_clock.dart';
import '../util/geo.dart';

/// 緯度経度を地図上の画面座標に直す関数。
typedef MapProjector = Offset Function(double latitude, double longitude);

/// 強風域（風速15m/s以上）の色。
const typhoonGaleColor = Color(0xFFFFE600);

/// 暴風域（風速25m/s以上）・暴風警戒域の色。
const typhoonStormColor = CyberpunkColors.neonRed;

/// 地図に重ねる台風の表示（これまでの経路・現在位置・強風域・暴風域・予報円・暴風警戒域）。
///
/// 気象庁の台風情報の図と同じ約束で描く: 強風域は黄、暴風域は赤、予報円は白の破線、
/// 暴風警戒域は赤の細線。熱帯低気圧は全体を淡くする。
class TyphoonMapLayer extends StatelessWidget {
  const TyphoonMapLayer({
    super.key,
    required this.typhoons,
    required this.project,
    required this.useFixedJst,
  });

  final List<Typhoon> typhoons;
  final MapProjector project;
  final bool useFixedJst;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('d日H時');
    Offset at(GeoPoint p) => project(p.latitude, p.longitude);

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 震源の同心円のアニメーションのたびに描き直さないよう、層を分ける。
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TyphoonPainter(typhoons: typhoons, project: project),
              ),
            ),
          ),
          for (final t in typhoons) ...[
            // 予報円の右に、その予報の日時（24時間ごと）。
            for (final f in t.forecasts)
              if (f.advancedHours % 24 == 0)
                _label(
                  at(destinationPoint(f.center, 90, f.probabilityRadiusM)) +
                      const Offset(4, -7),
                  time.format(appLocalize(f.validTimeUtc, useFixedJst)),
                  Colors.white,
                ),
            _label(
              at(t.center) + const Offset(12, -20),
              t.label,
              t.isTyphoon ? CyberpunkColors.neonAmber : Colors.white70,
              bordered: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(Offset p, String text, Color color, {bool bordered = false}) =>
      Positioned(
        left: p.dx,
        top: p.dy,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: CyberpunkColors.bgDeep.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(3),
            border: bordered
                ? Border.all(color: color.withValues(alpha: 0.8), width: 0.8)
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: bordered ? 11 : 10,
              height: 1.25,
              fontWeight: bordered ? FontWeight.bold : null,
              color: color,
            ),
          ),
        ),
      );
}

class _TyphoonPainter extends CustomPainter {
  _TyphoonPainter({required this.typhoons, required this.project});

  final List<Typhoon> typhoons;
  final MapProjector project;

  Offset _at(GeoPoint p) => project(p.latitude, p.longitude);

  /// 円弧（地球上の円）を画面上の折れ線にする。メルカトル図法では高緯度ほど縦に伸びた形になる。
  Path _arc(GeoPoint center, double radiusM, double startDeg, double endDeg) {
    final end = endDeg < startDeg ? endDeg + 360 : endDeg;
    final steps = math.max(2, ((end - startDeg) / 5).ceil());
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final p = _at(
        destinationPoint(
          center,
          startDeg + (end - startDeg) * i / steps,
          radiusM,
        ),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  Path _circle(GeoPoint center, double radiusM) =>
      _arc(center, radiusM, 0, 360)..close();

  Path _area(TyphoonArea area) {
    final path = Path();
    for (final c in area.circles) {
      path.addPath(_circle(c.center, c.radiusM), Offset.zero);
    }
    for (final a in area.arcs) {
      path.addPath(
        _arc(a.center, a.radiusM, a.startDeg, a.endDeg),
        Offset.zero,
      );
    }
    for (final (a, b) in area.lines) {
      final pa = _at(a), pb = _at(b);
      path
        ..moveTo(pa.dx, pa.dy)
        ..lineTo(pb.dx, pb.dy);
    }
    return path;
  }

  static Path _dashed(Path source, {double dash = 5, double gap = 4}) {
    final path = Path();
    for (final metric in source.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        path.addPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          Offset.zero,
        );
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final t in typhoons) {
      // 熱帯低気圧は控えめに描く。
      final strength = t.isTyphoon ? 1.0 : 0.55;
      Paint stroke(Color color, double width, [double alpha = 1]) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: alpha * strength);
      Paint fill(Color color, double alpha) =>
          Paint()..color = color.withValues(alpha: alpha * strength);

      // 暴風警戒域（予報の期間中に暴風域に入るおそれのある範囲）。
      canvas.drawPath(
        _area(t.stormWarningArea),
        stroke(typhoonStormColor, 1.2, 0.75),
      );

      // 強風域・暴風域（実況）。
      final gale = _area(t.galeArea);
      canvas.drawPath(gale, fill(typhoonGaleColor, 0.10));
      canvas.drawPath(gale, stroke(typhoonGaleColor, 1.6, 0.9));
      final storm = _area(t.stormArea);
      canvas.drawPath(storm, fill(typhoonStormColor, 0.22));
      canvas.drawPath(storm, stroke(typhoonStormColor, 1.8));

      // これまでの経路。
      if (t.track.length >= 2) {
        final path = Path();
        for (final (i, p) in t.track.indexed) {
          final o = _at(p);
          i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, stroke(CyberpunkColors.neonCyan, 1.6, 0.8));
      }

      // 予報円（白の破線）と、円どうしをつなぐ線・中心を結ぶ線。
      final white = stroke(Colors.white, 1.3, 0.9);
      final centerLine = Path();
      final current = _at(t.center);
      centerLine.moveTo(current.dx, current.dy);
      for (final f in t.forecasts) {
        final c = _at(f.center);
        centerLine.lineTo(c.dx, c.dy);
        canvas.drawPath(
          _dashed(_circle(f.center, f.probabilityRadiusM)),
          white,
        );
        for (final (a, b) in f.tangents) {
          canvas.drawLine(_at(a), _at(b), stroke(Colors.white, 1, 0.6));
        }
        canvas.drawCircle(c, 1.8, fill(Colors.white, 0.9));
      }
      canvas.drawPath(
        _dashed(centerLine, dash: 3, gap: 3),
        stroke(Colors.white, 1, 0.7),
      );

      _paintMark(canvas, current, strength);
    }
  }

  /// 現在位置の台風マーク（渦を巻く2本の腕と中心の丸）。
  void _paintMark(Canvas canvas, Offset c, double strength) {
    final color = typhoonStormColor.withValues(alpha: strength);
    canvas.drawCircle(
      c,
      11,
      Paint()
        ..color = color.withValues(alpha: 0.45 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: strength);
    for (final start in const [-math.pi / 2, math.pi / 2]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 8.5),
        start,
        math.pi * 0.6,
        false,
        arm,
      );
    }
    canvas.drawCircle(c, 5, Paint()..color = Colors.white);
    canvas.drawCircle(c, 3.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TyphoonPainter old) => true;
}

/// 地図の隅に重ねる、台風の概要（号数・名前・勢力・位置・進み方）。
/// [compact]のときは1行（号数・強さ・気圧）だけにする。
class TyphoonInfoBox extends StatelessWidget {
  const TyphoonInfoBox({
    super.key,
    required this.typhoon,
    required this.useFixedJst,
    this.compact = false,
  });

  final Typhoon typhoon;
  final bool useFixedJst;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = typhoon;
    final color = t.isTyphoon ? CyberpunkColors.neonAmber : Colors.white70;
    const sub = TextStyle(fontSize: 12, color: Colors.white70);
    final time = DateFormat(
      'd日H時',
    ).format(appLocalize(t.validTimeUtc, useFixedJst));
    final power = [?t.scale, ?t.intensity].join('・');
    final wind = t.maxWindMs;
    final gust = t.maxGustMs;
    final next = t.forecasts.where((f) => f.advancedHours == 24).firstOrNull;

    if (compact) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: CyberpunkColors.bgDeep.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Flexible(
              child: Text(
                t.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            if (t.intensity != null)
              Text(t.intensity!, style: const TextStyle(fontSize: 12)),
            if (t.pressureHpa != null)
              Text('${t.pressureHpa}hPa', style: sub),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: CyberpunkColors.bgDeep.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [t.label, ?t.name].join(' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            [
              if (power.isNotEmpty) power,
              if (t.pressureHpa != null) '${t.pressureHpa}hPa',
            ].join('  '),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          if (wind != null)
            Text(
              '最大風速 ${wind}m/s${gust != null ? '（瞬間 ${gust}m/s）' : ''}',
              style: sub,
            ),
          Text(
            [?t.location, ?t.course, ?t.speed].join('  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: sub,
          ),
          Text(
            [
              '$time現在',
              if (next?.pressureHpa != null) '24時間後 ${next!.pressureHpa}hPa',
            ].join('  ・  '),
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
