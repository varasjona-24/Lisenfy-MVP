import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/data/playback/playback_database.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/data/playback/playback_session_command.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PlaybackDatabase db;
  late PlaybackRepository repository;
  var failBeforeCommit = false;
  setUp(() async {
    failBeforeCommit = false;
    directory = await Directory.systemTemp.createTemp('playback-session-');
    db = await PlaybackDatabaseOpener.openStaging(
      generation: 'test',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    repository = PlaybackRepository(
      db,
      faultInjector: (point) {
        if (failBeforeCommit && point == PlaybackFaultPoint.beforeCommit) {
          throw StateError('injected');
        }
      },
    );
    await repository.registerIdentity(
      const RegisterPlaybackIdentity(
        commandId: 'identity',
        mediaId: 'media',
        createdAtUtcMs: 0,
        alias: PlaybackAlias(
          namespace: 'local',
          scope: 'install',
          value: 'media',
        ),
      ),
    );
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });
  OpenPlaybackSession command({
    String id = 'start',
    String session = 'session',
    String event = 'event',
    String media = 'media',
    String variant = 'variant',
    PlaybackMode mode = PlaybackMode.audio,
    String snapshot = 'snapshot',
    String? title = 'Title',
    int position = 0,
    double speed = 1,
  }) => OpenPlaybackSession(
    commandId: id,
    sessionId: session,
    eventId: event,
    mediaId: media,
    variant: PlaybackVariant(
      id: variant,
      mode: mode,
      role: 'normal',
      format: 'mp3',
    ),
    snapshot: PlaybackSnapshot(id: snapshot, title: title, artist: 'Artist'),
    startedAtUtcMs: 100,
    clockEpoch: 'epoch',
    monotonicMs: 10,
    context: PlaybackContext.library,
    positionMs: position,
    durationMs: 240000,
    speed: speed,
  );
  Future<int> count(String table) async =>
      (await db.customSelect('SELECT count(*) AS n FROM $table').getSingle())
          .read<int>('n');

  test(
    'opening commits session, variant, snapshot and real play without counting listening',
    () async {
      final first = await repository.openSession(command(position: 40000));
      expect(first.revision, 2);
      expect(
        (await repository.openSession(command(position: 40000))).revision,
        2,
      );
      for (final table in [
        'playback_session',
        'media_variant',
        'metadata_snapshot',
        'playback_event',
      ]) {
        expect(await count(table), 1);
      }
      final session = await db
          .customSelect('SELECT * FROM playback_session')
          .getSingle();
      expect(
        session.data['initial_variant_id'],
        session.data['final_variant_id'],
      );
      expect(session.data['status'], 'open');
      expect(session.data['resumed'], 1);
      expect(session.data['valid_play'], 0);
      expect(session.data['wall_ms'], 0);
      expect(
        (await db.customSelect('SELECT type FROM playback_event').getSingle())
            .data['type'],
        'play',
      );
    },
  );
  test('conflicting session retry changes nothing', () async {
    await repository.openSession(command());
    await expectLater(
      repository.openSession(command(position: 99)),
      throwsA(isA<PlaybackIdempotencyConflict>()),
    );
    expect(await count('playback_event'), 1);
    expect(await repository.readRevision(), 2);
  });
  test(
    'audio and video remain separate while identical snapshots are deduplicated',
    () async {
      await repository.openSession(command());
      final second = await repository.openSession(
        command(
          id: 'video',
          session: 'video',
          event: 'video',
          variant: 'video',
          mode: PlaybackMode.video,
          snapshot: 'different-request-id',
        ),
      );
      expect(second.snapshotId, 'snapshot');
      expect(await count('metadata_snapshot'), 1);
      expect(await count('playback_session'), 2);
      expect(await count('media_variant'), 2);
    },
  );
  test('variant cannot move to another mode', () async {
    await repository.openSession(command());
    await expectLater(
      repository.openSession(
        command(
          id: 'other',
          session: 'other',
          event: 'other',
          mode: PlaybackMode.video,
        ),
      ),
      throwsStateError,
    );
    expect(await count('playback_session'), 1);
  });
  test('unknown media FK rolls back all writes', () async {
    await expectLater(
      repository.openSession(command(media: 'missing')),
      throwsA(anything),
    );
    expect(await count('media_variant'), 0);
    expect(await count('metadata_snapshot'), 0);
    expect(await repository.readRevision(), 1);
  });
  test(
    'fault before commit rolls back session and command, then retry succeeds',
    () async {
      failBeforeCommit = true;
      await expectLater(repository.openSession(command()), throwsStateError);
      for (final table in [
        'playback_session',
        'media_variant',
        'metadata_snapshot',
        'playback_event',
      ]) {
        expect(await count(table), 0);
      }
      expect(await count('applied_command'), 1);
      failBeforeCommit = false;
      expect((await repository.openSession(command())).revision, 2);
    },
  );
  test('invalid nonfinite speed is rejected before writes', () async {
    await expectLater(
      repository.openSession(command(speed: double.nan)),
      throwsArgumentError,
    );
    expect(await count('playback_session'), 0);
  });
  test('snapshot edits create new immutable history', () async {
    await repository.openSession(command());
    await repository.openSession(
      command(
        id: 'edit',
        session: 'edit',
        event: 'edit',
        snapshot: 'edited',
        title: 'New title',
      ),
    );
    expect(await count('metadata_snapshot'), 2);
    expect(
      (await db
              .customSelect(
                "SELECT title FROM metadata_snapshot WHERE snapshot_id='snapshot'",
              )
              .getSingle())
          .data['title'],
      'Title',
    );
  });
}
