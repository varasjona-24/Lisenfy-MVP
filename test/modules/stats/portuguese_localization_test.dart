import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/utils/app_locales.dart';
import 'package:listenfy/Modules/settings/view/widgets/language_section.dart';

Map<String, String> _flatten(
  Map<String, dynamic> map, [
  String prefix = '',
]) => {
  for (final entry in map.entries)
    if (entry.value is Map<String, dynamic>)
      ..._flatten(entry.value as Map<String, dynamic>, '$prefix${entry.key}.')
    else
      '$prefix${entry.key}': entry.value as String,
};

class _Files extends AssetLoader {
  const _Files();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await EasyLocalization.ensureInitialized();
  });

  test(
    'Portuguese includes all English keys and interpolation placeholders',
    () {
      final en = _flatten(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final pt = _flatten(
        jsonDecode(File('assets/translations/pt.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(pt.keys.toSet(), en.keys.toSet());
      List<String> tokens(String text) => RegExp(
        r'\{[^{}]*\}',
      ).allMatches(text).map((match) => match.group(0)!).toList()..sort();
      for (final key in en.keys) {
        expect(pt[key]!.trim(), isNotEmpty, reason: key);
        expect(tokens(pt[key]!), tokens(en[key]!), reason: key);
      }
    },
  );

  test(
    'regional Portuguese device locales resolve to supported Portuguese',
    () {
      expect(
        AppLocales.forDevice(const Locale('pt', 'BR')),
        const Locale('pt'),
      );
      expect(
        AppLocales.forDevice(const Locale('pt', 'PT')),
        const Locale('pt'),
      );
      expect(AppLocales.forDevice(const Locale('fr')), const Locale('es'));
    },
  );

  testWidgets('language selector switches to Portuguese without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        path: 'assets/translations',
        assetLoader: const _Files(),
        startLocale: const Locale('en'),
        fallbackLocale: AppLocales.fallback,
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const Scaffold(
              body: SingleChildScrollView(child: LanguageSection()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portuguese').last);
    await tester.pumpAndSettle();
    expect(find.text('Português'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
