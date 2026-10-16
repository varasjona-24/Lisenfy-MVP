import 'package:get/get.dart';
import 'dart:io';

import '../../../app/models/media_item.dart';
import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/playback/atlas_station_session_store.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/services/audio_service.dart';
import '../domain/entities/country_station_entity.dart';

class WorldModePlaybackFacade {
  const WorldModePlaybackFacade({this.openPlayer});
  final Future<void> Function(
    List<MediaItem> queue,
    int index,
    String stationId,
  )?
  openPlayer;

  Future<void> playStation(
    CountryStationEntity station, {
    int startIndex = 0,
  }) async {
    await playQueue(
      station.tracks,
      startIndex: startIndex,
      stationId: station.stationId,
    );
  }

  Future<List<MediaItem>> _playableLibrary() async {
    final library = await Get.find<LocalLibraryStore>().readAll();
    final playable = <MediaItem>[];
    for (final item in library) {
      final variants = <MediaVariant>[];
      for (final variant in item.variants) {
        final path = variant.localPath;
        if (variant.kind == MediaVariantKind.audio &&
            variant.isValid &&
            path != null &&
            await File(path).exists()) {
          variants.add(variant);
        }
      }
      if (variants.isNotEmpty) playable.add(item.copyWith(variants: variants));
    }
    return playable;
  }

  Future<void> playQueue(
    List<MediaItem> queue, {
    int startIndex = 0,
    required String stationId,
  }) async {
    if (queue.isEmpty) return;
    final session = AtlasStationSession(
      stationId: stationId,
      queue: queue.map(AtlasTrackReference.fromItem).toList(),
      index: startIndex.clamp(0, queue.length - 1),
      positionMs: 0,
    );
    final resolved = session.resolve(await _playableLibrary());
    if (resolved != null) await _start(stationId, resolved);
  }

  Future<bool> resumeActiveStation(CountryStationEntity station) async {
    if (!Get.isRegistered<AudioService>()) return false;
    final audio = Get.find<AudioService>();
    if (audio.activeAtlasStationId == station.stationId &&
        audio.hasSourceLoaded &&
        audio.queueItems.isNotEmpty) {
      audio.revealMiniPlayer();
      await audio.resume();
      await _open(audio, station.stationId);
      return true;
    }
    final saved = await audio.atlasSessions.read(station.stationId);
    if (saved == null) return false;
    final resolved = saved.resolve(await _playableLibrary());
    if (resolved == null) return false;
    await _start(station.stationId, resolved, preserveQueueOrder: true);
    return true;
  }

  Future<void> _start(
    String stationId,
    AtlasStationResume session, {
    bool preserveQueueOrder = false,
  }) async {
    final audio = Get.find<AudioService>();
    final item = session.queue[session.index];
    final variant = _localVariant(item);
    if (variant == null) return;
    await audio.play(
      item,
      variant,
      queue: session.queue,
      queueIndex: session.index,
      initialPosition: session.position,
      forceReload: true,
      atlasStationId: stationId,
      preserveQueueOrder: preserveQueueOrder,
    );
    await _open(audio, stationId);
  }

  Future<void> _open(AudioService audio, String stationId) async {
    if (openPlayer != null) {
      await openPlayer!(audio.queueItems, audio.currentQueueIndex, stationId);
      return;
    }
    await Get.toNamed(
      AppRoutes.audioPlayer,
      arguments: {
        'queue': audio.queueItems,
        'index': audio.currentQueueIndex,
        'atlasStationId': stationId,
        'atlasResumeLoaded': true,
      },
    );
  }

  MediaVariant? _localVariant(MediaItem item) {
    MediaVariant? fallback;
    for (final variant in item.variants) {
      if (variant.kind != MediaVariantKind.audio ||
          !variant.isValid ||
          (variant.localPath?.isEmpty ?? true)) {
        continue;
      }
      if (!variant.isInstrumental && !variant.isSpatial8d) return variant;
      fallback ??= variant;
    }
    return fallback;
  }
}
