import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/services/audio_cleanup_service.dart';
import '../../artists/controller/artists_controller.dart';
import '../../artists/data/artist_store.dart';
import '../../captures/data/capture_gallery_store.dart';
import '../../playlists/controller/playlists_controller.dart';
import '../../playlists/data/playlist_store.dart';
import '../../sources/controller/sources_controller.dart';
import '../../sources/data/source_theme_pill_store.dart';
import '../../sources/data/source_theme_topic_store.dart';
import '../../sources/data/source_theme_topic_playlist_store.dart';

import '../controller/edit_entity_controller.dart';

class EditEntityBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<LocalLibraryStore>()) {
      Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<MediaRepository>()) {
      Get.put(MediaRepository(), permanent: true);
    }
    if (!Get.isRegistered<AudioCleanupService>()) {
      Get.put(AudioCleanupService(), permanent: true);
    }
    if (!Get.isRegistered<ArtistStore>()) {
      Get.put(ArtistStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<SourceThemePillStore>()) {
      Get.put(SourceThemePillStore(Get.find<GetStorage>()), permanent: true);
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
    if (!Get.isRegistered<PlaylistStore>()) {
      Get.put(PlaylistStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<CaptureGalleryStore>()) {
      Get.put(CaptureGalleryStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<ArtistsController>()) {
      Get.put(ArtistsController());
    }
    if (!Get.isRegistered<PlaylistsController>()) {
      Get.put(PlaylistsController());
    }
    if (!Get.isRegistered<SourcesController>()) {
      Get.put(SourcesController());
    }

    Get.lazyPut<EditEntityController>(() => EditEntityController());
  }
}
