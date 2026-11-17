import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:table_calendar/table_calendar.dart';
import 'package:listenfy/Modules/player/audio/view/audio_player_page.dart';
import 'package:listenfy/Modules/player/audio/controller/audio_player_controller.dart'
    show CoverStyle;
import 'package:listenfy/Modules/sources/ui/source_collection_card.dart';
import 'package:listenfy/Modules/sources/ui/source_add_items_sheet.dart';
import 'package:listenfy/Modules/stats/application/weekly_collage_summary.dart';
import 'package:listenfy/Modules/stats/presentation/views/weekly_collage_page.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/ui/widgets/dialogs/sort_options_sheet.dart';

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
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void centered(WidgetTester tester, Size size) {
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    final rect = tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );
    expect(rect.center.dx, closeTo(size.width / 2, 1));
    expect(rect.center.dy, closeTo(size.height / 2, 1));
    expect(rect.top, greaterThanOrEqualTo(32));
    expect(rect.bottom, lessThanOrEqualTo(size.height - 32));
  }

  for (final size in [const Size(600, 520), const Size(1280, 900)]) {
    testWidgets(
      'desktop cover style chooses and closes at $size',
      (tester) async {
        viewport(tester, size);
        CoverStyle? selected;
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => openPlayerVisualStyleSheet(
                    currentStyle: CoverStyle.square,
                    options: CoverStyle.values,
                    onSelected: (style) => selected = style,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        centered(tester, size);
        final choice = find.byKey(const ValueKey('desktop-cover-style-vinyl'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(selected, CoverStyle.vinyl);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }

  testWidgets(
    'mobile cover style keeps its bottom sheet',
    (tester) async {
      viewport(tester, const Size(480, 900));
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () => openPlayerVisualStyleSheet(
                currentStyle: CoverStyle.square,
                options: CoverStyle.values,
                onSelected: (_) {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'desktop calendar is centered and selects whole weeks',
    (tester) async {
      const size = Size(1000, 800);
      viewport(tester, size);
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
      centered(tester, size);
      final calendar = tester.widget<TableCalendar<void>>(
        find.byType(TableCalendar<void>),
      );
      expect(calendar.enabledDayPredicate!(DateTime(2026, 10, 7)), isFalse);
      calendar.onDaySelected!(DateTime(2026, 10, 3), DateTime(2026, 10, 3));
      await tester.pumpAndSettle();
      expect(requested.last, DateTime(2026, 9, 28));
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'collection right click opens centered actions without opening the collection',
    (tester) async {
      const size = Size(1000, 700);
      viewport(tester, size);
      var opened = 0, edited = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SourceCollectionCard(
                  name: 'My collection',
                  itemCount: 2,
                  childCollectionCount: 1,
                  baseColor: Colors.green,
                  onOpen: () => opened++,
                  onEdit: () => edited++,
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byType(SourceCollectionCard),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      centered(tester, size);
      expect(opened, 0);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(edited, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'collection item picker fits desktop and preserves filtered selection',
    (tester) async {
      const size = Size(900, 650);
      viewport(tester, size);
      List<MediaItem> added = [];
      final items = [
        for (final title in ['Alpha', 'Beta'])
          MediaItem.fromJson({'id': title, 'title': title, 'variants': []}),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAdaptiveSortMenu<void>(
                  context: context,
                  maxWidth: 820,
                  isScrollControlled: true,
                  builder: (_) => SourceAddItemsSheet(
                    items: items,
                    keyForItem: (item) => item.id,
                    onAdd: (selected) async {
                      added = selected;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      centered(tester, size);
      await tester.enterText(find.byType(TextField), 'Beta');
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsNothing);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(added.map((item) => item.id), ['Beta']);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
