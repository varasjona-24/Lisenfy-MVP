import '../../domain/entities/world_station_type.dart';

class RemoteCountryModel {
  const RemoteCountryModel({
    required this.code,
    required this.name,
    required this.regionKey,
  });

  final String code;
  final String name;
  final String regionKey;

  factory RemoteCountryModel.fromJson(Map<String, dynamic> json) {
    return RemoteCountryModel(
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      name: (json['name'] as String? ?? '').trim(),
      regionKey: (json['regionKey'] as String? ?? '').trim().toLowerCase(),
    );
  }
}

class RemoteStationSeedModel {
  const RemoteStationSeedModel({
    required this.stationId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.trackIds,
    required this.ttlSec,
  });

  final String stationId;
  final WorldStationType type;
  final String title;
  final String subtitle;
  final List<String> trackIds;
  final int ttlSec;

  factory RemoteStationSeedModel.fromJson(Map<String, dynamic> json) {
    final stationType = WorldStationTypeX.fromKey(json['type'] as String?);
    final trackIds = <String>[];

    final directTrackIds =
        (json['trackPublicIds'] as List?) ?? json['trackIds'];
    if (directTrackIds is List) {
      for (final entry in directTrackIds) {
        final id = '$entry'.trim();
        if (id.isNotEmpty && !trackIds.contains(id)) {
          trackIds.add(id);
        }
      }
    }

    final tracksRaw = (json['tracks'] as List?) ?? const <dynamic>[];
    for (final raw in tracksRaw) {
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      final id = (data['publicId'] as String? ?? data['id'] as String? ?? '')
          .trim();
      if (id.isEmpty || trackIds.contains(id)) continue;
      trackIds.add(id);
    }

    final id = (json['stationId'] as String? ?? json['id'] as String? ?? '')
        .trim();
    final fallbackId = id.isEmpty
        ? 'remote-${stationType.key}-${DateTime.now().millisecondsSinceEpoch}'
        : id;

    return RemoteStationSeedModel(
      stationId: fallbackId,
      type: stationType,
      title: (json['title'] as String? ?? stationType.title).trim(),
      subtitle: (json['subtitle'] as String? ?? '').trim(),
      trackIds: trackIds,
      ttlSec: (json['ttlSec'] as num?)?.toInt() ?? 21600,
    );
  }
}

class RemoteCountryExploreResponse {
  const RemoteCountryExploreResponse({
    required this.countryCode,
    required this.generatedAtMs,
    required this.stations,
  });

  final String countryCode;
  final int generatedAtMs;
  final List<RemoteStationSeedModel> stations;

  factory RemoteCountryExploreResponse.fromJson(
    Map<String, dynamic> json, {
    required String fallbackCountryCode,
  }) {
    final stationsRaw = (json['stations'] as List?) ?? const <dynamic>[];
    final stations = stationsRaw
        .whereType<Map>()
        .map(
          (raw) =>
              RemoteStationSeedModel.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList(growable: false);

    return RemoteCountryExploreResponse(
      countryCode:
          (json['region'] as String? ??
                  json['country'] as String? ??
                  fallbackCountryCode)
              .trim()
              .toLowerCase(),
      generatedAtMs:
          (json['generatedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      stations: stations,
    );
  }
}
