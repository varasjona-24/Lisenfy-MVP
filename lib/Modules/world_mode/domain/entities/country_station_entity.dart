import '../../../../app/models/media_item.dart';
import 'station_seed_entity.dart';
import 'world_station_type.dart';

class CountryStationEntity {
  const CountryStationEntity({
    required this.stationId,
    required this.countryCode,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.tracks,
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
  final List<MediaItem> tracks;
  final String source;
  final int generatedAtMs;
  final int ttlSec;
  final StationSeedEntity seed;

  bool get hasPlayableTracks => tracks.any((item) => item.hasAudioLocal);

  CountryStationEntity copyWith({
    String? stationId,
    String? countryCode,
    WorldStationType? type,
    String? title,
    String? subtitle,
    List<MediaItem>? tracks,
    String? source,
    int? generatedAtMs,
    int? ttlSec,
    StationSeedEntity? seed,
  }) {
    return CountryStationEntity(
      stationId: stationId ?? this.stationId,
      countryCode: countryCode ?? this.countryCode,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      tracks: tracks ?? this.tracks,
      source: source ?? this.source,
      generatedAtMs: generatedAtMs ?? this.generatedAtMs,
      ttlSec: ttlSec ?? this.ttlSec,
      seed: seed ?? this.seed,
    );
  }
}
