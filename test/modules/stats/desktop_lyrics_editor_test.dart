import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/player/Video/view/lyrics_entry_page.dart';
import 'package:listenfy/app/models/media_item.dart';

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
    const Size(600, 800),
  ]) {
    testWidgets(
      'lyrics editor fits $size and preserves saved lyrics and translation',
      (tester) async {
        Get.testMode = true;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        LyricsEntryResult? saved;
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
                  saved = await Get.to<LyricsEntryResult>(
                    () => const LyricsEntryPage(),
                    arguments: const LyricsEntryArgs(
                      title: 'Song',
                      artist: 'Artist',
                      lyrics: 'Primera línea\nSegunda línea',
                      lyricsLanguage: 'es',
                      translations: {'en': 'First line\nSecond line'},
                      timedLyrics: {
                        'es': [
                          TimedLyricCue(text: 'Primera línea', startMs: 0),
                          TimedLyricCue(text: 'Segunda línea', startMs: 1200),
                        ],
                      },
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
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.save_rounded),
          ),
          desktop ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        final song = find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'Song',
        );
        final lyrics = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.controller?.text == 'Primera línea\nSegunda línea',
        );
        if (desktop && size.width >= 1080) {
          expect(
            tester.getTopLeft(lyrics).dx,
            greaterThan(tester.getTopRight(song).dx),
          );
        }
        await tester.ensureVisible(lyrics);
        await tester.enterText(
          lyrics,
          'Primera línea\nSegunda línea\nNueva línea',
        );
        await tester.pump();
        await tester.tap(find.byIcon(Icons.save_rounded));
        await tester.pumpAndSettle();
        expect(saved?.lyrics, 'Primera línea\nSegunda línea\nNueva línea');
        expect(saved?.translations['en'], 'First line\nSecond line');
        expect(saved?.lyricsLanguage, 'es');
        expect(saved?.timedLyrics['es']?.length, 2);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.android,
      }),
    );
  }
}
