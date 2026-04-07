import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../domain/entities/country_station_entity.dart';

class WorldModePlaybackFacade {
  const WorldModePlaybackFacade();

  Future<void> playStation(
    CountryStationEntity station, {
    int startIndex = 0,
  }) async {
    final queue = station.tracks.where((track) => track.hasAudioLocal).toList();
    if (queue.isEmpty) return;
    final index = startIndex.clamp(0, queue.length - 1).toInt();
    await Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {'queue': queue, 'index': index},
    );
  }

  Future<void> playQueue(List<MediaItem> queue, {int startIndex = 0}) async {
    final filtered = queue.where((item) => item.hasAudioLocal).toList();
    if (filtered.isEmpty) return;
    final index = startIndex.clamp(0, filtered.length - 1).toInt();
    await Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {'queue': filtered, 'index': index},
    );
  }
}
