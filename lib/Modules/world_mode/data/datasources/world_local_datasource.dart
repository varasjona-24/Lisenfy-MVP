import 'package:get_storage/get_storage.dart';

import '../models/world_cached_station_model.dart';

class WorldLocalDatasource {
  WorldLocalDatasource(this._storage);

  WorldLocalDatasource.memory([Map<String, dynamic>? initialState])
    : _storage = null,
      _memoryState = initialState ?? <String, dynamic>{};

  final GetStorage? _storage;
  Map<String, dynamic>? _memoryState;

  static const _stationsCacheKey = 'world_mode_stations_cache_v1';
  static const _countryDiscoveryKey = 'world_mode_country_discovery_v1';
  static const _stationMemoryKey = 'world_mode_station_memory_v1';
  static const _countryAffinityKey = 'world_mode_country_affinity_v1';
  static const _playbackEventsKey = 'world_mode_playback_events_v1';

  dynamic _read(String key) {
    return _storage?.read(key) ?? _memoryState?[key];
  }

  Future<void> _write(String key, dynamic value) async {
    final storage = _storage;
    if (storage != null) {
      await storage.write(key, value);
      return;
    }
    _memoryState ??= <String, dynamic>{};
    _memoryState![key] = value;
  }

  Future<Map<String, int>> readDiscoveryMap() async {
    final raw = _read(_countryDiscoveryKey);
    if (raw is! Map) return <String, int>{};
    final map = <String, int>{};
    raw.forEach((key, value) {
      final code = '$key'.trim().toUpperCase();
      if (code.isEmpty) return;
      final count = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      map[code] = count < 0 ? 0 : count;
    });
    return map;
  }

  Future<void> incrementCountryDiscovery(String countryCode) async {
    final code = countryCode.trim().toUpperCase();
    if (code.isEmpty) return;
    final map = await readDiscoveryMap();
    map[code] = (map[code] ?? 0) + 1;
    await _write(_countryDiscoveryKey, map);
  }

  Future<List<WorldCachedStationModel>> readCachedStations(
    String countryCode,
  ) async {
    final code = countryCode.trim().toUpperCase();
    if (code.isEmpty) return const <WorldCachedStationModel>[];
    final raw = _read(_stationsCacheKey);
    if (raw is! Map) return const <WorldCachedStationModel>[];
    final byCountry = raw[code];
    if (byCountry is! List) return const <WorldCachedStationModel>[];

    final out = <WorldCachedStationModel>[];
    for (final entry in byCountry) {
      if (entry is! Map) continue;
      try {
        out.add(
          WorldCachedStationModel.fromJson(Map<String, dynamic>.from(entry)),
        );
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Future<void> writeCachedStations(
    String countryCode,
    List<WorldCachedStationModel> stations,
  ) async {
    final code = countryCode.trim().toUpperCase();
    if (code.isEmpty) return;
    final raw = _read(_stationsCacheKey);
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    map[code] = stations.map((e) => e.toJson()).toList(growable: false);
    await _write(_stationsCacheKey, map);
  }

  Future<Map<String, double>> readCountryAffinity() async {
    final raw = _read(_countryAffinityKey);
    if (raw is! Map) return const <String, double>{};
    final out = <String, double>{};
    raw.forEach((key, value) {
      final code = '$key'.trim().toUpperCase();
      if (code.isEmpty) return;
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      if (parsed == null) return;
      out[code] = parsed;
    });
    return out;
  }

  Future<void> writeCountryAffinity(Map<String, double> affinity) async {
    final normalized = <String, double>{};
    affinity.forEach((key, value) {
      final code = key.trim().toUpperCase();
      if (code.isEmpty) return;
      normalized[code] = value;
    });
    await _write(_countryAffinityKey, normalized);
  }

  Future<Set<String>> readPlayedTrackIds(String stationId) async {
    final id = stationId.trim();
    if (id.isEmpty) return const <String>{};
    final raw = _read(_stationMemoryKey);
    if (raw is! Map) return const <String>{};
    final list = raw[id];
    if (list is! List) return const <String>{};
    return list.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> appendPlayedTrackIds(
    String stationId,
    List<String> trackIds, {
    int keepLast = 250,
  }) async {
    final id = stationId.trim();
    if (id.isEmpty) return;
    final normalizedIds = trackIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (normalizedIds.isEmpty) return;

    final raw = _read(_stationMemoryKey);
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final current = (map[id] as List? ?? const <dynamic>[])
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    current.addAll(normalizedIds);

    final deduped = <String>[];
    final seen = <String>{};
    for (final value in current.reversed) {
      if (seen.contains(value)) continue;
      seen.add(value);
      deduped.add(value);
      if (deduped.length >= keepLast) break;
    }

    map[id] = deduped.reversed.toList(growable: false);
    await _write(_stationMemoryKey, map);
  }

  Future<void> addPlaybackEvent(Map<String, dynamic> event) async {
    final raw = _read(_playbackEventsKey);
    final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
    list.add(event);
    if (list.length > 1200) {
      list.removeRange(0, list.length - 1200);
    }
    await _write(_playbackEventsKey, list);
  }

  Future<List<Map<String, dynamic>>> readRecentPlaybackEvents({
    int limit = 200,
  }) async {
    if (limit <= 0) return const <Map<String, dynamic>>[];
    final raw = _read(_playbackEventsKey);
    if (raw is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final entry in raw.reversed) {
      if (entry is! Map) continue;
      out.add(Map<String, dynamic>.from(entry));
      if (out.length >= limit) break;
    }
    return out;
  }
}
