import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/world_mode/data/models/world_cached_station_model.dart';

void main() {
  test(
    'old cache ignores obsolete source without losing station identity or tracks',
    () {
      for (final source in ['hybrid', 'remote', 'local']) {
        final model = WorldCachedStationModel.fromJson({
          'stationId': 'rio_plata_radio_1',
          'countryCode': 'rio_plata',
          'type': 'gateway',
          'title': 'Radio',
          'subtitle': 'Local library',
          'trackIds': ['song-a', 'song-b'],
          'source': source,
          'generatedAtMs': 1,
          'ttlSec': 3600,
        });
        expect(model.stationId, 'rio_plata_radio_1');
        expect(model.trackIds, ['song-a', 'song-b']);
        expect(model.toJson(), isNot(contains('source')));
        expect(
          WorldCachedStationModel.fromJson(model.toJson()).trackIds,
          model.trackIds,
        );
      }
    },
  );

  test(
    'station generation depends on local storage, not a network repository',
    () {
      for (final path in [
        'lib/Modules/world_mode/data/repositories/world_mode_repository_impl.dart',
        'lib/Modules/world_mode/binding/world_mode_binding.dart',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text, contains('LocalLibraryStore'));
        for (final marker in [
          'MediaRepository',
          'DioClient',
          'world_remote_datasource',
        ]) {
          expect(text, isNot(contains(marker)), reason: '$path: $marker');
        }
      }
    },
  );

  test('Atlas labels no longer advertise a hybrid station source', () {
    for (final locale in ['en', 'es']) {
      final json =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map;
      expect(json['world_mode']['station_sources'], isNull);
      expect(json['world_mode']['station_types'], isNull);
    }
    expect(
      File(
        'lib/Modules/world_mode/presentation/widgets/country_station_card.dart',
      ).readAsStringSync(),
      isNot(contains('_sourceLabel')),
    );
  });
}
