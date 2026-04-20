import 'package:get/get.dart';
import 'package:listenfy/Modules/downloads/data/repositories/downloads_repository_impl.dart';
import 'package:listenfy/Modules/downloads/domain/contracts/downloads_repository.dart';
import 'package:listenfy/Modules/downloads/domain/usecases/load_download_items_usecase.dart';
import 'package:listenfy/app/data/repo/media_repository.dart';

import '../controller/downloads_controller.dart';
import '../service/download_task_service.dart';

// ============================
// 📦 BINDINGS
// ============================
class DownloadsBinding extends Bindings {
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

    if (!Get.isRegistered<LoadDownloadItemsUseCase>()) {
      Get.lazyPut<LoadDownloadItemsUseCase>(
        () => LoadDownloadItemsUseCase(
          repository: Get.find<DownloadsRepository>(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<DownloadTaskService>()) {
      Get.put(DownloadTaskService(), permanent: true);
    }
    if (!Get.isRegistered<DownloadsController>()) {
      Get.put(
        DownloadsController(
          loadDownloadItemsUseCase: Get.find<LoadDownloadItemsUseCase>(),
        ),
      );
    }
  }
}
