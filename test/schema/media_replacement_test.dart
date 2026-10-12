import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/data/playback/playback_database.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/data/playback/playback_session_command.dart';
import 'package:listenfy/app/data/playback/playback_restoration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PlaybackDatabase db;
  late PlaybackRepository repository;
  var fail = false;
  Map<String, dynamic> item(String id) => {
    'id': id,
    'publicId': id,
    'title': id,
    'subtitle': 'Artist',
    'importedAt': id == 'old' ? 100 : 900,
    'isFavorite': id == 'old',
    'variants': [
      {
        'kind': 'audio',
        'format': 'mp3',
        'fileName': '$id.mp3',
        'localPath': '/files/$id.mp3',
        'durationSeconds': 200,
      },
    ],
  };
  setUp(() async {
    fail = false;
    directory = await Directory.systemTemp.createTemp('replacement-');
    db = await PlaybackDatabaseOpener.openStaging(
      generation: 'test',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    repository = PlaybackRepository(
      db,
      faultInjector: (point) {
        if (fail && point == PlaybackFaultPoint.beforeCommit) {
          throw StateError('injected');
        }
      },
    );
    await repository.replaceCatalog('local_library_items', [
      item('old'),
      item('new'),
    ]);
    for (final id in ['old', 'new']) {
      await repository.registerIdentity(
        RegisterPlaybackIdentity(
          commandId: 'identity-$id',
          mediaId: id,
          libraryId: id,
          createdAtUtcMs: 0,
          alias: PlaybackAlias(namespace: 'local', scope: 'test', value: id),
        ),
      );
      await repository.openSession(
        OpenPlaybackSession(
          commandId: 'open-$id',
          sessionId: 'session-$id',
          eventId: 'event-$id',
          mediaId: id,
          variant: PlaybackVariant(
            id: 'variant-$id',
            mode: PlaybackMode.audio,
            role: 'normal',
            format: 'mp3',
          ),
          snapshot: PlaybackSnapshot(id: 'snapshot-$id', title: id),
          startedAtUtcMs: 100,
          clockEpoch: 'epoch',
          monotonicMs: 10,
          context: PlaybackContext.library,
          durationMs: 200000,
        ),
      );
    }
    await repository.recoverInterruptedSessions();
    await repository.replaceCatalog('playlists', [
      {
        'id': 'list',
        'name': 'List',
        'itemIds': ['new', 'old'],
        'itemAddedAt': {'old': 100, 'new': 900},
        'createdAt': 1,
        'updatedAt': 2,
      },
    ]);
    await repository.saveOperationalBundle(
      [
        PlaybackRestoration(
          mode: RestorationMode.audio,
          queue: [item('new')],
          variants: [
            (item('new')['variants'] as List).first as Map<String, dynamic>,
          ],
          positionMs: 60000,
        ),
      ],
      [
        const PlaybackResumePoint(
          mode: RestorationMode.audio,
          trackKey: 'old',
          positionMs: 30000,
        ),
        const PlaybackResumePoint(
          mode: RestorationMode.audio,
          trackKey: 'new',
          positionMs: 60000,
        ),
      ],
      1000,
    );
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'unites history and playlists, preserves original metadata and queue',
    () async {
      final before = await db
          .customSelect('SELECT * FROM playback_event ORDER BY event_id')
          .get();
      final result = await repository.replaceMediaFile('old', 'new', {
        'audio': 'target',
      });
      expect(result.$1.id, 'old');
      expect(result.$1.originalImportAt, 100);
      expect(result.$1.isFavorite, true);
      expect(result.$1.variants.first.localPath, '/files/new.mp3');
      expect(result.$1.variants.length, 2);
      expect(result.$2, 1);
      final sessions = await db
          .customSelect('SELECT media_id FROM playback_session')
          .get();
      expect(sessions.map((r) => r.read<String>('media_id')), ['old', 'old']);
      final after = await db
          .customSelect('SELECT * FROM playback_event ORDER BY event_id')
          .get();
      expect(
        after.map((r) => r.data).toList(),
        before.map((r) => r.data).toList(),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      final points = await repository.readResumePoints(RestorationMode.audio);
      expect(points.single.trackKey, 'old');
      expect(points.single.positionMs, 60000);
      final state = (await repository.readRestoration(RestorationMode.audio))!;
      expect((state.payload['queue'] as List).single['id'], 'old');
      expect(state.positionMs, 60000);
      expect(
        (await db.customSelect('SELECT item_key FROM playlist_member').get())
            .single
            .read<String>('item_key'),
        'old',
      );
    },
  );
  test(
    'missing resume decision leaves both identities and points untouched',
    () async {
      await expectLater(
        repository.replaceMediaFile('old', 'new', {}),
        throwsStateError,
      );
      expect(
        (await repository.readResumePoints(RestorationMode.audio)).length,
        2,
      );
      expect(
        (await db.customSelect('SELECT * FROM library_record').get()).length,
        2,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT * FROM sqlite_master WHERE name='session_terminal_immutable'",
                )
                .get())
            .length,
        1,
      );
    },
  );
  test(
    'failure before commit rolls back catalogue, history and resume',
    () async {
      fail = true;
      await expectLater(
        repository.replaceMediaFile('old', 'new', {'audio': 'restart'}),
        throwsStateError,
      );
      expect(
        (await repository.readResumePoints(RestorationMode.audio)).length,
        2,
      );
      final ids = await db
          .customSelect('SELECT DISTINCT media_id FROM playback_session')
          .get();
      expect(ids.length, 2);
      expect(
        (await db.customSelect('SELECT * FROM library_record').get()).length,
        2,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
  test(
    'open playback blocks replacement without removing either item',
    () async {
      await repository.openSession(
        const OpenPlaybackSession(
          commandId: 'again',
          sessionId: 'active',
          eventId: 'active-event',
          mediaId: 'new',
          variant: PlaybackVariant(
            id: 'variant-new',
            mode: PlaybackMode.audio,
            role: 'normal',
            format: 'mp3',
          ),
          snapshot: PlaybackSnapshot(id: 'active-snapshot', title: 'new'),
          startedAtUtcMs: 2000,
          clockEpoch: 'epoch',
          monotonicMs: 20,
          context: PlaybackContext.library,
          durationMs: 200000,
        ),
      );
      await expectLater(
        repository.replaceMediaFile('old', 'new', {'audio': 'source'}),
        throwsStateError,
      );
      expect(
        (await db.customSelect('SELECT * FROM library_record').get()).length,
        2,
      );
    },
  );
  test(
    'restart clears pending resume without clearing the saved queue',
    () async {
      await repository.replaceMediaFile('old', 'new', {'audio': 'restart'});
      expect(await repository.readResumePoints(RestorationMode.audio), isEmpty);
      expect(
        (await repository.readRestoration(RestorationMode.audio))!.positionMs,
        0,
      );
    },
  );
  test('collections and recommendation references survive replacement', () async {
    await repository.restoreDomainValues({
      'source_theme_topics': [
        {
          'id': 'topic',
          'itemIds': ['new', 'old'],
        },
      ],
      'recommendation_mix_state_v2': {
        'activeCycle': {
          'mixes': [
            {
              'itemKeys': ['new', 'old'],
            },
          ],
        },
      },
      'recommendation_feedback_v1': {
        'hiddenTrackKeys': ['new'],
        'trackBias': {'old': 1.0, 'new': -1.0},
      },
      'recommendation_ml_state_v1': {
        'weights': {'new': 0.5},
      },
    });
    await repository.replaceMediaFile('old', 'new', {'audio': 'source'});
    final values = await repository.readDomains();
    expect((values['source_theme_topics'] as List).single['itemIds'], ['old']);
    expect(
      values['recommendation_mix_state_v2']['activeCycle']['mixes'][0]['itemKeys'],
      ['old'],
    );
    expect(values['recommendation_feedback_v1']['hiddenTrackKeys'], ['old']);
    expect(values['recommendation_feedback_v1']['trackBias'], {'old': 1.0});
    expect(values['recommendation_ml_state_v1']['weights'], {'new': 0.5});
  });
}
