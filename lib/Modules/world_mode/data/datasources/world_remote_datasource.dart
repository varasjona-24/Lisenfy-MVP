import '../../../../app/data/network/dio_client.dart';
import '../models/world_remote_models.dart';

class WorldRemoteDatasource {
  WorldRemoteDatasource(this._client);

  final DioClient _client;

  Future<List<RemoteCountryModel>?> fetchCountries() async {
    try {
      final response = await _client.get('/countries');
      final data = response.data;
      if (data is! List) return null;
      return data
          .whereType<Map>()
          .map(
            (raw) =>
                RemoteCountryModel.fromJson(Map<String, dynamic>.from(raw)),
          )
          .where(
            (country) => country.code.isNotEmpty && country.name.isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<RemoteCountryExploreResponse?> exploreCountry({
    required String countryCode,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _client.post(
        '/agent/explore-country',
        data: payload,
      );
      final data = response.data;
      if (data is! Map) return null;
      final json = Map<String, dynamic>.from(data);
      final normalized = (json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'] as Map)
          : json;
      return RemoteCountryExploreResponse.fromJson(
        normalized,
        fallbackCountryCode: countryCode,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<String>?> continueStation({
    required String stationId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _client.post(
        '/agent/continue-station',
        data: payload,
      );
      final data = response.data;
      if (data is! Map) return null;
      final json = Map<String, dynamic>.from(data);
      final body = (json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'] as Map)
          : json;

      final result = <String>[];
      final ids =
          (body['trackPublicIds'] as List?) ??
          (body['trackIds'] as List?) ??
          ((body['queue'] is Map)
              ? ((body['queue'] as Map)['trackPublicIds'] as List?) ??
                    ((body['queue'] as Map)['trackIds'] as List?)
              : null) ??
          const <dynamic>[];
      for (final raw in ids) {
        final id = '$raw'.trim();
        if (id.isEmpty || result.contains(id)) continue;
        result.add(id);
      }
      final tracks =
          (body['tracks'] as List?) ??
          ((body['queue'] is Map)
              ? ((body['queue'] as Map)['tracks'] as List?)
              : null) ??
          const <dynamic>[];
      for (final raw in tracks) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id = (map['publicId'] as String? ?? map['id'] as String? ?? '')
            .trim();
        if (id.isEmpty || result.contains(id)) continue;
        result.add(id);
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}
