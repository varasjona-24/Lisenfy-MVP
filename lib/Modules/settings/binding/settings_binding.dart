import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../playlists/data/playlist_store.dart';
import '../../artists/data/artist_store.dart';
import '../../sources/data/source_theme_pill_store.dart';
import '../../sources/data/source_theme_topic_store.dart';
import '../../sources/data/source_theme_topic_playlist_store.dart';
import '../../recommendations/data/recommendation_store.dart';
import '../../recommendations/data/recommendation_feedback_store.dart';
import '../controller/settings_controller.dart';
import '../controller/playback_settings_controller.dart';
import '../controller/sleep_timer_controller.dart';
import '../controller/equalizer_controller.dart';
import '../controller/backup_restore_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GetStorage>()) {
      Get.put(GetStorage(), permanent: true);
    }
    if (!Get.isRegistered<LocalLibraryStore>()) {
      Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<PlaylistStore>()) {
      Get.put(PlaylistStore(Get.find<GetStorage>()), permanent: true);
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
    if (!Get.isRegistered<RecommendationStore>()) {
      Get.put(RecommendationStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<RecommendationFeedbackStore>()) {
      Get.put(
        RecommendationFeedbackStore(Get.find<GetStorage>()),
        permanent: true,
      );
    }
    Get.lazyPut<SettingsController>(() => SettingsController(), fenix: true);
    Get.lazyPut<PlaybackSettingsController>(
      () => PlaybackSettingsController(),
      fenix: true,
    );
    Get.lazyPut<SleepTimerController>(
      () => SleepTimerController(),
      fenix: true,
    );
    Get.lazyPut<EqualizerController>(() => EqualizerController(), fenix: true);
    Get.lazyPut<BackupRestoreController>(
      () => BackupRestoreController(),
      fenix: true,
    );
  }
}
