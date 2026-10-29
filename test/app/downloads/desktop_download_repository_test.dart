import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:listenfy/app/data/downloads/desktop_download_engine.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/data/network/dio_client.dart';
import 'package:listenfy/app/data/repo/media_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

class _Library implements LocalLibraryStore {
  final items = <MediaItem>[];
  @override
  Future<List<MediaItem>> readAll() async => items.toList();
  @override
  Future<void> upsert(MediaItem item) async {
    items.removeWhere((old) => old.id == item.id);
    items.add(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoBackend implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected backend call: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late _Library library;
  late MediaRepository repo;
  var downloads = 0;
  setUp(() async {
    Get.testMode = true;
    dir = await Directory.systemTemp.createTemp('listenfy-repository-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
    library = _Library();
    Get.put<LocalLibraryStore>(library);
    Get.put<DioClient>(_NoBackend());
    downloads = 0;
    repo = MediaRepository(
      desktopEngine: DesktopDownloadEngine(
        ytDlp: 'yt',
        ffmpeg: 'ffmpeg',
        runtime: 'deno',
        command: (_, args, onLine) async {
          if (args.contains('--flat-playlist')) {
            return '{"id":"list","title":"My list","entries":[{"id":"one","url":"https://example.com/one","title":"One"},{"id":"two","url":"https://example.com/two","title":"Two"}]}';
          }
          if (args.contains('--dump-single-json')) {
            final id = args.last.endsWith('two') ? 'two' : 'one';
            return '{"id":"$id","extractor":"generic","title":"Track $id","uploader":"Artist","duration":2}';
          }
          downloads++;
          await File(args[args.indexOf('-o') + 1]).writeAsBytes([1, 2, 3]);
          onLine?.call('LISTENFY_PROGRESS:3:3');
          return '';
        },
      ),
    );
  });
  tearDown(() async {
    Get.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await dir.delete(recursive: true);
  });
  test(
    'desktop downloads persist metadata and reuse local variants without backend',
    () async {
      expect(
        await repo.requestAndFetchMedia(
          url: 'https://example.com/one',
          kind: 'audio',
          format: 'mp3',
        ),
        isTrue,
      );
      expect(library.items.single.title, 'Track one');
      expect(library.items.single.subtitle, 'Artist');
      expect(
        await File(library.items.single.variants.single.localPath!).length(),
        3,
      );
      expect(
        await repo.requestAndFetchMedia(
          url: 'https://example.com/one',
          kind: 'audio',
          format: 'mp3',
        ),
        isTrue,
      );
      expect(downloads, 1);
      expect(library.items, hasLength(1));
      await repo.requestAndFetchMedia(
        url: 'https://example.com/one',
        kind: 'video',
        format: 'mp4',
      );
      expect(library.items.single.variants, hasLength(2));
    },
  );
  test(
    'preserves edited titles and adds normal audio beside an instrumental variant',
    () async {
      await repo.requestAndFetchMedia(
        mediaId: 'existing-id',
        url: 'https://example.com/one',
        kind: 'audio',
        format: 'mp3',
      );
      final original = library.items.single;
      await library.upsert(
        original.copyWith(
          title: 'Edited title',
          variants: [
            MediaVariant.fromJson({
              ...original.variants.single.toJson(),
              'role': 'instrumental',
            }),
          ],
        ),
      );
      await repo.requestAndFetchMedia(
        mediaId: 'existing-id',
        url: 'https://example.com/one',
        kind: 'audio',
        format: 'mp3',
      );
      expect(library.items.single.title, 'Edited title');
      expect(library.items.single.publicId, 'existing-id');
      expect(library.items.single.variants, hasLength(2));
      expect(downloads, 2);
    },
  );
  test('playlist preview and selected import remain local', () async {
    final preview = await repo.resolvePlaylistFromUrl(
      url: 'https://example.com/list',
    );
    expect(preview!.entries, hasLength(2));
    final result = await repo.importPlaylistFromUrl(
      url: 'https://example.com/list',
      kind: 'audio',
      format: 'mp3',
      selectedUrls: ['https://example.com/two'],
    );
    expect(result!.imported, 1);
    expect(result.failed, 0);
    expect(library.items.single.title, 'Track two');
    expect(downloads, 1);
  });
}
