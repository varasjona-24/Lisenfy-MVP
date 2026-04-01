import 'package:get/get.dart';

import '../controller/local_connect_controller.dart';
import '../service/local_connect_server_service.dart';

class LocalConnectBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LocalConnectServerService>()) {
      Get.put(LocalConnectServerService(), permanent: true);
    }
    if (!Get.isRegistered<LocalConnectController>()) {
      Get.put(LocalConnectController());
    }
  }
}
