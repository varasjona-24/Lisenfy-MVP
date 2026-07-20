import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/country_entity.dart';
import '../models/globe_land_shape.dart';

class WorldMapCanvas extends StatefulWidget {
  const WorldMapCanvas({
    super.key,
    required this.countries,
    required this.selectedCountryCode,
    required this.onCountryTap,
    this.interactive = true,
    this.showHint = true,
    this.minScale = 1.0,
    this.maxScale = 3.2,
  });

  final List<CountryEntity> countries;
  final String? selectedCountryCode;
  final ValueChanged<CountryEntity> onCountryTap;
  final bool interactive;
  final bool showHint;
  final double minScale;
  final double maxScale;

  @override
  State<WorldMapCanvas> createState() => _WorldMapCanvasState();
}

class _WorldMapCanvasState extends State<WorldMapCanvas> {
  static const Size _sourceMapSize = Size(1500, 844);
  static const double _panEnableThreshold = 1.01;

  final TransformationController _transformController =
      TransformationController();
  bool _panEnabled = false;
  List<GlobeLandShape> _landShapes = const [];

  @override
  void initState() {
    super.initState();
    _loadLandShapes();
  }

  @override
  void didUpdateWidget(covariant WorldMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactive && !widget.interactive) {
      _transformController.value = Matrix4.identity();
      if (_panEnabled) {
        setState(() => _panEnabled = false);
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _syncPanState() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final shouldEnablePan = scale > _panEnableThreshold;
    if (shouldEnablePan == _panEnabled) return;
    setState(() => _panEnabled = shouldEnablePan);
  }

  Future<void> _loadLandShapes() async {
    try {
      final raw = await rootBundle.loadString('assets/geo/land-110m.json');
      final shapes = GlobeLandShape.fromTopoJson(raw);
      if (!mounted) return;
      setState(() => _landShapes = shapes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _landShapes = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.09),
            scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapWidth = constraints.maxWidth.clamp(1.0, double.infinity);
            final mapHeight = constraints.maxHeight.clamp(1.0, double.infinity);
            final mapRect = _fittedRect(
              src: _sourceMapSize,
              dst: Size(mapWidth, mapHeight),
            );

            final mapLayer = SizedBox(
              width: mapWidth,
              height: mapHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: kDebugMode
                    ? (details) => _logNormalizedTap(
                        details: details,
                        mapRect: mapRect,
                        countries: widget.countries,
                      )
                    : null,
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: mapRect,
                      child: CustomPaint(
                        painter: _WorldMapBackgroundPainter(
                          landShapes: _landShapes,
                          colorScheme: scheme,
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: mapRect,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.22),
                            ],
                          ),
                        ),
                      ),
                    ),
                    for (final country in widget.countries)
                      _buildCountryPoint(
                        country: country,
                        selectedCountryCode: widget.selectedCountryCode,
                        onCountryTap: widget.onCountryTap,
                        mapRect: mapRect,
                      ),
                    if (widget.showHint)
                      Positioned(
                        right: 14,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            _panEnabled
                                ? tr('world_mode.zoom_active_hint')
                                : tr('world_mode.zoom_hint'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );

            if (!widget.interactive) return mapLayer;
            return InteractiveViewer(
              transformationController: _transformController,
              minScale: widget.minScale,
              maxScale: widget.maxScale,
              constrained: false,
              panEnabled: _panEnabled,
              onInteractionUpdate: (_) => _syncPanState(),
              onInteractionEnd: (_) => _syncPanState(),
              child: mapLayer,
            );
          },
        ),
      ),
    );
  }

  static void _logNormalizedTap({
    required TapUpDetails details,
    required Rect mapRect,
    required List<CountryEntity> countries,
  }) {
    final local = details.localPosition;
    if (!mapRect.contains(local)) return;
    final nx = ((local.dx - mapRect.left) / mapRect.width).clamp(0.0, 1.0);
    final ny = ((local.dy - mapRect.top) / mapRect.height).clamp(0.0, 1.0);

    CountryEntity? nearest;
    double bestDistanceSq = double.infinity;
    for (final country in countries) {
      final dx = nx - country.mapX;
      final dy = ny - country.mapY;
      final distSq = (dx * dx) + (dy * dy);
      if (distSq < bestDistanceSq) {
        bestDistanceSq = distSq;
        nearest = country;
      }
    }

    if (nearest == null) {
      debugPrint(
        '[WorldMap] tap mapX=${nx.toStringAsFixed(3)} mapY=${ny.toStringAsFixed(3)}',
      );
      return;
    }

    final distance = math.sqrt(bestDistanceSq);
    debugPrint(
      '[WorldMapCal] nearest=${nearest.code} '
      'current=(${nearest.mapX.toStringAsFixed(3)},${nearest.mapY.toStringAsFixed(3)}) '
      'suggested=(${nx.toStringAsFixed(3)},${ny.toStringAsFixed(3)}) '
      'distance=${distance.toStringAsFixed(4)}',
    );
  }

  static Widget _buildCountryPoint({
    required CountryEntity country,
    required String? selectedCountryCode,
    required ValueChanged<CountryEntity> onCountryTap,
    required Rect mapRect,
  }) {
    assert(
      country.mapX >= 0.0 &&
          country.mapX <= 1.0 &&
          country.mapY >= 0.0 &&
          country.mapY <= 1.0,
      'mapX/mapY fuera de rango para ${country.code}: '
      '${country.mapX}, ${country.mapY}',
    );
    return _CountryPoint(
      country: country,
      selected: selectedCountryCode == country.code,
      onTap: () => onCountryTap(country),
      x: mapRect.left + (country.mapX * mapRect.width),
      y: mapRect.top + (country.mapY * mapRect.height),
    );
  }

  static Rect _fittedRect({required Size src, required Size dst}) {
    final srcAspect = src.width / src.height;
    final dstAspect = dst.width / dst.height;

    if (srcAspect > dstAspect) {
      final renderWidth = dst.width;
      final renderHeight = renderWidth / srcAspect;
      final dy = (dst.height - renderHeight) / 2;
      return Rect.fromLTWH(0, dy, renderWidth, renderHeight);
    }

    final renderHeight = dst.height;
    final renderWidth = renderHeight * srcAspect;
    final dx = (dst.width - renderWidth) / 2;
    return Rect.fromLTWH(dx, 0, renderWidth, renderHeight);
  }
}

