import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/country_entity.dart';

class WorldMapCanvas extends StatelessWidget {
  const WorldMapCanvas({
    super.key,
    required this.countries,
    required this.selectedCountryCode,
    required this.onCountryTap,
  });

  final List<CountryEntity> countries;
  final String? selectedCountryCode;
  final ValueChanged<CountryEntity> onCountryTap;

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
            const virtualWidth = 1600.0;
            const virtualHeight = 820.0;

            return InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.2,
              constrained: false,
              child: SizedBox(
                width: virtualWidth,
                height: virtualHeight,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(virtualWidth, virtualHeight),
                      painter: _MapGridPainter(scheme),
                    ),
                    for (final country in countries)
                      _CountryPoint(
                        country: country,
                        selected: selectedCountryCode == country.code,
                        onTap: () => onCountryTap(country),
                        x: _lonToX(country.longitude, virtualWidth),
                        y: _latToY(country.latitude, virtualHeight),
                      ),
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
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'Pinch para zoom · arrastra para explorar',
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
          },
        ),
      ),
    );
  }

  static double _lonToX(double lon, double width) {
    return ((lon + 180.0) / 360.0) * width;
  }

  static double _latToY(double lat, double height) {
    return ((90.0 - lat) / 180.0) * height;
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
    final radius = selected ? 7.0 : 5.0;

    return Positioned(
      left: x - (selected ? 10 : 8),
      top: y - (selected ? 10 : 8),
      child: Tooltip(
        message: country.name,
        waitDuration: const Duration(milliseconds: 140),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: selected ? 20 : 16,
              height: selected ? 20 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.9),
                border: Border.all(
                  color: selected
                      ? scheme.onPrimary.withValues(alpha: 0.85)
                      : scheme.surface.withValues(alpha: 0.8),
                  width: selected ? 2.0 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: selected ? 0.45 : 0.28),
                    blurRadius: selected ? 12 : 8,
                    spreadRadius: selected ? 0.6 : 0,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: radius,
                  height: radius,
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

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;

    const lonStep = 200.0;
    const latStep = 120.0;
    for (double x = 0; x <= size.width; x += lonStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += latStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final wavePaint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path();
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.5 + sin(x / 72) * 28 + cos(x / 113) * 10;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.scheme != scheme;
  }
}
