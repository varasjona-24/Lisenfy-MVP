import '../../../app/utils/country_catalog.dart';

/// Presentation projection of effective listening intervals; never persisted.
class WeeklyCollageActivity {
  WeeklyCollageActivity(
    this.audioMs,
    this.videoMs,
    this.regionsMs,
    this.previousMs,
    this.comparable,
  );
  final List<double> audioMs;
  final List<double> videoMs;
  final Map<String, double> regionsMs;
  final double previousMs;
  final bool comparable;
  double get totalMs =>
      audioMs.fold(0.0, (a, b) => a + b) + videoMs.fold(0.0, (a, b) => a + b);
  double? get changePercent => comparable && previousMs > 0
      ? (totalMs - previousMs) / previousMs * 100
      : null;

  static WeeklyCollageActivity build(
    List<Map<String, dynamic>> intervals,
    DateTime start,
    DateTime end, {
    int? coverageStart,
  }) {
    final audio = List<double>.filled(7, 0);
    final video = List<double>.filled(7, 0);
    final regions = <String, double>{};
    final previousStart = DateTime(start.year, start.month, start.day - 7);
    var previous = 0.0;
    double overlap(int lo, int hi, int from, int to, double wall) {
      if (hi <= lo) return 0;
      final clippedLo = lo > from ? lo : from;
      final clippedHi = hi < to ? hi : to;
      return clippedHi <= clippedLo
          ? 0
          : wall * (clippedHi - clippedLo) / (hi - lo);
    }

    for (final interval in intervals) {
      final lo = interval['start'] as int, hi = interval['end'] as int;
      final wall = (interval['wallMs'] as num).toDouble();
      if (wall <= 0 || hi <= lo) continue;
      previous += overlap(
        lo,
        hi,
        previousStart.millisecondsSinceEpoch,
        start.millisecondsSinceEpoch,
        wall,
      );
      for (var day = 0; day < 7; day++) {
        final from = DateTime(start.year, start.month, start.day + day);
        final to = DateTime(start.year, start.month, start.day + day + 1);
        final value = overlap(
          lo,
          hi,
          from.millisecondsSinceEpoch,
          to.millisecondsSinceEpoch,
          wall,
        );
        (interval['video'] == true ? video : audio)[day] += value;
        if (interval['video'] != true) {
          final region = CountryCatalog.regionKeyFromCode(
            interval['country'] as String?,
          );
          if (region != null && value > 0) {
            regions.update(region, (v) => v + value, ifAbsent: () => value);
          }
        }
      }
    }
    return WeeklyCollageActivity(
      audio,
      video,
      regions,
      previous,
      coverageStart != null &&
          coverageStart <= previousStart.millisecondsSinceEpoch,
    );
  }
}
