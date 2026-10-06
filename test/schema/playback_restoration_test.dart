import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/data/playback/playback_restoration.dart';
import 'package:listenfy/app/data/playback/legacy_restoration_snapshot.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PlaybackRepository repository;
  Future<PlaybackRepository> open({
    Future<void> Function(PlaybackFaultPoint)? fault,
  }) async => PlaybackRepository(
    await PlaybackDatabaseOpener.openStaging(
      generation: 'restore',
      supportDirectory: directory,
      temporaryDirectory: directory,
    ),
    faultInjector: fault,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('restoration-test-');
    repository = await open();
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });
  LegacyRestorationSnapshot source() => LegacyRestorationSnapshot.capture(
    (key) => {
      'audio_session_queue_items': [
        {'id': 'audio'},
      ],
      'audio_session_queue_variants': [
        {'format': 'mp3'},
      ],
      'audio_session_position_ms': 12345,
      'audio_session_was_playing': true,
      'audio_speed': 1.5,
      'audio_resume_positions': {'audio': 23456},
      'video_queue_items': [
        {'id': 'video'},
      ],
      'video_resume_positions': {'video': 45678},
      'video_resume_watch_ms': {'video': 20000},
    }[key],
  );
  Future<bool> import(LegacyRestorationSnapshot snapshot) =>
      repository.importRestoration(
        sourceId: 'frozen-legacy',
        sourceHash: snapshot.hash,
        importedAtUtcMs: 100,
        states: snapshot.states,
        resumePoints: snapshot.resumePoints,
      );

  test(
    'imports both modes without manufacturing history and survives reopen',
    () async {
      final snapshot = source();
      expect(await import(snapshot), isTrue);
      await repository.close();
      repository = await open();
      final audio = (await repository.readRestoration(RestorationMode.audio))!;
      expect(audio.positionMs, 12345);
      expect(audio.speed, 1.5);
      expect(audio.wasPlaying, isTrue);
      expect(
        (await repository.readResumePoints(
          RestorationMode.video,
        )).single.trustedWatchMs,
        20000,
      );
      final raw = sqlite3.open('${directory.path}/playback/staging/restore.db');
      expect(
        raw.select('SELECT COUNT(*) AS n FROM playback_session').single['n'],
        0,
      );
      expect(
        raw.select('SELECT COUNT(*) AS n FROM playback_event').single['n'],
        0,
      );
      raw.close();
    },
  );
  test(
    'retry cannot overwrite newer state and changed source conflicts',
    () async {
      final snapshot = source();
      await import(snapshot);
      await repository.saveRestoration(
        PlaybackRestoration(
          mode: RestorationMode.audio,
          queue: [],
          positionMs: 999,
        ),
        nowUtcMs: 200,
      );
      final revision = await repository.readRevision();
      expect(await import(snapshot), isFalse);
      expect(await repository.readRevision(), revision);
      expect(
        (await repository.readRestoration(RestorationMode.audio))!.positionMs,
        999,
      );
      await expectLater(
        import(LegacyRestorationSnapshot.capture((_) => null)),
        throwsA(isA<PlaybackIdempotencyConflict>()),
      );
    },
  );
  test('failure rolls back both modes, receipt and revision', () async {
    await repository.close();
    repository = await open(
      fault: (point) async {
        if (point == PlaybackFaultPoint.beforeCommit) {
          throw StateError('injected');
        }
      },
    );
    await expectLater(import(source()), throwsStateError);
    expect(await repository.readRevision(), 0);
    expect(await repository.readRestoration(RestorationMode.audio), isNull);
    expect(await repository.readResumePoints(RestorationMode.video), isEmpty);
    await repository.close();
    repository = await open();
    expect(await import(source()), isTrue);
  });
  test(
    'resume save and delete isolate modes and do not remove history',
    () async {
      for (final mode in RestorationMode.values) {
        await repository.saveResumePoint(
          PlaybackResumePoint(mode: mode, trackKey: 'shared', positionMs: 10),
        );
      }
      await repository.clearResumePoint(RestorationMode.audio, 'shared');
      expect(await repository.readResumePoints(RestorationMode.audio), isEmpty);
      expect(
        await repository.readResumePoints(RestorationMode.video),
        hasLength(1),
      );
    },
  );
  test(
    'rejects mismatched queues and invalid progress rather than silently discarding data',
    () {
      expect(
        () => PlaybackRestoration(
          mode: RestorationMode.audio,
          queue: [
            {'id': 'a'},
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => PlaybackResumePoint(
          mode: RestorationMode.video,
          trackKey: 'a',
          positionMs: -1,
        ).validate(),
        throwsArgumentError,
      );
      final snapshot = source();
      expect(
        LegacyRestorationSnapshot.fromBytes(snapshot.bytes).hash,
        snapshot.hash,
      );
    },
  );
  test('upgrades real v1 without losing journal identities', () async {
    await repository.close();
    final raw = sqlite3.open('${directory.path}/playback/staging/old.db');
    raw.execute(await File(PlaybackDatabaseOpener.schemaAsset).readAsString());
    raw.execute(
      "INSERT INTO media_identity(media_id,created_at_utc_ms) VALUES('preserved',1)",
    );
    raw.close();
    final upgraded = await PlaybackDatabaseOpener.openStaging(
      generation: 'old',
      supportDirectory: directory,
      temporaryDirectory: directory,
    );
    expect(
      (await upgraded
              .customSelect('SELECT media_id FROM media_identity')
              .getSingle())
          .read<String>('media_id'),
      'preserved',
    );
    expect(
      (await upgraded.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      4,
    );
    await upgraded.close();
    repository = await open();
  });
}
