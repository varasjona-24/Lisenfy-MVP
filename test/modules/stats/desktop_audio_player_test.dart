import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/player/audio/controller/audio_player_controller.dart';
import 'package:listenfy/Modules/player/audio/view/desktop_audio_player_view.dart';
import 'package:listenfy/Modules/player/audio/view/queue_page.dart';
import 'package:listenfy/Modules/settings/controller/playback_settings_controller.dart';
import 'package:listenfy/Modules/playlists/data/playlist_store.dart';
import 'package:listenfy/Modules/playlists/domain/playlist.dart';
import 'package:listenfy/app/controllers/media_actions_controller.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/audio_service.dart';
import 'package:listenfy/app/services/spatial_audio_service.dart';

class _Audio extends AudioService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
  @override
  void onClose() {}
  @override
  Future<void> setVolume(double value) async {
    volume.value = value;
  }

  @override
  void applyUpdatedMediaItem(MediaItem item) {
    currentItem.value = item;
  }
}

class _Settings extends PlaybackSettingsController {
  double? savedVolume;
  @override
  // Intentionally skip persistence initialization in this UI test double.
  // ignore: must_call_super
  void onInit() {}
  @override
  void setDefaultVolume(double value) {
    savedVolume = value;
  }
}

class _Player extends AudioPlayerController {
  _Player(AudioService audio) : super(audioService: audio);
  int plays = 0;
  int? playedIndex;
  (int, int)? reordered;
  @override
  Future<void> playAt(int index, {bool recordSkip = true}) async {
    playedIndex = index;
    currentIndex.value = index;
  }

  @override
  Future<void> reorderQueueItem(int from, int to) async {
    reordered = (from, to);
    final item = queue.removeAt(from);
    queue.insert(to, item);
  }

  @override
  // Intentionally skip engine subscriptions in this UI test double.
  // ignore: must_call_super
  void onInit() {}
  @override
  void onClose() {}
  @override
  Future<void> togglePlay() async {
    plays++;
    audioService.isPlaying.toggle();
  }

  @override
  Future<void> toggleShuffle() async {
    isShuffling.toggle();
  }

  @override
  Future<void> cycleRepeatMode() async {
    repeatMode.value = RepeatMode.once;
  }
}

