import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('playback-repository-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Future<PlaybackRepository> open({
    Future<void> Function(PlaybackFaultPoint)? fault,
  }) async => PlaybackRepository(
    await PlaybackDatabaseOpener.openStaging(
      generation: 'test',
      supportDirectory: directory,
      temporaryDirectory: directory,
    ),
    faultInjector: fault,
  );
  RegisterPlaybackIdentity command({
    String id = 'cmd',
    String media = 'media',
  }) => RegisterPlaybackIdentity(
    commandId: id,
    mediaId: media,
    createdAtUtcMs: 10,
    alias: const PlaybackAlias(
      namespace: 'local',
      scope: 'install',
      value: 'original',
    ),
  );

  test(
    'retry returns durable result without repeating revision or notifications',
    () async {
      var repository = await open();
      final revisions = <int>[];
      final subscription = repository.revisions.listen(revisions.add);
      final first = await repository.registerIdentity(command());
      final retry = await repository.registerIdentity(command());
      expect(retry.revision, first.revision);
      expect(await repository.readRevision(), 1);
      await Future<void>.delayed(Duration.zero);
      expect(revisions, [1]);
      await subscription.cancel();
      await repository.close();
      repository = await open();
      expect((await repository.registerIdentity(command())).revision, 1);
      await repository.close();
    },
  );

  test(
    'conflicting retry is explicit and does not modify persisted state',
    () async {
      final repository = await open();
      await repository.registerIdentity(command());
      await expectLater(
        repository.registerIdentity(command(media: 'other')),
        throwsA(isA<PlaybackIdempotencyConflict>()),
      );
      expect(await repository.readRevision(), 1);
      expect(await repository.resolveAlias(command().alias), 'media');
      await repository.close();
    },
  );

  for (final point in [
    PlaybackFaultPoint.afterIdentityWrite,
    PlaybackFaultPoint.beforeCommit,
  ]) {
    test('fault $point rolls back all writes and retry succeeds', () async {
      var fail = true;
      final repository = await open(
        fault: (where) async {
          if (fail && where == point) {
            fail = false;
            throw StateError('injected');
          }
        },
      );
      await expectLater(
        repository.registerIdentity(command()),
        throwsStateError,
      );
      expect(await repository.readRevision(), 0);
      expect(await repository.resolveAlias(command().alias), isNull);
      expect((await repository.registerIdentity(command())).revision, 1);
      await repository.close();
    });
  }

  test('commit followed by lost response survives reopen and retry', () async {
    var repository = await open(
      fault: (point) async {
        if (point == PlaybackFaultPoint.afterCommit) {
          throw StateError('response lost');
        }
      },
    );
    await expectLater(repository.registerIdentity(command()), throwsStateError);
    expect(await repository.readRevision(), 1);
    await repository.close();
    repository = await open();
    expect((await repository.registerIdentity(command())).revision, 1);
    await repository.close();
  });

  test('concurrent retries are serialized', () async {
    final repository = await open();
    final results = await Future.wait(
      List.generate(12, (_) => repository.registerIdentity(command())),
    );
    expect(results.every((result) => result.revision == 1), isTrue);
    expect(await repository.readRevision(), 1);
    await repository.close();
    await expectLater(repository.registerIdentity(command()), throwsStateError);
  });
}
