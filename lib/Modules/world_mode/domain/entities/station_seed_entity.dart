import 'world_station_type.dart';

class StationSeedEntity {
  const StationSeedEntity({
    required this.countryCode,
    required this.stationType,
    required this.generatedAtMs,
    this.mood,
    this.language,
    this.energyTarget,
    this.seedGenres = const <String>[],
    this.seedArtists = const <String>[],
  });

  final String countryCode;
  final WorldStationType stationType;
  final int generatedAtMs;
  final String? mood;
  final String? language;
  final double? energyTarget;
  final List<String> seedGenres;
  final List<String> seedArtists;

  Map<String, dynamic> toJson() => {
    'countryCode': countryCode,
    'stationType': stationType.key,
    'generatedAtMs': generatedAtMs,
    'mood': mood,
    'language': language,
    'energyTarget': energyTarget,
    'seedGenres': seedGenres,
    'seedArtists': seedArtists,
  };

  factory StationSeedEntity.fromJson(Map<String, dynamic> json) {
    return StationSeedEntity(
      countryCode: (json['countryCode'] as String? ?? '').trim().toUpperCase(),
      stationType: WorldStationTypeX.fromKey(json['stationType'] as String?),
      generatedAtMs: (json['generatedAtMs'] as num?)?.toInt() ?? 0,
      mood: (json['mood'] as String?)?.trim(),
      language: (json['language'] as String?)?.trim(),
      energyTarget: (json['energyTarget'] as num?)?.toDouble(),
      seedGenres: ((json['seedGenres'] as List?) ?? const <dynamic>[])
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      seedArtists: ((json['seedArtists'] as List?) ?? const <dynamic>[])
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}
