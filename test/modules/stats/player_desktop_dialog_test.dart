import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/ui/widgets/player/player_desktop_dialog.dart';

void main() {
  for (final reading in [false, true]) {
    for (final size in [const Size(1440, 900), const Size(600, 400)]) {
      testWidgets('player dialog fits $size, reading: $reading', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => PlayerDesktopDialog(
                      reading: reading,
                      child: reading
                          ? const Column(
                              children: [
                                Text('Song'),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text('Lyrics'),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(
                              height: 1200,
                              child: Text('Progress'),
                            ),
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
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      });
    }
  }
}
