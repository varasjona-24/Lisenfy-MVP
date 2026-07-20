import 'package:flutter/material.dart';

import '../../domain/entities/country_entity.dart';

class GlobeProjectedPoint {
  const GlobeProjectedPoint({
    required this.country,
    required this.position,
    required this.depth,
    required this.visible,
  });

  final CountryEntity country;
  final Offset position;
  final double depth;
  final bool visible;
}
