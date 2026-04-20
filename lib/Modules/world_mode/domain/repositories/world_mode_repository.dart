import '../../../../app/models/media_item.dart';
import '../entities/country_entity.dart';
import '../entities/country_station_entity.dart';
import '../entities/world_explore_options.dart';

abstract class WorldModeRepository {
  Future<List<CountryEntity>> getCountries();

  Future<List<CountryStationEntity>> exploreCountry({
    required CountryEntity country,
    WorldExploreOptions options = const WorldExploreOptions(),
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
