import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/nearby_transfer/domain/paired_import_request.dart';
import 'package:listenfy/Modules/nearby_transfer/domain/paired_import_session.dart';

PairedImportRequest request([String id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa']) =>
    PairedImportRequest(
      id: id,
      url: 'https://youtu.be/O8BLUzAxNmQ?si=tracking',
      format: PairedImportFormat.mp3,
    );

void main() {
  test('preserves Vimeo, SoundCloud and generic source URLs', () {
    for (final url in [
      'https://vimeo.com/12345678',
      'https://soundcloud.com/artist/track?secret=abc',
      'https://media.example.com/video.mp4?token=123',
    ]) {
      expect(PairedImportRequest.validateUrl(url), url);
    }
  });
  test(
    'computer rejects public hostnames resolving to private addresses',
    () async {
      await expectLater(
        request().validateDestination(
          lookup: (_) async => [InternetAddress('192.168.1.1')],
        ),
        throwsFormatException,
      );
      await expectLater(
        request().validateDestination(
          lookup: (_) async => [InternetAddress('::ffff:127.0.0.1')],
        ),
        throwsFormatException,
      );
      await expectLater(
        request().validateDestination(
          lookup: (_) async => [
            InternetAddress('1.1.1.1'),
            InternetAddress('10.0.0.1'),
          ],
        ),
        throwsFormatException,
      );
      await request().validateDestination(
        lookup: (_) async => [
          InternetAddress('1.1.1.1'),
          InternetAddress('2606:4700:4700::1111'),
        ],
      );
    },
  );

  test(
    'accepts public HTTPS sources and rejects local URLs and injected fields',
    () {
      expect(PairedImportRequest.validateUrl(request().url), request().url);
      for (final url in [
        'http://youtu.be/O8BLUzAxNmQ',
        'https://user@youtube.com/watch?v=O8BLUzAxNmQ',
        'https://youtube.com:123/watch?v=O8BLUzAxNmQ',
        'http://127.0.0.1/admin',
        'file:///etc/passwd',
        '--exec rm',
        'https://127.0.0.1/video',
        'https://[::1]/video',
        'https://nas.local/video',
        'https://localhost/video',
      ]) {
        expect(
          () => PairedImportRequest.validateUrl(url),
          throwsFormatException,
          reason: url,
        );
      }
      expect(
        () => PairedImportRequest.fromJson({
          ...request().toJson(),
          'format': 'exe',
        }),
        throwsFormatException,
      );
      expect(
        () => PairedImportRequest.fromJson({
          ...request().toJson(),
          'id': '../file',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'client requires a companion capability and ignores unsolicited or stale status',
    () async {
      final changes = <String>[];
      final client = PairedImportSession(
        host: false,
        send: (_) async {},
        changed: (state, _) => changes.add(state),
      );
      addTearDown(client.close);
      await expectLater(client.request(request()), throwsStateError);
      await client.receive({'op': 'capabilities', 'download': true});
      await client.request(request());
      await client.receive({
        'op': 'status',
        'id': 'wrong',
        'state': 'completed',
      });
      expect(client.busy, isTrue);
      await client.receive({
        'op': 'status',
        'id': request().id,
        'state': 'completed',
      });
      expect(client.busy, isFalse);
      expect(changes, ['ready', 'waiting', 'completed']);
    },
  );

  test(
    'paired client request is approved, executed and completed in order',
    () async {
      final states = <String>[];
      late PairedImportSession host, client;
      host = PairedImportSession(
        host: true,
        send: (message) => client.receive(message),
        changed: (_, _) {},
        approve: (_) async => true,
        execute: (request, progress, active) async {
          expect(active(), isTrue);
          progress(.5);
          await host.transferring();
        },
      );
      client = PairedImportSession(
        host: false,
        send: (message) => host.receive(message),
        changed: (state, _) => states.add(state),
      );
      addTearDown(host.close);
      addTearDown(client.close);
      await host.announce();
      await client.request(request());
      expect(
        states,
        containsAllInOrder([
          'ready',
          'waiting',
          'downloading',
          'transferring',
          'completed',
        ]),
      );
      expect(client.busy, isFalse);
    },
  );

  test(
    'rejection never executes and replay cannot prompt or download again',
    () async {
      var approvals = 0, downloads = 0;
      final sent = <Map<String, dynamic>>[];
      final host = PairedImportSession(
        host: true,
        send: (m) async {
          sent.add(m);
        },
        changed: (_, _) {},
        approve: (_) async {
          approvals++;
          return false;
        },
        execute: (_, _, _) async {
          downloads++;
        },
      );
      final message = {'op': 'request', ...request().toJson()};
      await host.receive(message);
      await host.receive(message);
      expect(approvals, 1);
      expect(downloads, 0);
      expect(sent.last['state'], 'rejected');
    },
  );

  test(
    'only one job runs and disconnect while approving cannot execute',
    () async {
      final approval = Completer<bool>();
      var downloads = 0;
      final sent = <Map<String, dynamic>>[];
      final host = PairedImportSession(
        host: true,
        send: (m) async {
          sent.add(m);
        },
        changed: (_, _) {},
        approve: (_) => approval.future,
        execute: (_, _, _) async {
          downloads++;
        },
      );
      final first = host.receive({'op': 'request', ...request().toJson()});
      await Future<void>.delayed(Duration.zero);
      await host.receive({
        'op': 'request',
        ...request('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb').toJson(),
      });
      expect(sent.last['state'], 'busy');
      host.close();
      approval.complete(true);
      await first;
      expect(downloads, 0);
    },
  );

  test(
    'disconnect invalidates an executing job and suppresses completion',
    () async {
      final done = Completer<void>(), started = Completer<void>();
      late bool Function() active;
      final sent = <Map<String, dynamic>>[];
      final host = PairedImportSession(
        host: true,
        send: (m) async {
          sent.add(m);
        },
        changed: (_, _) {},
        approve: (_) async => true,
        execute: (_, _, isActive) async {
          active = isActive;
          started.complete();
          await done.future;
        },
      );
      final task = host.receive({'op': 'request', ...request().toJson()});
      await started.future;
      host.close();
      expect(active(), isFalse);
      done.complete();
      await task;
      expect(sent.where((m) => m['state'] == 'completed'), isEmpty);
    },
  );
}
