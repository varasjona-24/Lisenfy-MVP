import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/app/data/local/domain_storage.dart';
import 'package:listenfy/app/data/local/domain_backup_codec.dart';
import 'package:listenfy/app/data/playback/playback_database.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/Modules/sources/data/source_theme_topic_store.dart';
import 'package:listenfy/Modules/captures/data/capture_gallery_store.dart';
import 'package:listenfy/Modules/world_mode/data/datasources/world_local_datasource.dart';
import 'package:listenfy/Modules/recommendations/data/recommendation_feedback_store.dart';

class _Legacy implements GetStorage {
  final values = <String, dynamic>{
    for (final entry in durableDomainKeys.entries)
      entry.key: entry.value == 'map' ? <String, dynamic>{} : <dynamic>[],
    'source_theme_topics': [
      {'id': 'topic', 'title': 'Topic', 'themeId': 'parent'},
    ],
    'capture_gallery_tags': {
      '/missing/capture.jpg': ['tag'],
    },
    'world_mode_country_discovery_v1': {'JP': 2},
    'instrumental_tasks_v1': {
      'job': {
        'itemKey': 'job',
        'stage': 'uploading',
        'sessionId': 'remote',
        'sourcePath': '/missing/audio.mp3',
        'progress': 0.4,
      },
    },
    'selectedPalette': 'green',
    'defaultVolume': 80.0,
    'world_mode_stations_cache_v1': {'cache': true},
  };
  final writes = <String>[];
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  Future<void> write(String key, dynamic value) async {
    writes.add(key);
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    writes.add(key);
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unsupported legacy call');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory captures;
  late PlaybackDatabase db;
  late PlaybackRepository repository;
  late _Legacy legacy;
  Future<void> open() async {
    db = await PlaybackDatabaseOpener.openStaging(
      generation: 'domains',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    repository = PlaybackRepository(db);
  }

  Future<DomainStorage> load() => DomainStorage.open(
    repository,
    legacy,
    'test',
    supportDirectory: directory,
    capturesDirectory: captures,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('domain-test-');
    captures = Directory('${directory.path}/captures');
    await captures.create();
    legacy = _Legacy();
    await open();
  });
  test('complete SQL export includes every installed table', () async {
    await load();
    final bundle =
        jsonDecode(jsonEncode(await repository.exportCompleteDatabase()))
            as Map;
    final tables = bundle['tables'] as Map;
    final installed = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(
      tables.keys.toSet(),
      installed.map((row) => row.read<String>('name')).toSet(),
    );
    expect(tables.length, 28);
    expect(tables['app_domain_import'], hasLength(1));
    expect(tables['app_domain_record'], isNotEmpty);
    expect(tables.containsKey('playback_interval'), isTrue);
    expect(tables.containsKey('legacy_metrics'), isTrue);
    expect(bundle['scope'], 'all_application_tables');
    await db.customStatement('CREATE TABLE future_data(value TEXT)');
    await db.customStatement("INSERT INTO future_data VALUES ('preserved')");
    final future = await repository.exportCompleteDatabase();
    expect((future['tables'] as Map)['future_data'], [
      {'value': 'preserved'},
    ]);
  });
  tearDown(() async {
    Get.reset();
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'Atlas preserves more than 1200 events and repeated event ids',
    () async {
      final storage = await load();
      final events = List.generate(1205, (i) => {'id': 'same', 'sequence': i});
      await storage.write('world_mode_playback_events_v1', events);
      expect(storage.read<List>('world_mode_playback_events_v1'), events);
      expect(
        (await repository.readDomains())['world_mode_playback_events_v1'],
        events,
      );
    },
  );
  test('capture rename and delete update file registry', () async {
    final file = File('${captures.path}/original.jpg');
    await file.writeAsBytes([1, 2, 3]);
    final storage = await load();
    Get.put<DomainStorage>(storage);
    final store = CaptureGalleryStore(legacy);
    final renamed = await store.renameCapture(file.path, 'renamed');
    expect(
      storage.read<Map>('capture_files_v1')!.containsKey(file.path),
      isFalse,
    );
    expect(storage.read<Map>('capture_files_v1')!.containsKey(renamed), isTrue);
    await store.deleteCapture(renamed);
    expect(
      storage.read<Map>('capture_files_v1')!.containsKey(renamed),
      isFalse,
    );
    expect(await File(renamed).exists(), isFalse);
  });
  test(
    'all declared domains migrate, files are indexed, original data retained',
    () async {
      final capture = File('${captures.path}/untagged.jpg');
      await capture.writeAsBytes([1, 2, 3]);
      legacy.values['appBackgroundImagePaths'] = ['/missing/background.png'];
      final storage = await load();
      for (final key in durableDomainKeys.keys.where(
        (key) => key != 'capture_files_v1',
      )) {
        expect(storage.read(key), legacy.read(key), reason: key);
      }
      expect(
        storage.read<Map>('capture_files_v1')!.containsKey(capture.path),
        isTrue,
      );
      expect(
        await db.customSelect('SELECT * FROM app_domain_file').get(),
        hasLength(4),
      );
      expect(legacy.writes, isEmpty);
    },
  );
  test(
    'stores share SQL owner while preferences and station cache stay legacy',
    () async {
      final storage = await load();
      Get.put<DomainStorage>(storage);
      expect(SourceThemeTopicStore(legacy).readAllSync().single.id, 'topic');
      expect(CaptureGalleryStore(legacy).tagsFor('/missing/capture.jpg'), [
        'tag',
      ]);
      final world = WorldLocalDatasource(legacy);
      await world.incrementCountryDiscovery('JP');
      expect(await world.readDiscoveryMap(), {'JP': 3});
      expect(legacy.values['world_mode_country_discovery_v1'], {'JP': 2});
      final feedback = RecommendationFeedbackStore(legacy);
      await feedback.writeState(await feedback.readState());
      await storage.write('defaultVolume', 70.0);
      expect(legacy.writes, ['defaultVolume']);
      expect(storage.read('world_mode_stations_cache_v1'), {'cache': true});
    },
  );
  test(
    'job stage and result persist without ephemeral progress or message',
    () async {
      final storage = await load();
      await storage.write('instrumental_tasks_v1', {
        'job': {
          'itemKey': 'job',
          'stage': 'completed',
          'updatedAt': 3,
          'resultPath': '/missing/result.mp3',
          'progress': 1.0,
          'message': 'UI progress',
          'error': null,
        },
      });
      final durable = storage.read<Map>('instrumental_tasks_v1')!['job'] as Map;
      expect(durable.containsKey('progress'), isFalse);
      expect(durable.containsKey('message'), isFalse);
      expect(durable['stage'], 'completed');
      await repository.close();
      await open();
      expect(
        (await load()).read<Map>('instrumental_tasks_v1')!['job'],
        durable,
      );
      expect(
        (legacy.values['instrumental_tasks_v1'] as Map)['job']['stage'],
        'uploading',
      );
    },
  );
  test(
    'failed replacement rolls back, cache stays truthful and flush fails',
    () async {
      final storage = await load();
      await expectLater(
        storage.write('source_theme_topics', [
          {'id': 'same'},
          {'id': 'same'},
        ]),
        throwsA(anything),
      );
      expect(storage.read<List>('source_theme_topics')!.single['id'], 'topic');
      expect(
        (await repository.readDomains())['source_theme_topics'].single['id'],
        'topic',
      );
      await expectLater(storage.flush(), throwsStateError);
    },
  );
  test('import failure rolls back all namespaces and receipt', () async {
    await expectLater(
      repository.importDomains('bad', 'hash', {
        'world_mode_country_discovery_v1': {'JP': 1},
        'source_theme_topics': 42,
      }),
      throwsFormatException,
    );
    expect(await repository.readDomains(), isEmpty);
    expect(
      await db.customSelect('SELECT * FROM app_domain_import').get(),
      isEmpty,
    );
    await load();
  });
  test(
    'restoring supplemental data is atomic and keeps preferences untouched',
    () async {
      final storage = await load();
      await expectLater(
        storage.restoreValues({
          'world_mode_country_discovery_v1': {'JP': 9},
          'source_theme_topics': 42,
        }),
        throwsFormatException,
      );
      expect(storage.read('world_mode_country_discovery_v1'), {'JP': 2});
      await expectLater(storage.flush(), throwsStateError);
      final recovered = await load();
      await recovered.restoreValues({
        'world_mode_country_discovery_v1': {'JP': 9},
      });
      expect(recovered.read('world_mode_country_discovery_v1'), {'JP': 9});
      expect(legacy.writes, isEmpty);
    },
  );
  test('frozen retry never resurrects removed SQL data', () async {
    final storage = await load();
    await storage.remove('world_mode_station_memory_v1');
    await repository.close();
    await open();
    expect((await load()).read('world_mode_station_memory_v1'), isNull);
    expect(
      await db.customSelect('SELECT * FROM app_domain_import').get(),
      hasLength(1),
    );
  });
  test(
    'backup codec rebases nested file locators and preserves metadata',
    () async {
      final original = {
        'job': {
          'sourcePath': '/old/audio.mp3',
          'itemJson': {
            'variants': [
              {'localPath': '/old/result.mp3'},
            ],
          },
          'stage': 'saving',
        },
      };
      final encoded = await DomainBackupCodec.encode(
        original,
        (path) async => path.contains('result') ? null : 'Listenfy/audio.mp3',
      );
      final portable = jsonDecode(jsonEncode(encoded));
      final restored = await DomainBackupCodec.decode(
        portable,
        (rel) async => '/new/$rel',
      );
      expect(restored['job']['sourcePath'], '/new/Listenfy/audio.mp3');
      expect(restored['job']['itemJson']['variants'][0]['localPath'], isNull);
      expect(restored['job']['stage'], 'saving');
      await expectLater(
        DomainBackupCodec.decode({
          'sourcePath': {DomainBackupCodec.marker: '../unsafe'},
        }, (path) async => path),
        throwsFormatException,
      );
      await expectLater(
        DomainBackupCodec.decode({
          'sourcePath': '/old/unsafe',
        }, (path) async => path),
        throwsFormatException,
      );
    },
  );
}
