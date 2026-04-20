import 'dart:math' as math;

import '../../../app/models/media_item.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../../app/utils/country_catalog.dart';
import '../domain/entities/country_station_entity.dart';
import '../domain/entities/world_station_type.dart';
import 'local_affinity_engine.dart';

class RadioStationPlanner {
  RadioStationPlanner(this._affinityEngine);

  final LocalAffinityEngine _affinityEngine;

  List<MediaItem> buildContinuation({
    required CountryStationEntity station,
    required List<MediaItem> library,
    required Set<String> playedTrackIds,
    required List<Map<String, dynamic>> recentPlaybackEvents,
    required Map<String, double> countryAffinity,
    int limit = 20,
    int? shuffleSeed,
  }) {
    if (limit <= 0) return const <MediaItem>[];
    final targetCountryCode = station.countryCode.trim().toUpperCase();
    if (targetCountryCode.isEmpty) return const <MediaItem>[];

    final playable = library.where((item) => item.hasAudioLocal).toList();
    if (playable.isEmpty) return const <MediaItem>[];

    final byStableId = <String, MediaItem>{
      for (final item in playable) _stableId(item): item,
    };

    final normalizedPlayedIds = _normalizedPlayedIds(playedTrackIds);
    final recentTrackIds = _extractRecentTrackIds(
      recentPlaybackEvents,
      limit: 80,
    );
    final recentArtistKeys = _extractRecentArtistKeys(
      events: recentPlaybackEvents,
      byStableId: byStableId,
      stationId: station.stationId,
      limit: 8,
    );

    final effectiveSeed =
        shuffleSeed ?? DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

    final scored = <_ScoredTrack>[];
    for (final item in playable) {
      final stableId = _stableId(item);
      final resolvedCountry = _affinityEngine.resolveCountryCode(item);
      final relevance = _relevance(
        itemCountryCode: resolvedCountry,
        targetCountryCode: targetCountryCode,
      );
      final baseScore = _affinityEngine.scoreItemForCountry(
        item: item,
        targetCountryCode: targetCountryCode,
        stationType: station.type,
        countryAffinity: countryAffinity,
        resolvedCountryCode: resolvedCountry,
      );
      final resumeBoost = _resumeBoost(
        item: item,
        stableId: stableId,
        recentTrackIds: recentTrackIds,
        recentArtistKeys: recentArtistKeys,
      );
      final replayPenalty = normalizedPlayedIds.contains(stableId) ? 0.22 : 0.0;
      final score =
          baseScore +
          resumeBoost -
          replayPenalty +
          _stochasticJitter(
            stationId: station.stationId,
            stableId: stableId,
            stationType: station.type,
            shuffleSeed: effectiveSeed,
          );

      scored.add(
        _ScoredTrack(
          item: item,
          stableId: stableId,
          score: score,
          relevance: relevance,
          artistKey: _artistKey(item),
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Mezcla dentro de grupos de puntaje similar para verdadera variedad
    final shuffled = _shuffleWithinTiers(scored, effectiveSeed, tierSize: 6);

    return _selectWithRadioRotation(
      stationType: station.type,
      scored: shuffled,
      limit: limit,
    );
  }

  List<MediaItem> _selectWithRadioRotation({
    required WorldStationType stationType,
    required List<_ScoredTrack> scored,
    required int limit,
  }) {
    final direct = scored
        .where((entry) => entry.relevance == _CountryRelevance.direct)
        .toList(growable: false);
    final sameRegion = scored
        .where((entry) => entry.relevance == _CountryRelevance.sameRegion)
        .toList(growable: false);
    final other = scored
        .where(
          (entry) =>
              entry.relevance == _CountryRelevance.other ||
              entry.relevance == _CountryRelevance.unknown,
        )
        .toList(growable: false);

    final quotas = _quotas(
      stationType,
      limit: limit,
      hasDirect: direct.isNotEmpty,
    );
    final queue = <MediaItem>[];
    final usedIds = <String>{};
    final artistWindow = <String>[];

    void takeFrom(List<_ScoredTrack> source, int count) {
      if (count <= 0) return;
      for (final entry in source) {
        if (queue.length >= limit || count <= 0) break;
        if (!usedIds.add(entry.stableId)) continue;
        if (_violatesArtistWindow(artistWindow, entry.artistKey)) continue;
        queue.add(entry.item);
        artistWindow.add(entry.artistKey);
        if (artistWindow.length > 3) {
          artistWindow.removeAt(0);
        }
      }
    }

    takeFrom(direct, quotas.directQuota);
    takeFrom(sameRegion, quotas.sameRegionQuota);
    takeFrom(other, quotas.otherQuota);

    if (queue.length < limit) {
      for (final entry in scored) {
        if (queue.length >= limit) break;
        if (!usedIds.add(entry.stableId)) continue;
        if (_violatesArtistWindow(artistWindow, entry.artistKey)) continue;
        queue.add(entry.item);
        artistWindow.add(entry.artistKey);
        if (artistWindow.length > 3) {
          artistWindow.removeAt(0);
        }
      }
    }

    if (queue.length < limit) {
      for (final entry in scored) {
        if (queue.length >= limit) break;
        if (!usedIds.add(entry.stableId)) continue;
        queue.add(entry.item);
      }
    }

    return queue;
  }

  bool _violatesArtistWindow(List<String> window, String artistKey) {
    if (artistKey.isEmpty || artistKey == 'unknown') return false;
    if (window.isEmpty) return false;
    return window.last == artistKey ||
        (window.length >= 2 &&
            window[window.length - 1] == artistKey &&
            window[window.length - 2] == artistKey);
  }

  _StationQuotas _quotas(
    WorldStationType type, {
    required int limit,
    required bool hasDirect,
  }) {
    if (!hasDirect) {
      final sameRegion = (limit * 0.72).round();
      return _StationQuotas(
        directQuota: 0,
        sameRegionQuota: sameRegion,
        otherQuota: limit - sameRegion,
      );
    }

    switch (type) {
      case WorldStationType.essentials:
        return _ratioQuotas(limit: limit, direct: 0.75, sameRegion: 0.20);
      case WorldStationType.gateway:
        return _ratioQuotas(limit: limit, direct: 0.58, sameRegion: 0.28);
      case WorldStationType.discovery:
        return _ratioQuotas(limit: limit, direct: 0.48, sameRegion: 0.32);
      case WorldStationType.energy:
        return _ratioQuotas(limit: limit, direct: 0.56, sameRegion: 0.29);
      case WorldStationType.chill:
        return _ratioQuotas(limit: limit, direct: 0.54, sameRegion: 0.31);
    }
  }

  _StationQuotas _ratioQuotas({
    required int limit,
    required double direct,
    required double sameRegion,
  }) {
    final directQuota = (limit * direct).round();
    final sameQuota = (limit * sameRegion).round();
    return _StationQuotas(
      directQuota: directQuota,
      sameRegionQuota: sameQuota,
      otherQuota: (limit - directQuota - sameQuota).clamp(0, limit),
    );
  }

  /// Mezcla pistas dentro de grupos de tamaño [tierSize] para introducir
  /// variedad real manteniendo el orden general de relevancia.
  List<_ScoredTrack> _shuffleWithinTiers(
    List<_ScoredTrack> sorted,
    int seed, {
    int tierSize = 6,
  }) {
    final rng = math.Random(seed);
    final result = <_ScoredTrack>[];
    for (var i = 0; i < sorted.length; i += tierSize) {
      final end = math.min(i + tierSize, sorted.length);
      final tier = sorted.sublist(i, end).toList();
      tier.shuffle(rng);
      result.addAll(tier);
    }
    return result;
  }

  Set<String> _normalizedPlayedIds(Set<String> rawIds) {
    final normalized = <String>{};
    for (final raw in rawIds) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      normalized.add(value);
      if (value.startsWith('p:') || value.startsWith('i:')) {
        normalized.add(value.substring(2));
      } else {
        normalized.add('p:$value');
        normalized.add('i:$value');
      }
    }
    return normalized;
  }

  Set<String> _extractRecentTrackIds(
    List<Map<String, dynamic>> events, {
    required int limit,
  }) {
    final ids = <String>{};
    for (final event in events) {
      final id = (event['trackId'] as String? ?? '').trim();
      if (id.isEmpty) continue;
      ids.add(id);
      if (ids.length >= limit) break;
    }
    return ids;
  }

  Set<String> _extractRecentArtistKeys({
    required List<Map<String, dynamic>> events,
    required Map<String, MediaItem> byStableId,
    required String stationId,
    required int limit,
  }) {
    final keys = <String>{};
    for (final event in events) {
      final eventStationId = (event['stationId'] as String? ?? '').trim();
      if (eventStationId != stationId) continue;
      final trackId = (event['trackId'] as String? ?? '').trim();
      if (trackId.isEmpty) continue;
      final item = byStableId[trackId];
      if (item == null) continue;
      final key = _artistKey(item);
      if (key.isEmpty || key == 'unknown') continue;
      keys.add(key);
      if (keys.length >= limit) break;
    }
    return keys;
  }

  double _resumeBoost({
    required MediaItem item,
    required String stableId,
    required Set<String> recentTrackIds,
    required Set<String> recentArtistKeys,
  }) {
    var boost = 0.0;
    if (recentTrackIds.contains(stableId)) {
      boost += 0.08;
    }
    final artistKey = _artistKey(item);
    if (recentArtistKeys.contains(artistKey)) {
      boost += 0.12;
    }
    return boost;
  }

  _CountryRelevance _relevance({
    required String? itemCountryCode,
    required String targetCountryCode,
  }) {
    final itemCode = itemCountryCode?.trim().toUpperCase();
    if (itemCode == null || itemCode.isEmpty) return _CountryRelevance.unknown;
    if (itemCode == targetCountryCode) return _CountryRelevance.direct;
    final targetRegion = CountryCatalog.regionKeyFromCode(targetCountryCode);
    final itemRegion = CountryCatalog.regionKeyFromCode(itemCode);
    if (targetRegion != null && itemRegion == targetRegion) {
      return _CountryRelevance.sameRegion;
    }
    return _CountryRelevance.other;
  }

  /// Jitter estocástico: mezcla el seed aleatorio del usuario con el hash
  /// de la pista para que el mismo track produzca posiciones distintas
  /// en cada llamada con distinto [shuffleSeed].
  double _stochasticJitter({
    required String stationId,
    required String stableId,
    required WorldStationType stationType,
    required int shuffleSeed,
  }) {
    final hash =
        Object.hash(stationId, stationType.key, stableId, shuffleSeed).abs();
    return (hash % 1000) / 1000 * 0.04;
  }

  String _artistKey(MediaItem item) {
    final credits = ArtistCreditParser.parse(item.displaySubtitle);
    final key = ArtistCreditParser.normalizeKey(credits.primaryArtist);
    if (key != 'unknown') return key;
    return ArtistCreditParser.normalizeKey(item.displaySubtitle);
  }

  String _stableId(MediaItem item) {
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) return publicId;
    return item.id.trim();
  }
}

class _ScoredTrack {
  const _ScoredTrack({
    required this.item,
    required this.stableId,
    required this.score,
    required this.relevance,
    required this.artistKey,
  });

  final MediaItem item;
  final String stableId;
  final double score;
  final _CountryRelevance relevance;
  final String artistKey;
}

class _StationQuotas {
  const _StationQuotas({
    required this.directQuota,
    required this.sameRegionQuota,
    required this.otherQuota,
  });

  final int directQuota;
  final int sameRegionQuota;
  final int otherQuota;
}

enum _CountryRelevance { direct, sameRegion, other, unknown }
