import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../Modules/artists/data/artist_store.dart';
import '../../Modules/downloads/controller/downloads_controller.dart';
import '../../Modules/downloads/data/repositories/downloads_repository_impl.dart';
import '../../Modules/downloads/domain/contracts/downloads_repository.dart';
import '../../Modules/downloads/domain/usecases/load_download_items_usecase.dart';
import '../../Modules/downloads/service/download_task_service.dart';
import '../../Modules/playlists/data/playlist_store.dart';
import '../../Modules/recommendations/application/local_ml_recommendation_ranker.dart';
import '../../Modules/recommendations/application/local_recommendation_service.dart';
import '../../Modules/recommendations/application/recommendation_feedback_service.dart';
import '../../Modules/recommendations/data/listening_event_store.dart';
import '../../Modules/recommendations/data/recommendation_feedback_store.dart';
import '../../Modules/recommendations/data/recommendation_ml_store.dart';
import '../../Modules/recommendations/data/recommendation_store.dart';
import '../../Modules/recommendations/domain/contracts/recommendation_engine.dart';
import '../../Modules/settings/controller/equalizer_controller.dart';
import '../../Modules/settings/controller/notification_settings_controller.dart';
import '../../Modules/settings/controller/playback_settings_controller.dart';
import '../../Modules/settings/controller/settings_controller.dart';
import '../../Modules/settings/controller/sleep_timer_controller.dart';
import '../../Modules/sources/data/source_theme_topic_playlist_store.dart';
import '../../Modules/sources/data/source_theme_topic_store.dart';
import '../../Modules/stats/application/weekly_listening_summary.dart';
import '../bootstrap/app_bootstrap.dart';
import '../controllers/media_actions_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/theme_controller.dart';
import '../data/local/local_library_store.dart';
import '../data/network/dio_client.dart';
import '../data/repo/media_repository.dart';
import '../services/audio_service.dart';
import '../services/deep_link_service.dart';
import '../services/instrumental_generation_service.dart';
import '../services/karaoke_remote_pipeline_service.dart';
import '../services/local_media_metadata_service.dart';
import '../services/notification_service.dart';
import '../services/spatial8d_generation_service.dart';
import '../services/spatial_audio_service.dart';
import '../services/video_service.dart';

/// Registers dependencies whose lifecycle belongs to the whole application.
/// Route-specific controllers remain the responsibility of feature bindings.
class AppBinding extends Bindings {
  AppBinding(this._bootstrap);

  final AppBootstrap _bootstrap;

  @override
  void dependencies() {
    final storage = GetStorage();

    Get.put(ThemeController(), permanent: true);
    Get.put(NavigationController(), permanent: true);
    Get.put<NotificationService>(
      _bootstrap.notificationService,
      permanent: true,
    );

    // These controllers currently support app-wide playback, appearance and
    // background behavior. Their single registration lives here until those
    // capabilities are separated from their settings presentation.
    Get.put(SettingsController(), permanent: true);
    Get.put(PlaybackSettingsController(), permanent: true);
    Get.put(SleepTimerController(), permanent: true);
    Get.put(EqualizerController(), permanent: true);
    Get.put(NotificationSettingsController(), permanent: true);

    Get.put<AudioService>(_bootstrap.audioService, permanent: true);
    Get.put<VideoService>(VideoService(), permanent: true);
    Get.put<SpatialAudioService>(
      SpatialAudioService(audioService: _bootstrap.audioService),
      permanent: true,
    );

    Get.lazyPut<DioClient>(() => DioClient(), fenix: true);
    Get.put<GetStorage>(storage, permanent: true);
    Get.put(
      KaraokeRemotePipelineService(client: Get.find<DioClient>()),
      permanent: true,
    );
    Get.put(LocalMediaMetadataService(), permanent: true);

    Get.put(LocalLibraryStore(storage), permanent: true);
    Get.put(PlaylistStore(storage), permanent: true);
    Get.put(ArtistStore(storage), permanent: true);
    Get.put(InstrumentalGenerationService(), permanent: true);
    Get.put(Spatial8dGenerationService(), permanent: true);
    Get.put(SourceThemeTopicStore(storage), permanent: true);
    Get.put(SourceThemeTopicPlaylistStore(storage), permanent: true);

    Get.put(MediaActionsController(), permanent: true);
    Get.lazyPut<MediaRepository>(() => MediaRepository(), fenix: true);

    Get.put(RecommendationStore(storage), permanent: true);
    Get.put(RecommendationFeedbackStore(storage), permanent: true);
    Get.put(ListeningEventStore(storage), permanent: true);
    Get.put(RecommendationMlStore(storage), permanent: true);
    Get.put(
      LocalMlRecommendationRanker(store: Get.find<RecommendationMlStore>()),
      permanent: true,
    );
    Get.put(
      RecommendationFeedbackService(
        store: Get.find<RecommendationFeedbackStore>(),
      ),
      permanent: true,
    );
    final recommendationService = LocalRecommendationService(
      store: Get.find<RecommendationStore>(),
      feedbackService: Get.find<RecommendationFeedbackService>(),
      listeningEventStore: Get.find<ListeningEventStore>(),
      ranker: Get.find<LocalMlRecommendationRanker>(),
      libraryLoader: () => Get.find<MediaRepository>().getLibrary(),
      artistProfileLoader: () => Get.find<ArtistStore>().readAll(),
      topicLoader: () => Get.find<SourceThemeTopicStore>().readAll(),
      topicPlaylistLoader: () =>
          Get.find<SourceThemeTopicPlaylistStore>().readAll(),
    );
    Get.put<LocalRecommendationService>(recommendationService, permanent: true);
    Get.put<RecommendationEngine>(recommendationService, permanent: true);

    final weeklySummaryBuilder = WeeklyListeningSummaryBuilder(
      listeningEventStore: Get.find<ListeningEventStore>(),
      libraryLoader: () => Get.find<MediaRepository>().getLibrary(),
    );
    Get.find<NotificationService>().configureWeeklySummaryLoader(
      weeklySummaryBuilder.build,
    );

    Get.put(DownloadTaskService(), permanent: true);
    Get.lazyPut<DownloadsRepository>(
      () =>
          DownloadsRepositoryImpl(mediaRepository: Get.find<MediaRepository>()),
      fenix: true,
    );
    Get.lazyPut<LoadDownloadItemsUseCase>(
      () =>
          LoadDownloadItemsUseCase(repository: Get.find<DownloadsRepository>()),
      fenix: true,
    );
    Get.put(
      DownloadsController(
        loadDownloadItemsUseCase: Get.find<LoadDownloadItemsUseCase>(),
      ),
      permanent: true,
    );
    Get.put(DeepLinkService(), permanent: true);

    try {
      Get.find<EqualizerController>().refreshEqualizer();
    } catch (_) {
      // The audio platform may reject this during early startup.
    }
  }
}
