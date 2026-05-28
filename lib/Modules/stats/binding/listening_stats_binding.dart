import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../artists/data/artist_store.dart';
import '../../sources/binding/sources_binding.dart';
import '../../sources/controller/sources_controller.dart';
import '../controller/listening_stats_controller.dart';

class ListeningStatsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<LocalLibraryStore>()) {
      Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<ArtistStore>()) {
      Get.put(ArtistStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<SourcesController>()) {
      SourcesBinding().dependencies();
    }

    if (!Get.isRegistered<ListeningStatsController>()) {
      Get.lazyPut<ListeningStatsController>(() => ListeningStatsController());
    }
  }
}
