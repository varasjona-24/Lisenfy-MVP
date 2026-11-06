import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart' as car;
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Translations;
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/Modules/artists/data/artist_store.dart';
import 'package:listenfy/Modules/playlists/data/playlist_store.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/app_audio_handler.dart';
import 'package:listenfy/app/services/audio_service.dart' as app;

class _Memory implements GetStorage {
  final values = <String, dynamic>{};
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected write');
}

class _Audio extends app.AudioService {
  List<MediaItem> played = [];
  int? index;
  int resumes = 0;
  bool loaded = false;
  final savedQueue = <MediaItem>[];
  @override
  bool get hasSourceLoaded => loaded;
  @override
  List<MediaItem> get queueItems => savedQueue;
  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> playQueueFromExternalRequest({
    required List<MediaItem> items,
    required int index,
  }) async {
    played = items;
    this.index = index;
  }

  @override
  Future<void> playQueueIndexFromExternalRequest(int index) async {
    this.index = index;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Memory memory;
  late _Audio audio;
  late AppAudioHandler handler;
  const prefix = 'listenfy:auto:';
  Map<String, dynamic> song(
    String id,
    String artist, {
    int? last,
    bool favorite = false,
    String kind = 'audio',
  }) => {
    'id': id,
    'publicId': 'public-$id',
    'title': id,
    'subtitle': artist,
    'isFavorite': favorite,
    'lastPlayedAt': last,
    'thumbnail': 'https://example.com/$id.jpg',
    'variants': [
      {
        'kind': kind,
        'format': 'mp3',
        'fileName': '$id.mp3',
        'localPath': '/media/$id.mp3',
      },
    ],
  };
  late Directory storageDirectory;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync(
      'listenfy-auto-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathChannel,
          (_) async => storageDirectory.path,
        );
    await GetStorage.init();
    Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    await storageDirectory.delete(recursive: true);
  });
  setUp(() {
    memory = _Memory();
    memory.values['local_library_items'] = [
      song('one', 'Alpha feat. Beta', last: 10, favorite: true),
      song('two', 'Beta', last: 20),
      song('three', 'Alpha'),
      song('video', 'Video Artist', kind: 'video', last: 30),
    ];
    memory.values['playlists'] = [
      {
        'id': 'mix',
        'name': 'My Mix',
        'itemIds': ['public-two', 'one', 'public-two', 'missing', 'video'],
        'createdAt': 1,
        'updatedAt': 2,
        'coverUrl': 'https://example.com/mix.jpg',
      },
      {
        'id': 'empty',
        'name': 'Empty',
        'itemIds': ['missing'],
        'createdAt': 1,
        'updatedAt': 2,
      },
      {
        'id': 'temporary',
        'name': 'Temporary',
        'itemIds': ['one'],
        'createdAt': 1,
        'updatedAt': 2,
        'expiresAt': 4102444800000,
      },
    ];
    memory.values['artist_profiles'] = [
      {
        'key': 'alpha',
        'displayName': 'Alpha',
        'thumbnail': 'https://example.com/alpha.jpg',
      },
    ];
    Get.put<LocalLibraryStore>(LocalLibraryStore(memory));
    Get.put<PlaylistStore>(PlaylistStore(memory));
    Get.put<ArtistStore>(ArtistStore(memory));
    audio = _Audio();
    handler = AppAudioHandler(audio);
  });
  tearDown(() => Get.reset());

  test('four top-level tabs with browse styles and resource icons', () async {
    final roots = await handler.getChildren(car.AudioService.browsableRootId);
    expect(roots.map((item) => item.id), [
      '${prefix}home',
      '${prefix}playlists',
      '${prefix}artists',
      '${prefix}songs',
    ]);
    expect(roots.every((item) => item.playable == false), isTrue);
    expect(
      roots.every((item) => item.artUri?.scheme == 'android.resource'),
      isTrue,
    );
    expect(roots[1].extras?[car.AndroidContentStyle.browsableHintKey], 2);
    expect(roots[2].extras?[car.AndroidContentStyle.browsableHintKey], 2);
    expect(await handler.getMediaItem(roots.first.id), roots.first);
  });

  test(
    'playlist grids expose covers, count playable unique audio and open tracks',
    () async {
      final lists = await handler.getChildren('${prefix}playlists');
      expect(lists, hasLength(1));
      expect(lists.single.artUri, Uri.parse('https://example.com/mix.jpg'));
      expect(lists.single.displaySubtitle, '2 tracks');
      expect(lists.single.playable, isFalse);
      expect(
        lists
            .single
            .extras?['android.media.browse.CONTENT_STYLE_SINGLE_ITEM_HINT'],
        2,
      );
      final songs = await handler.getChildren(lists.single.id);
      expect(songs.map((item) => item.title), ['two', 'one']);
      expect(songs.every((item) => item.playable == true), isTrue);
      await handler.playMediaItem(songs.last);
      expect(audio.played.map((item) => item.id), ['two', 'one']);
      expect(audio.index, 1);
      expect((await handler.getMediaItem(songs.last.id))?.title, 'one');
    },
  );

  test(
    'playlist cover fallback respects a deliberately cleared cover',
    () async {
      final list = Map<String, dynamic>.from(
        (memory.values['playlists'] as List).first as Map,
      );
      list.remove('coverUrl');
      memory.values['playlists'] = [list];
      expect(
        (await handler.getChildren('${prefix}playlists')).single.artUri,
        Uri.parse('https://example.com/two.jpg'),
      );
      list['coverCleared'] = true;
      expect(
        (await handler.getChildren('${prefix}playlists')).single.artUri?.scheme,
        'android.resource',
      );
    },
  );

  test('artist grids use profiles and include collaboration credits', () async {
    final artists = await handler.getChildren('${prefix}artists');
    expect(artists.map((item) => item.title), ['Alpha', 'Beta']);
    expect(artists.first.artUri, Uri.parse('https://example.com/alpha.jpg'));
    final songs = await handler.getChildren(artists.first.id);
    expect(songs.map((item) => item.title), ['one', 'three']);
    await handler.playMediaItem(songs.last);
    expect(audio.played.map((item) => item.id), ['one', 'three']);
    expect(audio.index, 1);
    expect((await handler.getMediaItem(artists.first.id))?.title, 'Alpha');
    (memory.values['artist_profiles'] as List).first['displayName'] = '';
    expect(
      (await handler.getChildren('${prefix}artists')).first.title,
      'Alpha',
    );
  });

  test('home groups recent audio, favorites, queue and resume', () async {
    audio.currentItem.value = MediaItem.fromJson(
      (memory.values['local_library_items'] as List).first
          as Map<String, dynamic>,
    );
    audio.loaded = true;
    final home = await handler.getChildren('${prefix}home');
    expect(home.take(3).map((item) => item.id), [
      '${prefix}recent',
      '${prefix}favorites',
      '${prefix}queue',
    ]);
    final resume = home.firstWhere((item) => item.id == '${prefix}resume');
    await handler.playMediaItem(resume);
    expect(audio.resumes, 1);
    final recent = await handler.getChildren(car.AudioService.recentRootId);
    expect(recent.map((item) => item.title), ['two', 'one']);
    expect(recent.every((item) => item.playable == true), isTrue);
    final favorites = await handler.getChildren('${prefix}favorites');
    await handler.playMediaItem(favorites.single);
    expect(audio.played.map((item) => item.id), ['one']);
  });

  test(
    'context IDs escape punctuation, ignore deleted tracks and malformed input',
    () async {
      memory.values['local_library_items'] = [
        song('id:with / accents á', 'Alpha'),
      ];
      final songs = await handler.getChildren('${prefix}songs');
      await handler.playMediaItem(songs.single);
      expect(audio.played.single.id, 'id:with / accents á');
      audio.played = [];
      memory.values['local_library_items'] = [];
      expect(await handler.getMediaItem(songs.single.id), isNull);
      await handler.playMediaItem(songs.single);
      await handler.playFromMediaId('${prefix}entry:%XX:bad');
      expect(audio.played, isEmpty);
    },
  );

  test(
    'pagination, search and legacy playlist playback remain supported',
    () async {
      final page = await handler.getChildren('${prefix}songs', {
        'android.media.browse.extra.PAGE': 1,
        'android.media.browse.extra.PAGE_SIZE': 2,
      });
      expect(page.map((item) => item.title), ['three']);
      expect(
        await handler.getChildren('${prefix}songs', {
          'android.media.browse.extra.PAGE': 99,
          'android.media.browse.extra.PAGE_SIZE': 2,
        }),
        isEmpty,
      );
      expect((await handler.search('Alpha')).map((item) => item.title), [
        'one',
        'three',
      ]);
      await handler.playFromMediaId('${prefix}playlist:mix');
      expect(audio.played.map((item) => item.id), ['two', 'one']);
      audio.savedQueue.add(MediaItem.fromJson(song('one', 'Alpha')));
      final queue = await handler.getChildren('${prefix}queue');
      await handler.playMediaItem(queue.single);
      expect(audio.index, 0);
    },
  );

  test(
    'recent recommendations hydrate metrics without opening a phone screen',
    () async {
      var loads = 0;
      Get.replace<LocalLibraryStore>(
        LocalLibraryStore(
          memory,
          metricsLoader: () async {
            loads++;
            return {
              'one': {'lastPlayedAt': 300},
              'two': {'lastPlayedAt': 100},
            };
          },
        ),
      );
      final recent = await handler.getChildren(car.AudioService.recentRootId);
      expect(loads, 1);
      expect(recent.map((item) => item.title), ['one', 'two']);
    },
  );

  test('unavailable stores expose navigable empty sections', () async {
    Get.reset();
    expect(await handler.getChildren('${prefix}playlists'), isEmpty);
    expect(await handler.getChildren('${prefix}artists'), isEmpty);
    expect(await handler.getChildren('${prefix}songs'), isEmpty);
    expect((await handler.getChildren('${prefix}home')).length, 3);
  });
}
