import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/Home/domain/home_layout_models.dart';

void main() {
  test('missing session widget is inserted after favorites', () {
    expect(
      normalizeVideoHomeOrder([
        HomeWidgetId.favorites,
        HomeWidgetId.latestDownloads,
      ]),
      [
        HomeWidgetId.favorites,
        HomeWidgetId.continueWatching,
        HomeWidgetId.latestDownloads,
      ],
    );
  });
  test('custom position survives normalization without duplicates', () {
    final order = [
      HomeWidgetId.continueWatching,
      HomeWidgetId.favorites,
      HomeWidgetId.continueWatching,
    ];
    expect(normalizeVideoHomeOrder(order), [
      HomeWidgetId.continueWatching,
      HomeWidgetId.favorites,
    ]);
  });
  test('only continue watching cannot be disabled', () {
    expect(HomeWidgetId.continueWatching.canDisable, isFalse);
    expect(HomeWidgetId.values.where((id) => !id.canDisable), [
      HomeWidgetId.continueWatching,
    ]);
  });
}
