import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import '../data/server/local_connect_http_policy.dart';
import '../data/server/local_connect_playback_sync.dart';
import '../data/web/local_connect_web_page.dart';
import '../domain/entities/local_connect_models.dart';

class LocalConnectServerService extends GetxService {
  LocalConnectServerService({
    Duration tokenTtl = const Duration(minutes: 15),
    AudioService? audioService,
    LocalLibraryStore? libraryStore,
    ArtistStore? artistStore,
  }) : _pairingManager = LocalConnectPairingManager(tokenTtl: tokenTtl),
       _audioService = audioService ?? Get.find<AudioService>(),
       _localLibraryStore = libraryStore ?? Get.find<LocalLibraryStore>(),
       _artistStore =
           artistStore ??
           (Get.isRegistered<ArtistStore>()
               ? Get.find<ArtistStore>()
               : ArtistStore(Get.find<GetStorage>()));

  final AudioService _audioService;
  final LocalLibraryStore _localLibraryStore;
  final ArtistStore _artistStore;
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
  bool _starting = false;
  int _activeRequests = 0;
  final Map<HttpResponse, String> _activeStreams = {};
  final Map<String, (DateTime, int)> _pairingAttempts = {};
  bool _privatePlaybackWasActive = false;
  DateTime _lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

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
    unawaited(stop());
    super.onClose();
  }

  Future<void> start({InternetAddress? address}) async {
    if (isRunning.value || _starting) return;
    _starting = true;
    serverError.value = '';

    try {
      final lanIp = address ?? await _resolveLanAddress();
      final server = await HttpServer.bind(lanIp, 0);
      server.idleTimeout = const Duration(seconds: 15);
      _httpServer = server;

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
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    isRunning.value = false;
    _playbackTicker?.cancel();
    _playbackTicker = null;
    final sockets = _socketByClientId.values.toList();
    _socketByClientId.clear();
    _authorizedSocketClients.clear();
    _pairingManager.revokeAllSessions();
    _pairingAttempts.clear();
    for (final response in _activeStreams.keys.toList()) {
      unawaited(_abortResponse(response));
    }
    _activeStreams.clear();
    for (final socket in sockets) {
      unawaited(socket.close(WebSocketStatus.normalClosure, 'Server stopped'));
    }
    final server = _httpServer;
    _httpServer = null;
    if (server != null) await server.close(force: true);
    serverUrl.value = '';
    wsUrl.value = '';
    _refreshState();
  }

  Future<void> approvePairingRequest(String requestId) async {
    final session = _pairingManager.approveRequest(requestId);
    _refreshState();
    if (session == null) return;

    // Credentials are retrieved only by the browser holding the random receipt.
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
  }

  Future<void> revokeSession(String clientId) async {
    final session = _pairingManager.revokeSession(clientId);
    if (session == null) return;
    _abortStreamsFor(session.clientId);
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
      _abortStreamsFor(session.clientId);
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
      'lyrics': value('lyrics', 'Lyrics'),
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

  Map<String, String> _localConnectWebPalette() {
    final scheme = Get.theme.colorScheme;
    final accent = _neonAccent(scheme.primary, scheme.brightness);
    final accentOn = accent.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    return <String, String>{
      'bg': _cssColor(scheme.surface),
      'bgElevated': _cssColor(scheme.surfaceContainer),
      'surface': _cssColor(scheme.surfaceContainerHigh),
      'surface2': _cssColor(scheme.surfaceContainerHighest),
      'surface3': _cssColor(scheme.surfaceContainer),
      'text': _cssColor(scheme.onSurface),
      'muted': _cssColor(scheme.onSurfaceVariant),
      'muted2': _cssColor(scheme.outline),
      'border': _cssColor(scheme.outlineVariant),
      'accent': _cssColor(accent),
      'accentRgb': _cssRgb(accent),
      'accentOn': _cssColor(accentOn),
      'accentSoft': _cssColor(accent, alpha: 0.15),
      'accentBorder': _cssColor(accent, alpha: 0.46),
      'neonBorder': _cssColor(accent, alpha: 0.7),
      'neonGlow': _cssColor(accent, alpha: 0.24),
    };
  }

  Color _neonAccent(Color source, Brightness brightness) {
    final hsl = HSLColor.fromColor(source);
    if (hsl.saturation < 0.08) {
      return HSLColor.fromAHSL(
        1,
        hsl.hue,
        0.03,
        brightness == Brightness.dark ? 0.78 : 0.5,
      ).toColor();
    }
    return hsl
        .withSaturation(max(hsl.saturation, 0.64))
        .withLightness(
          brightness == Brightness.dark
              ? max(hsl.lightness, 0.62)
              : max(hsl.lightness, 0.5),
        )
        .toColor();
  }

  String _cssRgb(Color color) =>
      '${_colorChannel(color.r)}, ${_colorChannel(color.g)}, ${_colorChannel(color.b)}';

  String _cssColor(Color color, {double? alpha}) {
    final opacity = alpha ?? color.a;
    final hex = <int>[
      _colorChannel(color.r),
      _colorChannel(color.g),
      _colorChannel(color.b),
    ].map((channel) => channel.toRadixString(16).padLeft(2, '0')).join();
    final alphaHex = _colorChannel(opacity).toRadixString(16).padLeft(2, '0');
    return opacity >= 0.999 ? '#$hex' : '#$hex$alphaHex';
  }

  int _colorChannel(double value) => (value.clamp(0.0, 1.0) * 255).round();

  Future<void> _handleRequest(HttpRequest request) async {
    var counted = false;
    try {
      request.response.headers
        ..set('X-Content-Type-Options', 'nosniff')
        ..set('X-Frame-Options', 'DENY')
        ..set('Referrer-Policy', 'no-referrer')
        ..set('Cache-Control', 'no-store')
        ..set(
          'Content-Security-Policy',
          "default-src 'none'; frame-ancestors 'none'; sandbox",
        );
      if (!isRunning.value ||
          !LocalConnectHttpPolicy.allowsRequest(
            server: Uri.parse(serverUrl.value),
            host: request.headers.value(HttpHeaders.hostHeader),
            origin: request.headers.value('origin'),
            fetchSite: request.headers.value('sec-fetch-site'),
          )) {
        throw const ConnectHttpException(403, 'untrusted_origin');
      }
      if (_activeRequests >= 64) {
        throw const ConnectHttpException(429, 'too_many_requests');
      }
      _activeRequests++;
      counted = true;
      _log('HTTP ${request.method} ${request.uri.path}');
      if (request.uri.path == '/ws') {
        await _handleWebSocketUpgrade(request);
        return;
      }

      switch ('${request.method} ${request.uri.path}') {
        case 'GET /':
          final random = Random.secure();
          final nonce = base64UrlEncode(
            List<int>.generate(24, (_) => random.nextInt(256)),
          );
          request.response.headers.set(
            'Content-Security-Policy',
            "default-src 'none'; script-src 'nonce-$nonce'; style-src 'unsafe-inline'; "
                "img-src 'self' http: https:; media-src 'self' http: https:; "
                "connect-src 'self' ${wsUrl.value}; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
          );
          await _serveHtml(
            request,
            buildLocalConnectWebPage(
              translations: _localConnectWebTranslations(),
              palette: _localConnectWebPalette(),
              scriptNonce: nonce,
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
      final problem = error is ConnectHttpException
          ? error
          : error is FormatException ||
                error is TypeError ||
                error is ArgumentError
          ? const ConnectHttpException(400, 'invalid_request')
          : const ConnectHttpException(500, 'internal_error');
      // Exception strings can contain URLs/tokens; log only the error category.
      _log('HTTP failure: ${problem.code}');
      try {
        request.response.persistentConnection = false;
        await _writeJson(request.response, {
          'error': problem.code,
        }, statusCode: problem.statusCode);
      } catch (_) {}
    } finally {
      if (counted) _activeRequests--;
    }
  }

  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final clientId = request.uri.queryParameters['clientId']?.trim() ?? '';
    final token = _extractToken(request);
    if (request.method != 'GET' ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      throw const ConnectHttpException(400, 'invalid_upgrade');
    }
    if (clientId.isEmpty ||
        !_pairingManager.isTokenAuthorized(token: token, clientId: clientId)) {
      throw const ConnectHttpException(401, 'unauthorized');
    }
    final ws = await WebSocketTransformer.upgrade(
      request,
      compression: CompressionOptions.compressionOff,
    );
    if (!isRunning.value ||
        !_pairingManager.isTokenAuthorized(token: token, clientId: clientId)) {
      await ws.close(WebSocketStatus.policyViolation, 'Session ended');
      return;
    }
    final previous = _socketByClientId[clientId];
    _socketByClientId[clientId] = ws;
    _authorizedSocketClients.add(clientId);
    if (previous != null) {
      unawaited(previous.close(WebSocketStatus.normalClosure, 'Replaced'));
    }
    ws.pingInterval = const Duration(seconds: 20);
    _pairingManager.touchClient(clientId: clientId, isConnected: true);
    void disconnected() {
      // The old connection may finish after its replacement is already active.
      if (!identical(_socketByClientId[clientId], ws)) return;
      _socketByClientId.remove(clientId);
      _authorizedSocketClients.remove(clientId);
      _pairingManager.disconnectClient(clientId);
      _refreshState();
    }

    ws.listen(
      (_) {
        unawaited(
          ws.close(WebSocketStatus.policyViolation, 'Unexpected message'),
        );
        disconnected();
      },
      onDone: disconnected,
      onError: (_) => disconnected(),
      cancelOnError: true,
    );
    _sendToClient(
      clientId,
      type: _audioService.isInPrivatePlaybackSession
          ? 'privatePlaybackLocked'
          : 'playbackStateChanged',
      payload: _audioService.isInPrivatePlaybackSession
          ? _privatePlaybackPayload()
          : _playbackSync.buildSessionPayload(),
    );
    _refreshState();
  }

  Future<void> _handlePairingRequest(HttpRequest request) async {
    final now = DateTime.now();
    _pairingAttempts.removeWhere(
      (_, entry) => now.difference(entry.$1) > const Duration(minutes: 1),
    );
    final ip = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final previous = _pairingAttempts[ip];
    if ((previous?.$2 ?? 0) >= 6 ||
        (_pairingAttempts.length >= 128 && previous == null)) {
      throw const ConnectHttpException(429, 'pairing_rate_limited');
    }
    _pairingAttempts[ip] = (previous?.$1 ?? now, (previous?.$2 ?? 0) + 1);
    final body = await _readJsonBody(request);
    final clientId = (body['clientId'] as String? ?? '').trim();
    final name = (body['clientName'] as String? ?? '').trim();
    LocalConnectPairingRequest pending;
    try {
      pending = _pairingManager.requestPairing(
        clientId: clientId,
        clientName: name.isEmpty ? 'Browser client' : name,
      );
    } on StateError {
      throw const ConnectHttpException(409, 'pairing_unavailable');
    }
    _refreshState();
    await _writeJson(request.response, {
      'status': 'pending_approval',
      'requestId': pending.id,
    });
  }

  Future<void> _handlePairingStatus(HttpRequest request) async {
    final clientId = request.uri.queryParameters['clientId']?.trim() ?? '';
    final receipt = request.headers.value('x-listenfy-pairing') ?? '';
    final tokenSession = _pairingManager.findSessionByToken(
      _extractToken(request),
    );
    final session = tokenSession?.clientId == clientId
        ? tokenSession
        : _pairingManager.sessionForReceipt(clientId, receipt);
    if (session != null) {
      await _writeJson(request.response, {
        'status': 'already_paired',
        'clientId': session.clientId,
        'token': session.token,
        'expiresAt': session.expiresAt.toIso8601String(),
      });
      return;
    }
    final pending = _pairingManager.findPendingByClientId(clientId);
    await _writeJson(request.response, {
      'status': pending != null && receipt.isNotEmpty && pending.id == receipt
          ? 'pending_approval'
          : 'not_paired',
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
    if (_audioService.isInPrivatePlaybackSession) {
      await _writePrivatePlaybackLocked(request);
      return;
    }
    await handler(request);
  }

  Map<String, dynamic> _privatePlaybackPayload() {
    return <String, dynamic>{
      'privatePlayback': true,
      'reason': 'lyrics_sync',
      'message': tr('local_connect.private_playback_locked.message'),
    };
  }

  Future<void> _writePrivatePlaybackLocked(HttpRequest request) async {
    await _writeJson(request.response, <String, dynamic>{
      'error': 'private_playback_locked',
      ..._privatePlaybackPayload(),
    }, statusCode: HttpStatus.locked);
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
    final value = body['positionMs'];
    if (value is! num || !value.isFinite) {
      throw const ConnectHttpException(400, 'invalid_position');
    }
    final positionMs = value.toInt();
    await _audioService.seek(
      Duration(milliseconds: positionMs.clamp(0, 1 << 31)),
    );
    await _writeJson(request.response, <String, dynamic>{'ok': true});
  }

  Future<void> _handleVolumeControl(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final value = body['volume'];
    if (value is! num || !value.isFinite) {
      throw const ConnectHttpException(400, 'invalid_volume');
    }
    final volume = value.toDouble();
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
    if (LocalConnectHttpPolicy.isRemoteUrl(remote)) {
      request.response.statusCode = HttpStatus.temporaryRedirect;
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      request.response.headers.set(HttpHeaders.expiresHeader, '0');
      request.response.headers.set(HttpHeaders.locationHeader, remote!);
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
    if (LocalConnectHttpPolicy.isRemoteUrl(remote)) {
      request.response.statusCode = HttpStatus.temporaryRedirect;
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      request.response.headers.set(HttpHeaders.expiresHeader, '0');
      request.response.headers.set(HttpHeaders.locationHeader, remote!);
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
    final requestedTrack = request.uri.queryParameters['track'];
    final requestedVariant = request.uri.queryParameters['variant'];
    if (requestedVariant != null &&
        requestedVariant != _playbackSync.currentVariantId) {
      throw const ConnectHttpException(409, 'variant_changed');
    }
    if (requestedTrack != null && requestedTrack != item?.id) {
      throw const ConnectHttpException(409, 'track_changed');
    }
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
        if (item.id != _audioService.currentItem.value?.id ||
            !identical(variant, _audioService.currentVariant.value)) {
          throw const ConnectHttpException(409, 'variant_changed');
        }
        final session = _pairingManager.findSessionByToken(
          _extractToken(request),
        );
        if (session == null || _audioService.isInPrivatePlaybackSession) {
          throw const ConnectHttpException(401, 'session_ended');
        }
        if (_activeStreams.values
                .where((id) => id == session.clientId)
                .length >=
            4) {
          throw const ConnectHttpException(429, 'too_many_streams');
        }
        _activeStreams[request.response] = session.clientId;
        try {
          await _serveAudioFileWithRange(request, file);
        } finally {
          _activeStreams.remove(request.response);
        }
        return;
      }
    }

    if (variant.isInstrumental || variant.isSpatial8d) {
      throw const ConnectHttpException(404, 'variant_unavailable');
    }
    final remote = item.playableUrl.trim();
    if (LocalConnectHttpPolicy.isRemoteUrl(remote)) {
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

    if (rangeHeader == null) {
      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = totalLength;
      await request.response.addStream(file.openRead());
      await request.response.close();
      return;
    }

    ConnectByteRange range;
    try {
      range = ConnectByteRange.parse(rangeHeader, totalLength);
    } on ConnectHttpException {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */$totalLength',
      );
      request.response.contentLength = 0;
      await request.response.close();
      return;
    }
    request.response.statusCode = HttpStatus.partialContent;
    request.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes ${range.start}-${range.end}/$totalLength',
    );
    request.response.contentLength = range.length;
    await request.response.addStream(file.openRead(range.start, range.end + 1));
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
    final private = _audioService.isInPrivatePlaybackSession;
    if (private) {
      if (!_privatePlaybackWasActive) {
        for (final response in _activeStreams.keys.toList()) {
          unawaited(_abortResponse(response));
        }
        _broadcastPaired(
          type: 'privatePlaybackLocked',
          payload: _privatePlaybackPayload(),
        );
      }
      _privatePlaybackWasActive = true;
      return;
    }
    if (_privatePlaybackWasActive) {
      _lastQueueSignature = '';
      _privatePlaybackWasActive = false;
    }
    if (_authorizedSocketClients.isEmpty) return;
    final trackSig = _playbackSync.trackSignature();
    final playbackSig = _playbackSync.playbackStateSignature();
    final queueSig = _playbackSync.queueSignature();

    // One snapshot at most per tick, with the queue only when its contents change.
    if (queueSig != _lastQueueSignature) {
      _broadcastPaired(
        type: 'queueChanged',
        payload: _playbackSync.buildSessionPayload(),
      );
    } else if (trackSig != _lastTrackSignature ||
        playbackSig != _lastPlaybackSignature) {
      _broadcastPaired(
        type: trackSig != _lastTrackSignature
            ? 'currentTrackChanged'
            : 'playbackStateChanged',
        payload: _playbackSync.buildSessionPayload(includeQueue: false),
      );
    }
    _lastQueueSignature = queueSig;
    _lastTrackSignature = trackSig;
    _lastPlaybackSignature = playbackSig;

    final now = DateTime.now();
    if (now.difference(_lastProgressAt) >= const Duration(seconds: 1)) {
      _lastProgressAt = now;
      _broadcastPaired(
        type: 'progressUpdated',
        payload: _playbackSync.buildProgressPayload(),
      );
    }
  }

  void _broadcastPaired({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final pairedClientIds = _authorizedSocketClients.toList();
    final staleClientIds = <String>[];
    final message = jsonEncode({
      'type': type,
      'payload': payload,
      'sentAt': DateTime.now().toIso8601String(),
    });
    for (final clientId in pairedClientIds) {
      final touched = _pairingManager.findSessionByClientId(clientId);
      if (touched == null) {
        staleClientIds.add(clientId);
        continue;
      }
      _sendEncoded(clientId, message);
    }

    for (final clientId in staleClientIds) {
      _abortStreamsFor(clientId);
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
  }) => _sendEncoded(
    clientId,
    jsonEncode({
      'type': type,
      'payload': payload,
      'sentAt': DateTime.now().toIso8601String(),
    }),
  );

  void _sendEncoded(String clientId, String message) {
    final socket = _socketByClientId[clientId];
    if (socket == null) return;
    try {
      socket.add(message);
    } catch (_) {
      _socketByClientId.remove(clientId);
      _authorizedSocketClients.remove(clientId);
      _pairingManager.disconnectClient(clientId);
      unawaited(socket.close());
    }
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) =>
      LocalConnectHttpPolicy.readJson(request);

  void _abortStreamsFor(String clientId) {
    for (final entry in _activeStreams.entries.toList()) {
      if (entry.value == clientId) unawaited(_abortResponse(entry.key));
    }
  }

  Future<void> _abortResponse(HttpResponse response) async {
    _activeStreams.remove(response);
    try {
      final socket = await response.detachSocket(writeHeaders: false);
      socket.destroy();
    } catch (_) {}
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
    for (final clientId in _activeStreams.values.toSet()) {
      if (_pairingManager.findSessionByClientId(clientId) == null) {
        _abortStreamsFor(clientId);
      }
    }
    for (final clientId in _authorizedSocketClients.toList()) {
      if (_pairingManager.findSessionByClientId(clientId) == null) {
        unawaited(
          _closeClientSession(
            clientId: clientId,
            reason: 'expired',
            clientName: '',
          ),
        );
      }
    }
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
