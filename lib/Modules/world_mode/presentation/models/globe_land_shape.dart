import 'dart:convert';

class GlobeLandPoint {
  const GlobeLandPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class GlobeLandShape {
  const GlobeLandShape(this.rings);

  final List<List<GlobeLandPoint>> rings;

  static List<GlobeLandShape> fromTopoJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];

    final arcsRaw = decoded['arcs'];
    final transformRaw = decoded['transform'];
    if (arcsRaw is! List || transformRaw is! Map<String, dynamic>) {
      return const [];
    }

    final scaleRaw = transformRaw['scale'];
    final translateRaw = transformRaw['translate'];
    if (scaleRaw is! List || translateRaw is! List) return const [];
    if (scaleRaw.length < 2 || translateRaw.length < 2) return const [];

    final scaleX = (scaleRaw[0] as num).toDouble();
    final scaleY = (scaleRaw[1] as num).toDouble();
    final translateX = (translateRaw[0] as num).toDouble();
    final translateY = (translateRaw[1] as num).toDouble();

    final decodedArcs = arcsRaw
        .map<List<GlobeLandPoint>>(
          (arc) => _decodeArc(
            arc,
            scaleX: scaleX,
            scaleY: scaleY,
            translateX: translateX,
            translateY: translateY,
          ),
        )
        .toList(growable: false);

    final objects = decoded['objects'];
    if (objects is! Map<String, dynamic>) return const [];
    final land = objects['land'];
    if (land is! Map<String, dynamic>) return const [];

    final geometries = land['geometries'];
    if (geometries is! List) return const [];

    final shapes = <GlobeLandShape>[];
    for (final geometry in geometries) {
      if (geometry is! Map<String, dynamic>) continue;
      final type = geometry['type'];
      final arcs = geometry['arcs'];
      if (type == 'Polygon' && arcs is List) {
        final shape = _decodePolygon(arcs, decodedArcs);
        if (shape != null) shapes.add(shape);
      } else if (type == 'MultiPolygon' && arcs is List) {
        for (final polygon in arcs) {
          if (polygon is! List) continue;
          final shape = _decodePolygon(polygon, decodedArcs);
          if (shape != null) shapes.add(shape);
        }
      }
    }

    return shapes;
  }

  static List<GlobeLandPoint> _decodeArc(
    dynamic arc, {
    required double scaleX,
    required double scaleY,
    required double translateX,
    required double translateY,
  }) {
    if (arc is! List) return const [];
    var x = 0;
    var y = 0;
    final points = <GlobeLandPoint>[];

    for (final coordinate in arc) {
      if (coordinate is! List || coordinate.length < 2) continue;
      x += (coordinate[0] as num).toInt();
      y += (coordinate[1] as num).toInt();
      points.add(
        GlobeLandPoint(
          longitude: (x * scaleX) + translateX,
          latitude: (y * scaleY) + translateY,
        ),
      );
    }

    return points;
  }

  static GlobeLandShape? _decodePolygon(
    List<dynamic> polygon,
    List<List<GlobeLandPoint>> decodedArcs,
  ) {
    final rings = <List<GlobeLandPoint>>[];
    for (final ringRefs in polygon) {
      if (ringRefs is! List) continue;
      final ring = <GlobeLandPoint>[];
      for (final rawIndex in ringRefs) {
        if (rawIndex is! num) continue;
        final arcIndex = rawIndex.toInt();
        final source = arcIndex >= 0
            ? decodedArcs[arcIndex]
            : decodedArcs[~arcIndex].reversed;
        for (final point in source) {
          if (ring.isNotEmpty && _samePoint(ring.last, point)) continue;
          ring.add(point);
        }
      }
      if (ring.length >= 3) rings.add(ring);
    }

    if (rings.isEmpty) return null;
    return GlobeLandShape(rings);
  }

  static bool _samePoint(GlobeLandPoint a, GlobeLandPoint b) {
    return a.latitude == b.latitude && a.longitude == b.longitude;
  }
}
