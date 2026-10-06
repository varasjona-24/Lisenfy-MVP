import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/ui/widgets/layout/storage_startup_page.dart';

void main() {
  testWidgets('startup shows progress and preserves retry action', (
    tester,
  ) async {
    var retries = 0;
    Future<void> show(bool failed) => tester.pumpWidget(
      MaterialApp(
        home: StorageStartupPage(
          title: 'Preparando datos',
          stage: 'Verificando',
          failed: failed,
          retryLabel: 'Reintentar',
          onRetry: () => retries++,
        ),
      ),
    );
    await show(false);
    expect(find.text('Listenfy'), findsOneWidget);
    expect(find.text('Verificando'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    await show(true);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
