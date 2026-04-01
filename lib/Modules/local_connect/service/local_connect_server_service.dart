import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../app/models/media_item.dart';
import '../../../app/services/audio_service.dart';
import '../data/server/local_connect_pairing_manager.dart';
import '../data/server/local_connect_playback_sync.dart';
import '../data/web/local_connect_web_page.dart';
import '../domain/entities/local_connect_models.dart';

class LocalConnectServerService extends GetxService {
  LocalConnectServerService({Duration tokenTtl = const Duration(minutes: 15)})
    : _pairingManager = LocalConnectPairingManager(tokenTtl: tokenTtl);

  final AudioService _audioService = Get.find<AudioService>();
  final LocalConnectPairingManager _pairingManager;

  late final LocalConnectPlaybackSync _playbackSync = LocalConnectPlaybackSync(
    audioService: _audioService,
  );

  HttpServer? _httpServer;
  final Map<String, WebSocket> _socketByClientId = <String, WebSocket>{};
  final Set<String> _authorizedSocketClients = <String>{};
  Timer? _playbackTicker;

  String _lastTrackSignature = '';
  String _lastPlaybackSignature = '';
  String _lastQueueSignature = '';

  final RxBool isRunning = false.obs;
  final RxString serverUrl = ''.obs;
  final RxString wsUrl = ''.obs;
  final RxString serverError = ''.obs;
  final RxList<LocalConnectPairingRequest> pendingRequests =
      <LocalConnectPairingRequest>[].obs;
  final RxList<LocalConnectClientSession> sessions =
      <LocalConnectClientSession>[].obs;

  @override
  void onInit() {
    super.onInit();
    _refreshState();
  }

  Future<void> start() async {
    if (isRunning.value) return;
    serverError.value = '';

    try {
      final bindAddress = InternetAddress.anyIPv4;
      final server = await HttpServer.bind(bindAddress, 0);
      _httpServer = server;

      final lanIp = await _resolveLanAddress();
      final url = 'http://${lanIp.address}:${server.port}';
      serverUrl.value = url;
      wsUrl.value = 'ws://${lanIp.address}:${server.port}/ws';
      isRunning.value = true;
      _log('server started at $url');

      _lastTrackSignature = _playbackSync.trackSignature();
      _lastPlaybackSignature = _playbackSync.playbackStateSignature();
      _lastQueueSignature = _playbackSync.queueSignature();

      _playbackTicker?.cancel();
      _playbackTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        _pairingManager.cleanupExpired();
        _refreshState();
        _tickPlaybackSync();
      });

