import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../../app/utils/listenfy_deep_link.dart';
import '../../downloads/controller/downloads_controller.dart';
import '../../sources/domain/source_origin.dart';

class NearbyTransferPeer {
  final String endpointId;
  final String name;

  const NearbyTransferPeer({required this.endpointId, required this.name});
}

class NearbyTransferController extends GetxController {
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final Nearby _nearby = Nearby();

  static const String _serviceId = 'com.listenfy.nearby.transfer';
  static const String _schema = 'listenfy.nearby.transfer.v1';
  static const String _inviteHandshakeSchema = 'listenfy.nearby.invite.v1';
  static const String _inviteEventHello = 'hello';
  static const String _inviteEventImported = 'imported';

  final Rxn<MediaItem> selectedItem = Rxn<MediaItem>();

  final RxBool isAdvertising = false.obs;
  final RxBool isDiscovering = false.obs;
  final RxString statusText = 'Listo para transferir'.obs;
  final RxList<NearbyTransferPeer> discoveredPeers = <NearbyTransferPeer>[].obs;
  final RxList<NearbyTransferPeer> connectedPeers = <NearbyTransferPeer>[].obs;
  final RxMap<int, double> transferProgress = <int, double>{}.obs;

  final Map<String, String> _endpointNames = <String, String>{};
  final Map<int, _IncomingNearbyDescriptor> _descriptorByPayloadId =
      <int, _IncomingNearbyDescriptor>{};
  final Map<int, Payload> _filePayloadById = <int, Payload>{};
  final Set<int> _filePayloadIds = <int>{};
  final Set<int> _completedPayloadIds = <int>{};
  final Set<int> _importedPayloadIds = <int>{};
  final Set<int> _importRetryInFlight = <int>{};

  late final String _nickName;
  String? _outgoingInviteSessionId;
  String? _expectedInviteSessionId;

  bool _autoConnectInProgress = false;
  final Set<String> _inviteHandshakeSent = <String>{};
  final Set<String> _autoSentBySessionEndpoint = <String>{};
  final Set<String> _autoSendingBySessionEndpoint = <String>{};

  bool get isAutoInviteSenderMode => _outgoingInviteSessionId != null;

  @override
  void onInit() {
    super.onInit();
    _nickName = 'Listenfy-${DateTime.now().millisecondsSinceEpoch % 10000}';

    final args = Get.arguments;
    if (args is Map) {
      final item = args['item'];
      if (item is MediaItem) {
        selectedItem.value = item;
      }

      final inviteRaw = args['inviteUri']?.toString().trim() ?? '';
      if (inviteRaw.isNotEmpty) {
        final invite = ListenfyDeepLink.parseNearbyInviteRaw(inviteRaw);
        if (invite != null) {
          Future<void>.microtask(() => startReceiveFromInvite(invite));
        }
      }
    }
  }

  @override
  void onClose() {
    stopAll();
    super.onClose();
  }

