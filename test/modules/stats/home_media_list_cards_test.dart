import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/ui/widgets/media/app_media_items_view.dart';

void main() {
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
    expect(tester.takeException(), isNull);
  });
}
