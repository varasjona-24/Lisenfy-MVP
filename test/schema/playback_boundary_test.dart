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
    dir = await Directory.systemTemp.createTemp('playback-boundary-');
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
  });
  tearDown(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });
  Future<void> open({
    int? duration = 100000,
    double speed = 1,
    PlaybackMode mode = PlaybackMode.audio,
  }) async {
    await repo.openSession(
      OpenPlaybackSession(
        commandId: 'open',
        sessionId: 's',
        eventId: 'play',
        mediaId: 'm',
        variant: PlaybackVariant(id: 'v', mode: mode, role: 'normal'),
        snapshot: const PlaybackSnapshot(id: 'snapshot'),
        startedAtUtcMs: 0,
        clockEpoch: 'clock',
        monotonicMs: 0,
        context: PlaybackContext.library,
        durationMs: duration,
        speed: speed,
      ),
    );
  }

  RecordPlaybackBoundary boundary(
    String id,
    PlaybackBoundary type,
    int time,
    int pos, {
    bool playing = false,
    int? start,
    int? target,
    double? speed,
    PlaybackTermination? reason,
  }) => RecordPlaybackBoundary(
    commandId: id,
    sessionId: 's',
    eventId: id,
    boundary: type,
    utcMs: time,
    monotonicMs: time,
    clockEpoch: 'clock',
    positionMs: pos,
    playingAfter: playing,
    intervalStartSequence: start,
    seekTargetMs: target,
    newSpeed: speed,
    termination: reason,
  );
  Future<Map<String, dynamic>> session() async =>
      (await db.customSelect('SELECT * FROM playback_session').getSingle())
          .data;
  test('video UI requires coverage and ignores audio completions', () async {
    await db.customStatement(
      "UPDATE media_identity SET library_id='item' WHERE media_id='m'",
    );
    await open(mode: PlaybackMode.video);
    await repo.recordBoundary(
      boundary(
        'end',
        PlaybackBoundary.stop,
        92000,
        92000,
        start: 1,
        reason: PlaybackTermination.manualNext,
      ),
    );
    expect((await repo.queryVideoStatuses())['item']?['fullListenCount'], 1);
  });
  test('seek to the end does not mark a video watched', () async {
    await db.customStatement(
      "UPDATE media_identity SET library_id='item' WHERE media_id='m'",
    );
    await open(mode: PlaybackMode.video);
    await repo.recordBoundary(
      boundary(
        'seek',
        PlaybackBoundary.seek,
        1000,
        1000,
        start: 1,
        target: 91000,
        playing: true,
      ),
    );
    await repo.recordBoundary(
      boundary(
        'end',
        PlaybackBoundary.stop,
        2000,
        92000,
        start: 2,
        reason: PlaybackTermination.manualNext,
      ),
    );
    expect((await repo.queryVideoStatuses())['item']?['fullListenCount'], 0);
  });
  test('audio completion does not mark a video watched', () async {
    await db.customStatement(
      "UPDATE media_identity SET library_id='item' WHERE media_id='m'",
    );
    await open();
    await repo.recordBoundary(
      boundary(
        'end',
        PlaybackBoundary.stop,
        92000,
        92000,
        start: 1,
        reason: PlaybackTermination.manualNext,
      ),
    );
    expect((await repo.queryVideoStatuses())['item'], isNull);
  });
  test(
    'short natural completion qualifies after three active seconds',
    () async {
      await open(duration: 4000);
      await repo.recordBoundary(
        boundary(
          'end',
          PlaybackBoundary.stop,
          4000,
          4000,
          start: 1,
          reason: PlaybackTermination.naturalEnd,
        ),
      );
      expect((await session())['valid_play'], 1);
      final event = await db
          .customSelect(
            "SELECT payload_json FROM playback_event WHERE event_id='end'",
          )
          .getSingle();
      expect(event.read<String>('payload_json'), contains('natural_end'));
    },
  );
  test('resume while already playing is rejected without mutation', () async {
    await open();
    await expectLater(
      repo.recordBoundary(
        boundary(
          'resume',
          PlaybackBoundary.resume,
          1000,
          1000,
          start: 1,
          playing: true,
        ),
      ),
      throwsStateError,
    );
    expect((await session())['last_sequence'], 1);
  });
  for (final position in [50000, 91900, 92000, 98000]) {
    test('manual next at $position respects 92 percent and retry', () async {
      await open();
      final command = boundary(
        'end',
        PlaybackBoundary.stop,
        position,
        position,
        start: 1,
        reason: PlaybackTermination.manualNext,
      );
      final result = await repo.recordBoundary(command);
      expect(result.skipped, position < 92000);
      expect(result.completed, position >= 92000);
      expect((await session())['termination_reason'], 'manual_next');
      expect((await repo.recordBoundary(command)).revision, result.revision);
    });
  }
  test('pause resume excludes inactive time', () async {
    await open();
    await repo.recordBoundary(
      boundary('pause', PlaybackBoundary.pause, 10000, 10000, start: 1),
    );
    await repo.recordBoundary(
      boundary('resume', PlaybackBoundary.resume, 50000, 10000, playing: true),
    );
    await repo.recordBoundary(
      boundary(
        'stop',
        PlaybackBoundary.stop,
        60000,
        20000,
        start: 3,
        reason: PlaybackTermination.explicitStop,
      ),
    );
    expect((await session())['wall_ms'], 20000);
    expect((await session())['skipped'], 0);
  });
  test('seek backwards unions overlapping ranges', () async {
    await open(duration: 120000);
    await repo.recordBoundary(
      boundary(
        'seek',
        PlaybackBoundary.seek,
        60000,
        60000,
        start: 1,
        target: 30000,
        playing: true,
      ),
    );
    await repo.recordBoundary(
      boundary(
        'stop',
        PlaybackBoundary.stop,
        120000,
        90000,
        start: 2,
        reason: PlaybackTermination.explicitStop,
      ),
    );
    final row = await session();
    expect(row['wall_ms'], 120000);
    expect(row['media_ms'], 120000);
    expect(row['coverage_ms'], 90000);
  });
  test('seek forwards adds no skipped content time', () async {
    await open();
    await repo.recordBoundary(
      boundary(
        'seek',
        PlaybackBoundary.seek,
        10000,
        10000,
        start: 1,
        target: 70000,
        playing: true,
      ),
    );
    await repo.recordBoundary(
      boundary(
        'end',
        PlaybackBoundary.stop,
        20000,
        80000,
        start: 2,
        reason: PlaybackTermination.engineError,
      ),
    );
    final row = await session();
    expect(row['media_ms'], 20000);
    expect(row['coverage_ms'], 20000);
    expect(row['skipped'], 0);
  });
  test('2x separates wall and media, natural completion', () async {
    await open(duration: 1200000, speed: 2);
    final result = await repo.recordBoundary(
      boundary(
        'end',
        PlaybackBoundary.stop,
        600000,
        1200000,
        start: 1,
        reason: PlaybackTermination.naturalEnd,
      ),
    );
    final row = await session();
    expect(row['wall_ms'], 600000);
    expect(row['media_ms'], 1200000);
    expect(result.completed, isTrue);
  });
  test('buffering and speed changes split effective intervals', () async {
    await open();
    await repo.recordBoundary(
      boundary(
        'buffer',
        PlaybackBoundary.bufferingStart,
        10000,
        10000,
        start: 1,
      ),
    );
    await repo.recordBoundary(
      boundary(
        'ready',
        PlaybackBoundary.bufferingEnd,
        50000,
        10000,
        playing: true,
      ),
    );
    await repo.recordBoundary(
      boundary(
        'speed',
        PlaybackBoundary.speedChange,
        60000,
        20000,
        start: 3,
        speed: 2,
        playing: true,
      ),
    );
    await repo.recordBoundary(
      boundary(
        'end',
        PlaybackBoundary.stop,
        70000,
        40000,
        start: 4,
        reason: PlaybackTermination.sourceLost,
      ),
    );
    final row = await session();
    expect(row['wall_ms'], 30000);
    expect(row['media_ms'], 40000);
    expect(row['skipped'], 0);
  });
  test('unknown duration never guesses skip', () async {
    await open(duration: null);
    final result = await repo.recordBoundary(
      boundary(
        'end',
        PlaybackBoundary.stop,
        10000,
        10000,
        start: 1,
        reason: PlaybackTermination.manualNext,
      ),
    );
    expect(result.skipped, isFalse);
    expect(result.completed, isFalse);
    expect((await session())['completion_ratio'], isNull);
  });
  test('unmarked seek rolls back and terminal rejects new commands', () async {
    await open();
    await expectLater(
      repo.recordBoundary(
        boundary(
          'bad',
          PlaybackBoundary.checkpoint,
          1000,
          80000,
          start: 1,
          playing: true,
        ),
      ),
      throwsStateError,
    );
    expect((await session())['last_sequence'], 1);
    await repo.recordBoundary(
      boundary(
        'end',
        PlaybackBoundary.stop,
        5000,
        5000,
        start: 1,
        reason: PlaybackTermination.processLost,
      ),
    );
    expect((await session())['status'], 'interrupted');
    await expectLater(
      repo.recordBoundary(
        boundary('late', PlaybackBoundary.resume, 6000, 5000, playing: true),
      ),
      throwsStateError,
    );
  });
}
