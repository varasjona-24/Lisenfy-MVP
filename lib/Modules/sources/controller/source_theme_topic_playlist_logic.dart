import 'package:file_picker/file_picker.dart';

import '../../../app/data/repo/media_repository.dart';
import '../controller/sources_controller.dart';
import '../domain/source_theme.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme_topic_playlist.dart';
import '../../../app/models/media_item.dart';

class SourceThemeTopicPlaylistLogic {
  SourceThemeTopicPlaylistLogic({
    required SourcesController sources,
    required MediaRepository repo,
    required SourceTheme theme,
    required List<SourceOrigin>? origins,
  }) : _sources = sources,
       _repo = repo,
       _theme = theme,
       _origins = origins;

  final SourcesController _sources;
  final MediaRepository _repo;
  final SourceTheme _theme;
  final List<SourceOrigin>? _origins;

  Future<List<MediaItem>> loadItems(SourceThemeTopicPlaylist playlist) {
    return _sources.loadPlaylistItems(
      theme: _theme,
      playlist: playlist,
      origins: _origins,
    );
  }

  Future<List<MediaItem>> candidateItems() {
    return _sources.loadCandidateItems(theme: _theme, origins: _origins);
  }

  Future<void> removeItem(
    SourceThemeTopicPlaylist playlist,
    MediaItem item,
  ) async {
    final key = _sources.keyForItem(item);
    final updated = playlist.copyWith(
      itemIds: playlist.itemIds.where((e) => e != key).toList(),
    );
    await _sources.updateTopicPlaylist(updated);
  }

  Future<void> addItemsToPlaylist({
    required SourceThemeTopicPlaylist playlist,
    required List<MediaItem> selectedItems,
  }) async {
    final mergedIds = {
      ...playlist.itemIds,
      ...selectedItems.map(_sources.keyForItem),
    }.toList();

    await _sources.updateTopicPlaylist(playlist.copyWith(itemIds: mergedIds));
  }

  Future<bool> addSubList({
    required SourceThemeTopicPlaylist parent,
    required String name,
    String? coverUrl,
    String? coverLocalPath,
    int? colorValue,
  }) {
    return _sources.addTopicPlaylist(
      topicId: parent.topicId,
      name: name,
      items: const [],
      parentId: parent.id,
      depth: parent.depth + 1,
      coverUrl: coverUrl,
      coverLocalPath: coverLocalPath,
      colorValue: colorValue,
    );
  }

  Future<void> updatePlaylist(SourceThemeTopicPlaylist updated) {
    return _sources.updateTopicPlaylist(updated);
  }

  Future<String?> pickLocalImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    final path = file?.path?.trim();
    if (path == null || path.isEmpty) return null;
    return path;
  }

  /// Cachea una url para el itemId y devuelve path local o null.
  Future<String?> cacheCoverForPlaylist({
    required String playlistId,
    required String url,
  }) async {
    final cleaned = url.trim();
    if (cleaned.isEmpty) return null;

    final cached = await _repo.cacheThumbnailForItem(
      itemId: playlistId,
      thumbnailUrl: cleaned,
    );
    final out = cached?.trim();
    return (out != null && out.isNotEmpty) ? out : null;
  }
}
