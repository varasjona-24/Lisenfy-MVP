import '../data/datasources/world_remote_datasource.dart';
import '../data/models/world_remote_models.dart';
import '../domain/entities/world_explore_options.dart';

class SyncManager {
  SyncManager(this._remoteDatasource);

  final WorldRemoteDatasource _remoteDatasource;

  Future<RemoteCountryExploreResponse?> tryExploreCountry({
    required String countryCode,
    required WorldExploreOptions options,
    required List<String> seedArtists,
    required List<String> seedGenres,
    required List<String> recentTrackIds,
    required List<String> candidateTrackIds,
  }) async {
    if (!options.preferOnline) return null;
    final tracksPerStation = options.tracksPerStation < 30
        ? 30
        : options.tracksPerStation;

    final payload = <String, dynamic>{
      'country': countryCode,
      'region': countryCode,
      'stationType': 'discovery',
      'seedArtists': seedArtists.take(8).toList(growable: false),
      'genres': seedGenres.take(8).toList(growable: false),
      'recentTrackIds': recentTrackIds.take(30).toList(growable: false),
      'candidateTrackIds': candidateTrackIds.take(240).toList(growable: false),
      'context': <String, dynamic>{
        'tracksPerStation': tracksPerStation,
        'maxStations': options.maxStations,
        'offlineFirst': true,
        'radioLike': true,
        'weights': <String, double>{
          'variety': 0.37,
          'affinity': 0.43,
          'resume': 0.20,
        },
        'rotation': <String, dynamic>{
          'maxConsecutiveByArtist': 1,
          'targetFreshRatio': 0.65,
        },
      },
    };

    try {
      return await _remoteDatasource
          .exploreCountry(countryCode: countryCode, payload: payload)
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      return null;
    }
  }

  Future<List<String>?> tryContinueStation({
    required String stationId,
    required String countryCode,
    required List<String> playedTrackIds,
    required List<String> recentTrackIds,
    required List<String> recentArtistKeys,
    required List<String> candidateTrackIds,
    int limit = 20,
  }) async {
    try {
      return await _remoteDatasource
          .continueStation(
            stationId: stationId,
            payload: <String, dynamic>{
              'stationId': stationId,
              'country': countryCode,
              'region': countryCode,
              'playedTrackIds': playedTrackIds.take(80).toList(growable: false),
              'recentTrackIds': recentTrackIds.take(40).toList(growable: false),
              'recentArtistKeys': recentArtistKeys
                  .take(12)
                  .toList(growable: false),
              'candidateTrackIds': candidateTrackIds
                  .take(240)
                  .toList(growable: false),
              'limit': limit,
              'strategy': <String, dynamic>{
                'mode': 'radio',
                'weights': <String, double>{
                  'variety': 0.35,
                  'affinity': 0.40,
                  'resume': 0.25,
                },
                'maxConsecutiveByArtist': 1,
                'targetFreshRatio': 0.60,
              },
            },
          )
          .timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      return null;
    }
  }
}
