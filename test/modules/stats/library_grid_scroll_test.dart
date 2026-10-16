import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/ui/widgets/media/app_media_items_view.dart';

void main() {
  for (final video in [false, true]) {
    testWidgets(
      '${video ? 'video' : 'audio'} sliver grid scrolls with library',
      (tester) async {
        final controller = ScrollController();
        final items = List.generate(
          60,
          (i) => MediaItem.fromJson({
            'id': 'item-$i',
            'title': 'Item $i',
            'source': 'local',
            'origin': 'device',
            'variants': [],
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrimaryScrollController(
                controller: controller,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                          AppMediaItemsSliver(
                            items: items,
                            gridView: true,
                            videoStyle: video,
                            onTap: (_, _) {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.drag(find.text('Item 0'), const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(controller.positions, hasLength(1));
        expect(controller.offset, greaterThan(100));
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
        await tester.pumpAndSettle();
        expect(controller.offset, lessThan(100));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
