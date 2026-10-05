import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/services/sqlite_engine_history_factory.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'composition shares canonical identity across concurrent audio/video',
    () async {
      final dir = await Directory.systemTemp.createTemp('playback-factory-');
      final db = await PlaybackDatabaseOpener.openStaging(
        generation: 'test',
        supportDirectory: dir,
        temporaryDirectory: dir,
      );
      final repo = PlaybackRepository(db);
      try {
        final factory = SqliteEngineHistoryFactory(
          repository: repo,
          installationScope: 'installation',
        );
        final audio = factory.create(
          clock: () => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          monotonicClock: () => 0,
        );
        final video = factory.create(
          clock: () => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          monotonicClock: () => 0,
        );
        final item = MediaItem(
          id: 'local-id',
          publicId: 'public',
          title: 'Title',
          subtitle: 'Artist',
          source: MediaSource.local,
          variants: const [],
          origin: SourceOrigin.device,
        );
        audio.select(
          item,
          variant: const MediaVariant(
            kind: MediaVariantKind.audio,
            format: 'mp3',
            fileName: 'audio',
            createdAt: 0,
          ),
        );
        video.select(
          item,
          variant: const MediaVariant(
            kind: MediaVariantKind.video,
            format: 'mp4',
            fileName: 'video',
            createdAt: 0,
          ),
        );
        for (final recorder in [audio, video]) {
          recorder.update(
            position: Duration.zero,
            duration: const Duration(seconds: 100),
            playing: true,
          );
        }
        await Future.wait([audio.flush(), video.flush()]);
        final rows = await db
            .customSelect(
              'SELECT media_id,mode,context FROM playback_session ORDER BY mode',
            )
            .get();
        expect(rows, hasLength(2));
        expect(rows.first.data['media_id'], rows.last.data['media_id']);
        expect(rows.map((row) => row.data['mode']).toList(), [
          'audio',
          'video',
        ]);
        expect(rows.every((row) => row.data['context'] == 'unknown'), isTrue);
        expect(
          (await db
                  .customSelect('SELECT count(*) AS n FROM media_identity')
                  .getSingle())
              .read<int>('n'),
          1,
        );
      } finally {
        await repo.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
