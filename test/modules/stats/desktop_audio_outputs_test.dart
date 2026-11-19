import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/services/bluetooth_audio_service.dart';
import 'package:listenfy/Modules/settings/view/widgets/desktop_audio_outputs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('listenfy/bluetooth_audio');
  late BluetoothAudioService service;
  late Map<String, dynamic> snapshot;
  late int reads;
  bool fail = false;
  bool opened = false;
  setUpAll(
    () => Localization.load(
      const Locale('es'),
      translations: Translations(
        jsonDecode(File('assets/translations/es.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    ),
  );
  setUp(() {
    reads = 0;
    fail = false;
    opened = false;
    snapshot = {
      'bluetoothOn': false,
      'outputs': ['USB DAC'],
      'devices': [
        {'name': 'Speakers', 'address': 'builtin', 'kind': 'builtin'},
        {'name': 'USB DAC', 'address': 'usb', 'kind': 'usb', 'isActive': true},
      ],
    };
    service = BluetoothAudioService(channel: channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (fail) throw PlatformException(code: 'unavailable');
          if (call.method == 'openAudioSettings') {
            opened = true;
            return true;
          }
          reads++;
          return snapshot;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'reports wired outputs independently of Bluetooth power and marks default',
    () async {
      final result = await service.getSnapshot();
      expect(result.isAvailable, isTrue);
      expect(result.bluetoothOn, isFalse);
      expect(result.devices.length, 2);
      expect(result.devices.where((d) => d.isActive).single.name, 'USB DAC');
      expect(result.outputs, ['USB DAC']);
    },
  );

  test(
    'legacy Android snapshots remain supported without default or battery',
    () async {
      snapshot = {
        'bluetoothOn': true,
        'outputs': [],
        'devices': [
          {
            'name': 'Headphones',
            'address': 'AA:BB',
            'kind': 'bluetooth',
            'battery': -1,
          },
        ],
      };
      final result = await service.getSnapshot();
      expect(result.devices.single.isActive, isFalse);
      expect(result.devices.single.batteryPercent, isNull);
      expect(result.devices.single.address, 'AA:BB');
    },
  );

  test('native failure differs from no connected outputs', () async {
    fail = true;
    expect((await service.getSnapshot()).isAvailable, isFalse);
    fail = false;
    snapshot = {'bluetoothOn': false, 'outputs': [], 'devices': []};
    expect((await service.getSnapshot()).isAvailable, isTrue);
  });

  test('opens native sound settings and reports failures', () async {
    expect(await service.openAudioSettings(), isTrue);
    expect(opened, isTrue);
    fail = true;
    expect(await service.openAudioSettings(), isFalse);
  });

  testWidgets(
    'updates connections and default, opens settings, stops polling on disposal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopAudioOutputs(service: service)),
        ),
      );
      await tester.pump();
      expect(find.text('USB DAC'), findsOneWidget);
      expect(find.text('Salida predeterminada'), findsOneWidget);
      expect(find.text('Bluetooth desactivado'), findsNothing);
      snapshot = {
        'bluetoothOn': false,
        'outputs': ['Monitor'],
        'devices': [
          {
            'name': 'Monitor',
            'address': 'display',
            'kind': 'hdmi',
            'isActive': true,
          },
        ],
      };
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Monitor'), findsOneWidget);
      expect(find.text('USB DAC'), findsNothing);
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      expect(opened, isTrue);
      final beforePause = reads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 4));
      expect(reads, beforePause);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(reads, greaterThan(beforePause));
      await tester.pumpWidget(const SizedBox());
      final beforeDispose = reads;
      await tester.pump(const Duration(seconds: 5));
      expect(reads, beforeDispose);
      expect(tester.takeException(), isNull);
    },
  );
}
