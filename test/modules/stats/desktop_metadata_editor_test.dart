import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/artists/controller/artists_controller.dart';
import 'package:listenfy/Modules/edit/controller/edit_entity_controller.dart';
import 'package:listenfy/Modules/edit/view/edit_entity_page.dart';
import 'package:listenfy/Modules/edit/view/create_entity_page.dart';
import 'package:listenfy/Modules/edit/view/edit_save_button.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/Modules/playlists/domain/playlist.dart';

class _Editor extends GetxController implements EditEntityController {
  String? createdName;
  @override
  Future<bool> createPlaylist({
    required String name,
    String? localThumbPath,
  }) async {
    createdName = name;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Artists extends GetxController implements ArtistsController {
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
  for (final size in [const Size(1440, 900), const Size(600, 800)]) {
    testWidgets(
      'create playlist matches compact editor at $size and preserves creation',
      (tester) async {
        Get.testMode = true;
        final editor = _Editor();
        Get.put<EditEntityController>(editor);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        bool? created;
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: TextButton(
                onPressed: () async {
                  created = await Get.to<bool>(
                    () => const CreateEntityPage(),
                    arguments: const CreateEntityArgs.playlist(
                      storageId: 'new-list',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final desktop = defaultTargetPlatform == TargetPlatform.macOS;
        final panel = find.byKey(const ValueKey('playlist-create-panel'));
        expect(panel, desktop ? findsOneWidget : findsNothing);
        if (desktop) {
          final bounds = tester.getRect(panel);
          expect(bounds.width, lessThanOrEqualTo(900));
          expect(bounds.center.dx, closeTo(size.width / 2, 1));
        }
        final name = find.byType(TextField);
        await tester.ensureVisible(name);
        await tester.enterText(name, ' My new list ');
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pumpAndSettle();
        expect(editor.createdName, 'My new list');
        expect(created, isTrue);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.android,
      }),
    );
  }
  for (final size in [const Size(1440, 900), const Size(600, 800)]) {
    testWidgets(
      'playlist editor uses a compact panel at $size',
      (tester) async {
        Get.testMode = true;
        Get.put<EditEntityController>(_Editor());
        Get.put<ArtistsController>(_Artists());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const playlist = Playlist(
          id: 'playlist',
          name: 'My playlist',
          itemIds: [],
          createdAt: 0,
          updatedAt: 0,
        );
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: TextButton(
                onPressed: () => Get.to(
                  () => const EditEntityPage(),
                  arguments: const EditEntityArgs.playlist(playlist),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        final panel = tester.getRect(
          find.byKey(const ValueKey('playlist-editor-panel')),
        );
        final artwork = tester.getRect(
          find.byKey(const ValueKey('playlist-editor-cover')),
        );
        expect(panel.width, lessThanOrEqualTo(900));
        expect(panel.center.dx, closeTo(size.width / 2, 1));
        expect(artwork.width, 260);
        final name = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.controller?.text == playlist.name,
        );
        if (size.width > 1000) {
          expect(tester.getTopLeft(name).dx, greaterThan(artwork.right));
        } else {
          expect(tester.getTopLeft(name).dy, greaterThan(artwork.bottom));
        }
        await tester.ensureVisible(name);
        await tester.enterText(name, 'Updated playlist');
        await tester.pump();
        expect(find.text('Updated playlist'), findsOneWidget);
        expect(find.byType(EditSaveButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
  for (final size in [
    const Size(1440, 900),
    const Size(960, 600),
    const Size(600, 700),
  ]) {
    testWidgets(
      'metadata desktop layout fits $size with larger text',
      (tester) async {
        Get.testMode = true;
        Get.put<EditEntityController>(_Editor());
        Get.put<ArtistsController>(_Artists());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final item = MediaItem.fromJson({
          'id': 'track',
          'title': 'A song with a long title',
          'subtitle': 'Artist',
          'source': 'local',
          'origin': 'device',
          'variants': [
            {
              'kind': 'audio',
              'format': 'mp3',
              'fileName': 'track.mp3',
              'localPath': '/tmp/track.mp3',
            },
          ],
        });
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: TextButton(
                onPressed: () => Get.to(
                  () => const EditEntityPage(),
                  arguments: EditEntityArgs.media(item),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(find.byType(EditSaveButton), findsOneWidget);
        final desktop = defaultTargetPlatform == TargetPlatform.macOS;
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(EditSaveButton),
          ),
          desktop ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(ExpansionTile),
          desktop ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        if (desktop) {
          final extras = find.byType(ExpansionTile);
          await tester.ensureVisible(extras);
          await tester.tap(extras);
          await tester.pumpAndSettle();
          final first = tester.getRect(
            find.byKey(const ValueKey('desktop-extra-0')),
          );
          final second = tester.getRect(
            find.byKey(const ValueKey('desktop-extra-1')),
          );
          if (size.width >= 1200) {
            expect(first.top, closeTo(second.top, 1));
            expect(second.left, greaterThan(first.right));
          } else {
            expect(second.top, greaterThan(first.top));
          }
          expect(tester.takeException(), isNull);
        }
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.controller?.text == item.title,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Updated title');
        await tester.pump();
        expect(
          find.text('Updated title'),
          desktop ? findsNWidgets(2) : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.android,
      }),
    );
  }
}
