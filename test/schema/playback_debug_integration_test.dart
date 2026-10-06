import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/app/data/playback/playback_debug_bootstrap.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/data/playback/playback_state_storage.dart';
import 'package:listenfy/app/data/playback/playback_restoration.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/Modules/recommendations/data/listening_event_store.dart';
import 'package:listenfy/app/services/sqlite_engine_history_factory.dart';
import 'package:listenfy/app/models/media_item.dart';

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
    await storage.flush();
    await repository.close();
    await directory.delete(recursive: true);
  });
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
