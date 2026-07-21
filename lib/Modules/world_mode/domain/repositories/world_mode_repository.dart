import '../../../../app/models/media_item.dart';
import '../entities/country_entity.dart';
import '../entities/country_station_entity.dart';

abstract class WorldModeRepository {
  Future<List<CountryEntity>> getCountries();

  Future<List<CountryStationEntity>> exploreCountry({
    required CountryEntity country,
    int? shuffleSeed,
  });

  Future<List<MediaItem>> continueStation({
    required CountryStationEntity station,
    int limit = 20,
  });

  Future<void> registerPlayback({
    required CountryStationEntity station,
    required MediaItem item,
    required int positionMs,
  });
}
