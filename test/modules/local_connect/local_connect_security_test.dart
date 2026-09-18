import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:listenfy/Modules/artists/data/artist_store.dart';
import 'package:listenfy/Modules/artists/domain/artist_profile.dart';
import 'package:listenfy/Modules/local_connect/data/server/local_connect_http_policy.dart';
import 'package:listenfy/Modules/local_connect/data/server/local_connect_pairing_manager.dart';
import 'package:listenfy/Modules/local_connect/data/server/local_connect_playback_sync.dart';
import 'package:listenfy/Modules/local_connect/data/web/local_connect_web_page.dart';
import 'package:listenfy/Modules/local_connect/service/local_connect_server_service.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/audio_service.dart';

class _Audio implements AudioService {
  @override
  final currentItem = Rxn<MediaItem>();
  @override
  final currentVariant = Rxn<MediaVariant>();
  @override
  final isPlaying = false.obs;
  @override
  final isLoading = false.obs;
  @override
  final speed = 1.0.obs;
  @override
  final volume = 1.0.obs;
  @override
  bool isInPrivatePlaybackSession = false;
  @override
  bool shuffleEnabled = false;
  @override
  int currentQueueIndex = 0;
  @override
  int queueRevision = 0;
  @override
  List<MediaItem> queueItems = [];
  @override
  int get queueLength => queueItems.length;
  @override
  Duration get currentPosition => Duration.zero;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Artists implements ArtistStore {
  @override
  int revision = 0;
  int reads = 0;
  List<ArtistProfile> profiles = [];
  @override
  List<ArtistProfile> readAllSync() {
    reads++;
    return profiles;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Library implements LocalLibraryStore {
  @override
  int revision = 0;
  int reads = 0;
  List<MediaItem> items = [];
  @override
  List<MediaItem> readAllSync() {
    reads++;
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaItem _track(String id, String artist) => MediaItem(
  id: id,
  publicId: id,
  title: id,
  subtitle: artist,
  source: MediaSource.local,
  origin: SourceOrigin.device,
  thumbnailLocalPath: '/private/device/$id.jpg',
  variants: const [],
);

void main() {
  test('same song variants have distinct stream identities and roles', () {
    final audio = _Audio();
    audio.currentItem.value = _track('song', 'A');
    final sync = LocalConnectPlaybackSync(
      audioService: audio,
      artistStore: _Artists(),
      localLibraryStore: _Library(),
    );
    final identities = <String>{};
    final signatures = <String>{};
    for (final role in ['main', 'instrumental', 'spatial8d']) {
      audio.currentVariant.value = MediaVariant(
        kind: MediaVariantKind.audio,
        format: 'mp3',
        fileName: 'song.mp3',
        localPath: '/private/song.mp3',
        createdAt: 1,
        role: role,
      );
      final track = sync.currentTrackPayload()!;
      expect(track['variantRole'], role);
      identities.add(track['variantId'] as String);
      signatures.add(sync.trackSignature());
      expect(jsonEncode(track), isNot(contains('/private/song.mp3')));
      expect(sync.currentVariantId, track['variantId']);
    }
    expect(identities.length, 3);
    expect(signatures.length, 3);
  });
  group('pairing security', () {
    test(
      'client id alone cannot retrieve credentials or replace a request',
      () {
        final manager = LocalConnectPairingManager(
          tokenTtl: const Duration(minutes: 15),
        );
        final request = manager.requestPairing(
          clientId: 'victim',
          clientName: 'Laptop',
        );
        expect(
          () => manager.requestPairing(
            clientId: 'victim',
            clientName: 'Attacker',
          ),
          throwsStateError,
        );
        final session = manager.approveRequest(request.id)!;
        expect(manager.sessionForReceipt('victim', ''), isNull);
        expect(manager.sessionForReceipt('victim', 'wrong'), isNull);
        expect(manager.sessionForReceipt('other', request.id), isNull);
        expect(
          manager.sessionForReceipt('victim', request.id)?.token,
          session.token,
        );
        manager.revokeSession('victim');
        expect(manager.sessionForReceipt('victim', request.id), isNull);
      },
    );

    test('pending requests are bounded and revoke-all clears receipts', () {
      final manager = LocalConnectPairingManager(
        tokenTtl: const Duration(minutes: 15),
      );
      for (var i = 0; i < LocalConnectPairingManager.maxPending; i++) {
        manager.requestPairing(clientId: 'client-$i', clientName: 'Browser');
      }
      expect(
        () => manager.requestPairing(clientId: 'extra', clientName: 'Browser'),
        throwsStateError,
      );
      manager.revokeAllSessions();
      expect(manager.pendingRequests, isEmpty);
    });
  });

  group('HTTP policy', () {
    test('rejects hostile hosts, cross origins and opaque origins', () {
      final server = Uri.parse('http://192.168.1.4:1234');
      for (final origin in [
        'http://evil.test',
        'null',
        'http://192.168.1.4:12345',
      ]) {
        expect(
          LocalConnectHttpPolicy.allowsRequest(
            server: server,
            host: server.authority,
            origin: origin,
          ),
          isFalse,
        );
      }
      expect(
        LocalConnectHttpPolicy.allowsRequest(
          server: server,
          host: 'evil.test:1234',
          origin: null,
        ),
        isFalse,
      );
      expect(
        LocalConnectHttpPolicy.allowsRequest(
          server: server,
          host: server.authority,
          origin: server.origin,
        ),
        isTrue,
      );
    });

    test('ranges include suffixes and reject empty/out-of-bounds files', () {
      expect(ConnectByteRange.parse('bytes=-10', 100).start, 90);
      expect(ConnectByteRange.parse('bytes=10-', 100).length, 90);
      expect(ConnectByteRange.parse('bytes=90-200', 100).end, 99);
      for (final range in [
        'bytes=100-',
        'bytes=9-1',
        'bytes=-0',
        'bytes=-',
        'bytes=0-1,5-6',
        'bytes=abc',
      ]) {
        expect(
          () => ConnectByteRange.parse(range, 100),
          throwsA(isA<ConnectHttpException>()),
        );
      }
      expect(
        () => ConnectByteRange.parse('bytes=0-', 0),
        throwsA(isA<ConnectHttpException>()),
      );
    });

    test('remote destinations exclude executable schemes and credentials', () {
      for (final url in [
        'javascript:alert(1)',
        'file:///private/data',
        'data:text/html,test',
        'https://user:pass@host/path',
      ]) {
        expect(LocalConnectHttpPolicy.isRemoteUrl(url), isFalse);
      }
      expect(
        LocalConnectHttpPolicy.isRemoteUrl('https://example.com/cover.jpg'),
        isTrue,
      );
    });
  });

  test('web translations cannot close the script element', () {
    final html = buildLocalConnectWebPage(
      scriptNonce: 'safe-nonce',
      translations: {'title': '</script><script>alert(1)</script>'},
    );
    expect(RegExp(r'<script\b').allMatches(html).length, 1);
    expect(RegExp(r'</script>').allMatches(html).length, 1);
    expect(html, contains('nonce="safe-nonce"'));
    expect(html, contains(r'\u003c/script>'));
  });

  test(
    'metadata cache reuses snapshots and invalidates each store independently',
    () {
      final audio = _Audio();
      final artists = _Artists()
        ..profiles = [const ArtistProfile(key: 'a', displayName: 'A')];
      final library = _Library()
        ..items = [_track('1', 'A'), _track('2', 'B feat. A')];
      audio.queueItems = [_track('1', 'A')];
      audio.currentItem.value = audio.queueItems.first;
      final sync = LocalConnectPlaybackSync(
        audioService: audio,
        artistStore: artists,
        localLibraryStore: library,
      );
      final first = sync.queuePayload();
      expect((first.first['artistProfile'] as Map)['trackCount'], 2);
      expect(first.first['coverUrl'], '/cover/item?itemId=1');
      expect(jsonEncode(first), isNot(contains('/private/device')));
      sync.buildSessionPayload();
      sync.currentTrackPayload();
      sync.buildProgressPayload();
      expect(identical(sync.queuePayload(), first), isTrue);
      expect(artists.reads, 1);
      expect(library.reads, 1);
      final signature = sync.queueSignature();
      audio.currentQueueIndex = 1;
      expect(sync.queueSignature(), signature);
      library.items = [_track('1', 'A')];
      library.revision++;
      expect(
        (sync.queuePayload().first['artistProfile'] as Map)['trackCount'],
        1,
      );
      expect(artists.reads, 1);
      expect(library.reads, 2);
      artists.profiles = [
        const ArtistProfile(key: 'a', displayName: 'Renamed'),
      ];
      artists.revision++;
      expect(
        (sync.queuePayload().first['artistProfile'] as Map)['displayName'],
        'Renamed',
      );
      expect(artists.reads, 2);
      expect(library.reads, 2);
    },
  );

  group('real HTTP and WebSocket server', () {
    late LocalConnectServerService server;
    late HttpClient client;
    late Uri base;
    late _Audio audio;

    setUp(() async {
      audio = _Audio();
      server = LocalConnectServerService(
        audioService: audio,
        artistStore: _Artists(),
        libraryStore: _Library(),
      );
      await server.start(address: InternetAddress.loopbackIPv4);
      expect(server.isRunning.value, isTrue, reason: server.serverError.value);
      base = Uri.parse(server.serverUrl.value);
      client = HttpClient();
    });
    tearDown(() async {
      client.close(force: true);
      await server.stop();
    });

    Future<(int, Map<String, dynamic>)> call(
      String path, {
      String method = 'GET',
      String? body,
      Map<String, String> headers = const {},
    }) async {
      final request = await client.openUrl(method, base.resolve(path));
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      if (body != null) request.write(body);
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return (response.statusCode, jsonDecode(text) as Map<String, dynamic>);
    }

    Future<String> pair() async {
      final result = await call(
        '/api/pairing/request',
        method: 'POST',
        body: jsonEncode({'clientId': 'browser', 'clientName': 'Laptop'}),
      );
      expect(result.$1, 200);
      final receipt = result.$2['requestId'] as String;
      await server.approvePairingRequest(receipt);
      final approved = await call(
        '/api/pairing/status?clientId=browser',
        headers: {'X-Listenfy-Pairing': receipt},
      );
      return approved.$2['token'] as String;
    }

    test(
      'rejects old variant URLs and never falls back for missing instrumental',
      () async {
        final token = await pair();
        audio.currentItem.value = _track('song', 'A');
        audio.currentVariant.value = const MediaVariant(
          kind: MediaVariantKind.audio,
          format: 'mp3',
          fileName: 'song.mp3',
          createdAt: 1,
          role: 'main',
        );
        final headers = {'Authorization': 'Bearer $token'};
        final session = await call('/api/current', headers: headers);
        final id = (session.$2['track'] as Map)['variantId'];
        audio.currentVariant.value = const MediaVariant(
          kind: MediaVariantKind.audio,
          format: 'mp3',
          fileName: 'song-inst.mp3',
          createdAt: 1,
          role: 'instrumental',
        );
        final stale = await call(
          '/stream/current?track=song&variant=$id',
          headers: headers,
        );
        expect(stale.$1, 409);
        expect(stale.$2['error'], 'variant_changed');
        final current = await call('/api/current', headers: headers);
        final nextId = (current.$2['track'] as Map)['variantId'];
        final missing = await call(
          '/stream/current?track=song&variant=$nextId',
          headers: headers,
        );
        expect(missing.$1, 404);
        expect(missing.$2['error'], 'variant_unavailable');
      },
    );

    test(
      'requires credentials after approval and on WebSocket reconnect',
      () async {
        final token = await pair();
        final exposed = await call('/api/pairing/status?clientId=browser');
        expect(exposed.$2.containsKey('token'), isFalse);
        expect((await call('/api/session')).$1, 401);
        expect(
          (await call(
            '/api/session',
            headers: {'Authorization': 'Bearer $token'},
          )).$1,
          200,
        );
        final socketUrl = base
            .replace(
              scheme: 'ws',
              path: '/ws',
              queryParameters: {'clientId': 'browser', 'token': token},
            )
            .toString();
        final first = await WebSocket.connect(socketUrl);
        final firstMessages = StreamIterator(first);
        expect(await firstMessages.moveNext(), isTrue);
        await expectLater(
          WebSocket.connect(
            base
                .replace(
                  scheme: 'ws',
                  path: '/ws',
                  queryParameters: {'clientId': 'browser'},
                )
                .toString(),
          ),
          throwsA(isA<WebSocketException>()),
        );
        final second = await WebSocket.connect(socketUrl);
        final messages = StreamIterator(second);
        expect(await messages.moveNext(), isTrue);
        expect(
          jsonDecode(messages.current as String)['type'],
          'playbackStateChanged',
        );
        // A stale onDone from the first socket must not remove the new socket.
        expect(
          await messages.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(
          jsonDecode(messages.current as String)['type'],
          'progressUpdated',
        );
        await firstMessages.cancel();
        await messages.cancel();
        await first.close();
        await second.close();
        await server.stop();
        expect(server.sessions, isEmpty);
      },
    );

    test(
      'rejects foreign origins, invalid JSON and oversized requests',
      () async {
        expect(
          (await call('/health', headers: {'Origin': 'http://evil.test'})).$1,
          403,
        );
        expect((await call('/health', headers: {'Host': 'evil.test'})).$1, 403);
        expect(
          (await call('/api/pairing/request', method: 'POST', body: '[]')).$1,
          400,
        );
        expect(
          (await call('/api/pairing/request', method: 'POST', body: '{')).$1,
          400,
        );
        expect(
          (await call(
            '/api/pairing/request',
            method: 'POST',
            body: jsonEncode({'large': 'x' * 9000}),
          )).$1,
          413,
        );
      },
    );

    test(
      'private playback blocks metadata and active sockets receive a lock',
      () async {
        final token = await pair();
        final socket = await WebSocket.connect(
          base
              .replace(
                scheme: 'ws',
                path: '/ws',
                queryParameters: {'clientId': 'browser', 'token': token},
              )
              .toString(),
        );
        final messages = StreamIterator(socket);
        await messages.moveNext();
        audio.isInPrivatePlaybackSession = true;
        expect(
          (await call(
            '/api/session',
            headers: {'Authorization': 'Bearer $token'},
          )).$1,
          423,
        );
        expect(
          await messages.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(
          jsonDecode(messages.current as String)['type'],
          'privatePlaybackLocked',
        );
        await messages.cancel();
        await socket.close();
      },
    );
  });
}
