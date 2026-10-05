import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/data/playback/playback_database.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/data/playback/playback_session_command.dart';
import 'package:listenfy/app/data/playback/playback_boundary_command.dart';
import 'package:listenfy/app/services/sqlite_engine_history_recorder.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late PlaybackDatabase db;
  late PlaybackRepository repo;
  late SqliteEngineHistoryRecorder recorder;
  var now = 0, ids = 0, sessions = 0;
  final item = MediaItem(
    id: 'item',
    publicId: 'public',
    title: 'Title',
    subtitle: 'Artist',
    source: MediaSource.local,
    variants: const [],
    origin: SourceOrigin.device,
  );
  const variant = MediaVariant(
    kind: MediaVariantKind.audio,
    format: 'mp3',
    fileName: 'song.mp3',
    createdAt: 0,
  );
  setUp(() async {
    now = 0;
    ids = 0;
    sessions = 0;
    dir = await Directory.systemTemp.createTemp('engine-history-');
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
        alias: PlaybackAlias(
          namespace: 'local',
          scope: 'install',
          value: 'item',
        ),
      ),
    );
    recorder = SqliteEngineHistoryRecorder(
      repository: repo,
      commandIdFactory: () => 'cmd${++ids}',
      clock: () => DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      monotonicClock: () => now,
      sessionFactory: (item, variant, utc, mono, pos, duration, speed) async {
        final id = 's${++sessions}';
        return OpenPlaybackSession(
          commandId: 'open$id',
          sessionId: id,
          eventId: 'play$id',
          mediaId: 'm',
          variant: PlaybackVariant(
            id: 'variant-${variant.kind.name}',
            mode: variant.kind == MediaVariantKind.audio
                ? PlaybackMode.audio
                : PlaybackMode.video,
            role: 'normal',
          ),
          snapshot: PlaybackSnapshot(id: 'snapshot$id', title: item.title),
          startedAtUtcMs: utc,
          clockEpoch: 'clock',
          monotonicMs: mono,
          context: PlaybackContext.library,
          positionMs: pos.inMilliseconds,
          durationMs: duration.inMilliseconds,
          speed: speed,
        );
      },
    );
  });
  tearDown(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });
  void sample(
    int time,
    int position, {
    bool playing = true,
    bool buffering = false,
    bool completed = false,
    bool looped = false,
  }) {
    now = time;
    recorder.update(
      position: Duration(milliseconds: position),
      duration: const Duration(seconds: 100),
      playing: playing,
      buffering: buffering,
      completed: completed,
      looped: looped,
    );
  }

  test(
    'explicit engine loop closes occurrence and starts a fresh session',
    () async {
      recorder.select(item, variant: variant);
      sample(0, 0);
      sample(99000, 99000);
      sample(100000, 0, looped: true);
      sample(105000, 5000);
      await recorder.flush();
      final rows = await db
          .customSelect(
            'SELECT * FROM playback_session ORDER BY started_at_utc_ms',
          )
          .get();
      expect(rows, hasLength(2));
      expect(rows.first.data['termination_reason'], 'natural_end');
      expect(rows.first.data['completed'], 1);
      expect(rows.last.data['wall_ms'], 5000);
    },
  );
  test('video observations retain video mode and natural completion', () async {
    const video = MediaVariant(
      kind: MediaVariantKind.video,
      format: 'mp4',
      fileName: 'video.mp4',
      createdAt: 0,
    );
    recorder.select(item, variant: video);
    sample(0, 0);
    sample(100000, 100000, playing: false, completed: true);
    await recorder.flush();
    final row =
        (await db.customSelect('SELECT * FROM playback_session').getSingle())
            .data;
    expect(row['mode'], 'video');
    expect(row['completed'], 1);
    expect(row['termination_reason'], 'natural_end');
  });
  test('duplicate queue entries create distinct occurrences', () async {
    recorder.select(item, variant: variant);
    sample(0, 0);
    sample(40000, 40000);
    recorder.intent(PlaybackTermination.manualNext);
    recorder.select(item, variant: variant, occurrenceChanged: true);
    sample(41000, 0);
    sample(46000, 5000);
    await recorder.flush();
    final rows = await db
        .customSelect(
          'SELECT * FROM playback_session ORDER BY started_at_utc_ms',
        )
        .get();
    expect(rows, hasLength(2));
    expect(rows.first.data['termination_reason'], 'manual_next');
    expect(rows.first.data['skipped'], 1);
    expect(rows.last.data['wall_ms'], 5000);
  });
  test('selection stays inert until ready playing', () async {
    recorder.select(item, variant: variant);
    sample(0, 0, playing: false);
    await recorder.flush();
    expect(
      (await db
              .customSelect('SELECT count(*) AS n FROM playback_session')
              .getSingle())
          .read<int>('n'),
      0,
    );
    sample(0, 0);
    sample(50000, 50000);
    recorder.intent(PlaybackTermination.manualNext);
    recorder.select(null);
    await recorder.flush();
    final row =
        (await db.customSelect('SELECT * FROM playback_session').getSingle())
            .data;
    expect(row['skipped'], 1);
    expect(row['termination_reason'], 'manual_next');
    expect(row['wall_ms'], 50000);
  });
  test(
    'near-end manual action preserves fact but completes statistically',
    () async {
      recorder.select(item, variant: variant);
      sample(0, 0);
      sample(92000, 92000);
      recorder.intent(PlaybackTermination.manualNext);
      recorder.select(null);
      await recorder.flush();
      final row =
          (await db.customSelect('SELECT * FROM playback_session').getSingle())
              .data;
      expect(row['completed'], 1);
      expect(row['skipped'], 0);
      expect(row['termination_reason'], 'manual_next');
    },
  );
  test('seek pause buffering and resume exclude gaps', () async {
    recorder.select(item, variant: variant);
    sample(0, 0);
    sample(10000, 10000);
    recorder.beforeSeek(const Duration(seconds: 50));
    recorder.afterSeek(playing: true);
    sample(20000, 60000);
    sample(20000, 60000, playing: false, buffering: true);
    sample(50000, 60000);
    sample(60000, 70000);
    recorder.select(null);
    await recorder.flush();
    final row =
        (await db.customSelect('SELECT * FROM playback_session').getSingle())
            .data;
    expect(row['wall_ms'], 30000);
    expect(row['media_ms'], 30000);
    expect(row['coverage_ms'], 30000);
  });
  test(
    'engine error does not classify an incomplete session as skip',
    () async {
      recorder.select(item, variant: variant);
      sample(0, 0);
      sample(40000, 40000);
      recorder.intent(PlaybackTermination.engineError);
      recorder.select(null);
      await recorder.flush();
      final row =
          (await db.customSelect('SELECT * FROM playback_session').getSingle())
              .data;
      expect(row['skipped'], 0);
      expect(row['termination_reason'], 'engine_error');
    },
  );
  test(
    'unreported discontinuity surfaces failure without fabricated time',
    () async {
      recorder.select(item, variant: variant);
      sample(0, 0);
      sample(1000, 80000);
      await expectLater(recorder.flush(), throwsStateError);
      expect(
        (await db
                .customSelect('SELECT wall_ms FROM playback_session')
                .getSingle())
            .data['wall_ms'],
        0,
      );
    },
  );
}
