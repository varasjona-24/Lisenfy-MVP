import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/network/dio_client.dart';
import '../../../app/data/repo/media_repository.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import '../../artists/data/artist_store.dart';
import '../../sources/data/source_theme_topic_store.dart';
import '../../sources/data/source_theme_topic_playlist_store.dart';
import '../../recommendations/data/recommendation_store.dart';
import '../../recommendations/data/recommendation_feedback_store.dart';
import '../../recommendations/application/hybrid_recommendation_service.dart';
import '../../recommendations/application/local_recommendation_service.dart';
import '../../recommendations/application/recommendation_feedback_service.dart';
import '../../recommendations/domain/contracts/recommendation_engine.dart';
import '../../recommendations/application/usecases/get_or_build_daily_recommendations_use_case.dart';
import '../../recommendations/application/usecases/refresh_daily_recommendations_use_case.dart';
import '../../recommendations/application/usecases/recommendation_refresh_policy_use_case.dart';
import '../../recommendations/application/usecases/build_recommendation_collections_use_case.dart';

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
    if (!Get.isRegistered<RecommendationFeedbackStore>()) {
      Get.put(
        RecommendationFeedbackStore(Get.find<GetStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<RecommendationFeedbackService>()) {
      Get.put(
        RecommendationFeedbackService(
          store: Get.find<RecommendationFeedbackStore>(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ArtistStore>()) {
      Get.put(ArtistStore(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<DioClient>()) {
      Get.put(DioClient(), permanent: true);
    }

    // Repo (local-first)
    if (!Get.isRegistered<MediaRepository>()) {
      Get.put(MediaRepository(), permanent: true);
    }
    if (!Get.isRegistered<LocalRecommendationService>()) {
      final service = LocalRecommendationService(
        store: Get.find<RecommendationStore>(),
        feedbackService: Get.find<RecommendationFeedbackService>(),
        libraryLoader: () => Get.find<MediaRepository>().getLibrary(),
        artistProfileLoader: () => Get.find<ArtistStore>().readAll(),
        topicLoader: () => Get.find<SourceThemeTopicStore>().readAll(),
        topicPlaylistLoader: () =>
            Get.find<SourceThemeTopicPlaylistStore>().readAll(),
      );
      Get.put<LocalRecommendationService>(service, permanent: true);
    }
    if (!Get.isRegistered<HybridRecommendationService>()) {
      Get.put(
        HybridRecommendationService(
          localEngine: Get.find<LocalRecommendationService>(),
          client: Get.find<DioClient>(),
          libraryLoader: () => Get.find<MediaRepository>().getLibrary(),
          feedbackService: Get.find<RecommendationFeedbackService>(),
        ),
        permanent: true,
      );
    }
    final engine = Get.find<HybridRecommendationService>();
    if (Get.isRegistered<RecommendationEngine>()) {
      Get.replace<RecommendationEngine>(engine);
    } else {
      Get.put<RecommendationEngine>(engine, permanent: true);
    }
    if (!Get.isRegistered<GetOrBuildDailyRecommendationsUseCase>()) {
      Get.lazyPut<GetOrBuildDailyRecommendationsUseCase>(
        () => GetOrBuildDailyRecommendationsUseCase(
          Get.find<RecommendationEngine>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<RefreshDailyRecommendationsUseCase>()) {
      Get.lazyPut<RefreshDailyRecommendationsUseCase>(
        () => RefreshDailyRecommendationsUseCase(
          Get.find<RecommendationEngine>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<RecommendationRefreshPolicyUseCase>()) {
      Get.lazyPut<RecommendationRefreshPolicyUseCase>(
        () => RecommendationRefreshPolicyUseCase(
          Get.find<RecommendationEngine>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<BuildRecommendationCollectionsUseCase>()) {
      Get.lazyPut<BuildRecommendationCollectionsUseCase>(
        () => const BuildRecommendationCollectionsUseCase(),
        fenix: true,
      );
    }

    // Controller
    Get.put(HomeController());
  }
}
