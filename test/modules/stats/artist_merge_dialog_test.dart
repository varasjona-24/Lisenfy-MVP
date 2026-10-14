import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/artists/view/widgets/artist_merge_dialog.dart';
import 'package:listenfy/Modules/artists/view/widgets/artist_identity_dialog.dart';

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
  for (final brightness in Brightness.values) {
    testWidgets(
      'resolution cards explain identity without merging in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorSchemeSeed: Colors.green,
              brightness: brightness,
            ),
            home: const Scaffold(
              body: ArtistIdentityDialog(
                title: 'Resolve artist',
                candidates: [
                  {
                    'id': 'jp',
                    'name': 'Lisa',
                    'country': 'Japan',
                    'mainRegion': 'asiatico',
                  },
                  {
                    'id': 'kr',
                    'name': 'Lisa',
                    'country': 'South Korea',
                    'mainRegion': 'asiatico',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Japan · Asian'), findsOneWidget);
        expect(find.text('South Korea · Asian'), findsOneWidget);
        expect(find.byIcon(Icons.merge_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('identity choices fit small screens in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorSchemeSeed: Colors.green,
            brightness: brightness,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const ArtistMergeDialog(
                      candidates: [
                        {
                          'id': 'artist-2',
                          'name': 'Artist',
                          'country': 'Japan',
                        },
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Japan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byIcon(Icons.merge_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.merge_rounded));
      await tester.pumpAndSettle();
      expect(result, 'artist-2');
    });
  }
}
