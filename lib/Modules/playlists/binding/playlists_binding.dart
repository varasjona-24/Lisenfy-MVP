import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/repo/media_repository.dart';
import '../controller/playlists_controller.dart';
import '../data/playlist_store.dart';

class PlaylistsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<MediaRepository>()) {
      Get.put(MediaRepository(), permanent: true);
    }
    if (!Get.isRegistered<PlaylistStore>()) {
      Get.put(PlaylistStore(Get.find<GetStorage>()), permanent: true);
    }

    if (!Get.isRegistered<PlaylistsController>()) {
      Get.put(PlaylistsController());
    }
  }
}
