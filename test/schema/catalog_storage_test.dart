import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/app/data/local/catalog_storage.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/Modules/playlists/data/playlist_store.dart';
import 'package:listenfy/Modules/artists/data/artist_store.dart';
import 'package:listenfy/app/data/playback/playback_database.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';

class _Legacy implements GetStorage {
  final values = <String, dynamic>{
    'local_library_items': [
      {
        'id': 'local',
        'publicId': 'public',
        'title': 'Before',
        'subtitle': 'Artist',
        'source': 'local',
        'origin': 'device',
        'isFavorite': true,
        'playCount': 7,
        'thumbnailLocalPath': '/missing/cover.jpg',
        'variants': [
          {
            'kind': 'audio',
            'format': 'mp3',
            'fileName': 'song.mp3',
            'localPath': '/missing/song.mp3',
            'role': 'normal',
          },
        ],
      },
    ],
    'playlists': [
      {
        'id': 'list',
        'name': 'List',
        'createdAt': 1,
        'updatedAt': 2,
        'itemIds': ['public', 'missing', 'public'],
      },
    ],
    'artist_profiles': [
      {'key': 'artist', 'name': 'Artist'},
    ],
    'defaultVolume': 80.0,
  };
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Legacy must not be written');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PlaybackDatabase db;
  late PlaybackRepository repository;
  late _Legacy legacy;
  Future<void> open() async {
    db = await PlaybackDatabaseOpener.openStaging(
      generation: 'catalog',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    repository = PlaybackRepository(db);
  }

  Future<CatalogStorage> load() => CatalogStorage.open(
    repository,
    legacy,
    'test',
    supportDirectory: directory,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('catalog-test-');
    legacy = _Legacy();
    await open();
  });
  tearDown(() async {
    Get.reset();
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'imports normalized rows and keeps absent file references and aliases',
    () async {
      final storage = await load();
      expect(storage.read<List>('playlists')!.single['itemIds'], [
        'public',
        'missing',
        'public',
      ]);
      expect(
        (await db.customSelect('SELECT * FROM library_variant').get()),
        hasLength(1),
      );
      expect(
        (await db.customSelect('SELECT * FROM playlist_member').get()),
        hasLength(3),
      );
      expect(
        (await db.customSelect('SELECT * FROM catalog_file_reference').get()),
        hasLength(2),
      );
      expect(
        storage.read<List>('local_library_items'),
        legacy.values['local_library_items'],
      );
      expect(await File('/missing/song.mp3').exists(), isFalse);
    },
  );
  test(
    'all three existing stores read SQL and library edits leave legacy untouched',
    () async {
      final storage = await load();
      Get.put<CatalogStorage>(storage);
      final library = LocalLibraryStore(legacy);
      final before = library.revision;
      await library.upsert(
        library.readAllSync().single.copyWith(title: 'After'),
      );
      expect(library.readAllSync().single.title, 'After');
      expect(library.revision, greaterThan(before));
      expect(
        (legacy.values['local_library_items'] as List).single['title'],
        'Before',
      );
      expect((await PlaylistStore(legacy).readAll()).single.id, 'list');
      expect(ArtistStore(legacy).readAllSync(), hasLength(1));
      expect(legacy.read<double>('defaultVolume'), 80);
    },
  );
  test(
    'reopen preserves new SQL edits, retry cannot overwrite with legacy',
    () async {
      final storage = await load();
      await storage.write('artist_profiles', <dynamic>[]);
      await repository.close();
      await open();
      final restored = await load();
      expect(restored.read<List>('artist_profiles'), isEmpty);
      expect(
        (await db.customSelect('SELECT * FROM catalog_import').get()),
        hasLength(1),
      );
      expect(legacy.read<List>('artist_profiles'), hasLength(1));
    },
  );
  test(
    'invalid replacement rolls back and does not publish a false cache',
    () async {
      final storage = await load();
      await expectLater(
        storage.write('local_library_items', [
          {'id': 'duplicate'},
          {'id': 'duplicate'},
        ]),
        throwsA(anything),
      );
      expect(storage.read<List>('local_library_items')!.single['id'], 'local');
      expect(
        (await repository.readCatalog())['local_library_items']!.single['id'],
        'local',
      );
      await expectLater(storage.flush(), throwsStateError);
    },
  );
  test(
    'failed baseline import leaves every domain and receipt empty',
    () async {
      await expectLater(
        repository.importCatalog(
          sourceId: 'bad',
          sourceHash: 'hash',
          data: {
            'local_library_items': [
              {'id': 'ok'},
            ],
            'playlists': [
              {'id': 'duplicate'},
              {'id': 'duplicate'},
            ],
          },
        ),
        throwsA(anything),
      );
      final catalog = await repository.readCatalog();
      expect(catalog.values.every((list) => list.isEmpty), isTrue);
      expect(
        await db.customSelect('SELECT * FROM catalog_import').get(),
        isEmpty,
      );
      await load();
      expect(
        (await repository.readCatalog())['local_library_items'],
        hasLength(1),
      );
    },
  );
  test(
    'changed import hash is rejected without changing durable data',
    () async {
      await load();
      await expectLater(
        repository.importCatalog(
          sourceId: 'catalog-test',
          sourceHash: 'different',
          data: {},
        ),
        throwsStateError,
      );
      expect((await repository.readCatalog())['playlists'], hasLength(1));
    },
  );
}
