import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path/path.dart' as p;

import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/services/audio_service.dart';
import '../../../app/data/local/local_library_store.dart';
import '../../../app/services/notification_service.dart';
import '../../artists/data/artist_store.dart';
import '../data/server/local_connect_pairing_manager.dart';
import '../data/server/local_connect_playback_sync.dart';
import '../data/web/local_connect_web_page.dart';
import '../domain/entities/local_connect_models.dart';

class LocalConnectServerService extends GetxService {
  LocalConnectServerService({Duration tokenTtl = const Duration(minutes: 15)})
    : _pairingManager = LocalConnectPairingManager(tokenTtl: tokenTtl);

  final AudioService _audioService = Get.find<AudioService>();
  final LocalLibraryStore _localLibraryStore = Get.find<LocalLibraryStore>();
  final ArtistStore _artistStore = Get.isRegistered<ArtistStore>()
      ? Get.find<ArtistStore>()
      : ArtistStore(Get.find<GetStorage>());
  final LocalConnectPairingManager _pairingManager;

  late final LocalConnectPlaybackSync _playbackSync = LocalConnectPlaybackSync(
    audioService: _audioService,
    artistStore: _artistStore,
    localLibraryStore: _localLibraryStore,
  );

  HttpServer? _httpServer;
  final Map<String, WebSocket> _socketByClientId = <String, WebSocket>{};
  final Set<String> _authorizedSocketClients = <String>{};
  Timer? _playbackTicker;

  String _lastTrackSignature = '';
  String _lastPlaybackSignature = '';
  String _lastQueueSignature = '';
  String _lastStateSignature = '';
  DateTime _lastMaintenanceAt = DateTime.fromMillisecondsSinceEpoch(0);

  final RxBool isRunning = false.obs;
  final RxString serverUrl = ''.obs;
  final RxString wsUrl = ''.obs;
  final RxString serverError = ''.obs;
  final RxList<LocalConnectPairingRequest> pendingRequests =
      <LocalConnectPairingRequest>[].obs;
  final RxList<LocalConnectClientSession> sessions =
      <LocalConnectClientSession>[].obs;
  Worker? _pendingNotificationWorker;
  String? _lastNotifiedRequestId;

  @override
  void onInit() {
    super.onInit();
    _refreshState();
    _pendingNotificationWorker = ever<List<LocalConnectPairingRequest>>(
      pendingRequests,
      _onPendingRequestsChanged,
    );
  }

