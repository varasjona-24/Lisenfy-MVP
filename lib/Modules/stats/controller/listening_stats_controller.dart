import 'package:get/get.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../artists/data/artist_store.dart';
import '../../sources/binding/sources_binding.dart';
import '../../sources/controller/sources_controller.dart';
import '../domain/entities/listening_stats_entities.dart';

class ListeningStatsController extends GetxController {
  late final LocalLibraryStore _libraryStore;
  late final ArtistStore? _artistStore;
  late final SourcesController _sourcesController;

  final RxBool isLoading = true.obs;
  final RxBool showDashboard = false.obs;
  final RxList<MediaItem> _mediaItems = <MediaItem>[].obs;
  final Rxn<ListeningStats> stats = Rxn<ListeningStats>();
  Worker? _topicsWorker;
  Worker? _playlistsWorker;
  Worker? _itemsWorker;

  @override
  void onInit() {
    super.onInit();
    _libraryStore = Get.find<LocalLibraryStore>();
    _artistStore = Get.isRegistered<ArtistStore>()
        ? Get.find<ArtistStore>()
        : null;

    if (!Get.isRegistered<SourcesController>()) {
      SourcesBinding().dependencies();
    }
    _sourcesController = Get.find<SourcesController>();

    _loadData();
  }

  Future<void> _loadData() async {
    isLoading.value = true;
    try {
      final items = await _libraryStore.readAll();
      _mediaItems.assignAll(items);
      _bindReactivity();
      _computeStats();
    } catch (e) {
      // Handle error silently
    } finally {
      isLoading.value = false;
    }
  }

  void _bindReactivity() {
    _topicsWorker ??= ever(_sourcesController.topics, (_) => _computeStats());
    _playlistsWorker ??= ever(
      _sourcesController.topicPlaylists,
      (_) => _computeStats(),
    );
    _itemsWorker ??= ever(_mediaItems, (_) => _computeStats());
  }

  void _computeStats() {
    stats.value = ListeningStats.fromItems(
      _mediaItems,
      artistStore: _artistStore,
      sourcesController: _sourcesController,
    );
  }

  Future<void> refreshStats() async {
    try {
      final items = await _libraryStore.readAll();
      _mediaItems.assignAll(items);
    } catch (_) {
      // Handle error silently
    }
  }

  void openDashboard() {
    showDashboard.value = true;
  }

  void closeDashboard() {
    showDashboard.value = false;
  }

  @override
  void onClose() {
    _topicsWorker?.dispose();
    _playlistsWorker?.dispose();
    _itemsWorker?.dispose();
    super.onClose();
  }
}
