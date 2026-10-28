import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/ui/widgets/media/app_media_items_view.dart';
import 'package:listenfy/app/ui/widgets/media/media_item_grid.dart';

List<MediaItem> songs() => List.generate(
  8,
  (index) => MediaItem.fromJson({
    'id': '$index',
    'title': 'A song with a long descriptive title $index',
    'subtitle': 'Artist $index',
    'variants': [],
  }),
);

void main() {
  for (final width in [1200.0, 700.0, 360.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'expanded song grid fits $width with text scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          int? played;
          int? menu;
          final items = songs();
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    AppMediaItemsSliver(
                      items: items,
                      gridView: true,
                      expandedDesktopRows: true,
                      hintBuilder: (_, _) => 'Recommendation',
                      coverOverlayBuilder: (_, _) => const Icon(Icons.favorite),
                      onTap: (_, index) => played = index,
                      onLongPress: (_, index) => menu = index,
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = tester.getRect(find.byType(MediaGridTile).first);
          expect(card.left, 96);
          expect(card.width, inInclusiveRange(160, 510));
          expect(card.height, 120 * scale);
          expect(
            tester
                .widget<MediaGridTile>(find.byType(MediaGridTile).first)
                .desktopSongTile,
            isTrue,
          );
          expect(find.byIcon(Icons.favorite), findsWidgets);
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(0, 0));
          await mouse.moveTo(card.center);
          await tester.pumpAndSettle();
          final play = find.byIcon(Icons.play_arrow_rounded).hitTestable();
          expect(play, findsOneWidget);
          await tester.tap(play);
          expect(played, 0);
          await tester.tap(
            find.text(items.first.title),
            buttons: kSecondaryMouseButton,
          );
          expect(menu, 0);
          expect(played, 0);
          expect(tester.takeException(), isNull);
          await mouse.removePointer();
        },
        variant: TargetPlatformVariant({TargetPlatform.macOS}),
      );
    }
  }
  testWidgets(
    'song grid preserves selection without triggering playback',
    (tester) async {
      int? selected;
      var plays = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                AppMediaItemsSliver(
                  items: songs(),
                  gridView: true,
                  expandedDesktopRows: true,
                  selectionMode: true,
                  selectedBuilder: (_, index) => index == 0,
                  onTap: (_, _) => plays++,
                  onSelectionTap: (_, index) => selected = index,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text(songs().first.title));
      expect(selected, 0);
      expect(plays, 0);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