      unawaited(
        server.forEach((request) async {
          await _handleRequest(request);
        }),
      );
    } catch (error) {
      serverError.value = 'No se pudo iniciar servidor local: $error';
      _log('server start failed: $error');
      await stop();
    }
  }

  Future<void> stop() async {
    _playbackTicker?.cancel();
    _playbackTicker = null;

    for (final socket in _socketByClientId.values) {
      try {
        await socket.close(WebSocketStatus.normalClosure, 'Server stopped');
      } catch (_) {}
    }
    _socketByClientId.clear();
    _authorizedSocketClients.clear();

    if (_httpServer != null) {
      await _httpServer!.close(force: true);
      _httpServer = null;
    }

    isRunning.value = false;
    serverUrl.value = '';
    wsUrl.value = '';
    _refreshState();
    _log('server stopped');
  }

  Future<void> approvePairingRequest(String requestId) async {
    final session = _pairingManager.approveRequest(requestId);
    _refreshState();
    if (session == null) return;

    _authorizedSocketClients.add(session.clientId);
    _pairingManager.touchClient(clientId: session.clientId, isConnected: true);
    _sendToClient(
      session.clientId,
      type: 'pairingApproved',
      payload: <String, dynamic>{
        'clientId': session.clientId,
        'token': session.token,
        'expiresAt': session.expiresAt.toIso8601String(),
      },
    );

    _broadcastPaired(
      type: 'pairingApproved',
      payload: <String, dynamic>{'clientId': session.clientId},
    );
    _refreshState();
  }

  Future<void> rejectPairingRequest(String requestId) async {
    final request = _pairingManager.rejectRequest(requestId);
    _refreshState();
    if (request == null) return;

    _sendToClient(
      request.clientId,
      type: 'pairingRejected',
      payload: <String, dynamic>{'clientId': request.clientId},
    );
    _broadcastAny(
      type: 'pairingRejected',
      payload: <String, dynamic>{'clientId': request.clientId},
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      _log('HTTP ${request.method} ${request.uri.path}');
      if (request.uri.path == '/ws') {
        await _handleWebSocketUpgrade(request);
        return;
      }

      switch ('${request.method} ${request.uri.path}') {
        case 'GET /':
          await _serveHtml(request, buildLocalConnectWebPage());
          return;
        case 'GET /health':
          await _writeJson(request.response, <String, dynamic>{
            'ok': true,
            'running': isRunning.value,
          });
          return;
        case 'POST /api/pairing/request':
          await _handlePairingRequest(request);
          return;
        case 'GET /api/pairing/status':
          await _handlePairingStatus(request);
          return;
        case 'GET /api/session':
          await _handleAuthorizedRequest(request, _handleSessionSnapshot);
          return;
        case 'GET /api/current':
          await _handleAuthorizedRequest(request, _handleCurrentTrack);
          return;
        case 'GET /api/queue':
          await _handleAuthorizedRequest(request, _handleQueue);
          return;
        case 'GET /stream/current':
          await _handleAuthorizedRequest(request, _handleCurrentStream);
          return;
        case 'GET /cover/current':
          await _handleAuthorizedRequest(request, _handleCurrentCover);
          return;
        case 'GET /cover/item':
          await _handleAuthorizedRequest(request, _handleItemCover);
          return;
        case 'POST /api/control/toggle':
          await _handleAuthorizedRequest(request, _handleToggleControl);
          return;
        case 'POST /api/control/next':
          await _handleAuthorizedRequest(request, _handleNextControl);
          return;
        case 'POST /api/control/previous':
          await _handleAuthorizedRequest(request, _handlePreviousControl);
          return;
        case 'POST /api/control/seek':
          await _handleAuthorizedRequest(request, _handleSeekControl);
          return;
        case 'POST /api/control/volume':
          await _handleAuthorizedRequest(request, _handleVolumeControl);
          return;
        case 'POST /api/control/play-item':
          await _handleAuthorizedRequest(request, _handlePlayItemControl);
          return;
        default:
          await _writeJson(request.response, <String, dynamic>{
            'error': 'Not found',
          }, statusCode: HttpStatus.notFound);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('LocalConnect request error: $error');
      }
      try {
        await _writeJson(request.response, <String, dynamic>{
          'error': 'internal_error',
        }, statusCode: HttpStatus.internalServerError);
      } catch (_) {}
    }
  }

  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final clientId = request.uri.queryParameters['clientId']?.trim() ?? '';
    if (clientId.isEmpty) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'client_id_required',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    final ws = await WebSocketTransformer.upgrade(request);
    _log('WS upgraded for client=$clientId');
    final previous = _socketByClientId[clientId];
    if (previous != null) {
      try {
        await previous.close(WebSocketStatus.normalClosure, 'Replaced');
      } catch (_) {}
    }
    _socketByClientId[clientId] = ws;

    final token = request.uri.queryParameters['token']?.trim() ?? '';
    final authorized =
        token.isNotEmpty &&
        _pairingManager.isTokenAuthorized(token: token, clientId: clientId);
    if (authorized) {
      _authorizedSocketClients.add(clientId);
      _pairingManager.touchClient(clientId: clientId, isConnected: true);
      _log('WS authorized for client=$clientId');
      _sendToClient(
        clientId,
        type: 'pairingApproved',
        payload: <String, dynamic>{'clientId': clientId, 'token': token},
      );
      _sendToClient(
        clientId,
        type: 'playbackStateChanged',
        payload: _playbackSync.buildSessionPayload(),
      );
    } else {
      _authorizedSocketClients.remove(clientId);
      _log('WS requires pairing for client=$clientId');
      _sendToClient(
        clientId,
        type: 'pairingRequired',
        payload: <String, dynamic>{'clientId': clientId},
      );
    }
    _refreshState();

    ws.listen(
      (_) {},
      onDone: () {
        _log('WS closed for client=$clientId');
        _socketByClientId.remove(clientId);
        _authorizedSocketClients.remove(clientId);
        _pairingManager.disconnectClient(clientId);
        _refreshState();
      },
      onError: (_) {
        _log('WS errored for client=$clientId');
        _socketByClientId.remove(clientId);
        _authorizedSocketClients.remove(clientId);
        _pairingManager.disconnectClient(clientId);
        _refreshState();
      },
      cancelOnError: true,
    );
  }

  Future<void> _handlePairingRequest(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final clientId = (body['clientId'] as String? ?? '').trim();
    final rawName = (body['clientName'] as String? ?? '').trim();
    final clientName = rawName.isEmpty ? 'Browser client' : rawName;

    if (clientId.isEmpty) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'client_id_required',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    final existingSession = _pairingManager.findSessionByClientId(clientId);
    if (existingSession != null && !existingSession.isExpired) {
      _log('pairing already approved for client=$clientId');
      final sessionPayload = _playbackSync.buildSessionPayload();
      await _writeJson(request.response, <String, dynamic>{
        'status': 'already_paired',
        'clientId': existingSession.clientId,
        'token': existingSession.token,
        'expiresAt': existingSession.expiresAt.toIso8601String(),
        'session': sessionPayload,
      });
      return;
    }

    final req = _pairingManager.requestPairing(
      clientId: clientId,
      clientName: clientName,
    );
    _log('pairing requested client=$clientId requestId=${req.id}');
    _refreshState();

    _broadcastAny(
      type: 'pairingRequested',
      payload: <String, dynamic>{
        'requestId': req.id,
        'clientId': req.clientId,
        'clientName': req.clientName,
        'requestedAt': req.requestedAt.toIso8601String(),
      },
    );

    await _writeJson(request.response, <String, dynamic>{
      'status': 'pending_approval',
      'requestId': req.id,
    });
  }

  Future<void> _handlePairingStatus(HttpRequest request) async {
    final clientId = request.uri.queryParameters['clientId']?.trim() ?? '';
    if (clientId.isEmpty) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'client_id_required',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    final session = _pairingManager.findSessionByClientId(clientId);
    if (session != null && !session.isExpired) {
      _log('pairing status approved for client=$clientId');
      await _writeJson(request.response, <String, dynamic>{
        'status': 'already_paired',
        'clientId': session.clientId,
        'token': session.token,
        'expiresAt': session.expiresAt.toIso8601String(),
        'session': _playbackSync.buildSessionPayload(),
      });
      return;
    }

    final pending = _pairingManager.findPendingByClientId(clientId);
    if (pending != null) {
      await _writeJson(request.response, <String, dynamic>{
        'status': 'pending_approval',
        'requestId': pending.id,
      });
      return;
    }

    await _writeJson(request.response, <String, dynamic>{
      'status': 'not_paired',
    });
  }

  Future<void> _handleAuthorizedRequest(
    HttpRequest request,
    Future<void> Function(HttpRequest request) handler,
  ) async {
    final token = _extractToken(request);
    if (token.isEmpty || !_pairingManager.isTokenAuthorized(token: token)) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'unauthorized',
      }, statusCode: HttpStatus.unauthorized);
      return;
    }

    final session = _pairingManager.findSessionByToken(token);
    if (session != null) {
      _pairingManager.touchClient(
        clientId: session.clientId,
        isConnected: _socketByClientId.containsKey(session.clientId),
      );
    }
    _refreshState();
    await handler(request);
  }

  Future<void> _handleSessionSnapshot(HttpRequest request) async {
    final payload = _playbackSync.buildSessionPayload();
    await _writeJson(request.response, payload);
  }

  Future<void> _handleCurrentTrack(HttpRequest request) async {
    await _writeJson(request.response, <String, dynamic>{
      'track': _playbackSync.currentTrackPayload(),
    });
  }

  Future<void> _handleQueue(HttpRequest request) async {
    await _writeJson(request.response, <String, dynamic>{
      'queue': _playbackSync.queuePayload(),
      'currentQueueIndex': _audioService.currentQueueIndex,
    });
  }

  Future<void> _handleToggleControl(HttpRequest request) async {
    await _audioService.toggle();
    await _writeJson(request.response, <String, dynamic>{'ok': true});
  }

  Future<void> _handleNextControl(HttpRequest request) async {
    await _audioService.next(withTransition: true);
    await _writeJson(request.response, <String, dynamic>{'ok': true});
  }

  Future<void> _handlePreviousControl(HttpRequest request) async {
    await _audioService.previous(withTransition: true);
    await _writeJson(request.response, <String, dynamic>{'ok': true});
  }

  Future<void> _handleSeekControl(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final positionMs = (body['positionMs'] as num?)?.toInt() ?? 0;
    await _audioService.seek(
      Duration(milliseconds: positionMs.clamp(0, 1 << 31)),
    );
    await _writeJson(request.response, <String, dynamic>{'ok': true});
  }

  Future<void> _handleVolumeControl(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final volume = (body['volume'] as num?)?.toDouble() ?? 1.0;
    await _audioService.setVolume(volume.clamp(0.0, 1.0));
    await _writeJson(request.response, <String, dynamic>{'ok': true});
  }

  Future<void> _handlePlayItemControl(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final itemId = (body['itemId'] as String?)?.trim() ?? '';
    final rawIndex = body['index'];
    final queue = _audioService.queueItems;

    int? targetIndex;
    if (itemId.isNotEmpty) {
      for (var i = 0; i < queue.length; i++) {
        if (queue[i].id == itemId) {
          targetIndex = i;
          break;
        }
      }
    }

    if (targetIndex == null && rawIndex is num) {
      final idx = rawIndex.toInt();
      if (idx >= 0 && idx < queue.length) {
        targetIndex = idx;
      }
    }

    if (targetIndex == null) {
      await _writeJson(
        request.response,
        <String, dynamic>{'error': 'queue_item_not_found'},
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    await _audioService.jumpToQueueIndex(targetIndex);
    await _writeJson(request.response, <String, dynamic>{
      'ok': true,
      'index': targetIndex,
    });
  }

  Future<void> _handleCurrentCover(HttpRequest request) async {
    final item = _audioService.currentItem.value;
    await _serveCoverForItem(request, item);
  }

  Future<void> _handleItemCover(HttpRequest request) async {
    final itemId = request.uri.queryParameters['itemId']?.trim() ?? '';
    if (itemId.isEmpty) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'item_id_required',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    MediaItem? item;
    final current = _audioService.currentItem.value;
    if (current != null && current.id == itemId) {
      item = current;
    } else {
      for (final queueItem in _audioService.queueItems) {
        if (queueItem.id == itemId) {
          item = queueItem;
          break;
        }
      }
    }

    await _serveCoverForItem(request, item);
  }

  Future<void> _serveCoverForItem(HttpRequest request, MediaItem? item) async {
    if (item == null) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'no_track',
      }, statusCode: HttpStatus.notFound);
      return;
    }

    final local = item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (await file.exists()) {
        await _serveBinaryFile(request, file);
        return;
      }
    }

    final remote = item.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) {
      request.response.statusCode = HttpStatus.temporaryRedirect;
      request.response.headers.set(HttpHeaders.locationHeader, remote);
      await request.response.close();
      return;
    }

    await _writeJson(request.response, <String, dynamic>{
      'error': 'cover_unavailable',
    }, statusCode: HttpStatus.notFound);
  }

  Future<void> _handleCurrentStream(HttpRequest request) async {
    final variant = _audioService.currentVariant.value;
    final item = _audioService.currentItem.value;
    if (variant == null || item == null) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'no_track_loaded',
      }, statusCode: HttpStatus.conflict);
      return;
    }

    final localPath = variant.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        await _serveAudioFileWithRange(request, file);
        return;
      }
    }

    final remote = item.playableUrl.trim();
    if (remote.startsWith('http://') || remote.startsWith('https://')) {
      request.response.statusCode = HttpStatus.temporaryRedirect;
      request.response.headers.set(HttpHeaders.locationHeader, remote);
      await request.response.close();
      return;
    }

    await _writeJson(request.response, <String, dynamic>{
      'error': 'stream_unavailable',
    }, statusCode: HttpStatus.notFound);
  }

  Future<void> _serveAudioFileWithRange(HttpRequest request, File file) async {
    final totalLength = await file.length();
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.headers.contentType = ContentType.parse(
      _audioContentTypeFor(file.path),
    );

    if (rangeHeader == null || !rangeHeader.startsWith('bytes=')) {
      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = totalLength;
      await request.response.addStream(file.openRead());
      await request.response.close();
      return;
    }

    final range = rangeHeader.substring('bytes='.length).split('-');
    final start = int.tryParse(range.first) ?? 0;
    final end = (range.length > 1 && range[1].isNotEmpty)
        ? (int.tryParse(range[1]) ?? (totalLength - 1))
        : (totalLength - 1);

    final safeStart = start.clamp(0, totalLength - 1);
    final safeEnd = end.clamp(safeStart, totalLength - 1);
    final chunkLength = safeEnd - safeStart + 1;

    request.response.statusCode = HttpStatus.partialContent;
    request.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $safeStart-$safeEnd/$totalLength',
    );
    request.response.contentLength = chunkLength;

    await request.response.addStream(file.openRead(safeStart, safeEnd + 1));
    await request.response.close();
  }

  Future<void> _serveBinaryFile(HttpRequest request, File file) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.set(
      HttpHeaders.contentTypeHeader,
      _contentTypeFor(file.path),
    );
    request.response.contentLength = await file.length();
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  void _tickPlaybackSync() {
    final trackSig = _playbackSync.trackSignature();
    final playbackSig = _playbackSync.playbackStateSignature();
    final queueSig = _playbackSync.queueSignature();

    if (trackSig != _lastTrackSignature) {
      _lastTrackSignature = trackSig;
      _broadcastPaired(
        type: 'currentTrackChanged',
        payload: _playbackSync.buildSessionPayload(),
      );
    }

    if (playbackSig != _lastPlaybackSignature) {
      _lastPlaybackSignature = playbackSig;
      _broadcastPaired(
        type: 'playbackStateChanged',
        payload: _playbackSync.buildSessionPayload(),
      );
    }

    if (queueSig != _lastQueueSignature) {
      _lastQueueSignature = queueSig;
      _broadcastPaired(
        type: 'queueChanged',
        payload: _playbackSync.buildSessionPayload(),
      );
    }

    _broadcastPaired(
      type: 'progressUpdated',
      payload: _playbackSync.buildProgressPayload(),
    );
  }

  void _broadcastPaired({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final pairedClientIds = _authorizedSocketClients.toList();
    final staleClientIds = <String>[];
    for (final clientId in pairedClientIds) {
      final touched = _pairingManager.touchClient(
        clientId: clientId,
        isConnected: _socketByClientId.containsKey(clientId),
      );
      if (touched == null) {
        staleClientIds.add(clientId);
        continue;
      }
      _sendToClient(clientId, type: type, payload: payload);
    }

    for (final clientId in staleClientIds) {
      _authorizedSocketClients.remove(clientId);
      final socket = _socketByClientId.remove(clientId);
      if (socket != null) {
        try {
          socket.add(
            jsonEncode(<String, dynamic>{
              'type': 'pairingRequired',
              'payload': <String, dynamic>{
                'clientId': clientId,
                'reason': 'expired',
              },
              'sentAt': DateTime.now().toIso8601String(),
            }),
          );
          unawaited(
            socket.close(WebSocketStatus.policyViolation, 'Session expired'),
          );
        } catch (_) {}
      }
      _pairingManager.disconnectClient(clientId);
    }
  }

  void _broadcastAny({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final clientIds = _socketByClientId.keys.toList();
    for (final clientId in clientIds) {
      _sendToClient(clientId, type: type, payload: payload);
    }
  }

  void _sendToClient(
    String clientId, {
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final socket = _socketByClientId[clientId];
    if (socket == null) return;
    try {
      socket.add(
        jsonEncode(<String, dynamic>{
          'type': type,
          'payload': payload,
          'sentAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      _socketByClientId.remove(clientId);
      _authorizedSocketClients.remove(clientId);
      _pairingManager.disconnectClient(clientId);
    }
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  String _extractToken(HttpRequest request) {
    final queryToken = request.uri.queryParameters['token']?.trim() ?? '';
    if (queryToken.isNotEmpty) return queryToken;

    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader == null) return '';
    if (!authHeader.startsWith('Bearer ')) return '';
    return authHeader.substring('Bearer '.length).trim();
  }

  Future<void> _serveHtml(HttpRequest request, String html) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    request.response.headers.set(HttpHeaders.expiresHeader, '0');
    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, dynamic> jsonMap, {
    int statusCode = HttpStatus.ok,
  }) async {
    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    response.headers.set(HttpHeaders.expiresHeader, '0');
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(jsonMap));
    await response.close();
  }

  Future<InternetAddress> _resolveLanAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    final wifiCandidates = <InternetAddress>[];
    final otherCandidates = <InternetAddress>[];

    for (final iface in interfaces) {
      final ifaceName = iface.name.toLowerCase();
      final isWifiLike =
          ifaceName.contains('wlan') ||
          ifaceName.contains('wifi') ||
          ifaceName.contains('wi-fi') ||
          ifaceName.startsWith('en');
      final isLikelyVirtual =
          ifaceName.contains('rmnet') ||
          ifaceName.contains('tun') ||
          ifaceName.contains('tap') ||
          ifaceName.contains('vpn') ||
          ifaceName.contains('p2p') ||
          ifaceName.contains('veth') ||
          ifaceName.contains('docker') ||
          ifaceName.contains('bridge');

      for (final address in iface.addresses) {
        if (!_isPrivateIpv4(address.address)) continue;
        if (isLikelyVirtual) continue;
        if (isWifiLike) {
          wifiCandidates.add(address);
        } else {
          otherCandidates.add(address);
        }
      }
    }

    if (wifiCandidates.isNotEmpty) {
      return wifiCandidates.first;
    }
    if (otherCandidates.isNotEmpty) {
      return otherCandidates.first;
    }

    return InternetAddress.loopbackIPv4;
  }

  bool _isPrivateIpv4(String ip) {
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('192.168.')) return true;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    if (parts[0] == '172') {
      final second = int.tryParse(parts[1]) ?? -1;
      return second >= 16 && second <= 31;
    }
    return false;
  }

  String _contentTypeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  String _audioContentTypeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
      case '.aac':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
      case '.opus':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      default:
        return 'application/octet-stream';
    }
  }

  void _refreshState() {
    pendingRequests.assignAll(_pairingManager.pendingRequests);
    sessions.assignAll(_pairingManager.sessions);
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[LocalConnect] $message');
  }
}
