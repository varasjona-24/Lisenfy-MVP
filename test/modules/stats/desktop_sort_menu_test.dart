import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/ui/widgets/dialogs/sort_options_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets(
      'sort menu adapts on $platform and returns selection',
      (tester) async {
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showAdaptiveSortMenu<String>(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'title'),
                            child: const Text('Title'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Sort'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Sort'));
        await tester.pumpAndSettle();
        if (platform == TargetPlatform.macOS) {
          expect(find.byType(Dialog), findsOneWidget);
          final rect = tester.getRect(find.byType(Dialog));
          expect(rect.center.dy, closeTo(300, 1));
          expect(find.byType(BottomSheet), findsNothing);
        } else {
          expect(find.byType(BottomSheet), findsOneWidget);
        }
        await tester.tap(find.text('Title'));
        await tester.pumpAndSettle();
        expect(result, 'title');
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
