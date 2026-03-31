import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import '../../artists/data/artist_store.dart';
import '../../sources/data/source_theme_topic_store.dart';
import '../../sources/data/source_theme_topic_playlist_store.dart';
import '../data/recommendation_store.dart';
import '../service/local_recommendation_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Local storage
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<LocalLibraryStore>()) {
      Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<SourceThemeTopicStore>()) {
      Get.put(SourceThemeTopicStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<SourceThemeTopicPlaylistStore>()) {
      Get.put(
        SourceThemeTopicPlaylistStore(Get.find<GetStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<RecommendationStore>()) {
      Get.put(RecommendationStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<ArtistStore>()) {
      Get.put(ArtistStore(Get.find<GetStorage>()), permanent: true);
    }

    // Repo (local-first)
    if (!Get.isRegistered<MediaRepository>()) {
      Get.put(MediaRepository(), permanent: true);
    }
    if (!Get.isRegistered<LocalRecommendationService>()) {
      Get.put(
        LocalRecommendationService(
          store: Get.find<RecommendationStore>(),
          libraryLoader: () => Get.find<MediaRepository>().getLibrary(),
          artistProfileLoader: () => Get.find<ArtistStore>().readAll(),
          topicLoader: () => Get.find<SourceThemeTopicStore>().readAll(),
          topicPlaylistLoader: () =>
              Get.find<SourceThemeTopicPlaylistStore>().readAll(),
        ),
        permanent: true,
      );
    }

    // Controller
    Get.put(HomeController());
  }
}
