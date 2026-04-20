import '../../domain/entities/station_seed_entity.dart';
import '../../domain/entities/world_station_type.dart';

class WorldCachedStationModel {
  const WorldCachedStationModel({
    required this.stationId,
    required this.countryCode,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.trackIds,
    required this.source,
    required this.generatedAtMs,
    required this.ttlSec,
    required this.seed,
  });

  final String stationId;
  final String countryCode;
  final WorldStationType type;
  final String title;
  final String subtitle;
  final List<String> trackIds;
  final String source;
  final int generatedAtMs;
  final int ttlSec;
  final StationSeedEntity seed;

  bool get isExpired {
    final expiresAtMs = generatedAtMs + (ttlSec * 1000);
    return DateTime.now().millisecondsSinceEpoch > expiresAtMs;
  }

  Map<String, dynamic> toJson() => {
    'stationId': stationId,
    'countryCode': countryCode,
    'type': type.key,
    'title': title,
    'subtitle': subtitle,
    'trackIds': trackIds,
    'source': source,
    'generatedAtMs': generatedAtMs,
    'ttlSec': ttlSec,
    'seed': seed.toJson(),
  };

  factory WorldCachedStationModel.fromJson(Map<String, dynamic> json) {
    final trackIds = ((json['trackIds'] as List?) ?? const <dynamic>[])
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final seedRaw = json['seed'];
    final seed = seedRaw is Map
        ? StationSeedEntity.fromJson(Map<String, dynamic>.from(seedRaw))
        : StationSeedEntity(
            countryCode: (json['countryCode'] as String? ?? '')
                .trim()
                .toUpperCase(),
            stationType: WorldStationTypeX.fromKey(json['type'] as String?),
            generatedAtMs: (json['generatedAtMs'] as num?)?.toInt() ?? 0,
          );

    return WorldCachedStationModel(
      stationId: (json['stationId'] as String? ?? '').trim(),
      countryCode: (json['countryCode'] as String? ?? '').trim().toUpperCase(),
      type: WorldStationTypeX.fromKey(json['type'] as String?),
      title: (json['title'] as String? ?? '').trim(),
      subtitle: (json['subtitle'] as String? ?? '').trim(),
      trackIds: trackIds,
      source: (json['source'] as String? ?? 'local').trim(),
      generatedAtMs: (json['generatedAtMs'] as num?)?.toInt() ?? 0,
      ttlSec: (json['ttlSec'] as num?)?.toInt() ?? 21600,
      seed: seed,
    );
  }
}
