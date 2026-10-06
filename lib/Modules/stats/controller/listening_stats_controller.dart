import 'package:get/get.dart';
import 'dart:async';
import '../../../app/data/playback/playback_repository.dart';

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
  StreamSubscription<int>? _sqlRevision;
  List<MediaItem>? _audioPlaybackItems;
  List<MediaItem>? _videoPlaybackItems;

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
    if (Get.isRegistered<PlaybackRepository>()) {
      _sqlRevision = Get.find<PlaybackRepository>().revisions.listen(
        (_) => refreshStats(),
      );
    }
  }

  Future<void> _loadData() async {
    isLoading.value = true;
    try {
      final items = await _libraryStore.readAll();
      await _loadModeMetrics(items);
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
      audioPlaybackItems: _audioPlaybackItems,
      videoPlaybackItems: _videoPlaybackItems,
    );
  }

  Future<void> refreshStats() async {
    try {
      final items = await _libraryStore.readAll();
      await _loadModeMetrics(items);
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
    _sqlRevision?.cancel();
    _topicsWorker?.dispose();
    _playlistsWorker?.dispose();
    _itemsWorker?.dispose();
    super.onClose();
  }

  Future<void> _loadModeMetrics(List<MediaItem> items) async {
    if (!Get.isRegistered<PlaybackRepository>()) return;
    final repository = Get.find<PlaybackRepository>();
    List<MediaItem> project(Map<String, Map<String, dynamic>> metrics) =>
        items.map((item) {
          final json = item.toJson();
          json.addAll(
            metrics[item.id] ??
                {
                  'playCount': 0,
                  'skipCount': 0,
                  'fullListenCount': 0,
                  'avgListenProgress': 0.0,
                  'lastPlayedAt': null,
                  'lastCompletedAt': null,
                },
          );
          return MediaItem.fromJson(json);
        }).toList();
    _audioPlaybackItems = project(
      await repository.queryLibraryMetrics(mode: 'audio'),
    );
    _videoPlaybackItems = project(
      await repository.queryLibraryMetrics(mode: 'video'),
    );
  }
}
