import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/downloads/presentation/widgets/desktop_imports_actions.dart';

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
  for (final width in [1200.0, 540.0, 360.0]) {
    testWidgets(
      'imports actions fit width $width with larger text and retain three actions',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = <String>[];
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
                  padding: const EdgeInsets.all(24),
                  child: DesktopImportsActions(
                    onUrl: () => actions.add('url'),
                    onLocal: () => actions.add('local'),
                    onQr: () => actions.add('qr'),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.public_rounded), findsNothing);
        final qrCard = tester.getRect(find.byType(InkWell).at(2));
        expect(qrCard.center.dx, closeTo(width / 2, 1));
        final link = tester.getRect(find.byIcon(Icons.link_rounded));
        final local = tester.getRect(find.byIcon(Icons.folder_open_rounded));
        if (width >= 700) {
          expect(local.top, link.top);
          expect(local.left, greaterThan(link.left));
        } else {
          expect(local.top, greaterThan(link.top));
        }
        for (final icon in [
          Icons.link_rounded,
          Icons.folder_open_rounded,
          Icons.qr_code_scanner_rounded,
        ]) {
          await tester.ensureVisible(find.byIcon(icon));
          await tester.tap(find.byIcon(icon));
        }
        expect(actions, ['url', 'local', 'qr']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