class _CountryPoint extends StatelessWidget {
  const _CountryPoint({
    required this.country,
    required this.selected,
    required this.onTap,
    required this.x,
    required this.y,
  });

  final CountryEntity country;
  final bool selected;
  final VoidCallback onTap;
  final double x;
  final double y;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected
        ? scheme.primary
        : WorldMapRegionColors.colorFor(country.regionKey);
    final dotSize = selected ? 16.0 : 12.0;
    final innerDotSize = selected ? 4.8 : 3.6;

    return Positioned(
      left: x - (dotSize / 2),
      top: y - (dotSize / 2),
      child: Tooltip(
        message: country.localizedName,
        waitDuration: const Duration(milliseconds: 140),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.9),
                border: Border.all(
                  color: selected
                      ? scheme.onPrimary.withValues(alpha: 0.85)
                      : scheme.surface.withValues(alpha: 0.8),
                  width: selected ? 1.6 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: selected ? 0.45 : 0.28),
                    blurRadius: selected ? 10 : 7,
                    spreadRadius: selected ? 0.6 : 0,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: innerDotSize,
                  height: innerDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: selected ? 0.85 : 0.72,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldMapBackgroundPainter extends CustomPainter {
  const _WorldMapBackgroundPainter({
    required this.landShapes,
    required this.colorScheme,
  });

  final List<GlobeLandShape> landShapes;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _drawOcean(canvas, rect);
    _drawGraticule(canvas, size);
    _drawLand(canvas, size);
    _drawShade(canvas, rect);
  }

  void _drawOcean(Canvas canvas, Rect rect) {
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [Color(0xFF12365E), Color(0xFF1F6AAD), Color(0xFF072348)],
      stops: const [0, 0.48, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  void _drawGraticule(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.075);

    for (var longitude = -150; longitude <= 150; longitude += 30) {
      final x = _longitudeToX(longitude.toDouble(), size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (var latitude = -60; latitude <= 60; latitude += 30) {
      final y = _latitudeToY(latitude.toDouble(), size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint..color = Colors.white.withValues(alpha: 0.10),
    );
  }

  void _drawLand(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5FC58D).withValues(alpha: 0.42);
    final ridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.16);

    for (final shape in landShapes) {
      final path = Path()..fillType = PathFillType.evenOdd;
      var hasPath = false;

      for (final ring in shape.rings) {
        if (ring.length < 3) continue;
        final segments = _splitDateLineSegments(ring);
        for (final segment in segments) {
          if (segment.length < 3) continue;
          final points = segment
              .map((point) => _project(point, size))
              .toList(growable: false);
          path.moveTo(points.first.dx, points.first.dy);
          for (final point in points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          path.close();
          hasPath = true;
        }
      }

      if (!hasPath) continue;
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, ridgePaint);
    }
  }

  void _drawShade(Canvas canvas, Rect rect) {
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.04),
        Colors.transparent,
        Colors.black.withValues(alpha: 0.20),
      ],
      stops: const [0, 0.48, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  List<List<GlobeLandPoint>> _splitDateLineSegments(List<GlobeLandPoint> ring) {
    final segments = <List<GlobeLandPoint>>[];
    var current = <GlobeLandPoint>[];

    for (final point in ring) {
      if (current.isNotEmpty) {
        final previous = current.last;
        final crossesDateLine =
            (point.longitude - previous.longitude).abs() > 180;
        if (crossesDateLine) {
          if (current.length >= 3) segments.add(current);
          current = <GlobeLandPoint>[];
        }
      }
      current.add(point);
    }

    if (current.length >= 3) segments.add(current);
    return segments;
  }

  Offset _project(GlobeLandPoint point, Size size) {
    return Offset(
      _longitudeToX(point.longitude, size.width),
      _latitudeToY(point.latitude, size.height),
    );
  }

  double _longitudeToX(double longitude, double width) {
    return ((longitude + 180) / 360).clamp(0.0, 1.0) * width;
  }

  double _latitudeToY(double latitude, double height) {
    return ((90 - latitude) / 180).clamp(0.0, 1.0) * height;
  }

  @override
  bool shouldRepaint(covariant _WorldMapBackgroundPainter oldDelegate) {
    return oldDelegate.landShapes != landShapes ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class WorldMapRegionColors {
  const WorldMapRegionColors._();

  static Color colorFor(String regionKey) {
    switch (regionKey) {
      case 'americas':
        return const Color(0xFFE8793F);
      case 'europa':
        return const Color(0xFF5BA2FF);
      case 'africa':
        return const Color(0xFF53C7A5);
      case 'asia':
        return const Color(0xFFF27DBD);
      case 'oceania':
        return const Color(0xFFA88DFF);
      default:
        return Colors.white;
    }
  }
}
