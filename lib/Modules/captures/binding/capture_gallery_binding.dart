import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../controller/capture_gallery_controller.dart';
import '../data/capture_gallery_store.dart';
import '../services/capture_cover_service.dart';
import '../services/capture_share_service.dart';

class CaptureGalleryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<CaptureGalleryStore>()) {
      Get.lazyPut<CaptureGalleryStore>(
        () => CaptureGalleryStore(Get.find<GetStorage>()),
      );
    }
    if (!Get.isRegistered<CaptureShareService>()) {
      Get.lazyPut<CaptureShareService>(() => const CaptureShareService());
    }
    if (!Get.isRegistered<CaptureCoverService>()) {
      Get.lazyPut<CaptureCoverService>(() => const CaptureCoverService());
    }
    if (!Get.isRegistered<CaptureGalleryController>()) {
      Get.lazyPut<CaptureGalleryController>(() => CaptureGalleryController());
    }
  }
}
