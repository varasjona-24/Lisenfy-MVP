import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;

import '../../../../app/data/repo/media_repository.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/utils/artist_credit_parser.dart';
import '../../../../app/utils/country_catalog.dart';
import '../../../artists/data/artist_store.dart';
import '../../agent/local_affinity_engine.dart';
import '../../agent/radio_station_planner.dart';
import '../../data/models/world_cached_station_model.dart';
import '../../domain/entities/country_entity.dart';
import '../../domain/entities/country_station_entity.dart';
import '../../domain/entities/station_seed_entity.dart';
import '../../domain/entities/world_region_catalog.dart';
import '../../domain/entities/world_station_type.dart';
import '../../domain/repositories/world_mode_repository.dart';
import '../datasources/world_local_datasource.dart';

class WorldModeRepositoryImpl implements WorldModeRepository {
  WorldModeRepositoryImpl({
    required MediaRepository mediaRepository,
    required WorldLocalDatasource localDatasource,
    required ArtistStore artistStore,
    required LocalAffinityEngine affinityEngine,
    required RadioStationPlanner radioPlanner,
  }) : _mediaRepository = mediaRepository,
       _localDatasource = localDatasource,
       _artistStore = artistStore,
       _affinityEngine = affinityEngine,
       _radioPlanner = radioPlanner;

  final MediaRepository _mediaRepository;
  final WorldLocalDatasource _localDatasource;
  final ArtistStore _artistStore;
  final LocalAffinityEngine _affinityEngine;
  final RadioStationPlanner _radioPlanner;

