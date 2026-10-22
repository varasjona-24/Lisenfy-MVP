import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:nearby_connections/nearby_connections.dart';
import 'package:listenfy/Modules/nearby_transfer/controller/nearby_transfer_controller.dart';
import 'package:listenfy/Modules/nearby_transfer/data/wifi_direct_transport.dart';
import 'package:listenfy/Modules/nearby_transfer/domain/hybrid_transfer_protocol.dart';
import 'package:listenfy/Modules/nearby_transfer/view/nearby_transfer_page.dart';
import 'package:listenfy/Modules/nearby_transfer/view/nearby_qr_scanner_page.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

const _endpoint = 'peer';
const _historyKey = 'nearby_transfer_history_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });

  testWidgets(
    'empty library can advertise; rejecting security confirmation does not send',
    (tester) async {
      await _withController(tester, (fixture) async {
        final c = fixture.controller;
        await c.prepareInvitation();
        expect(c.phase.value, TransferPhase.advertising);
        expect(c.inviteUri.value, isNotNull);
        expect(c.inviteCode.value, isNotEmpty);
        expect(c.libraryItems(), isEmpty);
        expect(
          fixture.nearby.advertisedName,
          'LF2-${c.inviteCode.value}-${c.nickName}',
        );
        expect(fixture.nearby.strategy, Strategy.P2P_POINT_TO_POINT);

        fixture.nearby.initiated(
          _endpoint,
          ConnectionInfo('Other Listenfy', '123456', true),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('123456'), findsOneWidget);
        expect(fixture.nearby.accepted, isEmpty);
        await tester.tap(find.widgetWithText(TextButton, tr('nearby.reject')));
        await tester.pumpAndSettle();
        expect(c.phase.value, TransferPhase.advertising);
        expect(c.statusKey.value, 'nearby_session.rejected');
        expect(fixture.nearby.rejected, [_endpoint]);
        // A late CONNECTED callback cannot bypass the local approval.
        fixture.nearby.result(_endpoint, Status.CONNECTED);
        await tester.pump();
        expect(fixture.nearby.controls, isEmpty);
        expect(fixture.transport.prepared, isEmpty);
        expect(fixture.transport.hostStarts, 0);
        expect(fixture.transport.sends, isEmpty);
      });
    },
  );

  testWidgets(
    'approved host commits handoff; explicit send completes only on native ACK and survives reopening SQL',
    (tester) async {
      await _withController(tester, (fixture) async {
        final item = fixture.audioItem();
        fixture.controller.selectedItems.assignAll([item]);
        final session = await fixture.connectHost(tester);
        final c = fixture.controller;
        expect(fixture.transport.sends, isEmpty);
        await tester.runAsync(() => c.sendItems([item]));
        expect(fixture.transport.sends, hasLength(1));
        final transfer = fixture.transport.sends.single;
        expect(transfer.$1, item.variants.single.localPath);
        expect(transfer.$2['sessionId'], session);
        expect(transfer.$2['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(c.sent.single.state, 'sending');
        final id = c.sent.single.id;
        expect(transfer.$2['payloadId'], id);
        fixture.transport.emit({
          'type': 'progress',
          'sessionId': session,
          'payloadId': id,
          'bytes': 4,
          'total': 4,
          'direction': 'sent',
        });
        await tester.pump();
        expect(c.sent.single.progress, 1);
        expect(c.sent.single.state, 'sending');
        fixture.transport.emit({
          'type': 'sent',
          'sessionId': session,
          'payloadId': id,
        });
        await tester.pump();
        expect(c.sent.single.state, 'completed');
        expect(c.sent.single.progress, 1);
        // readDomains queues behind the controller's preceding history write.
        final domains = await tester.runAsync(
          () => fixture.repository.readDomains(),
        );
        expect((domains![_historyKey] as List).single['state'], 'completed');
        await tester.runAsync(() async {
          await c.closeConnection();
          final reader = await fixture.openRepository();
          try {
            final reopened = await reader.readDomains();
            expect(
              (reopened[_historyKey] as List).single['state'],
              'completed',
            );
            expect(
              (reopened[_historyKey] as List).single['sessionId'],
              session,
            );
          } finally {
            await reader.close();
          }
        });
      });
    },
  );

  testWidgets(
    'previous-session native events are ignored; explicit close fails in-flight work durably',
    (tester) async {
      await _withController(tester, (fixture) async {
        final c = fixture.controller;
        await c.prepareInvitation();
        final oldSession = c.inviteUri.value!.queryParameters['sid']!;
        final session = await fixture.connectHost(tester);
        expect(c.inviteUri.value, isNull);
        expect(oldSession, isNot(session));
        await tester.runAsync(() => c.sendItems([fixture.audioItem()]));
        final id = c.sent.single.id;
        for (final event in <Map<String, dynamic>>[
          {'type': 'connected'},
          {'type': 'progress', 'payloadId': id, 'bytes': 4, 'total': 4},
          {'type': 'sent', 'payloadId': id},
          {'type': 'received', 'path': '/must-not-be-read', 'descriptor': {}},
          {'type': 'error'},
          {'type': 'closed'},
        ]) {
          fixture.transport.emit({...event, 'sessionId': oldSession});
        }
        await tester.pump();
        expect(c.phase.value, TransferPhase.connected);
        expect(c.sent.single.state, 'sending');
        expect(c.sent.single.progress, 0);
        expect(c.received, isEmpty);
        expect(fixture.library.imported, isEmpty);
        expect(fixture.transport.confirmed, isEmpty);
        final closes = fixture.transport.closes;
        await tester.runAsync(() => c.closeConnection());
        expect(fixture.transport.closes, closes + 1);
        expect(c.phase.value, TransferPhase.closed);
        expect(c.sent.single.state, 'failed');
        fixture.transport.emit({
          'type': 'sent',
          'sessionId': session,
          'payloadId': id,
        });
        await tester.pump();
        expect(c.sent.single.state, 'failed');
        final domains = await tester.runAsync(
          () => fixture.repository.readDomains(),
        );
        expect((domains![_historyKey] as List).single['state'], 'failed');
      });
    },
  );

  test('controller never uses Nearby file payloads', () {
    final source = File(
      'lib/Modules/nearby_transfer/controller/nearby_transfer_controller.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('.sendFilePayload')));
  });

  for (final brightness in Brightness.values) {
    testWidgets('bridge and session fit narrow $brightness with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _withController(tester, (fixture) async {
        Get.to<void>(
          () => Theme(
            data: ThemeData(brightness: brightness),
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: const NearbyTransferPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('transfer-scan-qr')), findsOneWidget);
        expect(find.byKey(const Key('transfer-show-qr')), findsOneWidget);
        expect(find.byKey(const Key('transfer-enter-code')), findsOneWidget);
        expect(find.byType(NearbyQrScannerPage), findsNothing);
        fixture.controller.peerName.value = 'Other phone';
        fixture.controller.phase.value = TransferPhase.connected;
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('transfer-send')), findsOneWidget);
        expect(find.byKey(const Key('transfer-close')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}

Future<void> _withController(
  WidgetTester tester,
  Future<void> Function(_Fixture) body,
) async {
  final fixture = _Fixture();
  Get.testMode = true;
  await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
  try {
    await tester.runAsync(() => fixture.initialize());
    await body(fixture);
  } finally {
    if (Get.isDialogOpen == true) {
      Get.back(result: false);
      await tester.pumpAndSettle();
    }
    await tester.runAsync(() async {
      await fixture.controller.closeConnection();
      fixture.controller.onClose();
      // onClose starts another asynchronous close; await an ordered close to
      // drain its SQL writes before shutting down the repository.
      await fixture.controller.closeConnection();
      await fixture.repository.close();
      await fixture.transport.stream.close();
      await fixture.directory.delete(recursive: true);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    Get.reset();
  }
}

class _Fixture {
  final nearby = _Nearby();
  final transport = _Transport();
  final library = _Library();
  late Directory directory;
  late PlaybackRepository repository;
  late NearbyTransferController controller;

  Future<PlaybackRepository> openRepository() async => PlaybackRepository(
    await PlaybackDatabaseOpener.openStaging(
      generation: 'hybrid-test',
      supportDirectory: directory,
      temporaryDirectory: directory,
    ),
  );

  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp(
      'listenfy-hybrid-controller-',
    );
    repository = await openRepository();
    controller = NearbyTransferController(
      library: library,
      repository: repository,
      nearby: nearby,
      transport: transport,
      permissionCheck: () async => true,
    );
    Get.put<NearbyTransferController>(controller);
    await repository.readDomains();
  }

  MediaItem audioItem() {
    final file = File('${directory.path}/sample.mp3')
      ..writeAsBytesSync([1, 2, 3, 4]);
    return MediaItem.fromJson({
      'id': 'local-test',
      'publicId': 'local-test',
      'title': 'Test audio',
      'artist': 'Test artist',
      'source': 'local',
      'variants': [
        {
          'kind': 'audio',
          'format': 'mp3',
          'fileName': 'sample.mp3',
          'localPath': file.path,
          'createdAt': 1,
        },
      ],
    });
  }

  Future<String> connectHost(WidgetTester tester) async {
    await controller.prepareInvitation();
    nearby.initiated(
      _endpoint,
      ConnectionInfo('Other Listenfy', '123456', true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(nearby.controls, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, tr('nearby.accept')));
    await tester.pumpAndSettle();
    expect(nearby.accepted, [_endpoint]);
    nearby.result(_endpoint, Status.CONNECTED);
    await tester.pumpAndSettle();
    expect(transport.prepared, hasLength(1));
    expect(
      nearby.controls,
      hasLength(1),
      reason:
          '${controller.phase.value} ${controller.statusKey.value} ${controller.statusDetail.value}',
    );
    expect(nearby.controls.single['type'], 'offer');
    final offer = nearby.controls.single;
    final session = offer['sessionId'] as String;
    expect(offer['fingerprint'], 'a' * 64);
    nearby.payload(
      _endpoint,
      Payload(
        id: 1,
        type: PayloadType.BYTES,
        bytes: Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'schema': HybridTransferProtocol.schema,
              'type': 'ack',
              'sessionId': session,
            }),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(nearby.controls.map((e) => e['type']).toList(), ['offer', 'commit']);
    expect(nearby.controls.last['sessionId'], session);
    expect(transport.hostStarts, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.phase.value, TransferPhase.preparingWifi);
    expect(transport.hostStarts, 0);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(transport.hostStarts, 1);
    expect(nearby.endpointStops, greaterThanOrEqualTo(2));
    expect(transport.sends, isEmpty);
    transport.emit({'type': 'connected', 'sessionId': session});
    await tester.pump();
    expect(controller.phase.value, TransferPhase.connected);
    expect(transport.sends, isEmpty);
    return session;
  }
}

class _Library implements LocalLibraryStore {
  final imported = <MediaItem>[];
  @override
  List<MediaItem> readAllSync() => List.of(imported);
  @override
  Future<void> upsert(MediaItem item) async {
    imported.add(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Nearby implements Nearby {
  late OnConnectionInitiated initiated;
  late OnConnectionResult result;
  late OnDisconnected disconnected;
  late OnPayloadReceived payload;
  String? advertisedName;
  Strategy? strategy;
  final accepted = <String>[];
  final rejected = <String>[];
  final controls = <Map<String, dynamic>>[];
  int endpointStops = 0;
  @override
  Future<bool> startAdvertising(
    String userNickName,
    Strategy strategy, {
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
    String serviceId = 'com.pkmnapps.nearby_connections',
  }) async {
    advertisedName = userNickName;
    this.strategy = strategy;
    initiated = onConnectionInitiated;
    result = onConnectionResult;
    disconnected = onDisconnected;
    return true;
  }

  @override
  Future<bool> acceptConnection(
    String endpointId, {
    required OnPayloadReceived onPayLoadRecieved,
    OnPayloadTransferUpdate? onPayloadTransferUpdate,
  }) async {
    accepted.add(endpointId);
    payload = onPayLoadRecieved;
    return true;
  }

  @override
  Future<bool> rejectConnection(String endpointId) async {
    rejected.add(endpointId);
    return true;
  }

  @override
  Future<void> sendBytesPayload(String endpointId, Uint8List bytes) async {
    if (endpointId != _endpoint) throw StateError('Unexpected peer');
    controls.add(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
    );
  }

  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> stopAllEndpoints() async {
    endpointStops++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport implements WifiDirectTransport {
  final stream = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final prepared = <Map<String, dynamic>>[];
  final sends = <(String, Map<String, dynamic>)>[];
  final confirmed = <int>[];
  int hostStarts = 0, closes = 0;
  void emit(Map<String, dynamic> event) => stream.add(event);
  @override
  Stream<Map<String, dynamic>> get events => stream.stream;
  @override
  Future<String> prepare(Map<String, dynamic> credentials) async {
    prepared.add(Map.of(credentials));
    return 'a' * 64;
  }

  @override
  Future<void> startHost() async {
    hostStarts++;
  }

  @override
  Future<void> join(Map<String, dynamic> credentials) async {
    fail('host must not join');
  }

  @override
  Future<void> send(String path, Map<String, dynamic> descriptor) async {
    sends.add((path, Map.of(descriptor)));
  }

  @override
  Future<void> confirm(int payloadId) async {
    confirmed.add(payloadId);
  }

  @override
  Future<void> close() async {
    closes++;
  }
}
