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
    expect(find.byType(Card), findsNothing);
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
  for (final reduced in [false, true]) {
    testWidgets(
      'startup fits large text and respects reduced motion: $reduced',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                disableAnimations: reduced,
                textScaler: const TextScaler.linear(1.6),
              ),
              child: child!,
            ),
            home: StorageStartupPage(
              title: 'Preparando tus datos',
              stage: 'Verificando biblioteca e historial',
              failed: false,
              retryLabel: 'Reintentar',
              onRetry: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        final scale = tester
            .widget<ScaleTransition>(find.byType(ScaleTransition).first)
            .scale
            .value;
        expect(scale, reduced ? equals(1) : greaterThan(1));
        expect(find.byType(Card), findsNothing);
        expect(
          find.byType(LinearProgressIndicator),
          reduced ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