  Future<void> startAdvertisingMode() async {
    if (!Platform.isAndroid) {
      statusText.value = 'Solo disponible en Android.';
      return;
    }

    final okPerm = await _ensureNearbyPermissions();
    if (!okPerm) return;

    await _safeStopDiscovery();
    discoveredPeers.clear();

    try {
      final ok = await _nearby.startAdvertising(
        _nickName,
        Strategy.P2P_POINT_TO_POINT,
        serviceId: _serviceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      isAdvertising.value = ok;
      statusText.value = ok
          ? 'Emisor activo. Esperando receptor...'
          : 'No se pudo activar modo emisor.';
    } catch (e) {
      isAdvertising.value = false;
      statusText.value = 'Error al iniciar emisor: $e';
    }
  }

  Future<void> stopAdvertisingMode() async {
    await _safeStopAdvertising();
    isAdvertising.value = false;
  }

  Future<void> startDiscoveryMode() async {
    if (!Platform.isAndroid) {
      statusText.value = 'Solo disponible en Android.';
      return;
    }

    final okPerm = await _ensureNearbyPermissions();
    if (!okPerm) return;

    await _safeStopAdvertising();

    try {
      final ok = await _nearby.startDiscovery(
        _nickName,
        Strategy.P2P_POINT_TO_POINT,
        serviceId: _serviceId,
        onEndpointFound: (id, endpointName, serviceId) {
          _endpointNames[id] = endpointName;
          _upsertDiscovered(
            NearbyTransferPeer(endpointId: id, name: endpointName),
          );

          if (_expectedInviteSessionId != null &&
              !_autoConnectInProgress &&
              connectedPeers.every((e) => e.endpointId != id)) {
            _autoConnectInProgress = true;
            connectToPeer(
              NearbyTransferPeer(endpointId: id, name: endpointName),
            );
          }
        },
        onEndpointLost: (id) {
          if (id == null) return;
          discoveredPeers.removeWhere((e) => e.endpointId == id);
        },
      );

      isDiscovering.value = ok;
      statusText.value = ok
          ? 'Buscando dispositivos Listenfy...'
          : 'No se pudo iniciar búsqueda.';
    } catch (e) {
      isDiscovering.value = false;
      statusText.value = 'Error al buscar: $e';
    }
  }

  Future<void> stopDiscoveryMode() async {
    await _safeStopDiscovery();
    isDiscovering.value = false;
  }

  Future<void> stopAll() async {
    await _safeStopAdvertising();
    await _safeStopDiscovery();
    try {
      await _nearby.stopAllEndpoints();
    } catch (_) {}

    isAdvertising.value = false;
    isDiscovering.value = false;
    connectedPeers.clear();
    _outgoingInviteSessionId = null;
    _expectedInviteSessionId = null;

    _autoConnectInProgress = false;
    _inviteHandshakeSent.clear();
    _autoSentBySessionEndpoint.clear();
    _autoSendingBySessionEndpoint.clear();
    statusText.value = 'Transferencia detenida.';
  }

  String get nickName => _nickName;

  Future<Uri?> prepareInviteUriForSelectedItem() async {
    final item = selectedItem.value;
    if (item == null) {
      statusText.value = 'Abre esta pantalla desde una canción para enviar.';
      return null;
    }

    final variant = _pickShareVariant(item);
    if (variant == null) {
      statusText.value = 'No hay archivo local para enviar.';
      return null;
    }

    final sourcePath = variant.localPath?.trim() ?? '';
    if (sourcePath.isEmpty || !await File(sourcePath).exists()) {
      statusText.value = 'El archivo local no existe.';
      return null;
    }

    final sessionId = _createInviteSessionId(item, variant);
    _outgoingInviteSessionId = sessionId;
    _autoSentBySessionEndpoint.clear();
    _autoSendingBySessionEndpoint.clear();
    _inviteHandshakeSent.clear();

    await startAdvertisingMode();
    statusText.value = 'Escanea el QR desde el otro Listenfy para recibir.';

    return ListenfyDeepLink.buildNearbyInviteUri(
      sessionId: sessionId,
      senderName: _nickName,
      title: item.title,
      subtitle: item.subtitle,
    );
  }

  Future<void> startReceiveFromInvite(ListenfyNearbyInvite invite) async {
    _expectedInviteSessionId = invite.sessionId;

    _autoConnectInProgress = false;
    statusText.value = 'Buscando a ${invite.senderName}...';
    await startDiscoveryMode();
  }

  Future<void> connectToPeer(NearbyTransferPeer peer) async {
    try {
      final ok = await _nearby.requestConnection(
        _nickName,
        peer.endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      statusText.value = ok
          ? 'Solicitud enviada a ${peer.name}.'
          : 'No se pudo solicitar conexión a ${peer.name}.';
    } catch (e) {
      statusText.value = 'Error al conectar con ${peer.name}: $e';
    }
  }

  Future<bool> sendSelectedItemToPeer(String endpointId) async {
    final item = selectedItem.value;
    if (item == null) {
      Get.snackbar('Transferir', 'No hay canción seleccionada.');
      return false;
    }

    final variant = _pickShareVariant(item);
    if (variant == null) {
      Get.snackbar('Transferir', 'No hay archivo local para enviar.');
      return false;
    }

    final sourcePath = variant.localPath?.trim() ?? '';
    if (sourcePath.isEmpty) {
      Get.snackbar('Transferir', 'No hay ruta local del archivo.');
      return false;
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      Get.snackbar('Transferir', 'El archivo ya no existe.');
      return false;
    }

    try {
      final payloadId = await _nearby.sendFilePayload(
        endpointId,
        sourceFile.path,
      );
      debugPrint(
        '[NearbyTransfer] sendFilePayload ok endpoint=$endpointId payloadId=$payloadId file=${sourceFile.path}',
      );
      _filePayloadIds.add(payloadId);
      transferProgress[payloadId] = 0;

      final descriptor = await _OutgoingNearbyDescriptor.fromItem(
        schema: _schema,
        payloadId: payloadId,
        item: item,
        variant: variant,
      );
      final descriptorBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(descriptor.toJson())),
      );
      await _nearby.sendBytesPayload(endpointId, descriptorBytes);

      statusText.value = 'Enviando "${item.title}"...';
      return true;
    } catch (e) {
      statusText.value = 'Error al enviar: $e';
      Get.snackbar('Transferir', 'No se pudo enviar la canción.');
      return false;
    }
  }