class _Library implements LocalLibraryStore {
  final values = <MediaItem>[];
  @override
  Future<List<MediaItem>> readAll() async => List.of(values);
  @override
  Future<void> upsert(MediaItem item) async {
    values.removeWhere((value) => value.id == item.id);
    values.add(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playlists implements PlaylistStore {
  Playlist value = const Playlist(
    id: 'list',
    name: 'Desktop list',
    itemIds: [],
    createdAt: 1,
    updatedAt: 1,
  );
  @override
  Future<List<Playlist>> readAll() async => [value];
  @override
  Future<void> upsert(Playlist playlist) async {
    value = playlist;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(
    () => Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    ),
  );
  tearDown(() => Get.reset());
  test('desktop selection never changes the Android or iOS player', () {
    expect(usesDesktopAudioPlayer(TargetPlatform.android), isFalse);
    expect(usesDesktopAudioPlayer(TargetPlatform.iOS), isFalse);
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(usesDesktopAudioPlayer(platform), isTrue);
    }
  });

  Future<(_Audio, _Player, _Settings)> mount(
    WidgetTester tester,
    Size size,
    Brightness brightness,
    double textScale, {
    bool queueScreen = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = Get.put<AudioService>(_Audio()) as _Audio;
    final settings =
        Get.put<PlaybackSettingsController>(_Settings()) as _Settings;
    Get.put(SpatialAudioService(audioService: audio));
    final player = Get.put<AudioPlayerController>(_Player(audio)) as _Player;
    final library = _Library();
    Get.put<LocalLibraryStore>(library);
    Get.put(MediaActionsController());
    final item = MediaItem.fromJson({
      'id': 'song',
      'title': 'A song with a longer title for the desktop player',
      'subtitle': 'Artist with a longer display name',
      'source': 'local',
      'variants': [],
    });
    library.values.add(item);
    audio.currentItem.value = item;
    player.queue.assignAll([item]);
    player.duration.value = const Duration(minutes: 4);
    player.position.value = const Duration(minutes: 1);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(
          brightness: brightness,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: brightness,
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: queueScreen
              ? const QueuePage()
              : Scaffold(
                  body: Obx(
                    () => DesktopAudioPlayerView(
                      controller: player,
                      item: player.queue.first,
                      style: CoverStyle.square,
                      onVisual: () {},
                      instrumental: false,
                      spatial8d: false,
                    ),
                  ),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (audio, player, settings);
  }

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(1440, 900),
      const Size(960, 540),
      const Size(360, 600),
    ]) {
      testWidgets('desktop layout $size $brightness with enlarged text', (
        tester,
      ) async {
        await mount(tester, size, brightness, 1.5);
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Favorite'), findsOneWidget);
        expect(find.byTooltip('More options'), findsNothing);
        expect(find.byTooltip('Add to a playlist'), findsOneWidget);
        expect(find.byIcon(Icons.surround_sound_rounded), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Repeat'),
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('desktop-player-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('desktop play, favorite and volume use existing actions', (
    tester,
  ) async {
    final (audio, player, settings) = await mount(
      tester,
      const Size(1440, 900),
      Brightness.dark,
      1,
    );
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(player.plays, 1);
    expect(audio.isPlaying.value, isTrue);
    await tester.tap(find.byTooltip('Favorite'));
    await tester.pumpAndSettle();
    expect(player.queue.first.isFavorite, isTrue);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    final volume = find.byType(Slider).last;
    final slider = tester.widget<Slider>(volume);
    slider.onChanged!(.4);
    slider.onChangeEnd!(.4);
    await tester.pump();
    expect(audio.volume.value, .4);
    expect(settings.savedVolume, 40);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'adding to a playlist preserves timestamps and prevents duplicates',
    (tester) async {
      await mount(tester, const Size(1440, 900), Brightness.dark, 1);
      final store = _Playlists();
      Get.put<PlaylistStore>(store);
      await tester.tap(find.byTooltip('Add to a playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desktop list'));
      await tester.pumpAndSettle();
      expect(store.value.itemIds, ['song']);
      final addedAt = store.value.itemAddedAt['song'];
      expect(addedAt, isNotNull);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add to a playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desktop list'));
      await tester.pumpAndSettle();
      expect(store.value.itemIds, ['song']);
      expect(store.value.itemAddedAt['song'], addedAt);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  List<MediaItem> queueItems() => List.generate(
    4,
    (index) => MediaItem.fromJson({
      'id': 'track-$index',
      'title': 'Track ${index + 1}',
      'subtitle': 'Artist ${index % 2}',
      'source': 'local',
      'durationSeconds': 180,
      'variants': [],
    }),
  );

  testWidgets(
    'Android retains the existing queue presentation',
    (tester) async {
      final (_, player, _) = await mount(
        tester,
        const Size(400, 800),
        Brightness.dark,
        1,
        queueScreen: true,
      );
      player.queue.assignAll(queueItems());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop-queue-list')), findsNothing);
      expect(find.byTooltip('Search queue'), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  for (final brightness in Brightness.values) {
    for (final size in [const Size(1440, 900), const Size(360, 600)]) {
      testWidgets(
        'desktop queue columns and resize $size $brightness',
        (tester) async {
          final (_, player, _) = await mount(
            tester,
            size,
            brightness,
            1.5,
            queueScreen: true,
          );
          player.queue.assignAll(queueItems());
          player.currentIndex.value = 1;
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('desktop-queue-list')),
            findsOneWidget,
          );
          expect(find.byType(ReorderableDragStartListener), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({TargetPlatform.macOS}),
      );
    }
  }

  testWidgets(
    'queue search keeps every row and navigates matches without playing',
    (tester) async {
      final (_, player, _) = await mount(
        tester,
        const Size(1440, 900),
        Brightness.dark,
        1,
        queueScreen: true,
      );
      player.queue.assignAll(queueItems());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search queue'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('desktop-queue-search')),
        'Artist 1',
      );
      await tester.pumpAndSettle();
      expect(find.text('Track 1'), findsOneWidget);
      expect(find.text('Track 4'), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(4));
      expect(find.text('1 of 2 matches'), findsOneWidget);
      expect(player.playedIndex, isNull);
      await tester.tap(find.byKey(const ValueKey('queue-match-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 matches'), findsOneWidget);
      expect(player.currentIndex.value, 0);
      expect(player.playedIndex, isNull);
      await tester.tap(find.byKey(const ValueKey('desktop-queue-search')));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 matches'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('queue-match-previous')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 matches'), findsOneWidget);
      expect(player.playedIndex, isNull);
      await tester.tap(find.text('Track 4'));
      await tester.pumpAndSettle();
      expect(player.playedIndex, 3);
      expect(find.byType(QueuePage), findsOneWidget);
      await tester.tap(find.byTooltip('Search queue'));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(4));
      final list = tester.widget<ReorderableListView>(
        find.byKey(const ValueKey('desktop-queue-list')),
      );
      list.onReorderItem!(0, 2);
      await tester.pumpAndSettle();
      expect(player.reordered, (0, 2));
      expect(player.queue[2].id, 'track-0');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'queue search scrolls to lazy distant rows and handles no matches',
    (tester) async {
      final (_, player, _) = await mount(
        tester,
        const Size(1440, 900),
        Brightness.dark,
        1,
        queueScreen: true,
      );
      final base = queueItems().first;
      player.queue.assignAll(
        List.generate(
          100,
          (index) => base.copyWith(
            id: 'long-$index',
            title: index == 95 ? 'Distant match' : 'Row $index',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search queue'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('desktop-queue-search')),
        'Distant',
      );
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('desktop-queue-list'));
      expect(tester.widget<ReorderableListView>(list).itemCount, 100);
      expect(find.text('Distant match'), findsOneWidget);
      final active = tester.getRect(
        find.byKey(const ValueKey('queue-active-match')),
      );
      expect(tester.getRect(list).overlaps(active), isTrue);
      expect(player.playedIndex, isNull);
      expect(player.currentIndex.value, 0);
      await tester.enterText(
        find.byKey(const ValueKey('desktop-queue-search')),
        'not found anywhere',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching tracks.'), findsOneWidget);
      expect(tester.widget<ReorderableListView>(list).itemCount, 100);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('queue-match-next')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('queue-match-previous')),
            )
            .onPressed,
        isNull,
      );
      expect(player.playedIndex, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'queue filter and repeated tracks render without duplicate keys',
    (tester) async {
      final (_, player, _) = await mount(
        tester,
        const Size(1440, 900),
        Brightness.dark,
        1,
        queueScreen: true,
      );
      final items = queueItems();
      player.queue.assignAll([...items, items.first]);
      player.currentIndex.value = 1;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Filter queue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Up next'));
      await tester.pumpAndSettle();
      expect(find.text('Track 2'), findsNothing);
      expect(find.text('Track 3'), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
