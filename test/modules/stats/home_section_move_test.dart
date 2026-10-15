import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/Home/domain/home_layout_models.dart';
import 'package:listenfy/Modules/Home/view/widgets/home_section_move_surface.dart';

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
  test('visible slots move without erasing hidden sections or targets', () {
    const hidden = HomeCustomSection(
      id: 'hidden',
      kind: HomeCustomSectionKind.artist,
      targetId: 'artist-1',
      title: 'Hidden',
      enabled: false,
    );
    const playlist = HomeCustomSection(
      id: 'playlist',
      kind: HomeCustomSectionKind.playlist,
      targetId: 'list-1',
      title: 'My playlist',
      layout: HomeCustomSectionLayout.list,
    );
    final input = <Object>[
      HomeWidgetId.favorites,
      hidden,
      HomeWidgetId.latestDownloads,
      playlist,
    ];
    final output = reorderHomeSectionSlots(input, [
      'custom:playlist',
      'widget:latestDownloads',
      'widget:favorites',
    ]);
    expect(output, [
      playlist,
      hidden,
      HomeWidgetId.latestDownloads,
      HomeWidgetId.favorites,
    ]);
    expect(input.first, HomeWidgetId.favorites);
    expect((output[1] as HomeCustomSection).enabled, isFalse);
    expect((output.first as HomeCustomSection).targetId, 'list-1');
    final custom = homeCustomSectionsInEditorOrder(output);
    expect(
      homeEditorEntries(
        output.whereType<HomeWidgetId>().toList(),
        custom,
      ).map(homeSectionOrderKey),
      output.map(homeSectionOrderKey),
    );
  });
  test('stale requests preserve new sections and reject duplicate ids', () {
    expect(
      reorderHomeSectionSlots(
        [
          HomeWidgetId.favorites,
          HomeWidgetId.featured,
          HomeWidgetId.latestDownloads,
        ],
        ['widget:latestDownloads', 'custom:removed', 'widget:favorites'],
      ),
      [
        HomeWidgetId.latestDownloads,
        HomeWidgetId.featured,
        HomeWidgetId.favorites,
      ],
    );
    expect(
      () => reorderHomeSectionSlots([], ['same', 'same']),
      throwsArgumentError,
    );
  });

  for (final save in [false, true]) {
    testWidgets(
      'real sections move inline; ${save ? 'Done saves' : 'Cancel restores'}',
      (tester) async {
        var plays = 0;
        List<String>? committed;
        await tester.pumpWidget(
          _home(onPlay: () => plays++, onCommit: (ids) => committed = ids),
        );
        await tester.pumpAndSettle();
        await tester.longPress(find.text('Section a'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('Real cover a'), findsOneWidget);
        expect(find.text('Real cover b'), findsOneWidget);
        await tester.tap(find.text('Play a'), warnIfMissed: false);
        expect(plays, 0);
        expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
        await _dragFirstDown(tester);
        expect(
          tester.getTopLeft(find.text('Real cover b')).dy,
          lessThan(tester.getTopLeft(find.text('Real cover a')).dy),
        );
        expect(committed, isNull);
        await tester.tap(find.text(save ? 'Done' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(committed, save ? equals(['b', 'a', 'c']) : isNull);
        if (!save) {
          expect(
            tester.getTopLeft(find.text('Real cover a')).dy,
            lessThan(tester.getTopLeft(find.text('Real cover b')).dy),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('dragging the actual section heading reorders the real content', (
    tester,
  ) async {
    await tester.pumpWidget(_home());
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Section a'));
    await tester.pumpAndSettle();
    await _dragFirstDown(tester);
    expect(
      tester.getTopLeft(find.text('Real cover b')).dy,
      lessThan(tester.getTopLeft(find.text('Real cover a')).dy),
    );
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets('real blocks respect reduced motion: $reduced', (tester) async {
      await tester.pumpWidget(_home(reduced: reduced));
      await tester.pump();
      await tester.longPress(find.text('Section a'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 95));
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byKey(const ValueKey('a')),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(
        transform.transform.entry(0, 1).abs(),
        reduced ? equals(0) : greaterThan(0),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Back cancels movement without saving or leaving the Home', (
    tester,
  ) async {
    var commits = 0;
    await tester.pumpWidget(_home(onCommit: (_) => commits++));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Section a'));
    await tester.pumpAndSettle();
    await _dragFirstDown(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(commits, 0);
    expect(find.text('Done'), findsNothing);
    expect(find.text('Real cover a'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Real cover a')).dy,
      lessThan(tester.getTopLeft(find.text('Real cover b')).dy),
    );
  });
}

Future<void> _dragFirstDown(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  final target = tester.getCenter(find.byKey(const ValueKey('home-drag-b')));
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(const ValueKey('home-drag-a'))),
  );
  await gesture.moveBy(const Offset(0, 20));
  await tester.pump();
  final start = tester.getCenter(find.byKey(const ValueKey('home-drag-a')));
  for (var step = 1; step <= 20; step++) {
    await gesture.moveTo(
      Offset(start.dx, start.dy + (target.dy - 20 - start.dy) * step / 20),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pumpAndSettle();
}

Widget _home({
  VoidCallback? onPlay,
  ValueChanged<List<String>>? onCommit,
  bool reduced = true,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: CustomScrollView(
        slivers: [
          HomeSectionMoveSurface(
            onCommit: onCommit ?? (_) {},
            sections: [
              for (final id in ['a', 'b', 'c'])
                HomeMoveSection(
                  id: id,
                  title: 'Section $id',
                  child: Builder(
                    builder: (context) => Column(
                      children: [
                        GestureDetector(
                          onLongPress: HomeMoveScope.maybeOf(context)?.start,
                          child: SizedBox(
                            height: 48,
                            child: Center(child: Text('Section $id')),
                          ),
                        ),
                        SizedBox(
                          height: 100,
                          child: ColoredBox(
                            color: Colors.blueGrey,
                            child: Center(child: Text('Real cover $id')),
                          ),
                        ),
                        TextButton(onPressed: onPlay, child: Text('Play $id')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  ),
);
