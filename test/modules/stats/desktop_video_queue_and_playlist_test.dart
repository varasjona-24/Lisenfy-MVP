import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/player/Video/controller/video_player_controller.dart';
import 'package:listenfy/Modules/player/Video/view/video_queue_page.dart';
import 'package:listenfy/Modules/playlists/controller/playlists_controller.dart';
import 'package:listenfy/Modules/playlists/domain/playlist.dart';
import 'package:listenfy/Modules/playlists/view/playlist_detail_page.dart';
import 'package:listenfy/Modules/playlists/view/widgets/playlist_song_picker_sheet.dart';
import 'package:listenfy/app/controllers/media_actions_controller.dart';
import 'package:listenfy/app/models/media_item.dart';

MediaItem media(String id, String title) => MediaItem.fromJson({
  'id': id,
  'publicId': id,
  'title': title,
  'subtitle': 'Artist',
  'variants': [],
});

class _Video extends GetxController implements VideoPlayerController {
  @override
  final queue = <MediaItem>[].obs;
  @override
  final currentIndex = 0.obs;
  @override
  final isQueueOpen = false.obs;
  int? played;
  (int, int)? reordered;
  @override
  Future<void> playAt(int index, {bool recordSkip = true}) async {
    played = index;
    currentIndex.value = index;
  }

  @override
  Future<void> reorderQueue(int from, int to) async {
    reordered = (from, to);
    if (to > from) to--;
    final item = queue.removeAt(from);
    queue.insert(to, item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playlists extends GetxController implements PlaylistsController {
  @override
  final playlists = <Playlist>[
    const Playlist(
      id: 'list',
      name: 'My list',
      itemIds: ['existing'],
      createdAt: 0,
      updatedAt: 0,
    ),
  ].obs;
  List<MediaItem> added = [];
  @override
  Playlist? getPlaylistById(String id) => playlists.first;
  @override
  List<MediaItem> resolvePlaylistItems(Playlist playlist) => [];
  @override
  List<MediaItem> get libraryAudio => [
    media('existing', 'Already in playlist'),
    media('new-one', 'First new song'),
    media('new-two', 'Second new song'),
  ];
  @override
  Future<void> load() async {}
  @override
  Future<void> addItemsToPlaylist(String id, List<MediaItem> items) async {
    added = items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Actions extends GetxController implements MediaActionsController {
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
  setUp(() {
    Get.testMode = true;
  });
  tearDown(() => Get.reset());
  Future<void> mount(
    WidgetTester tester,
    Widget page,
    Size size, {
    double textScale = 1.3,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(1440, 900),
    const Size(900, 700),
    const Size(600, 800),
  ]) {
    testWidgets(
      'desktop video queue layout, duplicates, playback and reorder at $size',
      (tester) async {
        final controller = _Video();
        final first = media('one', 'First video');
        controller.queue.assignAll([
          first,
          media('two', 'Second video'),
          first,
        ]);
        Get.put<VideoPlayerController>(controller);
        await mount(tester, const VideoQueuePage(), size);
        final panel = tester.getRect(
          find.byKey(const ValueKey('desktop-video-queue-overview')),
        );
        final list = tester.getRect(
          find.byKey(const ValueKey('desktop-video-queue-list')),
        );
        if (size.width >= 1200) {
          expect(panel.right, lessThan(list.left));
        } else {
          expect(panel.bottom, lessThan(list.top));
        }
        await tester.tap(find.text('Second video'));
        await tester.pumpAndSettle();
        expect(controller.played, 1);
        expect(find.byType(VideoQueuePage), findsOneWidget);
        final reorderable = tester.widget<ReorderableListView>(
          find.byKey(const ValueKey('desktop-video-queue-list')),
        );
        reorderable.onReorderItem!(0, 2);
        await tester.pumpAndSettle();
        expect(controller.reordered, (0, 3));
        expect(controller.queue.first.title, 'Second video');
        expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets(
      'playlist picker filters existing songs and preserves selection across searches on $platform',
      (tester) async {
        final controller =
            Get.put<PlaylistsController>(_Playlists()) as _Playlists;
        Get.put<MediaActionsController>(_Actions());
        await mount(
          tester,
          PlaylistDetailPage.custom(playlistId: 'list'),
          platform == TargetPlatform.macOS
              ? const Size(1440, 900)
              : const Size(390, 844),
          textScale: platform == TargetPlatform.android ? 1 : 1.3,
        );
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        final picker = find.byType(PlaylistSongPickerSheet);
        expect(picker, findsOneWidget);
        expect(find.text('Already in playlist'), findsNothing);
        if (platform == TargetPlatform.macOS) {
          expect(
            tester.getRect(find.byType(Dialog)).center,
            const Offset(720, 450),
          );
        } else {
          expect(find.byType(Dialog), findsNothing);
        }
        await tester.tap(find.text('First new song'));
        await tester.pumpAndSettle();
        final search = find.descendant(
          of: picker,
          matching: find.byType(TextField),
        );
        await tester.enterText(search, 'Second');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Second new song'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: picker, matching: find.byType(FilledButton)),
        );
        await tester.pumpAndSettle();
        expect(
          controller.added.map((item) => item.id),
          containsAll(['new-one', 'new-two']),
        );
        expect(controller.added, hasLength(2));
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
