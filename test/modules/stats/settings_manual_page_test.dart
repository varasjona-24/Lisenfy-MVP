import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:listenfy/Modules/settings/view/settings_manual_page.dart';
import 'package:listenfy/Modules/settings/view/widgets/guide_section.dart';

void main() {
  setUpAll(() {
    Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });

  testWidgets('settings opens a separate manual and can return', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GuideSection())),
    );
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.tap(find.text('Read the user manual'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsManualPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsManualPage), findsNothing);
    expect(find.text('Read the user manual'), findsOneWidget);
  });

  testWidgets('manual filters topics, handles empty searches and clears', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const SettingsManualPage()),
    );
    await tester.enterText(find.byType(TextField), 'zzzznomatch');
    await tester.pumpAndSettle();
    expect(find.text('No topics found. Try another word.'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.enterText(find.byType(TextField), 'region to focus');
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(
      tester
          .widget<ExpansionTile>(find.byType(ExpansionTile))
          .initiallyExpanded,
      isTrue,
    );
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('10 topics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
