import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/country_entity.dart';
import '../models/globe_projected_point.dart';

class GlobeVector {
  const GlobeVector(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

class GlobeProjection {
  const GlobeProjection._();

  static GlobeVector fromCountry(CountryEntity country) {
    return latitudeLongitudeToVector(
      latitude: country.latitude,
      longitude: country.longitude,
    );
  }

  static GlobeVector latitudeLongitudeToVector({
    required double latitude,
    required double longitude,
  }) {
    final lat = latitude * math.pi / 180;
    final lon = longitude * math.pi / 180;

    return GlobeVector(
      math.cos(lat) * math.sin(lon),
      math.sin(lat),
      math.cos(lat) * math.cos(lon),
    );
  }

  static GlobeVector rotate({
    required GlobeVector point,
    required double rotationX,
    required double rotationY,
  }) {
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);

    final x1 = point.x * cosY + point.z * sinY;
    final z1 = -point.x * sinY + point.z * cosY;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);

    final y2 = point.y * cosX - z1 * sinX;
    final z2 = point.y * sinX + z1 * cosX;

    return GlobeVector(x1, y2, z2);
  }

  static Offset project({
    required GlobeVector point,
    required Offset center,
    required double radius,
  }) {
    return Offset(center.dx + point.x * radius, center.dy - point.y * radius);
  }

  static List<GlobeProjectedPoint> projectCountries({
    required List<CountryEntity> countries,
    required Offset center,
    required double radius,
    required double rotationX,
    required double rotationY,
  }) {
    return countries
        .map((country) {
          final rotated = rotate(
            point: fromCountry(country),
            rotationX: rotationX,
            rotationY: rotationY,
          );
          return GlobeProjectedPoint(
            country: country,
            position: project(point: rotated, center: center, radius: radius),
            depth: rotated.z.clamp(0.0, 1.0),
            visible: rotated.z >= 0,
          );
        })
        .toList(growable: false);
  }

  static CountryEntity? nearestVisibleCountry({
    required Offset pointer,
    required List<GlobeProjectedPoint> projected,
    double maxDistance = 28,
  }) {
    CountryEntity? nearest;
    var bestDistance = maxDistance;

    for (final point in projected) {
      if (!point.visible) continue;
      final distance = (point.position - pointer).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = point.country;
      }
    }

    return nearest;
  }
}
