import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/ui/widgets/media/app_media_items_view.dart';

void main() {
  testWidgets(
    'desktop row supports keyboard focus and leaves previews unchanged',
    (tester) async {
      var plays = 0;
      final item = MediaItem.fromJson({
        'id': 'song',
        'title': 'Full list song',
        'durationSeconds': 180,
        'variants': [],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppMediaListTile(
                  item: item,
                  expandedDesktopRow: true,
                  onTap: () => plays++,
                ),
                AppMediaListTile(
                  item: item.copyWith(title: 'Home preview'),
                  carded: true,
                  scale: 1.3,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('3:00'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.play_arrow_rounded).hitTestable(),
        findsNWidgets(2),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(plays, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );
  for (final width in [1200.0, 360.0]) {
    testWidgets(
      'expanded desktop song row fits $width and preserves click actions',
      (tester) async {
        tester.view.physicalSize = Size(width, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final item = MediaItem.fromJson({
          'id': 'song',
          'title': 'A long song title',
          'subtitle': 'Artist name',
          'durationSeconds': 180,
          'variants': [],
        });
        var plays = 0;
        var menus = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppMediaListTile(
                item: item,
                expandedDesktopRow: true,
                carded: true,
                onTap: () => plays++,
                onLongPress: () => menus++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('3:00'), findsOneWidget);
        expect(find.text('Artist name'), findsOneWidget);
        expect(
          find.byIcon(Icons.play_arrow_rounded).hitTestable(),
          findsNothing,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(0, 0));
        await mouse.moveTo(tester.getCenter(find.text('A long song title')));
        await tester.pumpAndSettle();
        expect(
          find.byIcon(Icons.play_arrow_rounded).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        expect(plays, 1);
        await tester.tap(
          find.text('A long song title'),
          buttons: kSecondaryMouseButton,
        );
        expect(menus, 1);
        expect(plays, 1);
        expect(tester.takeException(), isNull);
        await mouse.removePointer();
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
  testWidgets(
    'expanded row selection keeps its checkbox action',
    (tester) async {
      var selections = 0;
      final item = MediaItem.fromJson({
        'id': 'song',
        'title': 'Track',
        'variants': [],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppMediaActionListTile(
              item: item,
              expandedDesktopRow: true,
              selectionMode: true,
              onTap: () => selections++,
              onLongPress: () {},
              onToggleSelection: () => selections++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Checkbox));
      expect(selections, 1);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );
  testWidgets('expanded video action row keeps card background and callbacks', (
    tester,
  ) async {
    final item = MediaItem.fromJson({
      'id': 'v',
      'title': 'Episode',
      'source': 'local',
      'origin': 'device',
      'variants': [],
    });
    var taps = 0;
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppMediaActionListTile(
            item: item,
            videoStyle: true,
            carded: true,
            onTap: () => taps++,
            onLongPress: () => holds++,
          ),
        ),
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(AppMediaActionListTile)),
    ).colorScheme;
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                scheme.surfaceContainer.withValues(alpha: 0.78) &&
            widget.padding ==
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Episode'));
    await tester.longPress(find.text('Episode'));
    expect(taps, 1);
    expect(holds, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Home list uses separate library cards and preserves actions', (
    tester,
  ) async {
    final items = List.generate(
      2,
      (i) => MediaItem.fromJson({
        'id': '$i',
        'title': 'Track $i',
        'source': 'local',
        'origin': 'device',
        'variants': [],
      }),
    );
    int? tapped;
    int? held;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppMediaItemsList(
            items: items,
            gridView: false,
            compactListCard: true,
            onTap: (_, i) => tapped = i,
            onLongPress: (_, i) => held = i,
          ),
        ),
      ),
    );
    expect(find.byType(Card), findsNWidgets(2));
    for (final card in tester.widgetList<Card>(find.byType(Card))) {
      expect(card.color, isNot(Colors.transparent));
    }
    final first = tester.getRect(find.byType(Card).first);
    final second = tester.getRect(find.byType(Card).last);
    expect(second.top - first.bottom, greaterThanOrEqualTo(8));
    await tester.tap(find.text('Track 1'));
    expect(tapped, 1);
    await tester.longPress(find.text('Track 0'));
    expect(held, 0);
    tapped = null;
    held = null;
    await tester.tap(find.text('Track 1'), buttons: kSecondaryMouseButton);
    expect(held, 1);
    expect(tapped, isNull);
    expect(tester.takeException(), isNull);
  });
}
