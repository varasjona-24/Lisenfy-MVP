import 'package:get/get.dart';

import '../controller/nearby_transfer_controller.dart';

class NearbyTransferBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<NearbyTransferController>()) {
      Get.put(NearbyTransferController(), permanent: true);
    } else {
      Get.find<NearbyTransferController>().acceptArguments(Get.arguments);
    }
  }
}
