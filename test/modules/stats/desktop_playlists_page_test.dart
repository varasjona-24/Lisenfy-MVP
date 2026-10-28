import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/Home/Controller/home_controller.dart';
import 'package:listenfy/Modules/playlists/controller/playlists_controller.dart';
import 'package:listenfy/Modules/playlists/domain/playlist.dart';
import 'package:listenfy/Modules/playlists/view/playlists_page.dart';
import 'package:listenfy/app/models/media_item.dart';

class _Home extends GetxController implements HomeController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playlists extends GetxController implements PlaylistsController {
  @override
  final playlists = List.generate(
    6,
    (index) => Playlist(
      id: '$index',
      name: 'Playlist with a descriptive name $index',
      itemIds: const ['song'],
      createdAt: 0,
      updatedAt: 0,
    ),
  ).obs;
  @override
  final isLoading = false.obs;
  @override
  List<MediaItem> resolvePlaylistItems(Playlist playlist) => [
    MediaItem.fromJson({'id': 'song', 'title': 'Song', 'variants': []}),
  ];
  @override
  Future<void> load() async {}
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
  for (final size in [
    const Size(1440, 900),
    const Size(900, 700),
    const Size(600, 800),
  ]) {
    testWidgets(
      'desktop playlist library fits $size and opens existing actions on right click',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Get.put<HomeController>(_Home());
        Get.put<PlaylistsController>(_Playlists());
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const PlaylistsPage(),
          ),
        );
        await tester.pumpAndSettle();
        // The same song belongs to six playlists, but the total is unique.
        expect(find.text('6 lists · 1 songs'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(
          delegate.crossAxisCount,
          size.width >= 1200
              ? 4
              : size.width >= 800
              ? 2
              : 1,
        );
        expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
        expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
        final target = find.text('Playlist with a descriptive name 1');
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
}
