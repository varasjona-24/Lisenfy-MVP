import 'dart:math' as math;

import '../../../../app/data/repo/media_repository.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/utils/artist_credit_parser.dart';
import '../../../../app/utils/country_catalog.dart';
import '../../../artists/data/artist_store.dart';
import '../../agent/local_affinity_engine.dart';
import '../../agent/radio_station_planner.dart';
import '../../agent/sync_manager.dart';
import '../../data/models/world_cached_station_model.dart';
import '../../domain/entities/country_entity.dart';
import '../../domain/entities/country_station_entity.dart';
import '../../domain/entities/station_seed_entity.dart';
import '../../domain/entities/world_explore_options.dart';
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
    required SyncManager syncManager,
  }) : _mediaRepository = mediaRepository,
       _localDatasource = localDatasource,
       _artistStore = artistStore,
       _affinityEngine = affinityEngine,
       _radioPlanner = radioPlanner,
       _syncManager = syncManager;

  final MediaRepository _mediaRepository;
  final WorldLocalDatasource _localDatasource;
  final ArtistStore _artistStore;
  final LocalAffinityEngine _affinityEngine;
  final RadioStationPlanner _radioPlanner;
  final SyncManager _syncManager;

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
    WorldExploreOptions options = const WorldExploreOptions(),
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
        options.shuffleSeed ??
        DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
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

    List<CountryStationEntity> merged = localStations;
    if (options.preferOnline) {
      final recentTrackIds = _extractRecentTrackIdsForCountry(
        countryCode: regionCode,
        events: recentEvents,
      );
      final remoteResponse = await _syncManager.tryExploreCountry(
        countryCode: regionCode,
        options: options,
        seedArtists: _seedArtists(localStations),
        seedGenres: _seedGenres(localStations),
        recentTrackIds: recentTrackIds,
        candidateTrackIds: regionTracks.map(_stableTrackId).toList(),
      );
      if (remoteResponse != null &&
          remoteResponse.countryCode == regionCode &&
          remoteResponse.stations.isNotEmpty) {
        merged = _mergeRemoteHints(
          base: localStations,
          remote: remoteResponse.stations
              .map(
                (entry) => _RemoteSeedView(
                  stationId: entry.stationId,
                  type: entry.type,
                  title: entry.title,
                  subtitle: entry.subtitle,
                  trackIds: entry.trackIds,
                  ttlSec: entry.ttlSec,
                ),
              )
              .toList(growable: false),
          library: library,
          countryCode: regionCode,
          tracksPerStation: options.tracksPerStation,
          artistRegionIndex: artistRegionIndex,
        );
      }
    }

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

    final recentTrackIds = _extractRecentTrackIdsForStation(
      stationId: station.stationId,
      events: recentEvents,
      limit: 80,
    );
    final recentArtistKeys = _extractRecentArtistKeysForStation(
      stationId: station.stationId,
      events: recentEvents,
      byStableId: _indexByStableId(library),
      limit: 8,
    );

    final remoteIds = await _syncManager.tryContinueStation(
      stationId: station.stationId,
      countryCode: station.countryCode,
      playedTrackIds: _mergePlayedIds(
        memoryIds: stationPlayed,
        queue: station.tracks,
      ),
      recentTrackIds: recentTrackIds,
      recentArtistKeys: recentArtistKeys.toList(growable: false),
      candidateTrackIds: station.tracks.map(_stableTrackId).toList(),
      limit: safeLimit,
    );

    final byStableId = _indexByStableId(library);
    if (remoteIds != null && remoteIds.isNotEmpty) {
      final remoteQueue = <MediaItem>[];
      for (final id in remoteIds) {
        final item = byStableId[id];
        if (item == null || !item.hasAudioLocal) continue;
        if (remoteQueue.contains(item)) continue;
        remoteQueue.add(item);
        if (remoteQueue.length >= safeLimit) break;
      }
      final blended = _blendRadioQueues(
        preferred: remoteQueue,
        fallback: localRadioContinuation,
        limit: safeLimit,
      );
      if (blended.isNotEmpty) {
        return blended;
      }
    }

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
          title: station.title,
          subtitle: station.subtitle,
          tracks: tracks,
          source: station.source,
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
      final title = output.isEmpty && end == rankedTracks.length
          ? 'Radio $regionName'
          : '$regionName · Estación ${stationIndex + 1}';
      output.add(
        CountryStationEntity(
          stationId: stationId,
          countryCode: regionCode,
          type: type,
          title: title,
          subtitle: '${chunk.length} canciones',
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

  List<String> _extractRecentTrackIdsForStation({
    required String stationId,
    required List<Map<String, dynamic>> events,
    int limit = 80,
  }) {
    final out = <String>[];
    final seen = <String>{};
    final id = stationId.trim();
    for (final event in events) {
      final eventStationId = (event['stationId'] as String? ?? '').trim();
      if (eventStationId != id) continue;
      final trackId = (event['trackId'] as String? ?? '').trim();
      if (trackId.isEmpty || !seen.add(trackId)) continue;
      out.add(trackId);
      if (out.length >= limit) break;
    }
    return out;
  }

  Set<String> _extractRecentArtistKeysForStation({
    required String stationId,
    required List<Map<String, dynamic>> events,
    required Map<String, MediaItem> byStableId,
    int limit = 8,
  }) {
    final out = <String>{};
    final id = stationId.trim();
    for (final event in events) {
      final eventStationId = (event['stationId'] as String? ?? '').trim();
      if (eventStationId != id) continue;
      final trackId = (event['trackId'] as String? ?? '').trim();
      if (trackId.isEmpty) continue;
      final track = byStableId[trackId];
      if (track == null) continue;
      final key = _primaryArtistKey(track);
      if (key.isEmpty || key == 'unknown') continue;
      out.add(key);
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

  List<MediaItem> _blendRadioQueues({
    required List<MediaItem> preferred,
    required List<MediaItem> fallback,
    required int limit,
  }) {
    if (preferred.isEmpty) {
      return fallback.take(limit).toList(growable: false);
    }
    if (fallback.isEmpty) {
      return preferred.take(limit).toList(growable: false);
    }

    final out = <MediaItem>[];
    final used = <String>{};
    var pIndex = 0;
    var fIndex = 0;

    while (out.length < limit &&
        (pIndex < preferred.length || fIndex < fallback.length)) {
      for (var i = 0; i < 2 && out.length < limit; i += 1) {
        if (pIndex >= preferred.length) break;
        final item = preferred[pIndex++];
        final id = _stableTrackId(item);
        if (!used.add(id)) continue;
        out.add(item);
      }

      if (out.length >= limit || fIndex >= fallback.length) continue;
      final item = fallback[fIndex++];
      final id = _stableTrackId(item);
      if (!used.add(id)) continue;
      out.add(item);
    }

    return out.take(limit).toList(growable: false);
  }

  List<CountryStationEntity> _mergeRemoteHints({
    required List<CountryStationEntity> base,
    required List<_RemoteSeedView> remote,
    required List<MediaItem> library,
    required String countryCode,
    required int tracksPerStation,
    required Map<String, Set<String>> artistRegionIndex,
  }) {
    final merged = base.toList(growable: true);
    final effectiveTracksPerStation = tracksPerStation < 30
        ? 30
        : tracksPerStation;
    final consumedLocalIndex = <int>{};
    final byStableId = _indexByStableId(library);

    for (final remoteSeed in remote) {
      var localIndex = -1;
      for (var i = 0; i < merged.length; i += 1) {
        if (consumedLocalIndex.contains(i)) continue;
        if (merged[i].type != remoteSeed.type) continue;
        localIndex = i;
        break;
      }
      final local = localIndex >= 0 ? merged[localIndex] : null;

      final remoteTracks = <MediaItem>[];
      for (final id in remoteSeed.trackIds) {
        final item = byStableId[id];
        if (item == null || !item.hasAudioLocal) continue;
        if (!_trackBelongsToRegion(
          item: item,
          regionCode: countryCode,
          artistRegionIndex: artistRegionIndex,
        )) {
          continue;
        }
        if (remoteTracks.contains(item)) continue;
        remoteTracks.add(item);
        if (remoteTracks.length >= effectiveTracksPerStation) break;
      }
      if (remoteTracks.isEmpty) {
        continue;
      }

      if (local == null) {
        continue;
      }

      final queue = <MediaItem>[];
      final seenStableIds = <String>{};

      void push(MediaItem item) {
        if (queue.length >= effectiveTracksPerStation) return;
        final stable = _stableTrackId(item);
        if (!seenStableIds.add(stable)) return;
        queue.add(item);
      }

      for (final item in remoteTracks) {
        push(item);
      }
      for (final item in local.tracks) {
        push(item);
      }

      consumedLocalIndex.add(localIndex);
      merged[localIndex] = local.copyWith(
        stationId: remoteSeed.stationId,
        title: remoteSeed.title.isEmpty ? local.title : remoteSeed.title,
        subtitle: remoteSeed.subtitle.isEmpty
            ? local.subtitle
            : remoteSeed.subtitle,
        tracks: queue,
        source: queue.isEmpty ? local.source : 'hybrid',
        ttlSec: remoteSeed.ttlSec,
      );
    }

    return merged;
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

  bool _trackBelongsToRegion({
    required MediaItem item,
    required String regionCode,
    required Map<String, Set<String>> artistRegionIndex,
  }) {
    final regions = _resolveRegionsForItem(
      item: item,
      artistRegionIndex: artistRegionIndex,
    );
    return regions.contains(regionCode);
  }

  String _sanitizeCountryLabel(String? value) {
    var text = (value ?? '').trim();
    if (text.isEmpty) return '';
    text = text.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]', unicode: true), '');
    text = text.replaceAll(RegExp(r'[\(\)\[\]\{\}]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  List<String> _seedArtists(List<CountryStationEntity> stations) {
    final artists = <String>[];
    for (final station in stations) {
      for (final track in station.tracks.take(8)) {
        final name = track.displaySubtitle.trim();
        if (name.isEmpty || artists.contains(name)) continue;
        artists.add(name);
        if (artists.length >= 10) return artists;
      }
    }
    return artists;
  }

  List<String> _seedGenres(List<CountryStationEntity> stations) {
    final genres = <String>[];
    for (final station in stations) {
      final hint = station.type.key;
      if (!genres.contains(hint)) genres.add(hint);
      if (genres.length >= 6) return genres;
    }
    return genres;
  }
}

class _RemoteSeedView {
  const _RemoteSeedView({
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
