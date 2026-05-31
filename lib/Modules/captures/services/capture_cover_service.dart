import 'package:get/get.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../sources/binding/sources_binding.dart';
import '../../sources/controller/sources_controller.dart';
import '../domain/capture_gallery_models.dart';

class CaptureCoverService {
  const CaptureCoverService();

  Future<List<CaptureCoverTarget>> loadTargets() async {
    final targets = <CaptureCoverTarget>[];
    targets.addAll(_videoTargets());
    targets.addAll(await _collectionTargets());
    return targets;
  }

  List<CaptureCoverTarget> _videoTargets() {
    if (!Get.isRegistered<LocalLibraryStore>()) return const [];

    final store = Get.find<LocalLibraryStore>();
    final videos = store
        .readAllSync()
        .where((item) => item.hasVideoLocal || item.localVideoVariant != null)
        .toList(growable: false);

    return [
      for (final item in videos)
        CaptureCoverTarget(
          id: item.id,
          label: item.title,
          subtitle: item.subtitle,
          type: CaptureCoverTargetType.video,
        ),
    ];
  }

  Future<List<CaptureCoverTarget>> _collectionTargets() async {
    if (!Get.isRegistered<SourcesController>()) {
      SourcesBinding().dependencies();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!Get.isRegistered<SourcesController>()) return const [];

    final sources = Get.find<SourcesController>();
    await sources.refreshAll();

    return [
      for (final topic in sources.topics)
        CaptureCoverTarget(
          id: topic.id,
          label: topic.title,
          subtitle: 'Collection principal',
          type: CaptureCoverTargetType.topic,
        ),
      for (final playlist in sources.topicPlaylists)
        CaptureCoverTarget(
          id: playlist.id,
          label: playlist.name,
          subtitle: 'Subcollection',
          type: CaptureCoverTargetType.playlist,
        ),
    ];
  }

  Future<void> applyCover({
    required String path,
    required CaptureCoverTarget target,
  }) async {
    switch (target.type) {
      case CaptureCoverTargetType.video:
        if (!Get.isRegistered<LocalLibraryStore>()) return;
        final store = Get.find<LocalLibraryStore>();
        final item = store.readAllSync().firstWhereOrNull((item) {
          return item.id == target.id;
        });
        if (item == null) return;
        await store.upsert(item.copyWith(thumbnailLocalPath: path));
      case CaptureCoverTargetType.topic:
        final sources = await _sourcesController();
        if (sources == null) return;
        final topic = sources.topics.firstWhereOrNull((topic) {
          return topic.id == target.id;
        });
        if (topic == null) return;
        await sources.updateTopic(
          topic.copyWith(coverLocalPath: path, coverUrl: ''),
        );
      case CaptureCoverTargetType.playlist:
        final sources = await _sourcesController();
        if (sources == null) return;
        final playlist = sources.topicPlaylists.firstWhereOrNull((playlist) {
          return playlist.id == target.id;
        });
        if (playlist == null) return;
        await sources.updateTopicPlaylist(
          playlist.copyWith(coverLocalPath: path, coverUrl: ''),
        );
    }
  }

  Future<SourcesController?> _sourcesController() async {
    if (!Get.isRegistered<SourcesController>()) {
      SourcesBinding().dependencies();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!Get.isRegistered<SourcesController>()) return null;
    final sources = Get.find<SourcesController>();
    await sources.refreshAll();
    return sources;
  }
}
