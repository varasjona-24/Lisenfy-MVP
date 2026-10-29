import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/world_mode/presentation/widgets/world_globe_canvas.dart';
import 'package:listenfy/Modules/world_mode/presentation/widgets/world_map_canvas.dart';
import 'package:listenfy/Modules/world_mode/presentation/painters/world_globe_painter.dart';

void main() {
  testWidgets('mouse wheel zooms globe within its limits', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldGlobeCanvas(
            countries: const [],
            selectedCountryCode: null,
            onCountryTap: (_) {},
            showHint: false,
          ),
        ),
      ),
    );
    double zoom() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<WorldGlobePainter>()
        .single
        .zoom;
    final initial = zoom();
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(400, 300),
        scrollDelta: Offset(0, -100),
      ),
    );
    await tester.pump();
    expect(zoom(), greaterThan(initial));
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(400, 300),
        scrollDelta: Offset(0, 100),
      ),
    );
    await tester.pump();
    expect(zoom(), closeTo(initial, .001));
    expect(tester.takeException(), isNull);
  });
  testWidgets('mouse wheel zooms map', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldMapCanvas(
            countries: const [],
            selectedCountryCode: null,
            onCountryTap: (_) {},
            showHint: false,
          ),
        ),
      ),
    );
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final initial = viewer.transformationController!.value.getMaxScaleOnAxis();
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(400, 300),
        scrollDelta: Offset(0, -100),
      ),
    );
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(initial),
    );
    expect(tester.takeException(), isNull);
  });
}
