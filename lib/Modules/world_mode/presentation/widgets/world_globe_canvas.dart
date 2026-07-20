import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/country_entity.dart';
import '../models/globe_land_shape.dart';
import '../models/globe_projected_point.dart';
import '../painters/world_globe_painter.dart';
import '../utils/globe_projection.dart';

class WorldGlobeCanvas extends StatefulWidget {
  const WorldGlobeCanvas({
    super.key,
    required this.countries,
    required this.selectedCountryCode,
    required this.onCountryTap,
    this.interactive = true,
    this.showHint = true,
    this.minZoom = 0.86,
    this.maxZoom = 1.85,
  });

  final List<CountryEntity> countries;
  final String? selectedCountryCode;
  final ValueChanged<CountryEntity> onCountryTap;
  final bool interactive;
  final bool showHint;
  final double minZoom;
  final double maxZoom;

  @override
  State<WorldGlobeCanvas> createState() => _WorldGlobeCanvasState();
}

class _WorldGlobeCanvasState extends State<WorldGlobeCanvas>
    with SingleTickerProviderStateMixin {
  static const double _rotationSensitivity = 0.006;
  static const double _velocitySensitivity = 0.000035;

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  double _rotationX = 0;
  double _rotationY = 0;
  double _velocityX = 0;
  double _velocityY = 0;
  double _zoom = 1;
  double _zoomAtGestureStart = 1;
  bool _dragging = false;
  List<GlobeLandShape> _landShapes = const [];

  @override
  void initState() {
    super.initState();
    _centerSelectedCountry();
    _loadLandShapes();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant WorldGlobeCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCountryCode != widget.selectedCountryCode &&
        !_dragging) {
      _centerSelectedCountry();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _centerSelectedCountry() {
    final selected = _selectedCountry();
    if (selected == null) return;
    _rotationY = -selected.longitude * math.pi / 180;
    _rotationX = (selected.latitude * math.pi / 180).clamp(-1.18, 1.18);
    _velocityX = 0;
    _velocityY = 0;
  }

  CountryEntity? _selectedCountry() {
    final selectedCode = widget.selectedCountryCode;
    if (selectedCode == null) return null;
    for (final country in widget.countries) {
      if (country.code == selectedCode) return country;
    }
    return null;
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

  void _onTick(Duration elapsed) {
    final deltaSeconds =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    if (deltaSeconds <= 0 || _dragging || !widget.interactive) return;
    if (_velocityX.abs() < 0.0001 && _velocityY.abs() < 0.0001) return;

    setState(() {
      _rotationX = (_rotationX + (_velocityX * deltaSeconds)).clamp(
        -1.18,
        1.18,
      );
      _rotationY += _velocityY * deltaSeconds;

      final damping = math.pow(0.05, deltaSeconds).toDouble();
      _velocityX *= damping;
      _velocityY *= damping;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.interactive) return;
    _dragging = true;
    _zoomAtGestureStart = _zoom;
    _velocityX = 0;
    _velocityY = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.interactive) return;
    setState(() {
      _rotationY += details.focalPointDelta.dx * _rotationSensitivity;
      _rotationX =
          (_rotationX + details.focalPointDelta.dy * _rotationSensitivity)
              .clamp(-1.18, 1.18);
      _zoom = (_zoomAtGestureStart * details.scale).clamp(
        widget.minZoom,
        widget.maxZoom,
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!widget.interactive) return;
    _dragging = false;
    _velocityY = details.velocity.pixelsPerSecond.dx * _velocitySensitivity;
    _velocityX = details.velocity.pixelsPerSecond.dy * _velocitySensitivity;
  }

  void _onTapUp(TapUpDetails details, Size size) {
    if (!widget.interactive) return;
    final projected = _projectedCountries(size);
    final country = GlobeProjection.nearestVisibleCountry(
      pointer: details.localPosition,
      projected: projected,
    );
    if (country != null) {
      widget.onCountryTap(country);
    }
  }

  List<GlobeProjectedPoint> _projectedCountries(Size size) {
    final shortest = math.min(size.width, size.height);
    final radius = shortest * 0.38 * _zoom;
    final center = Offset(size.width / 2, size.height / 2);
    return GlobeProjection.projectCountries(
      countries: widget.countries,
      center: center,
      radius: radius,
      rotationX: _rotationX,
      rotationY: _rotationY,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth.clamp(1.0, double.infinity),
            constraints.maxHeight.clamp(1.0, double.infinity),
          );
          final projected = _projectedCountries(size);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onTapUp: (details) => _onTapUp(details, size),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: WorldGlobePainter(
                      landShapes: _landShapes,
                      projectedCountries: projected,
                      selectedCountryCode: widget.selectedCountryCode,
                      rotationX: _rotationX,
                      rotationY: _rotationY,
                      zoom: _zoom,
                      colorScheme: scheme,
                    ),
                  ),
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
                        color: scheme.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        tr('world_mode.globe_hint'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
