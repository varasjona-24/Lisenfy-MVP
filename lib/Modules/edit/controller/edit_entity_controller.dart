import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/audio_cleanup.dart';
import '../../../app/models/media_item.dart';
import '../../../app/services/audio_cleanup_service.dart';
import '../../../app/services/audio_service.dart';
import '../../../app/services/musicbrainz_metadata_service.dart';
import '../../../app/services/metadata_search_query_resolver_service.dart';
import '../../artists/controller/artists_controller.dart';
import '../../artists/domain/artist_profile.dart';
import '../../captures/controller/capture_gallery_controller.dart';
import '../../captures/data/capture_gallery_store.dart';
import '../../captures/domain/capture_item.dart';
import '../../captures/domain/capture_tag_folder.dart';
import '../../downloads/controller/downloads_controller.dart';
import '../../Home/Controller/home_controller.dart';
import '../../player/audio/controller/audio_player_controller.dart';
import '../../playlists/controller/playlists_controller.dart';
import '../../playlists/data/playlist_store.dart';
import '../../playlists/domain/playlist.dart';
import '../../sources/controller/sources_controller.dart';
import '../../sources/domain/source_theme_topic.dart';
import '../../sources/domain/source_theme_topic_playlist.dart';
import '../view/desktop_image_cropper_dialog.dart';

enum EditEntityType {
  media,
  artist,
  playlist,
  topic,
  topicPlaylist,
  capture,
  captureTag,
}

class EditEntityArgs {
  final EditEntityType type;
  final MediaItem? media;
  final ArtistGroup? artist;
  final Playlist? playlist;
  final SourceThemeTopic? topic;
  final SourceThemeTopicPlaylist? topicPlaylist;
  final CaptureItem? capture;
  final CaptureTagFolder? captureTag;

  const EditEntityArgs.media(this.media)
    : type = EditEntityType.media,
      artist = null,
      playlist = null,
      topic = null,
      topicPlaylist = null,
      capture = null,
      captureTag = null;

  const EditEntityArgs.artist(this.artist)
    : type = EditEntityType.artist,
      media = null,
      playlist = null,
      topic = null,
      topicPlaylist = null,
      capture = null,
      captureTag = null;

  const EditEntityArgs.playlist(this.playlist)
    : type = EditEntityType.playlist,
      media = null,
      artist = null,
      topic = null,
      topicPlaylist = null,
      capture = null,
      captureTag = null;

  const EditEntityArgs.topic(this.topic)
    : type = EditEntityType.topic,
      media = null,
      artist = null,
      playlist = null,
      topicPlaylist = null,
      capture = null,
      captureTag = null;

  const EditEntityArgs.topicPlaylist(this.topicPlaylist)
    : type = EditEntityType.topicPlaylist,
      media = null,
      artist = null,
      playlist = null,
      topic = null,
      capture = null,
      captureTag = null;

  const EditEntityArgs.capture(this.capture)
    : type = EditEntityType.capture,
      media = null,
      artist = null,
      playlist = null,
      topic = null,
      topicPlaylist = null,
      captureTag = null;

  const EditEntityArgs.captureTag(this.captureTag)
    : type = EditEntityType.captureTag,
      media = null,
      artist = null,
      playlist = null,
      topic = null,
      topicPlaylist = null,
      capture = null;
}

enum CreateEntityType { playlist, topic, topicPlaylist, captureTag }

class CreateEntityArgs {
  final CreateEntityType type;
  final String storageId;
  final String? initialName;
  final int? initialColorValue;

  // topic only
  final String? themeId;

  // topic playlist only
  final String? topicId;
  final String? parentId;
  final int? depth;

  const CreateEntityArgs.playlist({required this.storageId, this.initialName})
    : type = CreateEntityType.playlist,
      themeId = null,
      topicId = null,
      parentId = null,
      depth = null,
      initialColorValue = null;

  const CreateEntityArgs.topic({
    required this.storageId,
    required this.themeId,
    this.initialName,
    this.initialColorValue,
  }) : type = CreateEntityType.topic,
       topicId = null,
       parentId = null,
       depth = null;

  const CreateEntityArgs.topicPlaylist({
    required this.storageId,
    required this.topicId,
    required this.depth,
    this.parentId,
    this.initialName,
    this.initialColorValue,
  }) : type = CreateEntityType.topicPlaylist,
       themeId = null;

