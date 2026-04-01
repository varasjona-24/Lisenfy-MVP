import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../domain/entities/local_connect_models.dart';
import '../service/local_connect_server_service.dart';

class LocalConnectController extends GetxController {
  final LocalConnectServerService _service =
      Get.find<LocalConnectServerService>();

  RxBool get isRunning => _service.isRunning;
  RxString get serverUrl => _service.serverUrl;
  RxString get wsUrl => _service.wsUrl;
  RxString get serverError => _service.serverError;
  RxList<LocalConnectPairingRequest> get pendingRequests =>
      _service.pendingRequests;
  RxList<LocalConnectClientSession> get sessions => _service.sessions;

  Worker? _pendingWorker;
  String? _lastPromptedRequestId;
  bool _dialogOpen = false;

  @override
  void onInit() {
    super.onInit();
    if (!isRunning.value) {
      unawaited(startServer());
    }
    _pendingWorker = ever<List<LocalConnectPairingRequest>>(
      _service.pendingRequests,
      _onPendingRequestsChanged,
    );
  }

  @override
  void onClose() {
    _pendingWorker?.dispose();
    super.onClose();
  }

  Future<void> startServer() => _service.start();
  Future<void> stopServer() => _service.stop();

  Future<void> approvePairing(String requestId) {
    return _service.approvePairingRequest(requestId);
  }

  Future<void> rejectPairing(String requestId) {
    return _service.rejectPairingRequest(requestId);
  }

  void _onPendingRequestsChanged(List<LocalConnectPairingRequest> requests) {
    if (requests.isEmpty || _dialogOpen) return;

    final newest = requests.first;
    if (_lastPromptedRequestId == newest.id) return;
    _lastPromptedRequestId = newest.id;
    _dialogOpen = true;

    Get.dialog<void>(
      AlertDialog(
        title: const Text('Nueva solicitud de emparejamiento'),
        content: Text(
          'Cliente: ${newest.clientName}\nID: ${newest.clientId}\n\n¿Deseas autorizar esta sesión web?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await rejectPairing(newest.id);
              _dialogOpen = false;
              if (Get.isDialogOpen ?? false) {
                Get.back<void>();
              }
            },
            child: const Text('Rechazar'),
          ),
          FilledButton(
            onPressed: () async {
              await approvePairing(newest.id);
              _dialogOpen = false;
              if (Get.isDialogOpen ?? false) {
                Get.back<void>();
              }
            },
            child: const Text('Aprobar'),
          ),
        ],
      ),
      barrierDismissible: false,
    ).whenComplete(() {
      _dialogOpen = false;
    });
  }
}
