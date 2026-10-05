import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/data/playback/playback_database.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/data/playback/playback_session_command.dart';
import 'package:listenfy/app/data/playback/playback_boundary_command.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late PlaybackDatabase db;
  late PlaybackRepository repo;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('playback-aggregate-');
    db = await PlaybackDatabaseOpener.openStaging(
      generation: 'test',
      supportDirectory: dir,
      temporaryDirectory: dir,
    );
    repo = PlaybackRepository(db);
    await repo.registerIdentity(
      const RegisterPlaybackIdentity(
        commandId: 'identity',
        mediaId: 'm',
        createdAtUtcMs: 0,
        alias: PlaybackAlias(namespace: 'local', scope: 'install', value: 'm'),
      ),
    );
    await repo.openSession(
      const OpenPlaybackSession(
        commandId: 'open',
        sessionId: 's',
        eventId: 'play',
        mediaId: 'm',
        variant: PlaybackVariant(
          id: 'v',
          mode: PlaybackMode.audio,
          role: 'normal',
        ),
        snapshot: PlaybackSnapshot(id: 'snapshot'),
        startedAtUtcMs: 0,
        clockEpoch: 'clock',
        monotonicMs: 0,
        context: PlaybackContext.library,
        durationMs: 100000,
      ),
    );
  });
  tearDown(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });
  test('incremental aggregate matches repair rebuild exactly', () async {
    await repo.recordBoundary(
      const RecordPlaybackBoundary(
        commandId: 'end',
        sessionId: 's',
        eventId: 'end',
        boundary: PlaybackBoundary.stop,
        utcMs: 95000,
        monotonicMs: 95000,
        clockEpoch: 'clock',
        positionMs: 95000,
        playingAfter: false,
        intervalStartSequence: 1,
        termination: PlaybackTermination.manualNext,
      ),
    );
    final before =
        (await db.customSelect('SELECT * FROM playback_aggregate').getSingle())
            .data;
    expect(before['play_count'], 1);
    expect(before['completed_count'], 1);
    expect(before['skip_count'], 0);
    expect(before['wall_ms'], 95000);
    await db.customStatement('UPDATE playback_aggregate SET wall_ms=999');
    await repo.rebuildAggregates();
    expect(
      (await db.customSelect('SELECT * FROM playback_aggregate').getSingle())
          .data,
      before,
    );
  });
  test('recovery preserves confirmed time and is repeatable', () async {
    await repo.recordBoundary(
      const RecordPlaybackBoundary(
        commandId: 'checkpoint',
        sessionId: 's',
        eventId: 'checkpoint',
        boundary: PlaybackBoundary.checkpoint,
        utcMs: 25000,
        monotonicMs: 25000,
        clockEpoch: 'clock',
        positionMs: 25000,
        playingAfter: true,
        intervalStartSequence: 1,
      ),
    );
    await repo.close();
    db = await PlaybackDatabaseOpener.openStaging(
      generation: 'test',
      supportDirectory: dir,
      temporaryDirectory: dir,
    );
    repo = PlaybackRepository(db);
    expect(await repo.recoverInterruptedSessions(), 1);
    expect(await repo.recoverInterruptedSessions(), 0);
    final row =
        (await db.customSelect('SELECT * FROM playback_session').getSingle())
            .data;
    expect(row['status'], 'interrupted');
    expect(row['termination_reason'], 'process_lost');
    expect(row['wall_ms'], 25000);
    expect(row['ended_at_utc_ms'], 25000);
    expect(row['skipped'], 0);
    final before =
        (await db.customSelect('SELECT * FROM playback_aggregate').getSingle())
            .data;
    await repo.rebuildAggregates();
    expect(
      (await db.customSelect('SELECT * FROM playback_aggregate').getSingle())
          .data,
      before,
    );
  });
}
