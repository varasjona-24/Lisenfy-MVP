import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/ui/widgets/motion/app_motion.dart';

void main() {
  testWidgets('reduced motion renders entrance without scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppMotionEntrance(child: Text('Content')),
        ),
      ),
    );
    expect(find.text('Content'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });
  testWidgets('outgoing controls cannot receive taps', (tester) async {
    var taps = 0;
    Widget build(bool visible) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: AppMotionSwap(
            child: visible
                ? TextButton(
                    key: const ValueKey('button'),
                    onPressed: () => taps++,
                    child: const Text('Old control'),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpWidget(build(true));
    await tester.pumpWidget(build(false));
    await tester.tap(find.text('Old control'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pumpAndSettle();
    expect(find.text('Old control'), findsNothing);
  });
}
