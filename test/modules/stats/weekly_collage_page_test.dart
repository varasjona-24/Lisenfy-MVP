import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_summary.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_activity.dart';
import 'package:listenfy/Modules/stats/presentation/views/weekly_collage_page.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  setUpAll(() {
    Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'complete collage fits narrow $brightness at text scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final entries = List.generate(4, (i) {
            final entry = WeeklyCollageEntry(
              MediaItem.fromJson({
                'id': '$i',
                'title': 'A song with a long title $i',
                'subtitle': 'Artist name',
                'variants': [],
              }),
              i == 3,
            );
            entry.plays = 5 - i;
            return entry;
          });
          final summary = WeeklyCollageSummary(
            start: DateTime(2026, 10, 5),
            end: DateTime(2026, 10, 12),
            entries: entries,
          );
          final activity = WeeklyCollageActivity(
            List.filled(7, 600000),
            List.filled(7, 60000),
            {'asiatico': 600000, 'europeo': 30000},
            2100000,
            true,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.green,
                  brightness: brightness,
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: WeeklyCollagePage(
                summaryLoader: () async => summary,
                activity: activity,
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Each export page owns a boundary, rather than capturing one tall image.
          expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byWidgetPredicate(
                (widget) => widget is RepaintBoundary && widget.key is GlobalKey,
              ),
            ),
            findsNWidgets(2),
          );
          expect(find.text('Your week’s headliner'), findsOneWidget);
          expect(find.text('Your daily rhythm · minutes'), findsOneWidget);
          expect(find.text('Most-listened regions'), findsOneWidget);
          expect(find.text('Asian · 10 min'), findsOneWidget);
          expect(find.text('European · <1 min'), findsOneWidget);
          expect(find.text('Your week in video'), findsOneWidget);
          expect(find.text('of active viewing'), findsOneWidget);
          expect(
            find.text(
              'You closed Sunday with 11 min of playback: 14.3% of your total weekly activity.',
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (w) => w is AspectRatio && w.aspectRatio == 16 / 9,
            ),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -1500),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
