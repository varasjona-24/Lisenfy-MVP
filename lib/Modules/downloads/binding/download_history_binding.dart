import 'package:get/get.dart';
import 'package:listenfy/Modules/downloads/data/repositories/downloads_repository_impl.dart';
import 'package:listenfy/Modules/downloads/domain/contracts/downloads_repository.dart';
import 'package:listenfy/Modules/downloads/domain/usecases/load_download_history_items_usecase.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import 'package:listenfy/app/data/repo/media_repository.dart';

import '../controller/download_history_controller.dart';

// ============================
// 🧷 BINDING: HISTORIAL DE IMPORTS
// ============================
class DownloadHistoryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DownloadsRepository>()) {
      Get.lazyPut<DownloadsRepository>(
        () => DownloadsRepositoryImpl(
          mediaRepository: Get.find<MediaRepository>(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<LoadDownloadHistoryItemsUseCase>()) {
      Get.lazyPut<LoadDownloadHistoryItemsUseCase>(
        () => LoadDownloadHistoryItemsUseCase(
          repository: Get.find<DownloadsRepository>(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<DownloadHistoryController>()) {
      Get.put(
        DownloadHistoryController(
          loadHistoryItemsUseCase: Get.find<LoadDownloadHistoryItemsUseCase>(),
          homeController: Get.isRegistered<HomeController>()
              ? Get.find<HomeController>()
              : null,
        ),
      );
    }
  }
}
