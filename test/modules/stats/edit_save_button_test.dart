import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/edit/view/edit_save_button.dart';

void main() {
  testWidgets('saving shows progress and blocks duplicate submissions', (
    tester,
  ) async {
    var taps = 0;
    Widget page(bool busy) => MaterialApp(
      home: Scaffold(
        body: EditSaveButton(
          busy: busy,
          label: 'Save',
          busyLabel: 'Saving',
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.tap(find.text('Save'));
    expect(taps, 1);
    await tester.pumpWidget(page(true));
    expect(find.text('Saving'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Saving'));
    expect(taps, 1);
    await tester.pumpWidget(page(false));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Save'));
    expect(taps, 2);
  });
}
