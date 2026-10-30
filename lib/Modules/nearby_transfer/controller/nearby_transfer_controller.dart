import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/playback/playback_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/utils/listenfy_deep_link.dart';
import '../../downloads/controller/downloads_controller.dart';
import '../../sources/domain/source_origin.dart';
import '../data/wifi_direct_transport.dart';
import '../data/transfer_cover_attachment.dart';
import '../data/lan_transfer_transport.dart';
import '../domain/hybrid_transfer_protocol.dart';
import '../domain/paired_import_request.dart';
import '../domain/paired_import_session.dart';
import '../../../app/data/downloads/desktop_download_engine.dart';

enum TransferPhase {
  idle,
  advertising,
  discovering,
  pairing,
  preparingWifi,
  connected,
  closed,
  failed,
}

class TransferEntry {
  TransferEntry({
    required this.id,
    required this.title,
    required this.bytes,
    required this.state,
    this.progress = 0,
    this.bytesPerSecond = 0,
    this.sessionId = '',
    this.itemId,
    this.direction = 'sent',
    int? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now().millisecondsSinceEpoch;
  final int id;
  final String title, state, sessionId, direction;
  final int bytes;
  final int recordedAt;
  final double progress, bytesPerSecond;
  final String? itemId;
  TransferEntry copy({
    String? state,
    double? progress,
    double? bytesPerSecond,
    String? itemId,
  }) => TransferEntry(
    id: id,
    title: title,
    bytes: bytes,
    state: state ?? this.state,
    progress: progress ?? this.progress,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    sessionId: sessionId,
    itemId: itemId ?? this.itemId,
    direction: direction,
    recordedAt: recordedAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'bytes': bytes,
    'state': state,
    'sessionId': sessionId,
    'direction': direction,
    'itemId': itemId,
    'recordedAt': recordedAt,
  };
  factory TransferEntry.fromJson(Map data) => TransferEntry(
    id: (data['id'] as num).toInt(),
    title: data['title'] as String,
    bytes: (data['bytes'] as num).toInt(),
    sessionId: data['sessionId'] as String,
    direction: data['direction'] as String,
    itemId: data['itemId'] as String?,
    recordedAt: (data['recordedAt'] as num?)?.toInt(),
    state: data['state'] == 'completed' ? 'completed' : 'failed',
    progress: data['state'] == 'completed' ? 1 : 0,
  );
}

/// Nearby exchanges authenticated session credentials only. Files use pinned TLS
/// over our own Wi-Fi Direct group, never Nearby's file payload API.
class NearbyTransferController extends GetxController {
  NearbyTransferController({
    LocalLibraryStore? library,
    PlaybackRepository? repository,
    Nearby? nearby,
    WifiDirectTransport? transport,
    Future<bool> Function()? permissionCheck,
  }) : _store = library ?? Get.find<LocalLibraryStore>(),
       _repository = repository ?? Get.find<PlaybackRepository>(),
       _nearby = nearby ?? Nearby(),
       _wifiDirect = transport ?? MethodChannelWifiDirectTransport(),
       _listenWifi = transport != null || Platform.isAndroid,
       lanMode = (Platform.isMacOS && transport == null).obs,
       _permissionCheck = permissionCheck;

  final LocalLibraryStore _store;
  final PlaybackRepository _repository;
  final Nearby _nearby;
  final WifiDirectTransport _wifiDirect;
  final bool _listenWifi;
  final _lan = LanTransferTransport();
  PairedImportSession? _pairedImport;
  final pairedImportAvailable = false.obs;
  final pairedImportBusy = false.obs;
  final pairedImportState = 'ready'.obs;
  final pairedImportProgress = 0.0.obs;
  bool get isImportComputer => Platform.isMacOS;

  Future<void> requestComputerImport(
    String url,
    PairedImportFormat format,
  ) async {
    final session = _pairedImport;
    if (session == null || !isConnected || !lanMode.value) {
      throw StateError('unavailable');
    }
    await session.request(
      PairedImportRequest(
        id: List.generate(
          16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
        url: PairedImportRequest.validateUrl(url),
        format: format,
      ),
    );
  }

  void _startPairedImport() {
    _pairedImport?.close();
    pairedImportAvailable.value = false;
    final session = PairedImportSession(
      host: Platform.isMacOS && _host,
      send: _lan.sendControl,
      changed: (state, progress) {
        pairedImportState.value = state;
        pairedImportProgress.value = progress;
        pairedImportBusy.value = [
          'waiting',
          'downloading',
          'transferring',
        ].contains(state);
        pairedImportAvailable.value = _pairedImport?.available ?? false;
      },
      approve: (request) async =>
          await Get.dialog<bool>(
            AlertDialog(
              title: Text(tr('paired_import.approve_title')),
              content: Text(
                tr(
                  'paired_import.approve_body',
                  args: [
                    peerName.value,
                    request.url,
                    request.format.name.toUpperCase(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text(tr('nearby_session.cancel')),
                ),
                FilledButton(
                  onPressed: () => Get.back(result: true),
                  child: Text(tr('paired_import.allow')),
                ),
              ],
            ),
          ) ==
          true,
      execute: _executePairedImport,
    );
    _pairedImport = session;
    unawaited(session.announce().catchError((Object _) {}));
  }

  Future<void> _executePairedImport(
    PairedImportRequest request,
    void Function(double) progress,
    bool Function() active,
  ) async {
    if (!Platform.isMacOS || busy.value || !active()) {
      throw StateError('unavailable');
    }
    await request.validateDestination();
    if (!active()) return;
    final engine = await DesktopDownloadEngine.discover(
      cancelled: () => !active(),
    );
    if (!active()) return;
    final directory = await Directory.systemTemp.createTemp(
      'listenfy-paired-import-',
    );
    try {
      final info = await engine.resolve(request.url);
      if (!active()) return;
      if (info['_type'] == 'playlist' ||
          info['_type'] == 'multi_video' ||
          info['entries'] != null) {
        throw StateError('single_item_required');
      }
      final duration = info['duration'];
      if (info['is_live'] == true ||
          (duration is num && (duration <= 0 || duration > 3600))) {
        throw StateError('unsupported_duration');
      }
      final path = p.join(directory.path, 'media.${request.format.name}');
      await engine.download(
        request.url,
        path,
        kind: request.kind,
        format: request.format.name,
        maxBytes: 512 * 1024 * 1024,
        onProgress: (bytes, total) {
          if (total > 0) progress((bytes / total).clamp(0, 1));
        },
      );
      if (!active()) return;
      final item = MediaItem.fromJson({
        'id': DesktopDownloadEngine.stableId(info, request.url),
        'title': info['title'] is String
            ? info['title']
            : Uri.parse(request.url).host,
        'subtitle': info['artist'] is String
            ? info['artist']
            : info['uploader'] is String
            ? info['uploader']
            : '',
        'source': 'youtube',
        'variants': [
          {
            'kind': request.kind,
            'format': request.format.name,
            'fileName': 'media.${request.format.name}',
            'localPath': path,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'duration': info['duration'] is num
                ? (info['duration'] as num).toInt()
                : 0,
          },
        ],
      });
      await _pairedImport?.transferring();
      final existing = sent.map((entry) => entry.id).toSet();
      await sendItems([item]);
      if (!active()) return;
      final entries = sent
          .where((entry) => !existing.contains(entry.id))
          .toList();
      if (entries.length != 1) throw StateError('send');
      final id = entries.single.id;
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      while (active()) {
        final entry = sent.firstWhere((entry) => entry.id == id);
        if (entry.state == 'completed') return;
        if (entry.state == 'failed' || DateTime.now().isAfter(deadline)) {
          throw StateError('send');
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  final RxBool lanMode;
  WifiDirectTransport get _direct => lanMode.value ? _lan : _wifiDirect;
  bool get canCreateInvitation => !lanMode.value || Platform.isMacOS;
  final Future<bool> Function()? _permissionCheck;
  static const _schema = 'listenfy.nearby.transfer.v2';
  static const _serviceId = 'com.listenfy.transfer.pairing.v3';
  static const _historyKey = 'nearby_transfer_history_v1';
  static const _maxTransferBytes = 1024 * 1024 * 1024;
  // Legacy inline-cover reader only; binary attachments use their own 64 MiB cap.
  static const _maxCoverBytes = 2 * 1024 * 1024;
  static const _allowedFormats = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'ogg',
    'opus',
    'flac',
    'mp4',
    'mkv',
    'webm',
  };

  final phase = TransferPhase.idle.obs;
  final statusKey = 'nearby_session.ready'.obs;
  final statusDetail = ''.obs;
  final inviteCode = ''.obs;
  final inviteUri = Rxn<Uri>();
  final peerName = ''.obs;
  final busy = false.obs;
  final sent = <TransferEntry>[].obs;
  final received = <TransferEntry>[].obs;
  final selectedItems = <MediaItem>[].obs;
  final String _nickName =
      'Listenfy-${HybridTransferProtocol.newCode().substring(0, 4)}';
  String get nickName => _nickName;
  bool get isConnected => phase.value == TransferPhase.connected;
  List<MediaItem> get outgoingItems => selectedItems.toList();
  MediaVariant? shareVariant(MediaItem item) => _pickShareVariant(item);
  List<MediaItem> libraryItems() => _store
      .readAllSync()
      .where((item) => _pickShareVariant(item) != null)
      .toList();

  StreamSubscription<Map<String, dynamic>>? _events;
  StreamSubscription<Map<String, dynamic>>? _lanEvents;
  Timer? _deadline;
  String? _sessionId, _expectedSession, _endpoint, _approvedEndpoint;
  DateTime? _expiresAt;
  bool _host = false,
      _handoff = false,
      _disposed = false,
      _pairingDialog = false,
      _failureInFlight = false;
  int _generation = 0;
  Map<String, dynamic>? _offer;
  final _names = <String, String>{};
  final _receiveIds = <String>{};
  final _speedSamples = <String, (DateTime, int)>{};
  Future<void> _receiveTail = Future.value();
  Future<void> _historyLoaded = Future.value();

  @override
  void onInit() {
    super.onInit();
    if (_listenWifi) {
      _events = _wifiDirect.events.listen(
        (event) {
          if (!lanMode.value) _onDirectEvent(event);
        },
        onError: (Object error) {
          if (!lanMode.value) unawaited(_fail('transport_unavailable'));
        },
      );
    }
    _lan.approve = _approveLan;
    _lan.pairingStarted = () {
      phase.value = TransferPhase.pairing;
    };
    _lanEvents = _lan.events.listen((event) {
      if (!lanMode.value || event['sessionId'] != _sessionId) return;
      if (event['type'] == 'rejected') {
        phase.value = _host ? TransferPhase.advertising : TransferPhase.idle;
        statusKey.value = 'nearby_session.rejected';
        return;
      }
      if (event['peerName'] is String) {
        peerName.value = event['peerName'] as String;
      }
      _onDirectEvent(event);
    });
    _historyLoaded = _restoreHistory();
    acceptArguments(Get.arguments);
  }

  void acceptArguments(dynamic args) {
    if (args is Map) {
      final list = args['items'];
      if (list is List) selectedItems.assignAll(list.whereType<MediaItem>());
      if (args['item'] is MediaItem && selectedItems.isEmpty) {
        selectedItems.add(args['item'] as MediaItem);
      }
    }
    if (!isConnected && args is Map && args['inviteUri'] is String) {
      final uri = Uri.tryParse(args['inviteUri'] as String);
      if (uri?.path == '/lan') {
        unawaited(
          receiveLanInvite(uri!).catchError((Object _) {
            statusKey.value = 'nearby_session.invalid_invite';
          }),
        );
        return;
      }
      final invite = ListenfyDeepLink.parseNearbyInviteRaw(
        args['inviteUri'] as String,
      );
      if (invite != null) unawaited(startReceiveFromInvite(invite));
    }
  }

  Future<void> _restoreHistory() async {
    try {
      final values = await _repository.readDomains();
      final records = values[_historyKey];
      if (records is List) {
        for (final raw in records.whereType<Map>()) {
          final entry = TransferEntry.fromJson(raw);
          (entry.direction == 'received' ? received : sent).add(entry);
        }
      }
    } catch (_) {
      statusKey.value = 'nearby_session.history_error';
    }
  }

  Future<void> _persistHistory() {
    final records = [...sent, ...received].map((e) => e.toJson()).toList();
    // Queue immediately on the repository's single writer, before a backup or
    // history query can overtake an ACK that has already reached the UI.
    final write = _repository.replaceDomain(_historyKey, records);
    unawaited(
      write.catchError((Object _) {
        statusKey.value = 'nearby_session.history_error';
      }),
    );
    return write;
  }

  Future<bool> _permissions() async {
    if (_permissionCheck != null) return _permissionCheck();
    if (!Platform.isAndroid) {
      statusKey.value = 'nearby_session.android_only';
      return false;
    }
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.location,
    ].request();
    // Different Android versions do not expose all permission groups.
    if (!results.values.any((status) => status.isGranted)) {
      statusKey.value = 'nearby_session.permissions';
      return false;
    }
    return true;
  }

  Future<void> prepareInvitation() async {
    if (isConnected || busy.value) return;
    await closeConnection();
    if (lanMode.value) {
      if (!Platform.isMacOS) return;
      busy.value = true;
      try {
        _host = true;
        final uri = await _lan.advertise(name: nickName);
        _sessionId = uri.queryParameters['sid'];
        inviteCode.value = HybridTransferProtocol.codeFromSession(_sessionId!);
        inviteUri.value = uri;
        _handoff = true;
        phase.value = TransferPhase.advertising;
        statusKey.value = 'nearby_session.waiting';
      } catch (_) {
        await _fail('lan_failed');
      } finally {
        busy.value = false;
      }
      return;
    }
    if (!await _permissions()) return;
    _host = true;
    inviteCode.value = HybridTransferProtocol.newCode();
    _sessionId = HybridTransferProtocol.newSessionId(inviteCode.value);
    _expiresAt = DateTime.now().add(const Duration(minutes: 5));
    inviteUri.value = ListenfyDeepLink.buildNearbyInviteUri(
      sessionId: _sessionId!,
      senderName: nickName,
      title: tr('nearby_session.title'),
      subtitle: '',
      expiresAt: _expiresAt!.millisecondsSinceEpoch,
    );
    try {
      final okay = await _nearby.startAdvertising(
        'LF2-${inviteCode.value}-$nickName',
        Strategy.P2P_POINT_TO_POINT,
        serviceId: _serviceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onNearbyDisconnected,
      );
      if (!okay) throw StateError('advertising');
      phase.value = TransferPhase.advertising;
      statusKey.value = 'nearby_session.waiting';
      _deadline = Timer(
        const Duration(minutes: 5),
        () => unawaited(_fail('expired')),
      );
    } catch (_) {
      await _fail('advertising_failed');
    }
  }

  Future<void> joinCode(String code) async {
    if (!lanMode.value) return _joinCode(code);
    if (isConnected || busy.value) return;
    busy.value = true;
    phase.value = TransferPhase.discovering;
    statusKey.value = 'nearby_session.searching';
    try {
      final uri = await _lan.discover(code.trim().toUpperCase());
      await receiveLanInvite(uri);
    } catch (_) {
      await _fail('lan_failed');
    } finally {
      busy.value = false;
    }
  }

  Future<void> setLanMode(bool value) async {
    if (isConnected || busy.value || phase.value == TransferPhase.pairing) {
      return;
    }
    await closeConnection();
    lanMode.value = value;
    statusKey.value = 'nearby_session.ready';
  }

  Future<void> receiveLanInvite(Uri uri) async {
    if (isConnected || _disposed) return;
    LanTransferTransport.validateInvite(uri);
    await closeConnection();
    lanMode.value = true;
    _host = false;
    _sessionId = uri.queryParameters['sid'];
    _handoff = true;
    phase.value = TransferPhase.pairing;
    statusKey.value = 'nearby_session.lan_pairing';
    try {
      await _lan.connect(uri, name: nickName);
    } catch (_) {
      await _fail('lan_failed');
    }
  }

  Future<bool> _approveLan(String peer, String verification) async {
    final generation = _generation;
    final accepted = await Get.dialog<bool>(
      AlertDialog(
        title: Text(tr('nearby.incoming_connection')),
        content: Text(
          tr('nearby_session.lan_verify', args: [peer, verification]),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(tr('nearby.reject')),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text(tr('nearby.accept')),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    return accepted == true && generation == _generation && !_disposed;
  }

  Future<void> _joinCode(String code, {String? expectedSession}) async {
    code = code.trim().toUpperCase();
    if (!HybridTransferProtocol.validCode(code)) {
      statusKey.value = 'nearby_session.invalid_code';
      return;
    }
    if (isConnected || busy.value) return;
    await closeConnection();
    _expectedSession = expectedSession;
    if (!await _permissions()) return;
    _host = false;
    inviteCode.value = code;
    phase.value = TransferPhase.discovering;
    statusKey.value = 'nearby_session.searching';
    _deadline = Timer(
      const Duration(seconds: 60),
      () => unawaited(_fail('not_found')),
    );
    try {
      final okay = await _nearby.startDiscovery(
        nickName,
        Strategy.P2P_POINT_TO_POINT,
        serviceId: _serviceId,
        onEndpointFound: (id, name, service) {
          if (phase.value != TransferPhase.discovering ||
              !name.startsWith('LF2-$code-')) {
            return;
          }
          _endpoint = id;
          _names[id] = name.substring(12);
          phase.value = TransferPhase.pairing;
          unawaited(
            _nearby
                .requestConnection(
                  nickName,
                  id,
                  onConnectionInitiated: _onConnectionInitiated,
                  onConnectionResult: _onConnectionResult,
                  onDisconnected: _onNearbyDisconnected,
                )
                .catchError((Object _) {
                  unawaited(_fail('pairing_failed'));
                  return false;
                }),
          );
        },
        onEndpointLost: (id) {},
      );
      if (!okay) throw StateError('discovery');
    } catch (_) {
      await _fail('discovery_failed');
    }
  }

  Future<void> startReceiveFromInvite(ListenfyNearbyInvite invite) async {
    if (isConnected || busy.value) return;
    if (invite.isExpired) {
      statusKey.value = 'nearby_session.expired';
      return;
    }
    try {
      await _joinCode(
        HybridTransferProtocol.codeFromSession(invite.sessionId),
        expectedSession: invite.sessionId,
      );
    } on FormatException {
      statusKey.value = 'nearby_session.invalid_code';
    }
  }

  Future<void> _onConnectionInitiated(
    String endpointId,
    ConnectionInfo info,
  ) async {
    if (_pairingDialog ||
        (_endpoint != null && _endpoint != endpointId) ||
        (_host &&
            (_expiresAt == null || DateTime.now().isAfter(_expiresAt!)))) {
      await _nearby.rejectConnection(endpointId);
      return;
    }
    _pairingDialog = true;
    final generation = _generation;
    _names[endpointId] = info.endpointName;
    phase.value = TransferPhase.pairing;
    final accepted = await Get.dialog<bool>(
      AlertDialog(
        title: Text(tr('nearby.incoming_connection')),
        content: Text(
          tr(
            'nearby.security_body',
            args: [info.endpointName, info.authenticationToken],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(tr('nearby.reject')),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text(tr('nearby.accept')),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    _pairingDialog = false;
    if (generation != _generation || _disposed) {
      await _nearby.rejectConnection(endpointId);
      return;
    }
    if (accepted != true || _disposed) {
      await _nearby.rejectConnection(endpointId);
      phase.value = _host ? TransferPhase.advertising : TransferPhase.idle;
      statusKey.value = 'nearby_session.rejected';
      _endpoint = null;
      return;
    }
    _endpoint = endpointId;
    _approvedEndpoint = endpointId;
    final okay = await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (_, _) {},
    );
    if (!okay) await _fail('pairing_failed');
  }

  void _onConnectionResult(String id, Status status) {
    if (id != _approvedEndpoint) return;
    if (status != Status.CONNECTED) {
      phase.value = _host ? TransferPhase.advertising : TransferPhase.idle;
      statusKey.value = 'nearby_session.rejected';
      _endpoint = null;
      _approvedEndpoint = null;
      return;
    }
    peerName.value = _names[id] ?? 'Listenfy';
    if (_host) unawaited(_sendOffer(id));
  }

  Future<void> _sendOffer(String endpoint) async {
    try {
      final provisional = HybridTransferProtocol.createOffer(
        sessionId: _sessionId!,
        fingerprint: '0' * 64,
      );
      final fingerprint = await _direct.prepare(provisional);
      if (_approvedEndpoint != endpoint) return;
      provisional['fingerprint'] = fingerprint;
      _offer = provisional;
      await _sendControl(endpoint, provisional);
    } catch (error, stack) {
      assert(() {
        debugPrint('Wi-Fi Direct preparation: ${error.runtimeType}');
        debugPrintStack(stackTrace: stack);
        return true;
      }());
      await _fail('wifi_prepare_failed');
    }
  }

  Future<void> _sendControl(String endpoint, Map<String, dynamic> message) =>
      _nearby.sendBytesPayload(
        endpoint,
        Uint8List.fromList(utf8.encode(jsonEncode(message))),
      );

  Future<void> _onPayloadReceived(String id, Payload payload) async {
    if (id != _approvedEndpoint || _handoff) return;
    if (payload.type != PayloadType.BYTES || payload.bytes == null) {
      await _fail('unexpected_payload');
      return;
    }
    try {
      final message = HybridTransferProtocol.decodeMessage(payload.bytes!);
      if (message['schema'] != HybridTransferProtocol.schema) {
        throw const FormatException();
      }
      if (!_host && message['type'] == 'offer') {
        _offer = HybridTransferProtocol.validateOffer(
          message,
          expectedCode: inviteCode.value,
          expectedSessionId: _expectedSession,
        );
        _sessionId = _offer!['sessionId'] as String;
        await _sendControl(id, {
          'schema': HybridTransferProtocol.schema,
          'type': 'ack',
          'sessionId': _sessionId,
        });
      } else if (_host &&
          message['type'] == 'ack' &&
          message['sessionId'] == _sessionId &&
          _offer != null) {
        await _sendControl(id, {
          'schema': HybridTransferProtocol.schema,
          'type': 'commit',
          'sessionId': _sessionId,
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _beginHandoff();
      } else if (!_host &&
          message['type'] == 'commit' &&
          message['sessionId'] == _sessionId &&
          _offer != null) {
        await _beginHandoff();
      } else {
        throw const FormatException();
      }
    } catch (_) {
      await _fail('invalid_handshake');
    }
  }

  Future<void> _beginHandoff() async {
    if (_handoff) return;
    if (_offer == null ||
        (_offer!['expiresAt'] as int) <=
            DateTime.now().millisecondsSinceEpoch) {
      await _fail('expired');
      return;
    }
    final generation = _generation;
    _handoff = true;
    _deadline?.cancel();
    phase.value = TransferPhase.preparingWifi;
    statusKey.value = 'nearby_session.preparing_wifi';
    _deadline = Timer(
      const Duration(seconds: 75),
      () => unawaited(_fail('wifi_timeout')),
    );
    await _stopNearby();
    // Leave time for the peer's final pairing message and radio resources to settle.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_disposed || !_handoff || generation != _generation) return;
    try {
      if (_host) {
        await _direct.startHost();
      } else {
        await _direct.join(_offer!);
      }
    } catch (_) {
      await _fail('wifi_unavailable');
    }
  }

  void _onNearbyDisconnected(String id) {
    if (_handoff || id != _approvedEndpoint) return;
    unawaited(_fail('pairing_lost'));
  }

  void _onDirectEvent(Map<String, dynamic> event) {
    if (_disposed) return;
    if (event['sessionId'] != null && event['sessionId'] != _sessionId) return;
    final type = event['type'];
    if (type == 'connected' && event['sessionId'] == _sessionId && _handoff) {
      _deadline?.cancel();
      phase.value = TransferPhase.connected;
      statusKey.value = 'nearby_session.connected';
      inviteUri.value = null;
      if (lanMode.value) _startPairedImport();
      return;
    }
    if (type == 'closed' || type == 'error') {
      if (_handoff || isConnected) {
        unawaited(
          _fail(type == 'error' ? 'wifi_unavailable' : 'connection_lost'),
        );
      }
      return;
    }
    if (!isConnected) return;
    if (type == 'control' && lanMode.value) {
      final message = event['message'];
      if (message is Map<String, dynamic>) {
        unawaited(
          _pairedImport?.receive(message).catchError((Object _) {}) ??
              Future<void>.value(),
        );
      }
      return;
    }
    if (type == 'progress') {
      final id = (event['payloadId'] as num?)?.toInt();
      if (id == null) return;
      final receiving = event['direction'] == 'received';
      final list = receiving ? received : sent;
      final index = list.indexWhere(
        (e) => e.id == id && e.sessionId == _sessionId,
      );
      final bytes = (event['bytes'] as num?)?.toInt() ?? 0;
      final total = (event['total'] as num?)?.toInt() ?? 1;
      if (index >= 0) {
        final sampleKey =
            '${_sessionId!}:${receiving ? 'received' : 'sent'}:$id';
        final now = DateTime.now(), last = _speedSamples[sampleKey];
        final seconds = last == null
            ? 0
            : now.difference(last.$1).inMilliseconds / 1000;
        final speed = seconds > 0 ? (bytes - last!.$2) / seconds : 0.0;
        _speedSamples[sampleKey] = (now, bytes);
        list[index] = list[index].copy(
          progress: (bytes / total).clamp(0, 1),
          bytesPerSecond: speed < 0 ? 0 : speed,
        );
      } else if (receiving) {
        received.add(
          TransferEntry(
            id: id,
            title: tr('nearby_session.receiving'),
            bytes: total,
            state: 'receiving',
            direction: 'received',
            sessionId: _sessionId!,
          ),
        );
      }
    } else if (type == 'received') {
      _receiveTail = _receiveTail
          .then((_) => _importReceived(event))
          .catchError((Object _) {
            statusKey.value = 'nearby_session.import_failed';
          });
    } else if (type == 'sent') {
      final id = (event['payloadId'] as num).toInt();
      final index = sent.indexWhere(
        (e) => e.id == id && e.sessionId == _sessionId,
      );
      if (index >= 0) {
        sent[index] = sent[index].copy(state: 'completed', progress: 1);
        unawaited(_persistHistory());
        statusKey.value = 'nearby_session.sent_success';
      }
    }
  }

  Future<void> sendItems(List<MediaItem> items) async {
    if (!isConnected || busy.value || items.isEmpty) return;
    busy.value = true;
    final generation = _generation;
    final session = _sessionId;
    try {
      await _historyLoaded;
      var total = 0;
      final files = <(MediaItem, MediaVariant, File)>[];
      for (final item in items) {
        final variant = _pickShareVariant(item);
        if (variant == null ||
            !_allowedFormats.contains(_formatForVariant(variant))) {
          throw const FormatException('format');
        }
        final file = File(variant.localPath!);
        final size = await file.length();
        total += size;
        if (size <= 0 || total > _maxTransferBytes) {
          throw const FormatException('size');
        }
        files.add((item, variant, file));
      }
      for (final (item, variant, file) in files) {
        if (!isConnected || generation != _generation) break;
        final id = DateTime.now().microsecondsSinceEpoch;
        final descriptor = await _OutgoingNearbyDescriptor.fromItem(
          schema: _schema,
          payloadId: id,
          sessionId: session!,
          sizeBytes: await file.length(),
          sha256Hex: await _sha256ForFile(file),
          item: item,
          variant: variant,
        );
        if (utf8
                .encode(
                  jsonEncode({
                    'type': 'file',
                    'sessionId': session,
                    'descriptor': descriptor.toJson(),
                  }),
                )
                .length >
            256 * 1024) {
          throw const FormatException('metadata');
        }
        if (!isConnected ||
            generation != _generation ||
            _sessionId != session) {
          break;
        }
        sent.add(
          TransferEntry(
            id: id,
            title: item.title,
            bytes: descriptor.sizeBytes,
            state: 'sending',
            sessionId: session,
          ),
        );
        await _persistHistory();
        if (!isConnected ||
            generation != _generation ||
            _sessionId != session) {
          break;
        }
        await _direct.send(
          file.path,
          descriptor.toJson(),
          coverPath: descriptor.cover?.path,
        );
      }
    } catch (_) {
      statusKey.value = 'nearby_session.send_failed';
      for (var i = 0; i < sent.length; i++) {
        if (sent[i].state == 'sending') sent[i] = sent[i].copy(state: 'failed');
      }
      await _persistHistory();
    } finally {
      busy.value = false;
    }
  }

  Future<void> _importReceived(Map<String, dynamic> event) async {
    await _historyLoaded;
    final session = _sessionId;
    final raw = Map<String, dynamic>.from(event['descriptor'] as Map);
    final descriptor = _IncomingNearbyDescriptor.fromJson(raw);
    if (descriptor == null ||
        descriptor.sessionId != session ||
        !_allowedFormats.contains(descriptor.format) ||
        descriptor.sizeBytes > _maxTransferBytes) {
      throw const FormatException('Invalid incoming descriptor');
    }
    final key = '$session:${descriptor.payloadId}';
    if (_receiveIds.contains(key)) {
      await _direct.confirm(descriptor.payloadId);
      return;
    }
    final source = File(event['path'] as String);
    if (!await _verifyReceivedFile(source.path, descriptor)) {
      throw const FormatException('integrity');
    }
    final destination = await _buildDestinationPath(
      descriptor.payloadId,
      descriptor.fileName,
    );
    if (destination == null) throw const FileSystemException('destination');
    await source.copy(destination);
    final item = await _buildImportedItemFromDescriptor(
      descriptor: descriptor,
      destinationPath: destination,
      attachmentPath: event['coverPath'] as String?,
    );
    if (item == null) {
      await File(destination).delete();
      throw StateError('import');
    }
    await _store.upsert(item);
    final entry = TransferEntry(
      id: descriptor.payloadId,
      title: item.title,
      bytes: descriptor.sizeBytes,
      state: 'completed',
      progress: 1,
      direction: 'received',
      sessionId: session!,
      itemId: item.id,
    );
    final index = received.indexWhere(
      (e) => e.id == entry.id && e.sessionId == session,
    );
    if (index < 0) {
      received.add(entry);
    } else {
      received[index] = entry;
    }
    await _persistHistory();
    _receiveIds.add(key);
    await source.delete();
    final attachment = event['coverPath'];
    if (attachment is String && attachment.isNotEmpty) {
      try {
        await File(attachment).delete();
      } on FileSystemException {
        /* already cleaned */
      }
    }
    if (Get.isRegistered<DownloadsController>()) {
      unawaited(Get.find<DownloadsController>().load());
    }
    // Do not acknowledge a transfer on a newer session.
    if (_sessionId == session && isConnected) {
      await _direct.confirm(descriptor.payloadId);
    }
    statusKey.value = 'nearby_session.received_success';
  }

  Future<void> _stopNearby() async {
    if (!_listenWifi) return;
    try {
      await _nearby.stopAdvertising();
    } catch (_) {}
    try {
      await _nearby.stopDiscovery();
    } catch (_) {}
    try {
      await _nearby.stopAllEndpoints();
    } catch (_) {}
  }

  Future<void> closeConnection() async {
    _pairedImport?.close();
    _pairedImport = null;
    pairedImportAvailable.value = false;
    pairedImportBusy.value = false;
    _generation++;
    _handoff = false;
    _deadline?.cancel();
    _approvedEndpoint = null;
    _endpoint = null;
    _offer = null;
    _sessionId = null;
    _expiresAt = null;
    inviteUri.value = null;
    inviteCode.value = '';
    _speedSamples.clear();
    _receiveIds.clear();
    phase.value = TransferPhase.closed;
    await _stopNearby();
    try {
      await _direct.close();
    } catch (_) {}
    if (!lanMode.value) await _lan.close();
    for (final list in [sent, received]) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].state != 'completed') {
          list[i] = list[i].copy(state: 'failed');
        }
      }
    }
    if (sent.isNotEmpty || received.isNotEmpty) await _persistHistory();
    statusKey.value = 'nearby_session.closed';
  }

  Future<void> _fail(String code) async {
    if (_failureInFlight || _disposed) return;
    _failureInFlight = true;
    try {
      await closeConnection();
      if (_disposed) return;
      phase.value = TransferPhase.failed;
      statusDetail.value = code;
      statusKey.value = 'nearby_session.$code';
    } finally {
      _failureInFlight = false;
    }
  }

  @override
  void onClose() {
    if (_disposed) return;
    _disposed = true;
    _deadline?.cancel();
    _events?.cancel();
    _lanEvents?.cancel();
    unawaited(closeConnection());
    super.onClose();
  }

  Future<MediaItem?> _buildImportedItemFromDescriptor({
    required _IncomingNearbyDescriptor descriptor,
    required String destinationPath,
    String? attachmentPath,
  }) async {
    try {
      final file = File(destinationPath);
      final stat = await file.stat();
      final ext = p
          .extension(destinationPath)
          .replaceFirst('.', '')
          .toLowerCase();
      final id = sha1
          .convert(
            utf8.encode(
              '$destinationPath|${stat.size}|${stat.modified.millisecondsSinceEpoch}',
            ),
          )
          .toString();

      final coverPath =
          await _saveCoverAttachment(id, attachmentPath, descriptor.cover) ??
          await _saveIncomingCover(
            itemId: id,
            base64Cover: descriptor.coverBase64,
          );

      final kind = descriptor.kind == 'video'
          ? MediaVariantKind.video
          : MediaVariantKind.audio;

      final variant = MediaVariant(
        kind: kind,
        format: ext.isNotEmpty ? ext : descriptor.format,
        fileName: p.basename(destinationPath),
        localPath: destinationPath,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        size: stat.size,
        durationSeconds: descriptor.durationSeconds,
        role: descriptor.role,
      );

      return MediaItem(
        id: id,
        publicId: id,
        title: descriptor.title.trim().isEmpty
            ? p.basenameWithoutExtension(destinationPath)
            : descriptor.title,
        subtitle: descriptor.subtitle,
        country: descriptor.country,
        source: MediaSource.local,
        origin: SourceOrigin.device,
        thumbnail: null,
        thumbnailLocalPath: coverPath,
        variants: [variant],
        durationSeconds: descriptor.durationSeconds,
        lyrics: descriptor.lyrics,
        lyricsLanguage: descriptor.lyricsLanguage,
        translations: descriptor.translations,
      );
    } catch (e) {
      statusKey.value = 'nearby_session.import_failed';
      return null;
    }
  }

  Future<String?> _buildDestinationPath(
    int payloadId,
    String incomingFileName,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final ext = p
          .extension(incomingFileName)
          .replaceFirst('.', '')
          .toLowerCase();
      final hash = sha1
          .convert(
            utf8.encode(
              '$incomingFileName|$payloadId|${DateTime.now().millisecondsSinceEpoch}',
            ),
          )
          .toString();
      final fileName = ext.isEmpty ? hash : '$hash.$ext';
      return p.join(mediaDir.path, fileName);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _saveCoverAttachment(
    String itemId,
    String? path,
    Map<String, dynamic>? metadata,
  ) async {
    if (path == null || path.isEmpty || metadata == null) return null;
    try {
      final cover = await TransferCoverAttachment.read(path);
      if (cover == null ||
          cover.size != metadata['sizeBytes'] ||
          cover.hash != metadata['sha256'] ||
          cover.format != metadata['format']) {
        return null;
      }
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDir.path, 'media', 'covers'));
      await dir.create(recursive: true);
      final destination = p.join(dir.path, '${itemId}_cover.${cover.format}');
      await File(path).copy(destination);
      return destination;
    } on FileSystemException {
      return null;
    }
  }

  Future<String?> _saveIncomingCover({
    required String itemId,
    required String? base64Cover,
  }) async {
    final raw = (base64Cover ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      if (raw.length > (_maxCoverBytes * 2)) return null;
      final bytes = base64Decode(raw);
      if (bytes.isEmpty || bytes.length > _maxCoverBytes) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'media', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final ext = _guessImageExt(bytes);
      final coverPath = p.join(coversDir.path, '${itemId}_cover.$ext');
      await File(coverPath).writeAsBytes(bytes, flush: true);
      return coverPath;
    } catch (_) {
      return null;
    }
  }

  String _guessImageExt(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    return 'jpg';
  }

  Future<bool> _verifyReceivedFile(
    String destinationPath,
    _IncomingNearbyDescriptor descriptor,
  ) async {
    try {
      final file = File(destinationPath);
      if (!await file.exists()) return false;
      if (await file.length() != descriptor.sizeBytes) return false;
      final digest = await _sha256ForFile(file);
      return digest == descriptor.sha256Hex;
    } catch (_) {
      return false;
    }
  }

  Future<String> _sha256ForFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String _normalizedFormat(String pathOrName) {
    final ext = p.extension(pathOrName).replaceFirst('.', '').toLowerCase();
    return ext.trim();
  }

  String _formatForVariant(MediaVariant variant) {
    final ext = _normalizedFormat(variant.localPath ?? variant.fileName);
    return ext.isNotEmpty ? ext : variant.format.toLowerCase().trim();
  }

  MediaVariant? _pickShareVariant(MediaItem item) {
    final localVariants = item.variants.where((v) {
      final pth = v.localPath?.trim() ?? '';
      return pth.isNotEmpty;
    }).toList();
    if (localVariants.isEmpty) return null;

    for (final variant in localVariants) {
      if (variant.kind != MediaVariantKind.audio) continue;
      if (variant.isInstrumental || variant.isSpatial8d) continue;
      return variant;
    }

    for (final variant in localVariants) {
      if (variant.kind == MediaVariantKind.audio) return variant;
    }

    return localVariants.first;
  }
}

class _OutgoingNearbyDescriptor {
  final String schema;
  final int payloadId;
  final String sessionId;
  final int sizeBytes;
  final String sha256Hex;
  final String fileName;
  final String format;
  final String kind;
  final String role;
  final String title;
  final String subtitle;
  final String? country;
  final int? durationSeconds;
  final String? lyrics;
  final String? lyricsLanguage;
  final Map<String, String>? translations;
  final TransferCoverAttachment? cover;

  _OutgoingNearbyDescriptor({
    required this.schema,
    required this.payloadId,
    required this.sessionId,
    required this.sizeBytes,
    required this.sha256Hex,
    required this.fileName,
    required this.format,
    required this.kind,
    required this.role,
    required this.title,
    required this.subtitle,
    required this.country,
    required this.durationSeconds,
    required this.lyrics,
    required this.lyricsLanguage,
    required this.translations,
    required this.cover,
  });

  static Future<_OutgoingNearbyDescriptor> fromItem({
    required String schema,
    required int payloadId,
    required String sessionId,
    required int sizeBytes,
    required String sha256Hex,
    required MediaItem item,
    required MediaVariant variant,
  }) async {
    final fileName = p.basename(variant.localPath ?? variant.fileName);
    final ext = p
        .extension(variant.localPath ?? variant.fileName)
        .replaceFirst('.', '')
        .toLowerCase()
        .trim();
    final cover = await TransferCoverAttachment.read(item.thumbnailLocalPath);

    return _OutgoingNearbyDescriptor(
      schema: schema,
      payloadId: payloadId,
      sessionId: sessionId,
      sizeBytes: sizeBytes,
      sha256Hex: sha256Hex,
      fileName: fileName,
      format: ext.isNotEmpty ? ext : variant.format.toLowerCase().trim(),
      kind: variant.kind == MediaVariantKind.video ? 'video' : 'audio',
      role: variant.roleKey,
      title: item.title,
      subtitle: item.subtitle,
      country: item.country,
      durationSeconds: item.durationSeconds ?? variant.durationSeconds,
      lyrics: item.lyrics,
      lyricsLanguage: item.lyricsLanguage,
      translations: item.translations,
      cover: cover,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'payloadId': payloadId,
    'sessionId': sessionId,
    'sizeBytes': sizeBytes,
    'sha256': sha256Hex,
    'fileName': fileName,
    'format': format,
    'kind': kind,
    'role': role,
    'title': title,
    'subtitle': subtitle,
    'country': country,
    'durationSeconds': durationSeconds,
    'lyrics': lyrics,
    'lyricsLanguage': lyricsLanguage,
    'translations': translations,
    if (cover != null) 'cover': cover!.toJson(),
  };
}

class _IncomingNearbyDescriptor {
  final int payloadId;
  final String sessionId;
  final int sizeBytes;
  final String sha256Hex;
  final String fileName;
  final String format;
  final String kind;
  final String role;
  final String title;
  final String subtitle;
  final String? country;
  final int? durationSeconds;
  final String? lyrics;
  final String? lyricsLanguage;
  final Map<String, String>? translations;
  final String? coverBase64;
  final Map<String, dynamic>? cover;

  _IncomingNearbyDescriptor({
    required this.payloadId,
    required this.sessionId,
    required this.sizeBytes,
    required this.sha256Hex,
    required this.fileName,
    required this.format,
    required this.kind,
    required this.role,
    required this.title,
    required this.subtitle,
    required this.country,
    required this.durationSeconds,
    required this.lyrics,
    required this.lyricsLanguage,
    required this.translations,
    required this.coverBase64,
    required this.cover,
  });

  static _IncomingNearbyDescriptor? fromJson(Map<String, dynamic> json) {
    final schema = (json['schema'] as String?)?.trim();
    if (schema != NearbyTransferController._schema) return null;

    final payloadIdRaw = json['payloadId'];
    int? payloadId;
    if (payloadIdRaw is num) {
      payloadId = payloadIdRaw.toInt();
    } else if (payloadIdRaw is String) {
      payloadId = int.tryParse(payloadIdRaw.trim());
    }
    if (payloadId == null) return null;

    final sessionId = ((json['sessionId'] as String?) ?? '').trim();
    final sizeRaw = json['sizeBytes'];
    final sizeBytes = sizeRaw is num
        ? sizeRaw.toInt()
        : int.tryParse(sizeRaw?.toString() ?? '');
    final sha256Hex = ((json['sha256'] as String?) ?? '').trim().toLowerCase();
    if (sizeBytes == null || sizeBytes <= 0) return null;

    final fileName = (json['fileName'] as String?)?.trim() ?? '';
    if (fileName.isEmpty) return null;

    final kind = ((json['kind'] as String?) ?? 'audio').trim().toLowerCase();
    final rawFormat = ((json['format'] as String?) ?? '').trim().toLowerCase();
    final format = rawFormat.isNotEmpty
        ? rawFormat
        : p.extension(fileName).replaceFirst('.', '').toLowerCase();
    final role = ((json['role'] as String?) ?? 'main').trim().toLowerCase();
    final title = ((json['title'] as String?) ?? '').trim();
    final subtitle = ((json['subtitle'] as String?) ?? '').trim();
    final country = (json['country'] as String?)?.trim();
    final durationRaw = json['durationSeconds'];
    final duration = MediaItem.normalizeDurationSeconds(durationRaw);
    final lyrics = (json['lyrics'] as String?)?.trim();
    final lyricsLanguage = (json['lyricsLanguage'] as String?)?.trim();
    final coverBase64 = (json['coverBase64'] as String?)?.trim();

    Map<String, String>? translations;
    final trRaw = json['translations'];
    if (trRaw is Map) {
      translations = trRaw.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }

    return _IncomingNearbyDescriptor(
      cover: json['cover'] is Map
          ? Map<String, dynamic>.from(json['cover'] as Map)
          : null,
      payloadId: payloadId,
      sessionId: sessionId,
      sizeBytes: sizeBytes,
      sha256Hex: sha256Hex,
      fileName: fileName,
      format: format,
      kind: kind == 'video' ? 'video' : 'audio',
      role: role,
      title: title,
      subtitle: subtitle,
      country: country,
      durationSeconds: duration,
      lyrics: lyrics,
      lyricsLanguage: lyricsLanguage,
      translations: translations,
      coverBase64: (coverBase64 == null || coverBase64.isEmpty)
          ? null
          : coverBase64,
    );
  }
}
