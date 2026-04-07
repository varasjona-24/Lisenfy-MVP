import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/network/dio_client.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../artists/data/artist_store.dart';
import '../agent/local_affinity_engine.dart';
import '../agent/radio_station_planner.dart';
import '../agent/sync_manager.dart';
import '../controller/world_mode_controller.dart';
import '../data/datasources/world_local_datasource.dart';
import '../data/datasources/world_remote_datasource.dart';
import '../data/repositories/world_mode_repository_impl.dart';
import '../domain/repositories/world_mode_repository.dart';
import '../services/world_mode_playback_facade.dart';

class WorldModeBinding extends Bindings {
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
    if (!Get.isRegistered<MediaRepository>()) {
      Get.put(MediaRepository(), permanent: true);
    }
    if (!Get.isRegistered<DioClient>()) {
      Get.put(DioClient(), permanent: true);
    }

    if (!Get.isRegistered<WorldLocalDatasource>()) {
      Get.put(WorldLocalDatasource(Get.find<GetStorage>()), permanent: true);
    }
    if (!Get.isRegistered<WorldRemoteDatasource>()) {
      Get.put(WorldRemoteDatasource(Get.find<DioClient>()), permanent: true);
    }
    if (!Get.isRegistered<LocalAffinityEngine>()) {
      Get.put(
        LocalAffinityEngine(artistStore: Get.find<ArtistStore>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<RadioStationPlanner>()) {
      Get.put(
        RadioStationPlanner(Get.find<LocalAffinityEngine>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<SyncManager>()) {
      Get.put(SyncManager(Get.find<WorldRemoteDatasource>()), permanent: true);
    }
    if (!Get.isRegistered<WorldModePlaybackFacade>()) {
      Get.put(const WorldModePlaybackFacade(), permanent: true);
    }
    if (!Get.isRegistered<WorldModeRepository>()) {
      Get.put<WorldModeRepository>(
        WorldModeRepositoryImpl(
          mediaRepository: Get.find<MediaRepository>(),
          localDatasource: Get.find<WorldLocalDatasource>(),
          artistStore: Get.find<ArtistStore>(),
          affinityEngine: Get.find<LocalAffinityEngine>(),
          radioPlanner: Get.find<RadioStationPlanner>(),
          syncManager: Get.find<SyncManager>(),
        ),
        permanent: true,
      );
    }

    if (!Get.isRegistered<WorldModeController>()) {
      Get.put(
        WorldModeController(
          repository: Get.find<WorldModeRepository>(),
          playbackFacade: Get.find<WorldModePlaybackFacade>(),
        ),
      );
    }
  }
}
