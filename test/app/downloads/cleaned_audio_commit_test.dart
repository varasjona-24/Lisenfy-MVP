import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/cleaned_audio_commit.dart';
import 'package:path/path.dart' as p;

class _Store implements LocalLibraryStore {
  final items = <MediaItem>[];
  int saves = 0;
  int? failAt;
  @override
  Future<List<MediaItem>> readAll() async => List.of(items);
  @override
  Future<void> upsert(MediaItem item) async {
    saves++;
    if (saves == failAt) throw StateError('Persistence failed');
    items.removeWhere((i) => i.id == item.id);
    items.add(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;
  late File original;
  late File cleaned;
  late _Store store;
  late MediaItem media;
  late MediaVariant variant;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('listenfy-replace-test-');
    original = await File(
      p.join(dir.path, 'original.mp3'),
    ).writeAsString('original audio');
    cleaned = await File(
      p.join(dir.path, 'clean.m4a'),
    ).writeAsString('validated clean audio');
    store = _Store();
    variant = MediaVariant(
      kind: MediaVariantKind.audio,
      format: 'm4a',
      localPath: cleaned.path,
      fileName: 'clean.m4a',
      createdAt: 1,
    );
    media = MediaItem(
      id: 'one',
      publicId: 'one',
      title: 'Song',
      subtitle: 'Artist',
      source: MediaSource.local,
      origin: SourceOrigin.device,
      variants: [
        MediaVariant(
          kind: MediaVariantKind.audio,
          format: 'mp3',
          localPath: original.path,
          fileName: 'original.mp3',
          createdAt: 1,
        ),
      ],
    );
    store.items.add(media);
  });
  tearDown(() => dir.delete(recursive: true));

  test(
    'replace saves new variant before deleting original and removes old reference',
    () async {
      final result = await CleanedAudioCommit(store).save(
        media: media,
        cleaned: variant,
        sourcePath: original.path,
        replaceOriginal: true,
      );
      expect(result.originalRetained, isFalse);
      expect(store.saves, 2);
      expect(result.item.variants.single.localPath, cleaned.path);
      expect(await original.exists(), isFalse);
      expect(await cleaned.exists(), isTrue);
    },
  );

  test('keep both leaves the original available', () async {
    final result = await CleanedAudioCommit(store).save(
      media: media,
      cleaned: variant,
      sourcePath: original.path,
      replaceOriginal: false,
    );
    expect(result.item.variants.length, 2);
    expect(await original.readAsString(), 'original audio');
  });

  for (final failure in [1, 2]) {
    test('save failure $failure never deletes the original', () async {
      store.failAt = failure;
      await expectLater(
        CleanedAudioCommit(store).save(
          media: media,
          cleaned: variant,
          sourcePath: original.path,
          replaceOriginal: true,
        ),
        throwsStateError,
      );
      expect(await original.readAsString(), 'original audio');
      expect(await cleaned.exists(), isTrue);
    });
  }

  test('shared files and files in playback are retained', () async {
    final other = media.copyWith(id: 'two');
    store.items.add(other);
    var result = await CleanedAudioCommit(store).save(
      media: media,
      cleaned: variant,
      sourcePath: original.path,
      replaceOriginal: true,
    );
    expect(result.originalRetained, isTrue);
    store.items.removeWhere((i) => i.id == 'two');
    result = await CleanedAudioCommit(store, isInUse: (_) => true).save(
      media: media,
      cleaned: variant,
      sourcePath: original.path,
      replaceOriginal: true,
    );
    expect(result.originalRetained, isTrue);
    expect(await original.exists(), isTrue);
  });

  test('invalid cleaned output cannot replace source', () async {
    await cleaned.delete();
    await expectLater(
      CleanedAudioCommit(store).save(
        media: media,
        cleaned: variant,
        sourcePath: original.path,
        replaceOriginal: true,
      ),
      throwsStateError,
    );
    expect(store.saves, 0);
    expect(await original.exists(), isTrue);
  });
}
