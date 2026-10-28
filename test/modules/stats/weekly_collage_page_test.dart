import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_summary.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_activity.dart';
import 'package:listenfy/Modules/stats/presentation/views/weekly_collage_page.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/Modules/stats/presentation/widgets/wrapped_artwork.dart';

class _SaveImagePicker extends FilePicker {
  _SaveImagePicker(this.result);
  final String? result;
  final called = Completer<void>();
  Uint8List? capturedBytes;
  String? suggestedName;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    capturedBytes = bytes;
    suggestedName = fileName;
    called.complete();
    return result;
  }
}

void main() {
  for (final cancelled in [false, true]) {
    testWidgets(
      'desktop save exports a PNG and handles cancellation: $cancelled',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final picker = _SaveImagePicker(
          cancelled ? null : '/chosen/weekly.png',
        );
        FilePicker.platform = picker;
        final item = MediaItem.fromJson({
          'id': 'song',
          'title': 'Weekly song',
          'variants': [],
        });
        await tester.pumpWidget(
          MaterialApp(
            home: WeeklyCollagePage(
              summaryLoader: () async => WeeklyCollageSummary(
                start: DateTime(2026, 10, 5),
                end: DateTime(2026, 10, 12),
                entries: [WeeklyCollageEntry(item, false)..plays = 4],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Share…'), findsOneWidget);
        final save = find.text('Save image…');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        for (
          var frame = 0;
          frame < 100 && !picker.called.isCompleted;
          frame++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(picker.called.isCompleted, isTrue);
        await tester.pumpAndSettle();
        expect(picker.capturedBytes!.take(8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]);
        expect(picker.suggestedName, 'listenfy-weekly-2026-10-05-1.png');
        expect(
          find.text('Image saved.'),
          cancelled ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
  for (final size in [const Size(1440, 900), const Size(900, 700)]) {
    testWidgets(
      'desktop weekly panels fit $size and load current local artwork',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final old = MediaItem.fromJson({
          'id': 'song',
          'title': 'Weekly song',
          'thumbnailLocalPath': '/missing-android-cover.jpg',
          'variants': [],
        });
        final current = old.copyWith(
          thumbnailLocalPath: File('assets/ui/vinyl.png').absolute.path,
        );
        final summary = WeeklyCollageSummary(
          start: DateTime(2026, 10, 5),
          end: DateTime(2026, 10, 12),
          entries: [
            WeeklyCollageEntry(old, false, artworkItem: current)..plays = 8,
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: WeeklyCollagePage(summaryLoader: () async => summary),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('A WEEK\nALL YOUR OWN'), findsOneWidget);
        final first = tester.getRect(
          find.byKey(const ValueKey('weekly-desktop-panel-0')),
        );
        final second = tester.getRect(
          find.byKey(const ValueKey('weekly-desktop-panel-1')),
        );
        final recap = tester.getRect(
          find.byKey(const ValueKey('weekly-desktop-recap')),
        );
        expect(recap.width, lessThanOrEqualTo(1240));
        expect(first.left, greaterThanOrEqualTo(recap.left));
        expect(second.right, lessThanOrEqualTo(recap.right));
        if (size.width >= 1200) {
          expect(first.top, closeTo(second.top, 1));
          expect(second.left, greaterThan(first.right));
        } else {
          expect(second.top, greaterThan(first.bottom));
        }
        final artwork = tester.widget<WrappedArtwork>(
          find.byType(WrappedArtwork).first,
        );
        expect(artwork.item.thumbnailLocalPath, current.thumbnailLocalPath);
        expect(
          tester.widget<Image>(find.byType(Image).first).image,
          isA<FileImage>(),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
  setUpAll(() {
    Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  testWidgets('calendar selects complete weeks and disables unavailable days', (
    tester,
  ) async {
    final requested = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyCollagePage(
          now: DateTime(2026, 10, 19),
          availableWeeksLoader: () async => [DateTime(2026, 9, 28)],
          weekLoader: (start) async {
            requested.add(start);
            return WeeklyCollageSummary(
              start: start,
              end: DateTime(start.year, start.month, start.day + 7),
              entries: [],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('weekly-calendar-button')));
    await tester.pumpAndSettle();
    final calendar = tester.widget<TableCalendar<void>>(
      find.byType(TableCalendar<void>),
    );
    expect(calendar.enabledDayPredicate!(DateTime(2026, 10, 3)), isTrue);
    expect(calendar.enabledDayPredicate!(DateTime(2026, 10, 7)), isFalse);
    expect(calendar.enabledDayPredicate!(DateTime(2026, 10, 19)), isFalse);
    expect(calendar.selectedDayPredicate!(DateTime(2026, 10, 18)), isTrue);
    calendar.onDaySelected!(DateTime(2026, 10, 3), DateTime(2026, 10, 3));
    await tester.pumpAndSettle();
    expect(requested.last, DateTime(2026, 9, 28));
    expect(find.byType(TableCalendar<void>), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('chooses an older complete week even when last week is empty', (
    tester,
  ) async {
    final latest = DateTime(2026, 10, 12);
    final older = DateTime(2026, 9, 28);
    final pending = Completer<WeeklyCollageSummary>();
    final requested = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyCollagePage(
          now: DateTime(2026, 10, 19),
          availableWeeksLoader: () async => [older, DateTime(2026, 10, 19)],
          weekLoader: (start) async {
            requested.add(start);
            if (start == older) return pending.future;
            return WeeklyCollageSummary(
              start: start,
              end: DateTime(start.year, start.month, start.day + 7),
              entries: [],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final finder = find.byKey(const ValueKey('weekly-week-selector'));
    final picker = tester.widget<DropdownButton<DateTime>>(finder);
    expect(picker.value, latest);
    expect(picker.items!.map((item) => item.value), [latest, older]);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sep 28, 2026 — Oct 4, 2026').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final entry = WeeklyCollageEntry(
      MediaItem.fromJson({
        'id': 'old',
        'title': 'Older week song',
        'variants': [],
      }),
      false,
    )..plays = 3;
    pending.complete(
      WeeklyCollageSummary(
        start: older,
        end: DateTime(2026, 10, 5),
        entries: [entry],
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, [latest, older]);
    expect(tester.widget<DropdownButton<DateTime>>(finder).value, older);
    expect(find.text('Older week song'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  for (final videoHeadliner in [false, true]) {
    testWidgets(
      'weekly collage shows exactly five songs; video headliner: $videoHeadliner',
      (tester) async {
        final entries = [
          if (videoHeadliner)
            WeeklyCollageEntry(
              MediaItem.fromJson({
                'id': 'video',
                'title': 'Video headliner',
                'variants': [],
              }),
              true,
            )..plays = 20,
          for (var i = 1; i <= 6; i++)
            WeeklyCollageEntry(
              MediaItem.fromJson({
                'id': 'audio-$i',
                'title': 'Ranked song $i',
                'variants': [],
              }),
              false,
            )..plays = 10 - i,
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: WeeklyCollagePage(
              summaryLoader: () async => WeeklyCollageSummary(
                start: DateTime(2026, 10, 5),
                end: DateTime(2026, 10, 12),
                entries: entries,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 1; i <= 5; i++) {
          expect(find.text('Ranked song $i'), findsOneWidget);
        }
        expect(find.text('Ranked song 6'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('complete collage fits narrow $brightness at text scale $scale', (
        tester,
      ) async {
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
      });
    }
  }
}
