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
import 'package:listenfy/Modules/edit/view/edit_save_button.dart';
import 'package:listenfy/app/models/media_item.dart';

class _Editor extends GetxController implements EditEntityController {
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
