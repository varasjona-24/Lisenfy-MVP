import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/services/audio_service.dart';
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

  Future<bool> resumeActiveStation(CountryStationEntity station) async {
    if (!Get.isRegistered<AudioService>()) return false;
    final audio = Get.find<AudioService>();
    if (!audio.hasSourceLoaded || audio.queueItems.isEmpty) return false;

    final stationKeys = station.tracks
        .where((item) => item.hasAudioLocal)
        .map(_stableKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (stationKeys.isEmpty) return false;

    final queue = audio.queueItems.where((item) => item.hasAudioLocal).toList();
    if (queue.isEmpty) return false;

    var matches = 0;
    for (final item in queue) {
      if (stationKeys.contains(_stableKey(item))) {
        matches++;
      }
    }
    final minimumMatches = stationKeys.length == 1 ? 1 : 2;
    if (matches < minimumMatches) return false;

    final current = audio.currentItem.value;
    final activeIndex = current == null
        ? audio.currentQueueIndex
        : queue.indexWhere((item) => _sameItem(item, current));
    final index = (activeIndex < 0 ? audio.currentQueueIndex : activeIndex)
        .clamp(0, queue.length - 1)
        .toInt();

    await Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {'queue': queue, 'index': index},
    );
    return true;
  }

  String _stableKey(MediaItem item) {
    final publicId = item.publicId.trim();
    return publicId.isNotEmpty ? publicId : item.id.trim();
  }

  bool _sameItem(MediaItem a, MediaItem b) {
    if (a.id == b.id) return true;
    final ap = a.publicId.trim();
    final bp = b.publicId.trim();
    return ap.isNotEmpty && bp.isNotEmpty && ap == bp;
  }
}
