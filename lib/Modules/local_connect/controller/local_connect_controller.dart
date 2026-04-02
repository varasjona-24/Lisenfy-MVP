import 'dart:async';

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

  @override
  void onInit() {
    super.onInit();
    if (!isRunning.value) {
      unawaited(startServer());
    }
  }

  Future<void> startServer() => _service.start();
  Future<void> stopServer() => _service.stop();

  Future<void> approvePairing(String requestId) {
    return _service.approvePairingRequest(requestId);
  }

  Future<void> rejectPairing(String requestId) {
    return _service.rejectPairingRequest(requestId);
  }
}
