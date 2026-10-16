import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/country_station_entity.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/station_seed_entity.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/world_station_type.dart';
import 'package:listenfy/Modules/world_mode/services/world_mode_playback_facade.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/data/playback/atlas_station_session_store.dart';
import 'package:listenfy/app/data/playback/playback_database.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/audio_service.dart';

class _Library implements LocalLibraryStore {
  _Library(this.items);
  final List<MediaItem> items;
  @override
  Future<List<MediaItem>> readAll() async => items;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

class _Audio extends GetxService implements AudioService {
  _Audio(this.atlasSessions);
  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  final AtlasStationSessionStore atlasSessions;
  @override
  String? activeAtlasStationId;
  @override
  bool hasSourceLoaded = false;
  @override
  List<MediaItem> queueItems = [];
  @override
  int currentQueueIndex = 0;
  int starts = 0;
  int resumes = 0;
  Duration? startedAt;
  bool? preservedOrder;
  @override
  Future<void> play(
    MediaItem item,
    MediaVariant variant, {
    bool autoPlay = true,
    List<MediaItem>? queue,
    int? queueIndex,
    bool forceReload = false,
    Duration initialPosition = Duration.zero,
    String? atlasStationId,
    bool preserveQueueOrder = false,
  }) async {
    starts++;
    preservedOrder = preserveQueueOrder;
    startedAt = initialPosition;
    activeAtlasStationId = atlasStationId;
    hasSourceLoaded = true;
    queueItems = queue!;
    currentQueueIndex = queueIndex!;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  void revealMiniPlayer() {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PlaybackDatabase database;
  late AtlasStationSessionStore store;
  late _Audio audio;
  late List<MediaItem> library;
  late WorldModePlaybackFacade facade;
  final opened = <String>[];

  CountryStationEntity station(String id) => CountryStationEntity(
    stationId: id,
    countryCode: 'JP',
    type: WorldStationType.gateway,
    title: 'Station',
    subtitle: '',
    tracks: library,
    source: 'local',
    generatedAtMs: 0,
    ttlSec: 3600,
    seed: const StationSeedEntity(
      countryCode: 'JP',
      stationType: WorldStationType.gateway,
      generatedAtMs: 0,
    ),
  );
  AtlasStationSession saved(String id, {int index = 1}) => AtlasStationSession(
    stationId: id,
    queue: library.map(AtlasTrackReference.fromItem).toList(),
    index: index,
    positionMs: 37000,
  );

  setUp(() async {
    Get.testMode = true;
    directory = await Directory.systemTemp.createTemp('atlas-resume-');
    database = await PlaybackDatabaseOpener.openStaging(
      generation: 'facade',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    store = AtlasStationSessionStore(PlaybackRepository(database));
    library = [];
    for (final id in ['a', 'b']) {
      final file = File('${directory.path}/$id.mp3');
      await file.writeAsBytes([0]);
      library.add(
        MediaItem(
          id: id,
          publicId: id,
          title: id,
          subtitle: '',
          source: MediaSource.local,
          origin: SourceOrigin.generic,
          variants: [
            MediaVariant(
              kind: MediaVariantKind.audio,
              format: 'mp3',
              fileName: '$id.mp3',
              createdAt: 1,
              localPath: file.path,
            ),
          ],
        ),
      );
    }
    audio = _Audio(store);
    Get.put<AudioService>(audio);
    Get.put<LocalLibraryStore>(_Library(library));
    opened.clear();
    facade = WorldModePlaybackFacade(
      openPlayer: (queue, index, id) async {
        opened.add(id);
        expect(queue[index].id, audio.queueItems[audio.currentQueueIndex].id);
      },
    );
  });
  tearDown(() async {
    Get.reset();
    await store.flush();
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'an unrelated playlist with identical songs is never resumed as a station',
    () async {
      audio.queueItems = library;
      audio.hasSourceLoaded = true;
      expect(await facade.resumeActiveStation(station('JP')), isFalse);
      expect(audio.resumes, 0);
      expect(audio.starts, 0);
      expect(opened, isEmpty);
    },
  );

  test(
    'closed station resumes its own index and position over another playlist',
    () async {
      await store.save(saved('JP'), activeId: null);
      audio.queueItems = library.reversed.toList();
      audio.hasSourceLoaded = true;
      expect(await facade.resumeActiveStation(station('JP')), isTrue);
      expect(audio.starts, 1);
      expect(audio.queueItems[audio.currentQueueIndex].id, 'b');
      expect(audio.startedAt, const Duration(seconds: 37));
      expect(audio.activeAtlasStationId, 'JP');
      expect(audio.preservedOrder, isTrue);
      expect(opened, ['JP']);
    },
  );

  test(
    'loaded station opens without restarting or seeking its audio',
    () async {
      audio.activeAtlasStationId = 'JP';
      audio.hasSourceLoaded = true;
      audio.queueItems = library;
      expect(await facade.resumeActiveStation(station('JP')), isTrue);
      expect(audio.starts, 0);
      expect(audio.resumes, 1);
      expect(opened, ['JP']);
    },
  );

  test(
    'a deleted file is skipped without applying its position to another song',
    () async {
      await store.save(saved('JP', index: 0), activeId: null);
      await File(library.first.variants.first.localPath!).delete();
      expect(await facade.resumeActiveStation(station('JP')), isTrue);
      expect(audio.queueItems.single.id, 'b');
      expect(audio.startedAt, Duration.zero);
    },
  );

  test(
    'if every file is gone continuation falls back without starting audio',
    () async {
      await store.save(saved('JP'), activeId: null);
      for (final item in library) {
        await File(item.variants.first.localPath!).delete();
      }
      expect(await facade.resumeActiveStation(station('JP')), isFalse);
      expect(audio.starts, 0);
      expect(opened, isEmpty);
    },
  );
}
