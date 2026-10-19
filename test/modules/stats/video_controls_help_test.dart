import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/Modules/settings/controller/playback_settings_controller.dart';
import 'package:listenfy/Modules/player/Video/view/video_controls_help_dialog.dart';

class _Memory implements GetStorage {
  final values = <String, dynamic>{};
  bool fail = false;
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  Future<void> write(String key, dynamic value) async {
    if (fail) throw StateError('write failed');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

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
  tearDown(() => Get.reset());
  test(
    'seek interval survives controller recreation with a safe default',
    () async {
      final memory = _Memory();
      final first = PlaybackSettingsController(storage: memory)..onInit();
      expect(first.videoSeekSeconds.value, 5);
      await first.setVideoSeekSeconds(15);
      final restored = PlaybackSettingsController(storage: memory)..onInit();
      expect(restored.videoSeekSeconds.value, 15);
      await restored.setVideoSeekSeconds(9);
      expect(restored.videoSeekSeconds.value, 15);
      memory.values[PlaybackSettingsController.videoSeekSecondsKey] = 99;
      expect(
        (PlaybackSettingsController(
          storage: memory,
        )..onInit()).videoSeekSeconds.value,
        5,
      );
    },
  );
  test('failed writes do not pretend the preference was saved', () async {
    final memory = _Memory()..fail = true;
    final settings = PlaybackSettingsController(storage: memory);
    await expectLater(settings.setVideoSeekSeconds(10), throwsStateError);
    expect(settings.videoSeekSeconds.value, 5);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'gesture help and interval selection fit large text in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final memory = _Memory();
        final settings = PlaybackSettingsController(storage: memory);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (_, child) => MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(body: VideoControlsHelpDialog(settings: settings)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ChoiceChip), findsNothing);
        final selector = find.byType(DropdownButton<int>);
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text('10 s').last);
        await tester.pumpAndSettle();
        expect(settings.videoSeekSeconds.value, 10);
        expect(tester.widget<DropdownButton<int>>(selector).value, 10);
        expect(
          memory.values[PlaybackSettingsController.videoSeekSecondsKey],
          10,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
