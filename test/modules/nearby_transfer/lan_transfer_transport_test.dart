import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/nearby_transfer/data/lan_transfer_transport.dart';

void main() {
  test('certificate pin mismatch never reaches user approval', () async {
    final host = LanTransferTransport(), client = LanTransferTransport();
    var asked = false;
    try {
      host.approve = (_, _) async {
        asked = true;
        return true;
      };
      client.approve = (_, _) async {
        asked = true;
        return true;
      };
      final invite = await host.advertise(
        name: 'Mac',
        addresses: ['127.0.0.1'],
        discoverable: false,
      );
      final wrong = invite.replace(
        queryParameters: {...invite.queryParameters, 'fp': '0' * 64},
      );
      await expectLater(
        client.connect(wrong, name: 'Android'),
        throwsStateError,
      );
      expect(asked, isFalse);
      expect(host.invitation, invite);
    } finally {
      await host.close();
      await client.close();
    }
  });
  test(
    'LAN invitation rejects Internet hosts, expired invites and invalid pins',
    () {
      final valid = Uri(
        scheme: 'listenfy',
        host: 'transfer',
        path: '/lan',
        queryParameters: {
          'target': 'lan-invite',
          'sid': 'ABCDEFG${'x' * 43}',
          'from': 'Mac',
          'hosts': '192.168.1.2',
          'port': '4455',
          'fp': 'a' * 64,
          'exp':
              '${DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch}',
        },
      );
      expect(LanTransferTransport.validateInvite(valid), valid);
      for (final entry in {
        'hosts': '8.8.8.8',
        'exp': '1',
        'fp': 'bad',
        'port': '65536',
      }.entries) {
        final bad = valid.replace(
          queryParameters: {...valid.queryParameters, entry.key: entry.value},
        );
        expect(
          () => LanTransferTransport.validateInvite(bad),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'TLS association, simultaneous bidirectional files, cover and import ACK',
    () async {
      final host = LanTransferTransport(), client = LanTransferTransport();
      final directory = await Directory.systemTemp.createTemp(
        'listenfy-lan-test-',
      );
      final verifications = <String>[];
      final subscriptions = <StreamSubscription<Map<String, dynamic>>>[];
      try {
        host.approve = (_, code) async {
          verifications.add(code);
          return true;
        };
        client.approve = (_, code) async {
          verifications.add(code);
          return true;
        };
        final invite = await host.advertise(
          name: 'Mac',
          addresses: ['127.0.0.1'],
          discoverable: false,
        );
        final hostConnected = host.events.firstWhere(
          (e) => e['type'] == 'connected',
        );
        final clientConnected = client.events.firstWhere(
          (e) => e['type'] == 'connected',
        );
        await client.connect(invite, name: 'Android');
        await Future.wait([
          hostConnected,
          clientConnected,
        ]).timeout(const Duration(seconds: 5));
        expect(verifications, hasLength(2));
        expect(verifications.first, verifications.last);
        final command = host.events.firstWhere(
          (event) => event['type'] == 'control',
        );
        await client.sendControl({'op': 'request', 'id': 'test'});
        expect((await command.timeout(const Duration(seconds: 5)))['message'], {
          'op': 'request',
          'id': 'test',
        });
        expect(
          () => client.sendControl({'data': 'x' * 9000}),
          throwsFormatException,
        );

        final bytes = Uint8List.fromList(
          List.generate(512 * 1024, (i) => i % 256),
        );
        final coverBytes = Uint8List(3 * 1024 * 1024)
          ..setAll(0, [137, 80, 78, 71, 13, 10, 26, 10]);
        final media = File('${directory.path}/song.mp3');
        await media.writeAsBytes(bytes);
        final cover = File('${directory.path}/cover.png');
        await cover.writeAsBytes(coverBytes);
        final session = invite.queryParameters['sid'];
        Map<String, dynamic> descriptor(int id) => {
          'schema': 'listenfy.nearby.transfer.v2',
          'payloadId': id,
          'sessionId': session,
          'kind': 'audio',
          'format': 'mp3',
          'fileName': 'song.mp3',
          'sizeBytes': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
          'title': 'Song',
        };
        final received = <Map<String, dynamic>>[];
        final importsDone = Completer<void>();
        for (final receiver in [host, client]) {
          subscriptions.add(
            receiver.events.listen((event) {
              if (event['type'] == 'received') {
                received.add(event);
                if (received.length == 2 && !importsDone.isCompleted) {
                  importsDone.complete();
                }
              }
            }),
          );
        }
        final one = descriptor(1)
          ..['cover'] = {
            'sizeBytes': coverBytes.length,
            'sha256': sha256.convert(coverBytes).toString(),
            'format': 'png',
          };
        final acks = <int>[];
        for (final sender in [host, client]) {
          subscriptions.add(
            sender.events.listen((event) {
              if (event['type'] == 'sent') acks.add(event['payloadId'] as int);
            }),
          );
        }
        await Future.wait([
          host.send(media.path, one, coverPath: cover.path),
          client.send(media.path, descriptor(2)),
        ]);
        await importsDone.future.timeout(const Duration(seconds: 10));
        expect(
          acks,
          isEmpty,
          reason: 'Files are not complete until durable import confirms',
        );
        for (final event in received) {
          expect(await File(event['path'] as String).readAsBytes(), bytes);
          if ((event['descriptor'] as Map)['payloadId'] == 1) {
            expect(
              await File(event['coverPath'] as String).readAsBytes(),
              coverBytes,
            );
            await client.confirm(1);
          } else {
            await host.confirm(2);
          }
        }
        for (var i = 0; i < 100 && acks.length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(acks, unorderedEquals([1, 2]));
        expect(await cover.readAsBytes(), coverBytes);
        final peerClosed = client.events.firstWhere(
          (e) => e['type'] == 'closed',
        );
        await host.close();
        await peerClosed.timeout(const Duration(seconds: 5));
      } finally {
        await host.close();
        await client.close();
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'rejecting association keeps host invitation available for retry',
    () async {
      final host = LanTransferTransport(), client = LanTransferTransport();
      try {
        host.approve = (_, _) async => false;
        client.approve = (_, _) async => true;
        final invite = await host.advertise(
          name: 'Mac',
          addresses: ['127.0.0.1'],
          discoverable: false,
        );
        final rejected = host.events.firstWhere((e) => e['type'] == 'rejected');
        await client.connect(invite, name: 'Android');
        await rejected;
        expect(host.invitation, invite);
        host.approve = (_, _) async => true;
        final connected = host.events.firstWhere(
          (e) => e['type'] == 'connected',
        );
        await client.connect(invite, name: 'Android');
        await connected.timeout(const Duration(seconds: 5));
      } finally {
        await host.close();
        await client.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
