import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/ui/widgets/navigation/app_bottom_nav.dart';
import 'package:listenfy/app/ui/widgets/navigation/app_top_bar.dart';

void main() {
  setUpAll(
    () => Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    ),
  );

  for (final compact in [false, true]) {
    testWidgets(
      'sidebar preserves every destination and toolbar callback: compact=$compact',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? destination;
        final actions = <String>[];
        final topBar = AppTopBar(
          title: const Text('Listenfy'),
          onSearch: () => actions.add('library'),
          onToggleMode: () => actions.add('mode'),
          onLocalConnect: () => actions.add('connect'),
          onSettings: () => actions.add('settings'),
          extraActions: [
            IconButton(
              tooltip: 'Edit home',
              icon: const Icon(Icons.edit),
              onPressed: () => actions.add('edit'),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SizedBox(
                  width: compact ? 76 : 264,
                  child: AppBottomNav(
                    vertical: true,
                    compact: compact,
                    currentIndex: 0,
                    onTap: (index) => destination = index,
                    tools: topBar.buildSidebarActions(
                      context,
                      compact: compact,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomNavigationBar), findsNothing);
        expect(find.byType(AppBar), findsNothing);
        final tooltips = tester
            .widgetList<Tooltip>(find.byType(Tooltip))
            .map((item) => item.message)
            .whereType<String>()
            .toList();
        final labels = tooltips.toSet().toList();
        expect(labels.length, 11);
        for (var index = 0; index < 6; index++) {
          await tester.tap(find.byTooltip(labels[index]).first);
          expect(destination, index);
        }
        for (final label in labels.skip(6)) {
          await tester.tap(find.byTooltip(label).first);
        }
        expect(actions, ['library', 'mode', 'edit', 'connect', 'settings']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('default navigation retains the mobile bottom bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(currentIndex: 0, onTap: (_) {}),
        ),
      ),
    );
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
