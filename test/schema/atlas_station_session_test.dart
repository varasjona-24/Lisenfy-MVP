import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/app/data/playback/atlas_station_session_store.dart';
import 'package:listenfy/app/data/playback/playback_database.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

MediaItem track(
  String id, {
  String? publicId,
  String path = '/current/audio.mp3',
}) => MediaItem(
  id: id,
  publicId: publicId ?? id,
  title: id,
  subtitle: 'Artist',
  source: MediaSource.local,
  origin: SourceOrigin.generic,
  durationSeconds: 180,
  variants: [
    MediaVariant(
      kind: MediaVariantKind.audio,
      format: 'mp3',
      fileName: '$id.mp3',
      createdAt: DateTime(2026).millisecondsSinceEpoch,
      localPath: path,
      durationSeconds: 180,
    ),
  ],
);

AtlasStationSession session(String id, {int index = 1, int position = 42000}) =>
    AtlasStationSession(
      stationId: id,
      queue: ['a', 'b', 'c'].map((id) => AtlasTrackReference(id, id)).toList(),
      index: index,
      positionMs: position,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PlaybackDatabase database;
  late PlaybackRepository repository;
  late AtlasStationSessionStore store;

  Future<void> open() async {
    database = await PlaybackDatabaseOpener.openStaging(
      generation: 'atlas',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    repository = PlaybackRepository(database);
    store = AtlasStationSessionStore(repository);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('atlas-sessions-');
    await open();
  });
  tearDown(() async {
    await store.flush();
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'two stations keep independent positions even with identical queues',
    () async {
      await store.save(session('JP'), activeId: 'JP');
      await store.save(session('UK', position: 90000), activeId: 'UK');
      expect((await store.read('JP'))!.positionMs, 42000);
      expect((await store.read('UK'))!.positionMs, 90000);
      expect(await store.read('unrelated-playlist'), isNull);
      expect(await store.readActiveStationId(), 'UK');
    },
  );

  test(
    'closing paused or playing audio and selecting a playlist keep station data',
    () async {
      await store.save(session('JP'), activeId: 'JP');
      await store.save(null, activeId: null);
      expect(await store.readActiveStationId(), isNull);
      expect((await store.read('JP'))!.index, 1);
      expect((await store.read('JP'))!.positionMs, 42000);
    },
  );

  test('station data survives closing and reopening SQLite', () async {
    await store.save(session('JP'), activeId: 'JP');
    await database.close();
    await open();
    final saved = (await store.read('JP'))!;
    expect(saved.queue.map((item) => item.id), ['a', 'b', 'c']);
    expect(saved.positionMs, 42000);
    expect(await store.readActiveStationId(), 'JP');
  });

  test('checkpoints serialize and reads wait for pending writes', () async {
    final writes = [
      for (var i = 0; i < 10; i++)
        store.save(session('JP', position: i * 1000), activeId: 'JP'),
    ];
    expect((await store.read('JP'))!.positionMs, 9000);
    await Future.wait(writes);
  });

  test('full backup restores station queues and positions', () async {
    await store.save(session('JP'), activeId: 'JP');
    final backup = await repository.exportCompleteDatabase();
    await store.save(session('JP', position: 120000), activeId: 'JP');
    await repository.restoreCompleteDatabase(backup);
    expect((await store.read('JP'))!.positionMs, 42000);
    expect(await store.readActiveStationId(), 'JP');
  });

  test(
    'current catalog paths and stable public IDs resolve a restored queue',
    () {
      final saved = session('JP');
      final resume = saved.resolve([
        track('a'),
        track('new-local-id', publicId: 'b', path: '/new/audio.mp3'),
        track('c'),
      ])!;
      expect(resume.index, 1);
      expect(resume.queue[1].variants.first.localPath, '/new/audio.mp3');
      expect(resume.position.inMilliseconds, 42000);
    },
  );

  test('missing active track advances to the next remaining song at zero', () {
    final resume = session('JP').resolve([track('a'), track('c')])!;
    expect(resume.queue[resume.index].id, 'c');
    expect(resume.position, Duration.zero);
    expect(session('JP').resolve([]), isNull);
  });

  test('removing an earlier item keeps the active song position', () {
    final resume = session('JP').resolve([track('b'), track('c')])!;
    expect(resume.index, 0);
    expect(resume.position.inMilliseconds, 42000);
    expect(
      session('JP', position: 999999).resolve([track('b')])!.position,
      Duration.zero,
    );
  });

  test(
    'malformed records cannot bind a station to an arbitrary session',
    () async {
      expect(
        AtlasStationSession.fromJson({
          'stationId': 'JP',
          'queue': [],
          'index': 0,
          'positionMs': 0,
        }),
        isNull,
      );
      await repository.replaceDomain(AtlasStationSessionStore.namespace, {
        'sessions': {'JP': session('UK').toJson()},
        'activeStationId': 'JP',
      });
      expect(await store.read('JP'), isNull);
    },
  );
}
