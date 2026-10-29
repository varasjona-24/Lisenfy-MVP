import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/ui/widgets/layout/app_library_header.dart';

void main() {
  for (final width in [1200.0, 600.0, 360.0]) {
    testWidgets('compact library header wraps at $width with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var added = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppLibraryHeader(
                  title: 'Artists',
                  subtitle: 'Your music library',
                  metrics: const [
                    AppLibraryHeaderMetric(
                      icon: Icons.person_outline,
                      label: '24 artists',
                    ),
                    AppLibraryHeaderMetric(
                      icon: Icons.music_note,
                      label: '300 songs',
                    ),
                    AppLibraryHeaderMetric(
                      icon: Icons.groups,
                      label: '8 groups',
                    ),
                    AppLibraryHeaderMetric(
                      icon: Icons.public,
                      label: '10 countries',
                    ),
                  ],
                  action: FilledButton(
                    onPressed: () => added = true,
                    child: const Text('Add'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AppLibraryHeaderMetric), findsNWidgets(4));
      await tester.tap(find.text('Add'));
      expect(added, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
