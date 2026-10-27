import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:listenfy/app/controllers/media_actions_controller.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/models/media_item.dart';

class _Store extends GetxService implements LocalLibraryStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() => Get.reset());
  testWidgets(
    'desktop menu opens centered and closes with Escape',
    (tester) async {
      Get.put<LocalLibraryStore>(_Store());
      final controller = Get.put(MediaActionsController());
      var selected = false;
      final item = MediaItem.fromJson({
        'id': 'one',
        'title': 'Track',
        'source': 'local',
        'origin': 'device',
        'variants': [],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: () {
                    controller.showItemActions(
                      context,
                      item,
                      onStartMultiSelect: () => selected = true,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(MediaActionRow), findsWidgets);
      expect(find.byType(Dialog), findsOneWidget);
      final dialog = tester.getRect(find.byType(Dialog));
      expect(dialog.center.dx, closeTo(400, 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MediaActionRow), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('media_actions.multi_select'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(find.byType(MediaActionRow), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(790, 590));
      await tester.pumpAndSettle();
      expect(find.byType(MediaActionRow), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