  Future<void> _onConnectionInitiated(
    String endpointId,
    ConnectionInfo info,
  ) async {
    _endpointNames[endpointId] = info.endpointName;

    final accepted = await _showSecurityDialog(
      endpointName: info.endpointName,
      token: info.authenticationToken,
      incoming: info.isIncomingConnection,
    );
    if (!accepted) {
      await _nearby.rejectConnection(endpointId);
      statusText.value = 'Conexión rechazada.';
      return;
    }

    final ok = await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );

    statusText.value = ok
        ? 'Conectando con ${info.endpointName}...'
        : 'No se pudo aceptar conexión.';
  }

  void _onConnectionResult(String endpointId, Status status) {
    switch (status) {
      case Status.CONNECTED:
        _autoConnectInProgress = false;
        _upsertConnected(
          NearbyTransferPeer(
            endpointId: endpointId,
            name: _endpointNames[endpointId] ?? endpointId,
          ),
        );
        discoveredPeers.removeWhere((e) => e.endpointId == endpointId);
        statusText.value =
            'Conectado con ${_endpointNames[endpointId] ?? endpointId}.';
        final expectedSession = _expectedInviteSessionId;
        if (expectedSession != null && expectedSession.isNotEmpty) {
          unawaited(stopDiscoveryMode());
          _sendInviteHandshake(
            endpointId,
            expectedSession,
            event: _inviteEventHello,
          );
        }
        break;
      case Status.REJECTED:
        _autoConnectInProgress = false;
        connectedPeers.removeWhere((e) => e.endpointId == endpointId);
        statusText.value = 'Conexión rechazada.';
        break;
      case Status.ERROR:
        _autoConnectInProgress = false;
        connectedPeers.removeWhere((e) => e.endpointId == endpointId);
        statusText.value = 'Error en la conexión.';
        break;
    }
  }

  void _onDisconnected(String endpointId) {
    connectedPeers.removeWhere((e) => e.endpointId == endpointId);
    _autoSendingBySessionEndpoint.removeWhere(
      (key) => key.endsWith('|$endpointId'),
    );
    _autoSentBySessionEndpoint.removeWhere(
      (key) => key.endsWith('|$endpointId'),
    );
    statusText.value =
        'Desconectado: ${_endpointNames[endpointId] ?? endpointId}.';
  }

  Future<void> _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES) {
      if (await _handleInviteHandshakeBytes(payload.bytes, endpointId)) {
        return;
      }
      final descriptor = _handleDescriptorBytes(payload.bytes);
      if (descriptor != null) {
        debugPrint(
          '[NearbyTransfer] descriptor received endpoint=$endpointId payloadId=${descriptor.payloadId} file=${descriptor.fileName}',
        );
        statusText.value = 'Metadata recibida. Esperando archivo...';
        if (_completedPayloadIds.contains(descriptor.payloadId)) {
          await _scheduleImportRetry(descriptor.payloadId, endpointId);
        } else {
          await _tryImportReceivedPayload(descriptor.payloadId, endpointId);
        }
      }
      return;
    }

    if (payload.type == PayloadType.FILE) {
      debugPrint(
        '[NearbyTransfer] file payload received endpoint=$endpointId payloadId=${payload.id} uri=${payload.uri}',
      );
      _filePayloadIds.add(payload.id);
      _filePayloadById[payload.id] = payload;
      if (_completedPayloadIds.contains(payload.id)) {
        await _scheduleImportRetry(payload.id, endpointId);
      } else {
        await _tryImportReceivedPayload(payload.id, endpointId);
      }
    }
  }

  _IncomingNearbyDescriptor? _handleDescriptorBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) return null;
      final descriptor = _IncomingNearbyDescriptor.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (descriptor == null) return null;
      _descriptorByPayloadId[descriptor.payloadId] = descriptor;
      return descriptor;
    } catch (_) {
      // Ignore bytes payloads from other apps.
      return null;
    }
  }

  Future<void> _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) async {
    debugPrint(
      '[NearbyTransfer] update endpoint=$endpointId payloadId=${update.id} status=${update.status.name} bytes=${update.bytesTransferred}/${update.totalBytes}',
    );
    final isFilePayload = _filePayloadIds.contains(update.id);

    if (update.totalBytes > 0) {
      if (isFilePayload) {
        transferProgress[update.id] =
            update.bytesTransferred / update.totalBytes;
      }
      if (update.bytesTransferred >= update.totalBytes) {
        _completedPayloadIds.add(update.id);
        if (isFilePayload) {
          transferProgress[update.id] = 1;
        }
        if (_isIncomingPayload(update.id)) {
          await _scheduleImportRetry(update.id, endpointId);
        }
      }
    }

    switch (update.status) {
      case PayloadStatus.IN_PROGRESS:
        return;
      case PayloadStatus.SUCCESS:
        _completedPayloadIds.add(update.id);
        if (isFilePayload) {
          transferProgress[update.id] = 1;
        }
        if (_isIncomingPayload(update.id)) {
          await _scheduleImportRetry(update.id, endpointId);
        } else {
          statusText.value = 'Archivo enviado. Esperando confirmación...';
        }
        if (isFilePayload) {
          Future<void>.delayed(const Duration(seconds: 3), () {
            transferProgress.remove(update.id);
          });
        }
        return;
      case PayloadStatus.FAILURE:
      case PayloadStatus.CANCELED:
        if (isFilePayload) {
          transferProgress.remove(update.id);
        }
        _filePayloadById.remove(update.id);
        _descriptorByPayloadId.remove(update.id);
        statusText.value =
            'Transferencia fallida/cancelada (payload ${update.id}).';
        return;
      case PayloadStatus.NONE:
        return;
    }
  }

  bool _isIncomingPayload(int payloadId) =>
      _descriptorByPayloadId.containsKey(payloadId) ||
      _filePayloadById.containsKey(payloadId);

  Future<void> _scheduleImportRetry(int payloadId, String endpointId) async {
    if (_importedPayloadIds.contains(payloadId)) return;
    if (_importRetryInFlight.contains(payloadId)) return;

    _importRetryInFlight.add(payloadId);
    try {
      const maxAttempts = 12;
      for (var i = 0; i < maxAttempts; i++) {
        final done = await _tryImportReceivedPayload(payloadId, endpointId);
        if (done) return;
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }

      if (_completedPayloadIds.contains(payloadId) &&
          !_importedPayloadIds.contains(payloadId)) {
        transferProgress.remove(payloadId);
        final hasDescriptor = _descriptorByPayloadId.containsKey(payloadId);
        final hasFilePayload = _filePayloadById.containsKey(payloadId);
        debugPrint(
          '[NearbyTransfer] import timeout payloadId=$payloadId hasDescriptor=$hasDescriptor hasFilePayload=$hasFilePayload',
        );
        if (hasDescriptor && !hasFilePayload) {
          statusText.value =
              'Metadata llegó, pero no llegó el archivo (payload $payloadId).';
          final expected = _expectedInviteSessionId;
          if (expected != null && expected.isNotEmpty) {
            await _sendInviteHandshake(
              endpointId,
              expected,
              event: _inviteEventHello,
              force: true,
            );
          }
        } else if (!hasDescriptor && hasFilePayload) {
          statusText.value =
              'Archivo llegó, pero falta metadata para importar (payload $payloadId).';
        } else {
          statusText.value =
              'No se pudo finalizar importación del payload $payloadId.';
        }
      }
    } finally {
      _importRetryInFlight.remove(payloadId);
    }
  }

  Future<bool> _handleInviteHandshakeBytes(
    Uint8List? bytes,
    String endpointId,
  ) async {
    if (bytes == null || bytes.isEmpty) return false;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded);
      final schema = (map['schema'] as String?)?.trim();
      if (schema != _inviteHandshakeSchema) return false;

      final sessionId = (map['sessionId'] as String?)?.trim() ?? '';
      final event = ((map['event'] as String?) ?? _inviteEventHello)
          .trim()
          .toLowerCase();
      if (sessionId.isEmpty) return false;

      final expected = _expectedInviteSessionId;
      if (expected != null && expected == sessionId) {
        if (event == _inviteEventImported) {
          statusText.value = 'Receptor confirmó importación completa.';
          return true;
        }
        statusText.value = 'Sesión validada. Recibiendo archivo...';
        return true;
      }

      final outgoing = _outgoingInviteSessionId;
      if (outgoing != null && outgoing == sessionId) {
        if (event == _inviteEventImported) {
          statusText.value = 'Transferencia completada en receptor.';
          _outgoingInviteSessionId = null;
          unawaited(stopAdvertisingMode());
          return true;
        }

        final dedupeKey = '$sessionId|$endpointId';
        if (_autoSentBySessionEndpoint.contains(dedupeKey)) {
          statusText.value = 'Receptor ya validado. Esperando confirmación...';
          return true;
        }
        if (_autoSendingBySessionEndpoint.contains(dedupeKey)) return true;

        _autoSendingBySessionEndpoint.add(dedupeKey);
        statusText.value = 'Receptor validado. Enviando canción...';
        final sent = await sendSelectedItemToPeer(endpointId);
        _autoSendingBySessionEndpoint.remove(dedupeKey);
        if (sent) {
          _autoSentBySessionEndpoint.add(dedupeKey);
        } else {
          statusText.value =
              'Falló envío automático. Reintentando al reconectar.';
        }
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<void> _sendInviteHandshake(
    String endpointId,
    String sessionId, {
    String event = _inviteEventHello,
    bool force = false,
  }) async {
    final dedupeKey = '$sessionId|$endpointId|$event';
    if (!force && _inviteHandshakeSent.contains(dedupeKey)) return;
    if (force) {
      _inviteHandshakeSent.remove(dedupeKey);
    }
    _inviteHandshakeSent.add(dedupeKey);
    try {
      final payload = <String, dynamic>{
        'schema': _inviteHandshakeSchema,
        'sessionId': sessionId,
        'event': event,
        'from': _nickName,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      await _nearby.sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(jsonEncode(payload))),
      );
    } catch (_) {}
  }

  String _createInviteSessionId(MediaItem item, MediaVariant variant) {
    final seed = [
      item.id,
      variant.fileName,
      DateTime.now().microsecondsSinceEpoch.toString(),
      _nickName,
    ].join('|');
    return sha1.convert(utf8.encode(seed)).toString().substring(0, 16);
  }

  Future<bool> _tryImportReceivedPayload(
    int payloadId,
    String endpointId,
  ) async {
    if (_importedPayloadIds.contains(payloadId)) return true;
    if (!_completedPayloadIds.contains(payloadId)) return false;

    final descriptor = _descriptorByPayloadId[payloadId];
    final payload = _filePayloadById[payloadId];
    if (descriptor == null || payload == null) return false;

    final destination = await _buildDestinationPath(
      payloadId,
      descriptor.fileName,
    );
    if (destination == null) return false;

    final copied = await _copyNearbyPayloadTo(destination, payload);
    if (!copied) {
      statusText.value = 'No se pudo guardar el archivo recibido.';
      return false;
    }

    final importedItem = await _buildImportedItemFromDescriptor(
      descriptor: descriptor,
      destinationPath: destination,
    );
    if (importedItem == null) {
      statusText.value = 'No se pudo importar archivo recibido.';
      return false;
    }

    await _store.upsert(importedItem);
    if (Get.isRegistered<DownloadsController>()) {
      await Get.find<DownloadsController>().load();
    }

    _importedPayloadIds.add(payloadId);
    transferProgress[payloadId] = 1;
    statusText.value =
        'Canción recibida de ${_endpointNames[endpointId] ?? endpointId}.';

    final expectedSession = _expectedInviteSessionId;
    if (expectedSession != null && expectedSession.isNotEmpty) {
      await _sendInviteHandshake(
        endpointId,
        expectedSession,
        event: _inviteEventImported,
      );
    }

    Get.snackbar(
      'Transferencia completa',
      'Se importó "${importedItem.title}".',
      snackPosition: SnackPosition.BOTTOM,
    );
    return true;
  }

  Future<MediaItem?> _buildImportedItemFromDescriptor({
    required _IncomingNearbyDescriptor descriptor,
    required String destinationPath,
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

      final coverPath = await _saveIncomingCover(
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
      statusText.value = 'Error al crear media importada: $e';
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

  Future<bool> _copyNearbyPayloadTo(
    String destinationPath,
    Payload payload,
  ) async {
    try {
      if (payload.uri != null && payload.uri!.trim().isNotEmpty) {
        final ok = await _nearby.copyFileAndDeleteOriginal(
          payload.uri!,
          destinationPath,
        );
        if (!ok) return false;
        return _hasValidFile(destinationPath);
      }

      // ignore: deprecated_member_use
      final fp = payload.filePath;
      if (fp != null && fp.trim().isNotEmpty) {
        final source = File(fp);
        if (await source.exists()) {
          await source.copy(destinationPath);
          return _hasValidFile(destinationPath);
        }
      }
    } catch (_) {}
    return false;
  }

  bool _hasValidFile(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      final stat = file.statSync();
      return stat.size > 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _saveIncomingCover({
    required String itemId,
    required String? base64Cover,
  }) async {
    final raw = (base64Cover ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      final bytes = base64Decode(raw);
      if (bytes.isEmpty) return null;

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

  Future<bool> _showSecurityDialog({
    required String endpointName,
    required String token,
    required bool incoming,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(incoming ? 'Conexión entrante' : 'Confirmar conexión'),
        content: Text(
          'Dispositivo: $endpointName\n\n'
          'Código de validación:\n$token\n\n'
          'Acepta solo si el mismo código aparece en ambos dispositivos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Rechazar'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    return result == true;
  }

  Future<void> _safeStopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
    } catch (_) {}
  }

  Future<void> _safeStopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
    } catch (_) {}
  }

  void _upsertDiscovered(NearbyTransferPeer peer) {
    final idx = discoveredPeers.indexWhere(
      (e) => e.endpointId == peer.endpointId,
    );
    if (idx < 0) {
      discoveredPeers.add(peer);
    } else {
      discoveredPeers[idx] = peer;
      discoveredPeers.refresh();
    }
  }

  void _upsertConnected(NearbyTransferPeer peer) {
    final idx = connectedPeers.indexWhere(
      (e) => e.endpointId == peer.endpointId,
    );
    if (idx < 0) {
      connectedPeers.add(peer);
    } else {
      connectedPeers[idx] = peer;
      connectedPeers.refresh();
    }
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

  Future<bool> _ensureNearbyPermissions() async {
    try {
      final perms = <Permission>[
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.location,
      ];

      // Android 13+ only; harmless en versiones previas.
      try {
        perms.add(Permission.nearbyWifiDevices);
      } catch (_) {}

      final statuses = await perms.request();
      final allGranted = statuses.values.every(
        (s) => s.isGranted || s.isLimited,
      );
      if (!allGranted) {
        statusText.value = 'Permisos incompletos para transferencia offline.';
        Get.snackbar(
          'Permisos requeridos',
          'Activa Bluetooth, ubicación y Nearby Wi-Fi para usar transferencia offline.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final locationEnabled = await Permission.location.serviceStatus.isEnabled;
      if (!locationEnabled) {
        statusText.value = 'Activa ubicación (GPS) para conexiones Nearby.';
        Get.snackbar(
          'Ubicación desactivada',
          'Para Nearby debes activar ubicación del sistema.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      return true;
    } catch (e) {
      statusText.value = 'Error validando permisos: $e';
      return false;
    }
  }
}

class _OutgoingNearbyDescriptor {
  final String schema;
  final int payloadId;
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

  _OutgoingNearbyDescriptor({
    required this.schema,
    required this.payloadId,
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
  });

  static Future<_OutgoingNearbyDescriptor> fromItem({
    required String schema,
    required int payloadId,
    required MediaItem item,
    required MediaVariant variant,
  }) async {
    String? coverBase64;
    final coverPath = (item.thumbnailLocalPath ?? '').trim();
    if (coverPath.isNotEmpty) {
      try {
        final coverFile = File(coverPath);
        if (await coverFile.exists()) {
          final len = await coverFile.length();
          if (len > 0 && len <= (1024 * 1024 * 2)) {
            coverBase64 = base64Encode(await coverFile.readAsBytes());
          }
        }
      } catch (_) {}
    }

    return _OutgoingNearbyDescriptor(
      schema: schema,
      payloadId: payloadId,
      fileName: p.basename(variant.localPath ?? variant.fileName),
      format: variant.format.toLowerCase().trim(),
      kind: variant.kind == MediaVariantKind.video ? 'video' : 'audio',
      role: variant.roleKey,
      title: item.title,
      subtitle: item.subtitle,
      country: item.country,
      durationSeconds: item.durationSeconds ?? variant.durationSeconds,
      lyrics: item.lyrics,
      lyricsLanguage: item.lyricsLanguage,
      translations: item.translations,
      coverBase64: coverBase64,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'payloadId': payloadId,
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
    'coverBase64': coverBase64,
  };
}

class _IncomingNearbyDescriptor {
  final int payloadId;
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

  _IncomingNearbyDescriptor({
    required this.payloadId,
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

    final fileName = (json['fileName'] as String?)?.trim() ?? '';
    if (fileName.isEmpty) return null;

    final kind = ((json['kind'] as String?) ?? 'audio').trim().toLowerCase();
    final format = ((json['format'] as String?) ?? '').trim().toLowerCase();
    final role = ((json['role'] as String?) ?? 'main').trim().toLowerCase();
    final title = ((json['title'] as String?) ?? '').trim();
    final subtitle = ((json['subtitle'] as String?) ?? '').trim();
    final country = (json['country'] as String?)?.trim();
    final durationRaw = json['durationSeconds'];
    final duration = durationRaw is num ? durationRaw.toInt() : null;
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
      payloadId: payloadId,
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
