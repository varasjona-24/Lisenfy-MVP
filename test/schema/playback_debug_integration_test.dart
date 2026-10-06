import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'package:listenfy/Modules/settings/controller/playback_settings_controller.dart';
import 'package:listenfy/Modules/player/Video/Controller/video_player_controller.dart';
import 'package:listenfy/app/data/playback/playback_debug_bootstrap.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/data/playback/playback_state_storage.dart';
import 'package:listenfy/app/data/playback/playback_restoration.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/Modules/recommendations/data/listening_event_store.dart';
import 'package:listenfy/app/services/sqlite_engine_history_factory.dart';
import 'package:listenfy/app/services/audio_service.dart';
import 'package:listenfy/app/models/media_item.dart';

class _CrossfadeAudio extends AudioService {
  final appliedCrossfade = <int>[];
  @override
  // This test double must not initialize native audio plugins.
  // ignore: must_call_super
  Future<void> onInit() async {}
  @override
  void onClose() {}
  @override
  Future<void> setVolume(double value) async {}
  @override
  Future<void> setCrossfadeSeconds(int seconds) async {
    appliedCrossfade.add(seconds);
  }
}

class _Legacy implements GetStorage {
  final values = <String, dynamic>{
    'local_library_items': [
      {
        'id': 'song',
        'publicId': 'public',
        'title': 'Song',
        'subtitle': 'Artist',
        'variants': [],
        'playCount': 10,
        'skipCount': 2,
        'fullListenCount': 4,
        'avgListenProgress': 0.5,
      },
    ],
    'listening_events_v1': [
      {
        'trackKey': 'p:public',
        'occurredAt': 1234,
        'progress': 0.5,
        'completed': false,
        'skipped': true,
        'mode': 'audio',
        'playedSeconds': 30,
      },
    ],
    'audio_session_queue_items': [
      {'id': 'song'},
    ],
    'audio_session_queue_variants': [
      {'format': 'mp3'},
    ],
    'audio_session_position_ms': 32100,
    'video_resume_positions': {'video': 24000},
    'video_resume_watch_ms': {'video': 12000},
  };
  final writes = <String>[];
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  Future<void> write(String key, dynamic value) async {
    values[key] = value;
    writes.add(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PlaybackRepository repository;
  late PlaybackStateStorage storage;
  late _Legacy legacy;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'playback-debug-integration-',
    );
    legacy = _Legacy();
    (repository, storage) = await PlaybackDebugBootstrap.open(
      legacy,
      'install',
      supportDirectory: directory,
    );
  });
  tearDown(() async {
    Get.reset();
    await storage.flush();
    await repository.close();
    await directory.delete(recursive: true);
  });
  test(
    'invalid partial queue rolls back and later valid state recovers both modes',
    () async {
      await storage.write('audio_resume_positions', {'honey': 42000});
      await expectLater(
        storage.write('audio_session_index', 2),
        throwsArgumentError,
      );
      expect(storage.failure, isNotNull);
      expect(
        (await repository.readRestoration(RestorationMode.audio))?.index ?? 0,
        0,
      );
      await storage.write('audio_session_index', 0);
      await storage.write('video_queue_items', <Map<String, dynamic>>[
        {'id': 'video'},
      ]);
      await storage.flush();
      expect(storage.failure, isNull);
      expect(
        (await repository.readResumePoints(
          RestorationMode.audio,
        )).single.positionMs,
        42000,
      );
      expect(
        (await repository.readRestoration(
          RestorationMode.video,
        ))!.payload['queue'],
        [
          {'id': 'video'},
        ],
      );
    },
  );
  test(
    'playback settings read SQL crossfade and leave legacy preferences separate',
    () async {
      legacy.values['audio_crossfade_seconds'] = 1;
      await storage.write('audio_crossfade_seconds', 8);
      await storage.flush();
      Get.put<PlaybackStateStorage>(storage);
      final audio = Get.put<AudioService>(_CrossfadeAudio()) as _CrossfadeAudio;
      final settings = PlaybackSettingsController();
      settings.onInit();
      expect(settings.crossfadeSeconds.value, 8);
      expect(audio.appliedCrossfade, [8]);
      await settings.setCrossfadeSeconds(4);
      await storage.flush();
      expect(
        (await repository.readRestoration(
          RestorationMode.audio,
        ))!.crossfadeSeconds,
        4,
      );
      expect(legacy.values['audio_crossfade_seconds'], 1);
      settings.setAutoPlayNext(false);
      expect(legacy.values['autoPlayNext'], false);
      await settings.resetPlaybackSettings();
      await storage.flush();
      expect(
        (await repository.readRestoration(
          RestorationMode.audio,
        ))!.crossfadeSeconds,
        0,
      );
      expect(legacy.values['audio_crossfade_seconds'], 1);
      settings.onClose();
      expect(audio.appliedCrossfade, [8, 4, 0]);
    },
  );
  test(
    'video restoration uses SQL queue rather than stale legacy snapshot',
    () async {
      final item = MediaItem.fromJson({
        'id': 'sql-video',
        'title': 'SQL video',
        'artist': '',
        'source': 'local',
        'origin': 'device',
        'variants': [],
      });
      await storage.write('video_queue_items', [item.toJson()]);
      await storage.write('video_queue_index', 0);
      await storage.flush();
      legacy.values['video_queue_items'] = [
        {'id': 'old-video', 'title': 'Old'},
      ];
      Get.put<PlaybackStateStorage>(storage);
      final queue = VideoPlayerController.restorePersistedQueue(
        storage: playbackStateStorage(),
      );
      expect(queue.single.id, 'sql-video');
      expect(
        VideoPlayerController.restorePersistedIndex(
          queueLength: queue.length,
          storage: playbackStateStorage(),
        ),
        0,
      );
      expect(
        (legacy.values['video_queue_items'] as List).single['id'],
        'old-video',
      );
    },
  );
  test('legacy ZIP refuses overlapping baseline before import', () async {
    await expectLater(
      repository.validateLegacyBackupTarget('other'),
      throwsStateError,
    );
    expect((await repository.queryLibraryMetrics())['song']!['playCount'], 10);
  });
  test(
    'legacy ZIP imports into empty SQL and retries without duplicate facts',
    () async {
      final target = PlaybackRepository(
        await PlaybackDatabaseOpener.openStaging(
          generation: 'legacy-zip-test',
          supportDirectory: directory,
          temporaryDirectory: directory,
        ),
      );
      try {
        await target.validateLegacyBackupTarget('zip-hash');
        Future<void> import() => target.importLegacyHistory(
          library: (legacy.values['local_library_items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          events: (legacy.values['listening_events_v1'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          scope: 'install',
          sourceHash: 'zip-hash',
          migrationId: 'legacy-zip-zip-hash',
          nowUtcMs: 5000,
        );
        await import();
        await target.validateLegacyBackupTarget('zip-hash');
        await import();
        expect((await target.queryLibraryMetrics())['song']!['playCount'], 10);
        expect(await target.queryListeningEvents(), hasLength(1));
        await expectLater(
          target.validateLegacyBackupTarget('different'),
          throwsStateError,
        );
      } finally {
        await target.close();
      }
    },
  );
  test(
    'bootstrap imports facts and preserves baseline without dated inventions',
    () async {
      final history = ListeningEventStore.sqlite(
        querySqlite: repository.queryListeningEvents,
      );
      final events = await history.readAsync();
      expect(events, hasLength(1));
      expect(events.single.playedSeconds, 30);
      expect(events.single.trackKey, 'p:public');
      final metrics = await repository.queryLibraryMetrics();
      expect(metrics['song']!['playCount'], 10);
      expect(metrics['song']!['skipCount'], 2);
      final library = LocalLibraryStore(
        legacy,
        metricsLoader: repository.queryLibraryMetrics,
      );
      expect((await library.readAll()).single.playCount, 10);
      expect(storage.read<int>('audio_session_position_ms'), 32100);
      expect(storage.read<Map>('video_resume_watch_ms')!['video'], 12000);
    },
  );
  test(
    'operational writes survive reopen and never modify legacy keys',
    () async {
      storage.write('audio_session_position_ms', 45600);
      storage.write('audio_session_was_playing', true);
      await storage.flush();
      expect(legacy.writes, isEmpty);
      expect(legacy.read<int>('audio_session_position_ms'), 32100);
      await repository.close();
      // Bootstrap retries the frozen source, not the modified live source.
      legacy.values['audio_session_position_ms'] = 999;
      (repository, storage) = await PlaybackDebugBootstrap.open(
        legacy,
        'install',
        supportDirectory: directory,
      );
      expect(storage.read<int>('audio_session_position_ms'), 45600);
      expect(storage.read<bool>('audio_session_was_playing'), isTrue);
      expect(await repository.queryListeningEvents(), hasLength(1));
    },
  );
  test(
    'coalesces structural queue changes and does not truncate resume history',
    () async {
      storage.write('audio_session_queue_items', [
        {'id': 'new'},
        {'id': 'other'},
      ]);
      storage.write('audio_session_queue_variants', [
        {'format': 'mp3'},
        {'format': 'm4a'},
      ]);
      storage.write('audio_session_index', 1);
      storage.write('video_resume_positions', {
        for (var i = 0; i < 350; i++) 'v$i': i,
      });
      await storage.flush();
      expect(
        (await repository.readRestoration(RestorationMode.audio))!.index,
        1,
      );
      expect(
        await repository.readResumePoints(RestorationMode.video),
        hasLength(350),
      );
    },
  );
  test(
    'backup exact merge round trip preserves facts, baseline and restoration',
    () async {
      await storage.flush();
      final bundle = await repository.exportDebugBundle();
      final target = PlaybackRepository(
        await PlaybackDatabaseOpener.openStaging(
          generation: 'target',
          supportDirectory: directory,
          temporaryDirectory: directory,
        ),
      );
      try {
        await target.restoreDebugBundle(bundle);
        await target.restoreDebugBundle(bundle);
        expect(
          await target.queryListeningEvents(),
          await repository.queryListeningEvents(),
        );
        expect(
          await target.queryLibraryMetrics(),
          await repository.queryLibraryMetrics(),
        );
        expect(
          (await target.readRestoration(RestorationMode.audio))!.positionMs,
          32100,
        );
      } finally {
        await target.close();
      }
    },
  );
  test(
    'weekly ranges split real time without counting a session twice',
    () async {
      final monday = DateTime.utc(2026, 10, 5).millisecondsSinceEpoch;
      var utc = monday - 20000, mono = 0;
      final recorder =
          SqliteEngineHistoryFactory(
            repository: repository,
            installationScope: 'install',
          ).create(
            clock: () => DateTime.fromMillisecondsSinceEpoch(utc, isUtc: true),
            monotonicClock: () => mono,
          );
      final item = MediaItem.fromJson(
        Map<String, dynamic>.from(
          (legacy.values['local_library_items'] as List).single as Map,
        ),
      );
      final variant = MediaVariant(
        kind: MediaVariantKind.audio,
        format: 'mp3',
        fileName: 'https://example.test/song.mp3',
        createdAt: 1,
      );
      recorder.select(item, variant: variant);
      recorder.update(
        position: Duration.zero,
        duration: const Duration(seconds: 120),
        playing: true,
      );
      await recorder.flush();
      utc += 40000;
      mono += 40000;
      recorder.update(
        position: const Duration(seconds: 40),
        duration: const Duration(seconds: 120),
        playing: true,
      );
      await recorder.flush();
      final after = (await repository.queryListeningEvents(
        startUtcMs: monday,
        endUtcMs: monday + 60000,
      )).single;
      final before = (await repository.queryListeningEvents(
        startUtcMs: monday - 604800000,
        endUtcMs: monday,
      )).single;
      expect(after['playedSeconds'], 20);
      expect(after['countsAsPlay'], isFalse);
      expect(before['playedSeconds'], 20);
      expect(before['countsAsPlay'], isTrue);
      expect(
        (await repository.queryLibraryMetrics())['song']!['playCount'],
        11,
      );
      expect(
        (await repository.queryLibraryMetrics(
          mode: 'audio',
        ))['song']!['playCount'],
        1,
      );
      expect(await repository.queryLibraryMetrics(mode: 'video'), isEmpty);
    },
  );
  test(
    'editing library metadata does not persist projected counters in GetStorage',
    () async {
      final library = LocalLibraryStore(
        legacy,
        metricsLoader: repository.queryLibraryMetrics,
      );
      final item = (await library.readAll()).single;
      await library.upsert(item.copyWith(title: 'Edited'));
      final raw = (legacy.values['local_library_items'] as List).single as Map;
      expect(raw['playCount'], 10);
      expect((await library.readAll()).single.playCount, 10);
    },
  );
  test('backup conflict rolls back without replacing existing facts', () async {
    final bundle = await repository.exportDebugBundle();
    final tables = bundle['tables'] as Map;
    ((tables['legacy_metrics'] as List).single as Map)['play_count'] = 999;
    final revision = await repository.readRevision();
    await expectLater(repository.restoreDebugBundle(bundle), throwsA(anything));
    expect(await repository.readRevision(), revision);
    expect((await repository.queryLibraryMetrics())['song']!['playCount'], 10);
  });
}
