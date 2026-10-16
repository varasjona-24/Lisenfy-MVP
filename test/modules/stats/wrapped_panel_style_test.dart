import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/stats/controller/listening_stats_controller.dart';
import 'package:listenfy/Modules/stats/domain/entities/listening_stats_entities.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/Modules/stats/presentation/views/listening_stats_page.dart';
import 'package:listenfy/Modules/stats/presentation/widgets/wrapped_panel_style.dart';
import 'package:listenfy/Modules/stats/presentation/widgets/wrapped_artwork.dart';

class _StatsController extends ListeningStatsController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

void main() {
  tearDown(() => Get.reset());
  for (final language in ['es', 'en']) {
    testWidgets('Wrapped retains all tabs on a phone in $language', (
      tester,
    ) async {
      Localization.load(
        Locale(language),
        translations: Translations(
          jsonDecode(
                File('assets/translations/$language.json').readAsStringSync(),
              )
              as Map<String, dynamic>,
        ),
      );
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _StatsController();
      controller.stats.value = ListeningStats.fromItems([
        MediaItem.fromJson({
          'id': 'song',
          'title': 'A song',
          'subtitle': 'An artist',
          'playCount': 12,
          'isFavorite': true,
          'fullListenCount': 9,
          'avgListenProgress': .8,
          'variants': [
            {
              'kind': 'audio',
              'format': 'mp3',
              'fileName': 'song.mp3',
              'localPath': '/song.mp3',
              'durationSeconds': 180,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            },
          ],
        }),
        MediaItem.fromJson({
          'id': 'another-song',
          'title': 'Another song',
          'subtitle': 'Another artist',
          'playCount': 3,
          'isFavorite': true,
          'variants': [
            {
              'kind': 'audio',
              'format': 'mp3',
              'fileName': 'another.mp3',
              'localPath': '/another.mp3',
            },
          ],
        }),
        MediaItem.fromJson({
          'id': 'video',
          'title': 'A video',
          'playCount': 4,
          'variants': [
            {
              'kind': 'video',
              'format': 'mp4',
              'fileName': 'video.mp4',
              'localPath': '/video.mp4',
              'durationSeconds': 180,
            },
          ],
        }),
      ]);
      controller.isLoading.value = false;
      Get.put<ListeningStatsController>(controller);
      await tester.pumpWidget(const GetMaterialApp(home: ListeningStatsPage()));
      await tester.pumpAndSettle();
      expect(find.byType(Tab), findsNWidgets(3));
      for (var index = 0; index < 3; index++) {
        await tester.tap(find.byType(Tab).at(index));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ListView), findsWidgets);
        for (final artwork in tester.widgetList<WrappedArtwork>(
          find.byType(WrappedArtwork),
        )) {
          expect(artwork.aspectRatio, index == 2 ? 16 / 9 : 1);
        }
      }
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('opaque readable panels over wallpaper in $brightness', (
      tester,
    ) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        ),
      );
      late BoxDecoration hero;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ColoredBox(
              color: Colors.pink,
              child: Builder(
                builder: (context) {
                  hero = wrappedPanelDecoration(context, highlighted: true);
                  return const StatsCard(child: Text('Chart content'));
                },
              ),
            ),
          ),
        ),
      );
      final panel =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(StatsCard),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(panel.color, theme.colorScheme.surfaceContainer);
      expect(panel.color!.a, 1);
      expect(panel.borderRadius, BorderRadius.circular(18));
      for (final color in hero.gradient!.colors) {
        expect(color.a, 1);
        final a = theme.colorScheme.onSurface.computeLuminance();
        final b = color.computeLuminance();
        final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    });
    testWidgets('headers and metrics wrap at phone width in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: Column(
                      children: const [
                        SectionHeader(
                          emoji: '📊',
                          title: 'A longer translated section title',
                          subtitle:
                              'A descriptive subtitle that must wrap safely over any wallpaper.',
                          gradient: [Colors.blue, Colors.green],
                        ),
                        FieldMetricTile(
                          data: FieldMetricData(
                            icon: Icons.music_note,
                            label: 'Listening time',
                            value: '120 hours',
                            caption: 'Your activity this period',
                          ),
                          accent: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    });
  }
}