  const CreateEntityArgs.captureTag({
    required this.storageId,
    this.initialName,
    this.initialColorValue,
  }) : type = CreateEntityType.captureTag,
       themeId = null,
       topicId = null,
       parentId = null,
       depth = null;
}

class MediaCleanupAnalysis {
  const MediaCleanupAnalysis({
    required this.media,
    required this.sourcePath,
    required this.analysis,
  });

  final MediaItem media;
  final String sourcePath;
  final AudioSilenceAnalysis analysis;
}

class MediaDataTransferResult {
  const MediaDataTransferResult({
    required this.updatedTarget,
    required this.playlistsUpdated,
  });

  final MediaItem updatedTarget;
  final int playlistsUpdated;
}

class EditEntityController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final AudioCleanupService _audioCleanup = Get.find<AudioCleanupService>();
  final ArtistsController _artists = Get.find<ArtistsController>();
  final PlaylistsController _playlists = Get.find<PlaylistsController>();
  final PlaylistStore _playlistStore = Get.find<PlaylistStore>();
  final SourcesController _sources = Get.find<SourcesController>();
  final CaptureGalleryStore _capturesStore = Get.find<CaptureGalleryStore>();
  final MusicBrainzMetadataService _musicBrainz = MusicBrainzMetadataService();
  final MetadataSearchQueryResolverService _metadataQueryResolver =
      MetadataSearchQueryResolverService();

  Future<String?> cacheRemoteToLocal({
    required String id,
    required String url,
  }) async {
    return _repo.cacheThumbnailForItem(itemId: id, thumbnailUrl: url.trim());
  }

  Future<String?> cropToSquare(String sourcePath) async {
    return cropImage(sourcePath, ratioX: 1, ratioY: 1);
  }

  Future<String?> cropToVideoThumbnail(String sourcePath) async {
    return cropImage(sourcePath, ratioX: 16, ratioY: 9);
  }

  Future<String?> cropImage(
    String sourcePath, {
    required double ratioX,
    required double ratioY,
  }) async {
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return Get.dialog<String>(
        DesktopImageCropperDialog(
          sourcePath: sourcePath,
          ratioX: ratioX,
          ratioY: ratioY,
        ),
        barrierDismissible: false,
      );
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: CropAspectRatio(ratioX: ratioX, ratioY: ratioY),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: tr('edit.crop'),
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(title: tr('edit.crop'), aspectRatioLockEnabled: true),
        ],
      );
      return cropped?.path;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<String?> persistCroppedImage({
    required String id,
    required String croppedPath,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'downloads', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(croppedPath).toLowerCase() == '.png'
          ? '.png'
          : '.jpg';
      final targetPath = p.join(coversDir.path, '$id-crop-$ts$extension');
      final src = File(croppedPath);
      if (!await src.exists()) return null;

      final out = await src.copy(targetPath);

      final sourceInsideAppDir = p.isWithin(appDir.path, src.path);
      if (croppedPath != targetPath && sourceInsideAppDir) {
        try {
          await src.delete();
        } catch (_) {}
      }

      return out.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteFile(String? path) async {
    final pth = path?.trim();
    if (pth == null || pth.isEmpty) return;
    try {
      final f = File(pth);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<MediaItem> resolveLatestMedia(MediaItem fallback) async {
    final all = await _store.readAll();
    for (final item in all) {
      if (item.id == fallback.id) return item;
    }
    final publicId = fallback.publicId.trim();
    if (publicId.isNotEmpty) {
      for (final item in all) {
        if (item.publicId.trim() == publicId) return item;
      }
    }
    return fallback;
  }

  Future<void> _applyMediaMetadataToSiblings(MediaItem updated) async {
    final all = await _store.readAll();
    final publicId = updated.publicId.trim();

    final matches = all
        .where((entry) {
          if (entry.id == updated.id) return true;
          return publicId.isNotEmpty && entry.publicId.trim() == publicId;
        })
        .toList(growable: false);

    if (matches.isEmpty) {
      await _store.upsert(updated);
      _refreshLivePlaybackItem(updated);
      return;
    }

    for (final entry in matches) {
      final next = entry.copyWith(
        title: updated.title,
        subtitle: updated.subtitle,
        thumbnail: updated.thumbnail,
        thumbnailLocalPath: updated.thumbnailLocalPath,
        durationSeconds: updated.durationSeconds,
        lyrics: updated.lyrics,
        lyricsLanguage: updated.lyricsLanguage,
        translations: updated.translations,
        timedLyrics: updated.timedLyrics,
      );
      await _store.upsert(next);
      _refreshLivePlaybackItem(next);
    }
  }

  void _refreshLivePlaybackItem(MediaItem updated) {
    if (!Get.isRegistered<AudioService>()) return;
    Get.find<AudioService>().applyUpdatedMediaItem(updated);
    if (Get.isRegistered<AudioPlayerController>()) {
      Get.find<AudioPlayerController>().updateQueueItem(updated);
    }
  }

  Future<MediaCleanupAnalysis?> analyzeMediaSilences({
    required MediaItem item,
    int minSilenceMs = 4000,
    int windowMs = 50,
    double thresholdDb = -35,
  }) async {
    final latest = await resolveLatestMedia(item);
    final sourcePath = latest.localAudioVariant?.localPath?.trim() ?? '';
    if (sourcePath.isEmpty) return null;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    final analysis = await _audioCleanup.analyzeSilences(
      localPath: sourcePath,
      minSilenceMs: minSilenceMs,
      windowMs: windowMs,
      thresholdDb: thresholdDb,
    );
    if (analysis == null) return null;

    return MediaCleanupAnalysis(
      media: latest,
      sourcePath: sourcePath,
      analysis: analysis,
    );
  }

  Future<MediaItem?> applyMediaSilenceCleanup({
    required MediaItem item,
    required String sourcePath,
    required List<AudioSilenceSegment> removeSegments,
    int fadeMs = 20,
  }) async {
    if (removeSegments.isEmpty) return null;

    final latest = await resolveLatestMedia(item);
    final result = await _audioCleanup.renderCleanedAudio(
      localPath: sourcePath.trim(),
      removeSegments: removeSegments,
      fadeMs: fadeMs,
    );
    if (result == null) return null;

    final outputPath = result.outputPath.trim();
    if (outputPath.isEmpty) return null;

    final outFile = File(outputPath);
    if (!await outFile.exists()) return null;

    final format = p.extension(outputPath).replaceFirst('.', '').toLowerCase();
    final cleanedDurationSeconds = result.cleanedDurationMs > 0
        ? (result.cleanedDurationMs / 1000).round()
        : null;
    final importCreatedAt =
        latest.localAudioVariant?.createdAt ??
        latest.variants
            .map((variant) => variant.createdAt)
            .fold<int>(0, (a, b) => a > b ? a : b);

    final cleanedVariant = MediaVariant(
      kind: MediaVariantKind.audio,
      format: format.isEmpty ? 'wav' : format,
      fileName: p.basename(outputPath),
      localPath: outputPath,
      createdAt: importCreatedAt,
      size: await outFile.length(),
      durationSeconds: cleanedDurationSeconds,
    );

    final existing = latest.variants.where((v) {
      final path = v.localPath?.trim();
      if (path == null || path.isEmpty) return true;
      return path != outputPath;
    });

    final updated = latest.copyWith(
      variants: [cleanedVariant, ...existing],
      durationSeconds: latest.durationSeconds,
    );

    await _store.upsert(updated);
    await _refreshDependentControllers();
    return updated;
  }

  Future<void> _refreshDependentControllers() async {
    if (Get.isRegistered<DownloadsController>()) {
      await Get.find<DownloadsController>().load();
    }
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().loadHome();
    }
    if (Get.isRegistered<ArtistsController>()) {
      await Get.find<ArtistsController>().load();
    }
    if (Get.isRegistered<PlaylistsController>()) {
      await Get.find<PlaylistsController>().load();
    }
    if (Get.isRegistered<SourcesController>()) {
      await Get.find<SourcesController>().refreshAll();
    }
  }

  String _libraryKeyFor(MediaItem item) {
    final publicId = item.publicId.trim();
    return publicId.isNotEmpty ? publicId : item.id.trim();
  }

  Future<List<MediaItem>> transferCandidateMedia(MediaItem source) async {
    final latest = await resolveLatestMedia(source);
    final sourceKey = _libraryKeyFor(latest);
    final all = await _store.readAll();
    return all
        .where((item) {
          if (item.id == latest.id) return false;
          if (_libraryKeyFor(item) == sourceKey) return false;
          return item.hasAudioLocal || item.hasVideoLocal;
        })
        .toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// Returns only media with the same cover aspect ratio as [sourceKind].
  /// Audio covers are square and video thumbnails are 16:9, so mixing them
  /// would produce incorrectly cropped artwork.
  Future<List<MediaItem>> coverTransferCandidateMedia({
    required MediaItem source,
    required MediaVariantKind sourceKind,
  }) async {
    final latest = await resolveLatestMedia(source);
    final sourceKey = _libraryKeyFor(latest);
    final all = await _store.readAll();
    return all
        .where((item) {
          if (_libraryKeyFor(item) == sourceKey) return false;
          return sourceKind == MediaVariantKind.video
              ? item.hasVideoLocal
              : item.hasAudioLocal;
        })
        .toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// Applies a physical copy of [source]'s cover to every selected target.
  /// A separate file is deliberately created for each target, so removing or
  /// replacing the source cover never leaves another item pointing at a
  /// deleted file.
  Future<int> applyCoverToMediaTargets({
    required MediaItem source,
    required List<MediaItem> targets,
    String? sourceLocalCoverPath,
  }) async {
    if (targets.isEmpty) return 0;

    final latestSource = await resolveLatestMedia(source);
    final localCover = sourceLocalCoverPath?.trim().isNotEmpty == true
        ? sourceLocalCoverPath!.trim()
        : (latestSource.thumbnailLocalPath?.trim() ?? '');
    String sourcePath = localCover;
    if (sourcePath.isEmpty || !await File(sourcePath).exists()) {
      final remoteCover = latestSource.thumbnail?.trim() ?? '';
      if (remoteCover.isEmpty) {
        throw StateError('The source item has no cover to apply.');
      }
      final cached = await cacheRemoteToLocal(
        id: '${latestSource.id}-cover-transfer-source',
        url: remoteCover,
      );
      sourcePath = cached?.trim() ?? '';
    }

    final sourceFile = File(sourcePath);
    if (sourcePath.isEmpty || !await sourceFile.exists()) {
      throw StateError('The source cover file is not available.');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'downloads', 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension = extension == '.png' || extension == '.webp'
        ? extension
        : '.jpg';
    final sourceKey = _libraryKeyFor(latestSource);
    var applied = 0;

    for (final target in targets) {
      final latestTarget = await resolveLatestMedia(target);
      if (_libraryKeyFor(latestTarget) == sourceKey) continue;

      final targetPath = p.join(
        coversDir.path,
        '${latestTarget.id}-cover-copy-${DateTime.now().microsecondsSinceEpoch}-$applied$safeExtension',
      );
      await sourceFile.copy(targetPath);

      final updatedTarget = latestTarget.copyWith(
        thumbnail: '',
        thumbnailLocalPath: targetPath,
      );
      await _applyMediaMetadataToSiblings(updatedTarget);
      applied++;
    }

    if (applied > 0) {
      await _refreshDependentControllers();
    }
    return applied;
  }

  /// Saves an independent copy of a media cover in Listenfy's own gallery.
  Future<String> saveMediaCoverToGallery({
    required MediaItem item,
    required String name,
    String? localCoverPath,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('A name is required for the gallery image.');
    }

    final latest = await resolveLatestMedia(item);
    final preferredLocal = localCoverPath?.trim().isNotEmpty == true
        ? localCoverPath!.trim()
        : (latest.thumbnailLocalPath?.trim() ?? '');
    var sourcePath = preferredLocal;
    var downloadedForExport = false;

    if (sourcePath.isEmpty || !await File(sourcePath).exists()) {
      final remote = latest.thumbnail?.trim() ?? '';
      if (remote.isEmpty) {
        throw StateError('The media item has no cover to save.');
      }
      final cached = await cacheRemoteToLocal(
        id: '${latest.id}-cover-gallery-export',
        url: remote,
      );
      sourcePath = cached?.trim() ?? '';
      downloadedForExport = sourcePath.isNotEmpty;
    }

    final source = File(sourcePath);
    if (sourcePath.isEmpty || !await source.exists()) {
      throw StateError('The media cover file is not available.');
    }

    try {
      final extension = p.extension(sourcePath).toLowerCase() == '.png'
          ? '.png'
          : '.jpg';
      final storedPath = await _capturesStore.saveCapture(
        bytes: await source.readAsBytes(),
        title: cleanName,
        sourceTitle: latest.title,
        sourceId: _libraryKeyFor(latest),
        extension: extension,
      );
      final renamedPath = await _capturesStore.renameCapture(
        storedPath,
        cleanName,
      );
      if (Get.isRegistered<CaptureGalleryController>()) {
        await Get.find<CaptureGalleryController>().reload();
      }
      return renamedPath;
    } finally {
      if (downloadedForExport) {
        await deleteFile(sourcePath);
      }
    }
  }

  Future<MediaDataTransferResult?> transferMediaData({
    required MediaItem source,
    required MediaItem target,
  }) async {
    final latestSource = await resolveLatestMedia(source);
    final latestTarget = await resolveLatestMedia(target);
    if (latestSource.id == latestTarget.id) return null;

    final updatedTarget = latestTarget.copyWith(
      title: latestSource.title,
      subtitle: latestSource.subtitle,
      country: latestSource.country,
      thumbnail: latestSource.thumbnail,
      thumbnailLocalPath: latestSource.thumbnailLocalPath,
      lyrics: latestSource.lyrics,
      lyricsLanguage: latestSource.lyricsLanguage,
      translations: latestSource.translations == null
          ? null
          : Map<String, String>.from(latestSource.translations!),
      timedLyrics: latestSource.timedLyrics == null
          ? null
          : Map<String, List<TimedLyricCue>>.from(latestSource.timedLyrics!),
      isFavorite: latestSource.isFavorite,
      playCount: latestSource.playCount,
      lastPlayedAt: latestSource.lastPlayedAt,
      skipCount: latestSource.skipCount,
      fullListenCount: latestSource.fullListenCount,
      avgListenProgress: latestSource.avgListenProgress,
      lastCompletedAt: latestSource.lastCompletedAt,
    );

    await _store.upsert(updatedTarget);
    final playlistsUpdated = await _replaceMediaInPlaylists(
      source: latestSource,
      target: updatedTarget,
    );
    _refreshLivePlaybackItem(updatedTarget);
    await _refreshDependentControllers();

    return MediaDataTransferResult(
      updatedTarget: updatedTarget,
      playlistsUpdated: playlistsUpdated,
    );
  }

  Future<int> _replaceMediaInPlaylists({
    required MediaItem source,
    required MediaItem target,
  }) async {
    final sourceKey = _libraryKeyFor(source);
    final targetKey = _libraryKeyFor(target);
    if (sourceKey.isEmpty || targetKey.isEmpty || sourceKey == targetKey) {
      return 0;
    }

    final playlists = await _playlistStore.readAll();
    var changed = 0;
    for (final playlist in playlists) {
      if (!playlist.itemIds.contains(sourceKey)) continue;

      final ids = <String>[];
      for (final id in playlist.itemIds) {
        final next = id == sourceKey ? targetKey : id;
        if (!ids.contains(next)) ids.add(next);
      }

      final addedAt = Map<String, int>.from(playlist.itemAddedAt);
      final sourceAddedAt = addedAt.remove(sourceKey);
      if (sourceAddedAt != null) {
        addedAt.putIfAbsent(targetKey, () => sourceAddedAt);
      }

      await _playlistStore.upsert(
        playlist.copyWith(
          itemIds: ids,
          itemAddedAt: addedAt,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      changed++;
    }
    return changed;
  }

  Future<void> deleteMediaFromLibrary(MediaItem item) async {
    final latest = await resolveLatestMedia(item);
    await _store.remove(latest.id);
    await _refreshDependentControllers();
  }

  Future<bool> saveMedia({
    required MediaItem item,
    required String title,
    required String subtitle,
    required bool thumbTouched,
    required String? localThumbPath,
    required String lyrics,
    required String lyricsLanguage,
    required Map<String, String> translations,
    required Map<String, List<TimedLyricCue>> timedLyrics,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      Get.snackbar(
        tr('edit.entity_type.metadata'),
        tr('edit.validation.title_empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    String? thumbRemoteUpdate;
    String? thumbLocalUpdate;
    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      if (local.isNotEmpty) {
        thumbRemoteUpdate = '';
        thumbLocalUpdate = local;
      } else {
        thumbRemoteUpdate = '';
        thumbLocalUpdate = '';
      }
    }

    final latest = await resolveLatestMedia(item);
    final updated = latest.copyWith(
      title: trimmedTitle,
      subtitle: subtitle.trim(),
      thumbnail: thumbRemoteUpdate,
      thumbnailLocalPath: thumbLocalUpdate,
      durationSeconds: latest.durationSeconds,
      lyrics: lyrics.trim(),
      lyricsLanguage: lyricsLanguage.trim().toLowerCase(),
      translations: Map<String, String>.from(translations),
      timedLyrics: Map<String, List<TimedLyricCue>>.from(timedLyrics),
    );

    await _applyMediaMetadataToSiblings(updated);
    await _refreshDependentControllers();

    return true;
  }

  Future<List<MusicBrainzRecordingSuggestion>> searchMusicBrainzSuggestions({
    required String title,
    required String artist,
    int? durationSeconds,
  }) {
    return _searchMusicBrainzSuggestions(
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
    );
  }

  Future<String?> resolveMusicBrainzArtistCountry(String artistId) {
    return _metadataQueryResolver.resolveArtistCountry(artistId);
  }

  Future<List<MusicBrainzRecordingSuggestion>> _searchMusicBrainzSuggestions({
    required String title,
    required String artist,
    int? durationSeconds,
  }) async {
    final query = await _metadataQueryResolver.resolve(
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
    );
    if (query.suggestions != null) {
      if (!query.suggestionsAvailable) {
        throw StateError('MusicBrainz is temporarily unavailable.');
      }
      return _musicBrainz.suggestionsFromJson(query.suggestions!);
    }
    return _musicBrainz.searchRecordings(
      title: query.title,
      artist: query.artist,
      fallbackTitle: query.hasDifferentFallback ? query.fallbackTitle : null,
      fallbackArtist: query.hasDifferentFallback ? query.fallbackArtist : null,
    );
  }

  Future<MediaItem> applyMusicBrainzSuggestion({
    required MediaItem item,
    required MusicBrainzRecordingSuggestion suggestion,
  }) async {
    final latest = await resolveLatestMedia(item);
    final updated = latest.copyWith(
      title: suggestion.title,
      subtitle: suggestion.artist,
    );
    await _applyMediaMetadataToSiblings(updated);
    await _refreshDependentControllers();
    return updated;
  }

  Future<String?> findMusicBrainzSuggestedCover(
    MusicBrainzRecordingSuggestion suggestion,
  ) {
    return _musicBrainz.findReleaseCoverUrl(suggestion);
  }

  Future<MediaItem?> applyMusicBrainzSuggestedCover({
    required MediaItem item,
    required String coverUrl,
  }) async {
    final cached = await cacheRemoteToLocal(
      id: '${item.id}-musicbrainz',
      url: coverUrl,
    );
    if (cached == null || cached.trim().isEmpty) return null;

    final cropped = await cropToSquare(cached);
    if (cropped == null || cropped.trim().isEmpty) {
      await deleteFile(cached);
      return null;
    }
    final persisted = await persistCroppedImage(
      id: item.id,
      croppedPath: cropped,
    );
    if (persisted == null || persisted.trim().isEmpty) {
      if (cropped != cached) await deleteFile(cropped);
      await deleteFile(cached);
      return null;
    }

    final latest = await resolveLatestMedia(item);
    final updated = latest.copyWith(
      thumbnail: '',
      thumbnailLocalPath: persisted,
    );
    await _applyMediaMetadataToSiblings(updated);
    await _refreshDependentControllers();
    return updated;
  }

  Future<bool> saveArtist({
    required ArtistGroup artist,
    required String name,
    required String country,
    String? countryCode,
    required ArtistMainRegion mainRegion,
    required ArtistProfileKind kind,
    required List<String> memberKeys,
    required bool thumbTouched,
    required String? localThumbPath,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        tr('edit.entity_type.artist'),
        tr('edit.validation.artist_empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    String? nextThumb = artist.thumbnail;
    String? nextLocal = artist.thumbnailLocalPath;

    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      if (local.isNotEmpty) {
        nextThumb = '';
        nextLocal = local;
      } else {
        nextThumb = '';
        nextLocal = '';
      }
    }

    await _artists.updateArtist(
      key: artist.key,
      newName: trimmed,
      country: country,
      countryCode: countryCode,
      mainRegion: mainRegion,
      kind: kind,
      memberKeys: memberKeys,
      thumbnail: nextThumb,
      thumbnailLocalPath: nextLocal,
    );

    return true;
  }

  Future<bool> savePlaylist({
    required Playlist playlist,
    required String name,
    required bool thumbTouched,
    required String? localThumbPath,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        tr('edit.entity_type.playlist'),
        tr('edit.validation.playlist_empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (trimmed != playlist.name) {
      await _playlists.renamePlaylist(playlist.id, trimmed);
    }

    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      final cleared = local.isEmpty;
      await _playlists.updateCover(
        playlist.id,
        coverUrl: null,
        coverLocalPath: local.isNotEmpty ? local : null,
        coverCleared: cleared,
      );
    }

    return true;
  }

  Future<bool> saveTopic({
    required SourceThemeTopic topic,
    required String name,
    required bool thumbTouched,
    required String? localThumbPath,
    required int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        tr('edit.entity_type.theme'),
        tr('edit.validation.theme_empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    String? coverUrl = topic.coverUrl;
    String? coverLocal = topic.coverLocalPath;
    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      coverUrl = null;
      coverLocal = local.isNotEmpty ? local : null;
    }

    await _sources.updateTopic(
      topic.copyWith(
        title: trimmed,
        coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl,
        coverLocalPath: coverLocal?.trim().isEmpty == true ? null : coverLocal,
        colorValue: colorValue,
      ),
    );

    return true;
  }

  Future<bool> saveTopicPlaylist({
    required SourceThemeTopicPlaylist playlist,
    required String name,
    required bool thumbTouched,
    required String? localThumbPath,
    required int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        tr('edit.entity_type.list'),
        tr('edit.validation.list_empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    String? coverUrl = playlist.coverUrl;
    String? coverLocal = playlist.coverLocalPath;
    if (thumbTouched) {
      final local = localThumbPath?.trim() ?? '';
      coverUrl = null;
      coverLocal = local.isNotEmpty ? local : null;
    }

    await _sources.updateTopicPlaylist(
      playlist.copyWith(
        name: trimmed,
        coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl,
        coverLocalPath: coverLocal?.trim().isEmpty == true ? null : coverLocal,
        colorValue: colorValue,
      ),
    );

    return true;
  }

  Future<bool> saveCapture({
    required CaptureItem capture,
    required String name,
    required Iterable<String> tags,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        tr('edit.entity_type.capture'),
        tr('edit.validation.capture_empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final nextPath = await _capturesStore.renameCapture(capture.path, trimmed);
    await _capturesStore.setTags(nextPath, tags);
    if (Get.isRegistered<CaptureGalleryController>()) {
      await Get.find<CaptureGalleryController>().reload();
    }
    return true;
  }

  Future<bool> saveCaptureTag({
    required CaptureTagFolder folder,
    required String name,
    required int? colorValue,
    required String? thumbnailPath,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        tr('edit.entity_type.tag'),
        tr('edit.validation.tag_empty'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final nextKey = trimmed.toLowerCase();
    if (nextKey != folder.key) {
      await _capturesStore.renameTag(folder.key, trimmed);
    }
    await _capturesStore.setTagCollection(
      trimmed,
      name: trimmed,
      colorValue: colorValue,
      thumbnailPath: thumbnailPath,
    );
    if (Get.isRegistered<CaptureGalleryController>()) {
      await Get.find<CaptureGalleryController>().reload();
    }
    return true;
  }

  Future<bool> createPlaylist({
    required String name,
    String? localThumbPath,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    await _playlists.createPlaylist(
      trimmed,
      coverLocalPath: localThumbPath?.trim().isEmpty == true
          ? null
          : localThumbPath,
    );
    return true;
  }

  Future<bool> createTopic({
    required String themeId,
    required String name,
    String? localThumbPath,
    int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    await _sources.addTopic(
      themeId: themeId,
      title: trimmed,
      coverUrl: null,
      coverLocalPath: localThumbPath?.trim().isEmpty == true
          ? null
          : localThumbPath,
      colorValue: colorValue,
    );
    return true;
  }

  Future<bool> createTopicPlaylist({
    required String topicId,
    required String? parentId,
    required int depth,
    required String name,
    String? localThumbPath,
    int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final ok = await _sources.addTopicPlaylist(
      topicId: topicId,
      name: trimmed,
      items: const [],
      parentId: parentId,
      depth: depth,
      coverUrl: null,
      coverLocalPath: localThumbPath?.trim().isEmpty == true
          ? null
          : localThumbPath,
      colorValue: colorValue,
    );
    return ok;
  }

  Future<bool> createCaptureTag({required String name, int? colorValue}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    await _capturesStore.setTagCollection(
      trimmed,
      name: trimmed,
      colorValue: colorValue,
    );
    if (Get.isRegistered<CaptureGalleryController>()) {
      await Get.find<CaptureGalleryController>().reload();
    }
    return true;
  }
}
