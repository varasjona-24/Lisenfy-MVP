import 'package:get/get.dart';
import 'package:listenfy/Modules/history/controller/history_controller.dart';
import 'package:listenfy/Modules/history/data/repositories/history_repository_impl.dart';
import 'package:listenfy/Modules/history/domain/contracts/history_repository.dart';
import 'package:listenfy/Modules/history/domain/usecases/load_history_items_usecase.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import 'package:listenfy/app/data/repo/media_repository.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<HistoryRepository>()) {
      Get.lazyPut<HistoryRepository>(
        () => HistoryRepositoryImpl(mediaRepository: Get.find<MediaRepository>()),
        fenix: true,
      );
    }

    if (!Get.isRegistered<LoadHistoryItemsUseCase>()) {
      Get.lazyPut<LoadHistoryItemsUseCase>(
        () => LoadHistoryItemsUseCase(repository: Get.find<HistoryRepository>()),
        fenix: true,
      );
    }

    if (!Get.isRegistered<HistoryController>()) {
      Get.put(
        HistoryController(
          loadHistoryItemsUseCase: Get.find<LoadHistoryItemsUseCase>(),
          homeController: Get.isRegistered<HomeController>()
              ? Get.find<HomeController>()
              : null,
        ),
      );
    }
  }
}
