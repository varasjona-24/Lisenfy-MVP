import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/globe_land_shape.dart';
import '../models/globe_projected_point.dart';
import '../utils/globe_projection.dart';
import '../widgets/world_map_canvas.dart';

class WorldGlobePainter extends CustomPainter {
  const WorldGlobePainter({
    required this.landShapes,
    required this.projectedCountries,
    required this.selectedCountryCode,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.colorScheme,
  });

  final List<GlobeLandShape> landShapes;
  final List<GlobeProjectedPoint> projectedCountries;
  final String? selectedCountryCode;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final radius = shortest * 0.38 * zoom;
    final center = Offset(size.width / 2, size.height / 2);
    final globeRect = Rect.fromCircle(center: center, radius: radius);

    _drawSpace(canvas, size, center, radius);
    _drawShadow(canvas, center, radius);
    _drawAtmosphere(canvas, center, radius);
    _drawOcean(canvas, center, radius);

    canvas.save();
    canvas.clipPath(Path()..addOval(globeRect));
    _drawLand(canvas, center, radius);
    _drawGraticule(canvas, center, radius);
    _drawTerminator(canvas, center, radius);
    _drawCountryPoints(canvas, center, radius);
    canvas.restore();

    _drawSelectedRing(canvas, center, radius);
  }

  void _drawSpace(Canvas canvas, Size size, Offset center, double radius) {
    final rect = Offset.zero & size;
    final shader = RadialGradient(
      center: const Alignment(-0.25, -0.35),
      radius: 1.1,
      colors: [
        const Color(0xFF122B4B).withValues(alpha: 0.72),
        const Color(0xFF061326),
        Colors.black,
      ],
    ).createShader(rect);

    canvas.drawRect(rect, Paint()..shader = shader);

    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeCap = StrokeCap.round;
    final seeds = <Offset>[
      Offset(size.width * .16, size.height * .22),
      Offset(size.width * .24, size.height * .72),
      Offset(size.width * .72, size.height * .18),
      Offset(size.width * .84, size.height * .64),
      Offset(size.width * .58, size.height * .82),
      Offset(size.width * .38, size.height * .12),
    ];
    for (final seed in seeds) {
      final distance = (seed - center).distance;
      if (distance < radius * 1.08) continue;
      canvas.drawCircle(seed, 1.1, starPaint);
    }
  }

  void _drawShadow(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center.translate(9, 13),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
  }

  void _drawAtmosphere(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius + 7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = const Color(0xFF65BFFF).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
    );
    canvas.drawCircle(
      center,
      radius + 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _drawOcean(Canvas canvas, Offset center, double radius) {
    final shader = RadialGradient(
      center: const Alignment(-0.42, -0.46),
      radius: 1.12,
      colors: const [Color(0xFF4B9EF0), Color(0xFF174D91), Color(0xFF071B3A)],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, Paint()..shader = shader);
  }

  void _drawLand(Canvas canvas, Offset center, double radius) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5FC58D).withValues(alpha: 0.46);
    final ridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.16);

    for (final shape in landShapes) {
      for (final ring in shape.rings) {
        final projectedRing = _projectLandRing(ring, center, radius);
        if (projectedRing.length < 3) continue;

        if (projectedRing.every((point) => point.visible)) {
          final path = _buildPath(
            projectedRing
                .map((point) => point.position)
                .toList(growable: false),
            close: true,
          );
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, ridgePaint);
          continue;
        }

        final runs = _visibleRuns(projectedRing);
        for (final run in runs) {
          if (run.length < 2) continue;
          if (run.length < 3) {
            canvas.drawPath(_buildPath(run, close: false), ridgePaint);
            continue;
          }

          final clippedPath = _buildHorizonClosedPath(
            run,
            center: center,
            radius: radius,
          );
          canvas.drawPath(clippedPath, fillPaint);
          canvas.drawPath(clippedPath, ridgePaint);
        }
      }
    }
  }

  List<_ProjectedLandPoint> _projectLandRing(
    List<GlobeLandPoint> ring,
    Offset center,
    double radius,
  ) {
    return ring
        .map((point) {
          final rotated = GlobeProjection.rotate(
            point: GlobeProjection.latitudeLongitudeToVector(
              latitude: point.latitude,
              longitude: point.longitude,
            ),
            rotationX: rotationX,
            rotationY: rotationY,
          );
          return _ProjectedLandPoint(
            position: GlobeProjection.project(
              point: rotated,
              center: center,
              radius: radius,
            ),
            visible: rotated.z >= 0.015,
          );
        })
        .toList(growable: false);
  }

  List<List<Offset>> _visibleRuns(List<_ProjectedLandPoint> ring) {
    final runs = <List<Offset>>[];
    var current = <Offset>[];

    for (final point in ring) {
      if (point.visible) {
        current.add(point.position);
        continue;
      }

      if (current.isEmpty) continue;
      runs.add(current);
      current = <Offset>[];
    }

    if (current.isNotEmpty) {
      runs.add(current);
    }

    if (runs.length > 1 && ring.first.visible && ring.last.visible) {
      final merged = <Offset>[...runs.last, ...runs.first];
      runs
        ..removeLast()
        ..removeAt(0)
        ..insert(0, merged);
    }

    return runs;
  }

  Path _buildPath(List<Offset> points, {required bool close}) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (close) path.close();
    return path;
  }

  Path _buildHorizonClosedPath(
    List<Offset> points, {
    required Offset center,
    required double radius,
  }) {
    final path = _buildPath(points, close: false);
    final startAngle = _angleFromCenter(points.last, center);
    final endAngle = _angleFromCenter(points.first, center);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      _shortestSweep(startAngle, endAngle),
      false,
    );
    path.close();
    return path;
  }

  double _angleFromCenter(Offset point, Offset center) {
    final delta = point - center;
    return math.atan2(delta.dy, delta.dx);
  }

  double _shortestSweep(double startAngle, double endAngle) {
    var sweep = endAngle - startAngle;
    while (sweep <= -math.pi) {
      sweep += math.pi * 2;
    }
    while (sweep > math.pi) {
      sweep -= math.pi * 2;
    }
    return sweep;
  }

  void _drawGraticule(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.075);

    for (final scale in <double>[0.28, 0.52, 0.74]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2 * scale,
        ),
        paint,
      );
    }

    for (final scale in <double>[0.32, 0.62]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 * scale,
          height: radius * 2,
        ),
        paint,
      );
    }

    canvas.drawLine(
      center.translate(-radius, 0),
      center.translate(radius, 0),
      paint,
    );
  }

  void _drawTerminator(Canvas canvas, Offset center, double radius) {
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.10),
        Colors.transparent,
        Colors.black.withValues(alpha: 0.30),
      ],
      stops: const [0.0, 0.48, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..shader = shader);
  }

  void _drawCountryPoints(Canvas canvas, Offset center, double radius) {
    final sorted =
        projectedCountries
            .where((point) => point.visible)
            .toList(growable: false)
          ..sort((a, b) => a.depth.compareTo(b.depth));

    for (final point in sorted) {
      final selected = selectedCountryCode == point.country.code;
      final color = selected
          ? colorScheme.primary
          : WorldMapRegionColors.colorFor(point.country.regionKey);
      final pointScale = 0.58 + (point.depth * 0.42);
      final opacity = 0.22 + (point.depth * 0.78);
      final outerRadius = (selected ? 9.0 : 6.0) * pointScale;
      final innerRadius = (selected ? 3.2 : 2.4) * pointScale;

      canvas.drawCircle(
        point.position,
        outerRadius + 4,
        Paint()
          ..color = color.withValues(alpha: selected ? 0.26 : 0.13 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(
        point.position,
        outerRadius,
        Paint()
          ..color = color.withValues(alpha: selected ? 0.95 : 0.68 * opacity),
      );
      canvas.drawCircle(
        point.position,
        outerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1.6 : 0.9
          ..color = Colors.white.withValues(alpha: selected ? 0.82 : 0.38),
      );
      canvas.drawCircle(
        point.position,
        innerRadius,
        Paint()..color = Colors.white.withValues(alpha: 0.82 * opacity),
      );
    }
  }

  void _drawSelectedRing(Canvas canvas, Offset center, double radius) {
    GlobeProjectedPoint? selected;
    for (final point in projectedCountries) {
      if (point.visible && point.country.code == selectedCountryCode) {
        selected = point;
        break;
      }
    }
    if (selected == null) return;

    canvas.drawCircle(
      selected.position,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = colorScheme.primary.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(covariant WorldGlobePainter oldDelegate) {
    return oldDelegate.landShapes != landShapes ||
        oldDelegate.projectedCountries != projectedCountries ||
        oldDelegate.selectedCountryCode != selectedCountryCode ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _ProjectedLandPoint {
  const _ProjectedLandPoint({required this.position, required this.visible});

  final Offset position;
  final bool visible;
}