  @override
  void onClose() {
    _pendingNotificationWorker?.dispose();
    super.onClose();
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
      _playbackTicker = Timer.periodic(const Duration(milliseconds: 450), (_) {
        _runPeriodicMaintenance();
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
    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().showConnectApproved(
        session.clientName,
      );
    }
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

  Future<void> revokeSession(String clientId) async {
    final session = _pairingManager.revokeSession(clientId);
    if (session == null) return;
    await _closeClientSession(
      clientId: session.clientId,
      reason: 'revoked',
      clientName: session.clientName,
    );
    _refreshState();
    Get.snackbar(
      tr('connect.title'),
      tr('connect.session_revoked', args: [session.clientName]),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> revokeAllSessions() async {
    final revoked = _pairingManager.revokeAllSessions();
    if (revoked.isEmpty) return;
    for (final session in revoked) {
      await _closeClientSession(
        clientId: session.clientId,
        reason: 'revoked_all',
        clientName: session.clientName,
      );
    }
    _refreshState();
    Get.snackbar(
      tr('connect.title'),
      tr('connect.all_sessions_revoked'),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Map<String, String> _localConnectWebTranslations() {
    String value(String key, String fallback) {
      final translationKey = 'local_connect.web.$key';
      final translated = tr(translationKey);
      if (translated == translationKey) return fallback;
      return translated;
    }

    return <String, String>{
      'title': value('title', 'Listenfy Local Connect'),
      'notPaired': value('not_paired', 'Not paired'),
      'pairingRequired': value('pairing_required', 'Pairing required'),
      'pairingInstructions': value(
        'pairing_instructions',
        'Request access from this browser and approve on your phone.',
      ),
      'requestPairing': value('request_pairing', 'Request pairing'),
      'remoteSession': value('remote_session', 'Remote session'),
      'noTrack': value('no_track', 'No track'),
      'info': value('info', 'Info'),
      'waitingSession': value('waiting_session', 'Waiting session'),
      'source': value('source', 'Source'),
      'notFavorite': value('not_favorite', 'Not favorite'),
      'favorite': value('favorite', 'Favorite'),
      'currentTime': value('current_time', 'Current Time'),
      'duration': value('duration', 'Duration'),
      'queuePosition': value('queue_position', 'Queue Position'),
      'progress': value('progress', 'Progress'),
      'trackHistory': value('track_history', 'Track history'),
      'realAppData': value('real_app_data', 'Real app data'),
      'noHistoryYet': value('no_history_yet', 'No history yet'),
      'plays': value('plays', 'Plays'),
      'completed': value('completed', 'Completed'),
      'skips': value('skips', 'Skips'),
      'retention': value('retention', 'Retention'),
      'lastPlayed': value('last_played', 'Last played'),
      'artistData': value('artist_data', 'Artist Data'),
      'unknownArtist': value('unknown_artist', 'Unknown artist'),
      'unknown': value('unknown', 'Unknown'),
      'type': value('type', 'Type'),
      'queueTracks': value('queue_tracks', 'Queue tracks'),
      'queuePlays': value('queue_plays', 'Queue plays'),
      'queueCompletes': value('queue_completes', 'Queue completes'),
      'queueSkips': value('queue_skips', 'Queue skips'),
      'queueAvg': value('queue_avg', 'Queue avg'),
      'nextTracksByArtist': value(
        'next_tracks_by_artist',
        'Next tracks by this artist',
      ),
      'noArtistDataYet': value(
        'no_artist_data_yet',
        'No artist data available yet.',
      ),
      'noArtistInfoForTrack': value(
        'no_artist_info_for_track',
        'No artist info available for this track.',
      ),
      'noMoreArtistTracks': value(
        'no_more_artist_tracks',
        'No more tracks from this artist in the current queue.',
      ),
      'queue': value('queue', 'Queue'),
      'track': value('track', 'track'),
      'tracks': value('tracks', 'tracks'),
      'playUnit': value('play_unit', 'play'),
      'playsUnit': value('plays_unit', 'plays'),
      'previous': value('previous', 'Previous'),
      'play': value('play', 'Play'),
      'pause': value('pause', 'Pause'),
      'next': value('next', 'Next'),
      'shuffle': value('shuffle', 'Shuffle'),
      'shuffleOn': value('shuffle_on', 'Shuffle On'),
      'shuffleOff': value('shuffle_off', 'Shuffle Off'),
      'volume': value('volume', 'Volume'),
      'buffering': value('buffering', 'Buffering'),
      'playing': value('playing', 'Playing'),
      'paused': value('paused', 'Paused'),
      'pairedSyncing': value('paired_syncing', 'Paired · Syncing...'),
      'pairedLive': value('paired_live', 'Paired · Live'),
      'pairedReconnecting': value(
        'paired_reconnecting',
        'Paired · Reconnecting',
      ),
      'waitingApproval': value('waiting_approval', 'Waiting approval'),
      'pairingApproved': value('pairing_approved', 'Pairing approved.'),
      'waitingApprovalPhone': value(
        'waiting_approval_phone',
        'Waiting for approval on your phone...',
      ),
      'sendingRequest': value('sending_request', 'Sending request...'),
      'alreadyPaired': value('already_paired', 'Already paired.'),
      'requestSent': value(
        'request_sent',
        'Request sent. Approve on your phone.',
      ),
      'couldNotRequestPairing': value(
        'could_not_request_pairing',
        'Could not request pairing.',
      ),
      'sessionExpired': value(
        'session_expired',
        'Session expired. Request pairing again.',
      ),
      'syncUnstable': value('sync_unstable', 'Sync unstable. Reconnecting...'),
      'sessionEnded': value('session_ended', 'Session ended on phone.'),
      'sessionRevoked': value(
        'session_revoked_web',
        'Session revoked on phone.',
      ),
      'pairingRejected': value(
        'pairing_rejected',
        'Pairing rejected on phone.',
      ),
      'unknownSource': value('unknown_source', 'unknown source'),
      'favShort': value('fav_short', 'fav'),
      'noRetention': value('no_retention', 'no retention'),
      'roleCollab': value('role_collab', 'feat/collab'),
      'rolePrincipal': value('role_principal', 'principal'),
      'member': value('member', 'member'),
      'members': value('members', 'members'),
      'estimatedType': value('estimated_type', 'Estimated type'),
      'artistKindCollab': value(
        'artist_kind_collab',
        'collaboration / multiple artists',
      ),
      'artistKindBand': value('artist_kind_band', 'Duo, band, or music group'),
      'artistKindSoloist': value(
        'artist_kind_soloist',
        'Soloist, DJ, or musician',
      ),
      'largeQueueOptimized': value(
        'large_queue_optimized',
        'Large queue optimized',
      ),
      'showingAroundCurrent': value(
        'showing_around_current',
        'Showing tracks around the current song',
      ),
    };
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
          await _serveHtml(
            request,
            buildLocalConnectWebPage(
              translations: _localConnectWebTranslations(),
            ),
          );
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
        case 'GET /cover/artist':
          await _handleAuthorizedRequest(request, _handleArtistCover);
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
        case 'POST /api/control/shuffle':
          await _handleAuthorizedRequest(request, _handleShuffleControl);
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
        payload: _playbackSync.buildSessionPayload(includeQueue: true),
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

  Future<void> _handleShuffleControl(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final rawEnabled = body['enabled'];
    final enabled = rawEnabled is bool
        ? rawEnabled
        : !_audioService.shuffleEnabled;
    await _audioService.setShuffle(enabled);
    await _writeJson(request.response, <String, dynamic>{
      'ok': true,
      'shuffleEnabled': _audioService.shuffleEnabled,
    });
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
      await _writeJson(request.response, <String, dynamic>{
        'error': 'queue_item_not_found',
      }, statusCode: HttpStatus.badRequest);
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

  Future<void> _handleArtistCover(HttpRequest request) async {
    final artistKey = request.uri.queryParameters['artistKey']?.trim() ?? '';
    if (artistKey.isEmpty) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'artist_key_required',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    final profile = _artistStore.getByKeySync(artistKey);
    if (profile == null) {
      await _writeJson(request.response, <String, dynamic>{
        'error': 'artist_not_found',
      }, statusCode: HttpStatus.notFound);
      return;
    }

    final local = profile.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (await file.exists()) {
        await _serveBinaryFile(request, file);
        return;
      }
    }

    final remote = profile.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) {
      request.response.statusCode = HttpStatus.temporaryRedirect;
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      request.response.headers.set(HttpHeaders.expiresHeader, '0');
      request.response.headers.set(HttpHeaders.locationHeader, remote);
      await request.response.close();
      return;
    }

    await _writeJson(request.response, <String, dynamic>{
      'error': 'artist_cover_unavailable',
    }, statusCode: HttpStatus.notFound);
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
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      request.response.headers.set(HttpHeaders.expiresHeader, '0');
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
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    request.response.headers.set(HttpHeaders.expiresHeader, '0');
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
        payload: _playbackSync.buildSessionPayload(includeQueue: false),
      );
    }

    if (playbackSig != _lastPlaybackSignature) {
      _lastPlaybackSignature = playbackSig;
      _broadcastPaired(
        type: 'playbackStateChanged',
        payload: _playbackSync.buildSessionPayload(includeQueue: false),
      );
    }

    if (queueSig != _lastQueueSignature) {
      _lastQueueSignature = queueSig;
      _broadcastPaired(
        type: 'queueChanged',
        payload: _playbackSync.buildSessionPayload(includeQueue: true),
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
    final isProgressUpdate = type == 'progressUpdated';
    for (final clientId in pairedClientIds) {
      final touched = isProgressUpdate
          ? _pairingManager.findSessionByClientId(clientId)
          : _pairingManager.touchClient(
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

  Future<void> _closeClientSession({
    required String clientId,
    required String reason,
    required String clientName,
  }) async {
    _authorizedSocketClients.remove(clientId);
    final socket = _socketByClientId.remove(clientId);
    if (socket == null) return;
    try {
      socket.add(
        jsonEncode(<String, dynamic>{
          'type': 'sessionRevoked',
          'payload': <String, dynamic>{
            'clientId': clientId,
            'clientName': clientName,
            'reason': reason,
          },
          'sentAt': DateTime.now().toIso8601String(),
        }),
      );
      await socket.close(WebSocketStatus.policyViolation, 'Session revoked');
    } catch (_) {}
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

  void _runPeriodicMaintenance() {
    final now = DateTime.now();
    if (now.difference(_lastMaintenanceAt) < const Duration(seconds: 10)) {
      return;
    }
    _lastMaintenanceAt = now;
    _pairingManager.cleanupExpired();
    _refreshState();
  }

  void _refreshState() {
    final nextPending = _pairingManager.pendingRequests;
    final nextSessions = _pairingManager.sessions;
    final nextSignature = [
      for (final request in nextPending)
        '${request.id}:${request.clientId}:${request.requestedAt.millisecondsSinceEpoch}',
      '#',
      for (final session in nextSessions)
        '${session.clientId}:${session.expiresAt.millisecondsSinceEpoch}:${session.isConnected}',
    ].join('|');

    if (nextSignature == _lastStateSignature) return;
    _lastStateSignature = nextSignature;
    pendingRequests.assignAll(nextPending);
    sessions.assignAll(nextSessions);
  }

  void _onPendingRequestsChanged(List<LocalConnectPairingRequest> requests) {
    if (requests.isEmpty) return;

    final newest = requests.first;
    if (_lastNotifiedRequestId == newest.id) return;
    _lastNotifiedRequestId = newest.id;

    final clientLabel = newest.clientName.trim().isEmpty
        ? tr('connect.web_client')
        : newest.clientName.trim();
    final truncatedLabel = clientLabel.length > 42
        ? '${clientLabel.substring(0, 42)}...'
        : clientLabel;

    if (Get.isRegistered<NotificationService>()) {
      unawaited(
        Get.find<NotificationService>().showConnectRequest(truncatedLabel),
      );
    }

    // La notificación del sistema debe publicarse incluso si el usuario está
    // viendo Connect. Solo evitamos duplicarla con un snackbar en esa pantalla.
    if (Get.currentRoute == AppRoutes.localConnect) return;

    Get.snackbar(
      tr('connect.title'),
      tr('connect.new_pairing', args: [truncatedLabel]),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 7),
      margin: const EdgeInsets.all(12),
      mainButton: TextButton(
        onPressed: () {
          if (Get.currentRoute != AppRoutes.localConnect) {
            Get.toNamed(AppRoutes.localConnect);
          }
        },
        child: Text(tr('connect.review')),
      ),
    );
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[LocalConnect] $message');
  }
}
