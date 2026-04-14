import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/country_entity.dart';

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
                      child: Image.asset(
                        'assets/ui/Mapa-Mundi.jpg',
                        fit: BoxFit.fill,
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
                                ? 'Zoom activo · puedes arrastrar el mapa'
                                : 'Pinch para zoom · luego arrastra',
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
    final color = selected ? scheme.primary : _regionColor(country.regionKey);
    final dotSize = selected ? 16.0 : 12.0;
    final innerDotSize = selected ? 4.8 : 3.6;

    return Positioned(
      left: x - (dotSize / 2),
      top: y - (dotSize / 2),
      child: Tooltip(
        message: country.name,
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

  Color _regionColor(String regionKey) {
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