  @override
  Future<List<CountryEntity>> getCountries() async {
    final library = await _mediaRepository.getLibrary();
    if (library.isEmpty) return const <CountryEntity>[];

    final artistRegionIndex = _buildArtistRegionIndex();
    final regionTrackCount = <String, int>{};
    for (final item in library) {
      if (!item.hasAudioLocal) continue;
      final regions = _resolveRegionsForItem(
        item: item,
        artistRegionIndex: artistRegionIndex,
      );
      for (final regionCode in regions) {
        regionTrackCount[regionCode] = (regionTrackCount[regionCode] ?? 0) + 1;
      }
    }
    if (regionTrackCount.isEmpty) return const <CountryEntity>[];

    final discoveryMap = await _localDatasource.readDiscoveryMap();
    final list = <CountryEntity>[];
    for (final region in WorldRegionCatalog.all) {
      final trackCount = regionTrackCount[region.code] ?? 0;
      if (trackCount <= 0) continue;
      list.add(
        CountryEntity(
          code: region.code,
          name: region.name,
          regionKey: region.continentKey,
          latitude: region.latitude,
          longitude: region.longitude,
          mapX: region.mapX,
          mapY: region.mapY,
          discoveryCount: trackCount,
        ),
      );
    }

    list.sort((a, b) {
      final aDiscovery = discoveryMap[a.code.toUpperCase()] ?? 0;
      final bDiscovery = discoveryMap[b.code.toUpperCase()] ?? 0;
      final diff = bDiscovery.compareTo(aDiscovery);
      if (diff != 0) return diff;
      final tracksDiff = b.discoveryCount.compareTo(a.discoveryCount);
      if (tracksDiff != 0) return tracksDiff;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  }

  @override
  Future<List<CountryStationEntity>> exploreCountry({
    required CountryEntity country,
    int? shuffleSeed,
  }) async {
    final regionCode = country.code.trim();
    if (regionCode.isEmpty) return const <CountryStationEntity>[];
    final regionDef = WorldRegionCatalog.byCode(regionCode);
    if (regionDef == null) return const <CountryStationEntity>[];

    await _localDatasource.incrementCountryDiscovery(regionCode);
    final library = await _mediaRepository.getLibrary();
    final artistRegionIndex = _buildArtistRegionIndex();
    final regionTracks = _eligibleTracksForRegion(
      regionCode: regionCode,
      library: library,
      artistRegionIndex: artistRegionIndex,
    );

    if (regionTracks.isEmpty) {
      return const <CountryStationEntity>[];
    }

    final recentEvents = await _localDatasource.readRecentPlaybackEvents(
      limit: 220,
    );
    final effectiveSeed =
        shuffleSeed ?? DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final ranked = _rankTracksForRegion(
      regionCode: regionCode,
      tracks: regionTracks,
      events: recentEvents,
      shuffleSeed: effectiveSeed,
    );
    // Mezcla dentro de grupos de 8 para variedad real entre recargas
    final shuffledRanked = _shuffleWithinTiers(
      ranked,
      effectiveSeed,
      tierSize: 8,
    );
    final localStations = _buildRegionStations(
      regionCode: regionCode,
      regionName: regionDef.name,
      rankedTracks: shuffledRanked,
    );

    final merged = localStations;

    if (merged.isEmpty || merged.every((station) => station.tracks.isEmpty)) {
      final fallback = await _loadCachedStations(
        countryCode: regionCode,
        library: library,
      );
      if (fallback.isNotEmpty) {
        return fallback;
      }
    }

    await _saveCachedStations(countryCode: regionCode, stations: merged);
    return merged;
  }

  @override
  Future<List<MediaItem>> continueStation({
    required CountryStationEntity station,
    int limit = 20,
  }) async {
    final safeLimit = limit.clamp(4, 80);
    final library = await _mediaRepository.getLibrary();
    final stationPlayed = await _localDatasource.readPlayedTrackIds(
      station.stationId,
    );
    final recentEvents = await _localDatasource.readRecentPlaybackEvents(
      limit: 180,
    );
    final isRegionMode = WorldRegionCatalog.byCode(station.countryCode) != null;

    final continueSeed = math.Random().nextInt(0x7FFFFFFF);
    final localRadioContinuation = isRegionMode
        ? _buildRegionContinuation(
            station: station,
            library: library,
            playedTrackIds: stationPlayed,
            recentEvents: recentEvents,
            limit: safeLimit,
            shuffleSeed: continueSeed,
          )
        : _radioPlanner.buildContinuation(
            station: station,
            library: library,
            playedTrackIds: stationPlayed,
            recentPlaybackEvents: recentEvents,
            countryAffinity: await _localDatasource.readCountryAffinity(),
            limit: safeLimit,
            shuffleSeed: continueSeed,
          );

    if (localRadioContinuation.isNotEmpty) return localRadioContinuation;
    return station.tracks.take(safeLimit).toList(growable: false);
  }

  List<MediaItem> _buildRegionContinuation({
    required CountryStationEntity station,
    required List<MediaItem> library,
    required Set<String> playedTrackIds,
    required List<Map<String, dynamic>> recentEvents,
    required int limit,
    int? shuffleSeed,
  }) {
    final effectiveSeed =
        shuffleSeed ?? DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final artistRegionIndex = _buildArtistRegionIndex();
    final eligible = _eligibleTracksForRegion(
      regionCode: station.countryCode,
      library: library,
      artistRegionIndex: artistRegionIndex,
    );
    if (eligible.isEmpty) return const <MediaItem>[];
    final ranked = _rankTracksForRegion(
      regionCode: station.countryCode,
      tracks: eligible,
      events: recentEvents,
      shuffleSeed: effectiveSeed,
    );

    final normalizedPlayed = _mergePlayedIds(
      memoryIds: playedTrackIds,
      queue: station.tracks,
    ).toSet();
    final fresh = <MediaItem>[];
    final repeated = <MediaItem>[];
    for (final item in ranked) {
      final stable = _stableTrackId(item);
      if (normalizedPlayed.contains(stable)) {
        repeated.add(item);
      } else {
        fresh.add(item);
      }
    }

    return <MediaItem>[
      ...fresh,
      ...repeated,
    ].take(limit).toList(growable: false);
  }

  @override
  Future<void> registerPlayback({
    required CountryStationEntity station,
    required MediaItem item,
    required int positionMs,
  }) async {
    await _localDatasource.appendPlayedTrackIds(station.stationId, [
      _stableTrackId(item),
    ]);
    await _localDatasource.addPlaybackEvent({
      'stationId': station.stationId,
      'countryCode': station.countryCode,
      'stationType': station.type.key,
      'trackId': _stableTrackId(item),
      'artistKey': _primaryArtistKey(item),
      'positionMs': positionMs,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final affinity = await _localDatasource.readCountryAffinity();
    final key = station.countryCode.trim().toUpperCase();
    final next = Map<String, double>.from(affinity);
    next[key] = ((next[key] ?? 0) + 0.2).clamp(0, 10).toDouble();
    await _localDatasource.writeCountryAffinity(next);
  }

  Future<List<CountryStationEntity>> _loadCachedStations({
    required String countryCode,
    required List<MediaItem> library,
  }) async {
    final cached = await _localDatasource.readCachedStations(countryCode);
    if (cached.isEmpty) return const <CountryStationEntity>[];
    final byStableId = _indexByStableId(library);
    final out = <CountryStationEntity>[];

    for (final station in cached) {
      if (station.isExpired) continue;
      final tracks = <MediaItem>[];
      for (final id in station.trackIds) {
        final item = byStableId[id];
        if (item == null || !item.hasAudioLocal) continue;
        tracks.add(item);
      }
      if (tracks.isEmpty) continue;

      out.add(
        CountryStationEntity(
          stationId: station.stationId,
          countryCode: station.countryCode,
          type: station.type,
          title: _stationTitle(
            regionName:
                WorldRegionCatalog.byCode(station.countryCode)?.name ??
                station.countryCode,
            stationIndex: out.length,
            totalStations: cached.length,
          ),
          subtitle: _stationSubtitle(
            trackCount: tracks.length,
            type: station.type,
          ),
          tracks: tracks,
          source: 'local',
          generatedAtMs: station.generatedAtMs,
          ttlSec: station.ttlSec,
          seed: station.seed,
        ),
      );
    }

    return out;
  }

  Future<void> _saveCachedStations({
    required String countryCode,
    required List<CountryStationEntity> stations,
  }) async {
    final records = stations
        .map(
          (entry) => WorldCachedStationModel(
            stationId: entry.stationId,
            countryCode: entry.countryCode,
            type: entry.type,
            title: entry.title,
            subtitle: entry.subtitle,
            trackIds: entry.tracks
                .map((item) => _stableTrackId(item))
                .toList(growable: false),
            source: entry.source,
            generatedAtMs: entry.generatedAtMs,
            ttlSec: entry.ttlSec,
            seed: entry.seed,
          ),
        )
        .toList(growable: false);
    await _localDatasource.writeCachedStations(countryCode, records);
  }

  Map<String, Set<String>> _buildArtistRegionIndex() {
    final profiles = _artistStore.readAllSync();
    if (profiles.isEmpty) return const <String, Set<String>>{};
    final index = <String, Set<String>>{};

    void addKey(String rawKey, Set<String> regions) {
      final key = ArtistCreditParser.normalizeKey(rawKey);
      if (key.isEmpty || key == 'unknown' || regions.isEmpty) return;
      index.putIfAbsent(key, () => <String>{}).addAll(regions);
    }

    for (final profile in profiles) {
      final regions = _regionsFromCountryInputs(
        countryCode: profile.countryCode,
        countryName: profile.country,
      );
      if (regions.isEmpty) continue;
      addKey(profile.key, regions);
      addKey(profile.displayName, regions);
      for (final memberKey in profile.memberKeys) {
        addKey(memberKey, regions);
      }
    }
    return index;
  }

  Set<String> _regionsFromCountryInputs({
    String? countryCode,
    String? countryName,
  }) {
    final out = <String>{};
    final codeCandidate = (countryCode ?? '').trim().toUpperCase();
    if (codeCandidate.length == 2) {
      out.addAll(WorldRegionCatalog.regionCodesForCountry(codeCandidate));
    }

    final byName = CountryCatalog.findByName(
      _sanitizeCountryLabel(countryName),
    );
    if (byName != null) {
      out.addAll(WorldRegionCatalog.regionCodesForCountry(byName.code));
    }
    return out;
  }

  List<MediaItem> _eligibleTracksForRegion({
    required String regionCode,
    required List<MediaItem> library,
    required Map<String, Set<String>> artistRegionIndex,
  }) {
    final tracks = <MediaItem>[];
    for (final item in library) {
      if (!item.hasAudioLocal) continue;
      final regions = _resolveRegionsForItem(
        item: item,
        artistRegionIndex: artistRegionIndex,
      );
      if (!regions.contains(regionCode)) continue;
      tracks.add(item);
    }
    return tracks;
  }

  Set<String> _resolveRegionsForItem({
    required MediaItem item,
    required Map<String, Set<String>> artistRegionIndex,
  }) {
    final regions = <String>{};

    final credits = ArtistCreditParser.parse(item.displaySubtitle);
    final artistNames = <String>{
      credits.primaryArtist,
      ...credits.allArtists,
      item.displaySubtitle,
    };
    for (final artistName in artistNames) {
      final key = ArtistCreditParser.normalizeKey(artistName);
      if (key.isEmpty || key == 'unknown') continue;
      regions.addAll(artistRegionIndex[key] ?? const <String>{});
    }

    final itemCountryCode = _affinityEngine.resolveCountryCode(item);
    if (itemCountryCode != null) {
      regions.addAll(WorldRegionCatalog.regionCodesForCountry(itemCountryCode));
    }

    return regions;
  }

  List<MediaItem> _rankTracksForRegion({
    required String regionCode,
    required List<MediaItem> tracks,
    required List<Map<String, dynamic>> events,
    int? shuffleSeed,
  }) {
    final effectiveSeed =
        shuffleSeed ?? DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final recentTrackIds = _extractRecentTrackIdsForCountry(
      countryCode: regionCode,
      events: events,
      limit: 120,
    ).toSet();
    final recentArtistKeys = _extractRecentArtistKeysFromEvents(events: events);
    final scored = <_RegionScoredItem>[];

    for (final item in tracks) {
      final stableId = _stableTrackId(item);
      final artistKey = _primaryArtistKey(item);
      final engagement = _engagementScore(item);
      final novelty = _noveltyScore(item);
      final resumeBoost =
          (recentTrackIds.contains(stableId) ? 0.16 : 0.0) +
          (recentArtistKeys.contains(artistKey) ? 0.14 : 0.0);
      final score =
          (engagement * 0.48) +
          (novelty * 0.24) +
          (resumeBoost) +
          _stochasticRegionJitter(
            regionCode: regionCode,
            stableTrackId: stableId,
            shuffleSeed: effectiveSeed,
          );
      scored.add(
        _RegionScoredItem(
          item: item,
          stableTrackId: stableId,
          artistKey: artistKey,
          score: score,
        ),
      );
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return _interleaveByArtist(scored);
  }

  /// Mezcla pistas dentro de grupos de [tierSize] respetando el ranking
  /// global pero introduciendo variedad real con cada [seed] distinto.
  List<MediaItem> _shuffleWithinTiers(
    List<MediaItem> sorted,
    int seed, {
    int tierSize = 8,
  }) {
    final rng = math.Random(seed);
    final result = <MediaItem>[];
    for (var i = 0; i < sorted.length; i += tierSize) {
      final end = math.min(i + tierSize, sorted.length);
      final tier = sorted.sublist(i, end).toList();
      tier.shuffle(rng);
      result.addAll(tier);
    }
    return result;
  }

  List<MediaItem> _interleaveByArtist(List<_RegionScoredItem> scored) {
    final byArtist = <String, List<_RegionScoredItem>>{};
    for (final entry in scored) {
      byArtist
          .putIfAbsent(entry.artistKey, () => <_RegionScoredItem>[])
          .add(entry);
    }

    final artistOrder = byArtist.entries.toList(growable: false)
      ..sort((a, b) {
        final aTop = a.value.first.score;
        final bTop = b.value.first.score;
        return bTop.compareTo(aTop);
      });

    final out = <MediaItem>[];
    final used = <String>{};
    var progressed = true;
    while (progressed) {
      progressed = false;
      for (final entry in artistOrder) {
        if (entry.value.isEmpty) continue;
        final next = entry.value.removeAt(0);
        if (!used.add(next.stableTrackId)) continue;
        out.add(next.item);
        progressed = true;
      }
    }
    return out;
  }

  List<CountryStationEntity> _buildRegionStations({
    required String regionCode,
    required String regionName,
    required List<MediaItem> rankedTracks,
  }) {
    if (rankedTracks.isEmpty) return const <CountryStationEntity>[];
    final chunkSize = rankedTracks.length < 30 ? rankedTracks.length : 30;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final output = <CountryStationEntity>[];
    var stationIndex = 0;

    for (var start = 0; start < rankedTracks.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, rankedTracks.length);
      final chunk = rankedTracks.sublist(start, end);
      if (chunk.isEmpty) continue;
      final type = _typeForIndex(stationIndex);
      final stationId = '${regionCode}_radio_${stationIndex + 1}';
      output.add(
        CountryStationEntity(
          stationId: stationId,
          countryCode: regionCode,
          type: type,
          title: _stationTitle(
            regionName: regionName,
            stationIndex: stationIndex,
            totalStations: (rankedTracks.length / chunkSize).ceil(),
          ),
          subtitle: _stationSubtitle(trackCount: chunk.length, type: type),
          tracks: chunk,
          source: 'local',
          generatedAtMs: nowMs,
          ttlSec: 21600,
          seed: StationSeedEntity(
            countryCode: regionCode,
            stationType: type,
            generatedAtMs: nowMs,
            seedArtists: _seedArtistsFromTracks(chunk),
            seedGenres: _seedGenresFromTracks(chunk),
          ),
        ),
      );
      stationIndex += 1;
    }

    return output;
  }

  WorldStationType _typeForIndex(int index) {
    const order = <WorldStationType>[
      WorldStationType.essentials,
      WorldStationType.discovery,
      WorldStationType.gateway,
      WorldStationType.energy,
      WorldStationType.chill,
    ];
    return order[index % order.length];
  }

  String _stationTitle({
    required String regionName,
    required int stationIndex,
    required int totalStations,
  }) {
    if (stationIndex == 0 && totalStations <= 1) {
      return tr('world_mode.station_title_radio', args: [regionName]);
    }
    return tr(
      'world_mode.station_title_mix',
      args: [regionName, '${stationIndex + 1}'],
    );
  }

  String _stationSubtitle({
    required int trackCount,
    required WorldStationType type,
  }) {
    return tr(
      'world_mode.station_subtitle_tracks',
      args: ['$trackCount', type.title],
    );
  }

  List<String> _seedArtistsFromTracks(List<MediaItem> tracks) {
    final out = <String>{};
    for (final track in tracks) {
      final artist = track.displaySubtitle.trim();
      if (artist.isEmpty) continue;
      out.add(artist);
      if (out.length >= 8) break;
    }
    return out.toList(growable: false);
  }

  List<String> _seedGenresFromTracks(List<MediaItem> tracks) {
    final out = <String>{};
    for (final track in tracks) {
      final origin = track.origin.name.trim();
      if (origin.isEmpty) continue;
      out.add(origin);
      if (out.length >= 6) break;
    }
    return out.toList(growable: false);
  }

  Set<String> _extractRecentArtistKeysFromEvents({
    required List<Map<String, dynamic>> events,
  }) {
    final out = <String>{};
    for (final event in events) {
      final key = (event['artistKey'] as String? ?? '').trim();
      if (key.isEmpty || key == 'unknown') continue;
      out.add(key);
      if (out.length >= 14) break;
    }
    return out;
  }

  double _engagementScore(MediaItem item) {
    final playSignal = (item.playCount / 45).clamp(0, 1).toDouble();
    final completionSignal = _completionRate(item);
    final favoriteSignal = item.isFavorite ? 1.0 : 0.0;
    final recentSignal = _recentSignal(item.lastPlayedAt);
    return ((playSignal * 0.35) +
            (completionSignal * 0.30) +
            (favoriteSignal * 0.20) +
            (recentSignal * 0.15))
        .clamp(0, 1)
        .toDouble();
  }

  double _noveltyScore(MediaItem item) {
    final playActivity = (item.playCount + item.fullListenCount).toDouble();
    return (1 - (playActivity / 28).clamp(0, 1)).toDouble();
  }

  double _completionRate(MediaItem item) {
    final total = item.skipCount + item.fullListenCount;
    if (total <= 0) return item.avgListenProgress.clamp(0, 1).toDouble();
    return (item.fullListenCount / total).clamp(0, 1).toDouble();
  }

  double _recentSignal(int? ts) {
    final value = ts ?? 0;
    if (value <= 0) return 0;
    final ageHours =
        (DateTime.now().millisecondsSinceEpoch - value) / 3600000.0;
    if (ageHours <= 24) return 1;
    if (ageHours <= 24 * 3) return 0.72;
    if (ageHours <= 24 * 7) return 0.44;
    return 0.2;
  }

  double _stochasticRegionJitter({
    required String regionCode,
    required String stableTrackId,
    required int shuffleSeed,
  }) {
    final hash = Object.hash(regionCode, stableTrackId, shuffleSeed).abs();
    return (hash % 1000) / 1000 * 0.06;
  }

  List<String> _extractRecentTrackIdsForCountry({
    required String countryCode,
    required List<Map<String, dynamic>> events,
    int limit = 50,
  }) {
    final out = <String>[];
    final seen = <String>{};
    final code = countryCode.trim().toUpperCase();
    for (final event in events) {
      final eventCountryCode = (event['countryCode'] as String? ?? '')
          .trim()
          .toUpperCase();
      if (eventCountryCode != code) continue;
      final trackId = (event['trackId'] as String? ?? '').trim();
      if (trackId.isEmpty || !seen.add(trackId)) continue;
      out.add(trackId);
      if (out.length >= limit) break;
    }
    return out;
  }

  List<String> _mergePlayedIds({
    required Set<String> memoryIds,
    required List<MediaItem> queue,
  }) {
    final merged = <String>{};
    for (final raw in memoryIds) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      merged.add(value);
      if (value.startsWith('p:') || value.startsWith('i:')) {
        merged.add(value.substring(2));
      }
    }
    for (final item in queue) {
      merged.add(_stableTrackId(item));
    }
    return merged.toList(growable: false);
  }

  Map<String, MediaItem> _indexByStableId(List<MediaItem> library) {
    final byId = <String, MediaItem>{};
    for (final item in library) {
      final stable = _stableTrackId(item);
      byId.putIfAbsent(stable, () => item);

      final publicId = item.publicId.trim();
      if (publicId.isNotEmpty) {
        byId.putIfAbsent(publicId, () => item);
      }
      final id = item.id.trim();
      if (id.isNotEmpty) {
        byId.putIfAbsent(id, () => item);
      }
    }
    return byId;
  }

  String _stableTrackId(MediaItem item) {
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) return publicId;
    return item.id.trim();
  }

  String _primaryArtistKey(MediaItem item) {
    final parsed = ArtistCreditParser.parse(item.displaySubtitle);
    final key = ArtistCreditParser.normalizeKey(parsed.primaryArtist);
    if (key != 'unknown') return key;
    return ArtistCreditParser.normalizeKey(item.displaySubtitle);
  }

  String _sanitizeCountryLabel(String? value) {
    var text = (value ?? '').trim();
    if (text.isEmpty) return '';
    text = text.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]', unicode: true), '');
    text = text.replaceAll(RegExp(r'[\(\)\[\]\{\}]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}

class _RegionScoredItem {
  const _RegionScoredItem({
    required this.item,
    required this.stableTrackId,
    required this.artistKey,
    required this.score,
  });

  final MediaItem item;
  final String stableTrackId;
  final String artistKey;
  final double score;
}
