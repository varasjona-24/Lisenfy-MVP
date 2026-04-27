import 'dart:io';

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
import '../../artists/controller/artists_controller.dart';
import '../../artists/domain/artist_profile.dart';
import '../../downloads/controller/downloads_controller.dart';
import '../../home/controller/home_controller.dart';
import '../../player/audio/controller/audio_player_controller.dart';
import '../../playlists/controller/playlists_controller.dart';
import '../../playlists/domain/playlist.dart';
import '../../sources/controller/sources_controller.dart';
import '../../sources/domain/source_theme_topic.dart';
import '../../sources/domain/source_theme_topic_playlist.dart';

enum EditEntityType { media, artist, playlist, topic, topicPlaylist }

class EditEntityArgs {
  final EditEntityType type;
  final MediaItem? media;
  final ArtistGroup? artist;
  final Playlist? playlist;
  final SourceThemeTopic? topic;
  final SourceThemeTopicPlaylist? topicPlaylist;

  const EditEntityArgs.media(this.media)
    : type = EditEntityType.media,
      artist = null,
      playlist = null,
      topic = null,
      topicPlaylist = null;

  const EditEntityArgs.artist(this.artist)
    : type = EditEntityType.artist,
      media = null,
      playlist = null,
      topic = null,
      topicPlaylist = null;

  const EditEntityArgs.playlist(this.playlist)
    : type = EditEntityType.playlist,
      media = null,
      artist = null,
      topic = null,
      topicPlaylist = null;

  const EditEntityArgs.topic(this.topic)
    : type = EditEntityType.topic,
      media = null,
      artist = null,
      playlist = null,
      topicPlaylist = null;

  const EditEntityArgs.topicPlaylist(this.topicPlaylist)
    : type = EditEntityType.topicPlaylist,
      media = null,
      artist = null,
      playlist = null,
      topic = null;
}

enum CreateEntityType { playlist, topicPlaylist }

class CreateEntityArgs {
  final CreateEntityType type;
  final String storageId;
  final String? initialName;
  final int? initialColorValue;

  // topic playlist only
  final String? topicId;
  final String? parentId;
  final int? depth;

  const CreateEntityArgs.playlist({required this.storageId, this.initialName})
    : type = CreateEntityType.playlist,
      topicId = null,
      parentId = null,
      depth = null,
      initialColorValue = null;

  const CreateEntityArgs.topicPlaylist({
    required this.storageId,
    required this.topicId,
    required this.depth,
    this.parentId,
    this.initialName,
    this.initialColorValue,
  }) : type = CreateEntityType.topicPlaylist;
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

class EditEntityController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final AudioCleanupService _audioCleanup = Get.find<AudioCleanupService>();
  final ArtistsController _artists = Get.find<ArtistsController>();
  final PlaylistsController _playlists = Get.find<PlaylistsController>();
  final SourcesController _sources = Get.find<SourcesController>();

  Future<String?> cacheRemoteToLocal({
    required String id,
    required String url,
  }) async {
    return _repo.cacheThumbnailForItem(itemId: id, thumbnailUrl: url.trim());
  }

  Future<String?> cropToSquare(String sourcePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar',
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(title: 'Recortar', aspectRatioLockEnabled: true),
        ],
      );
      return cropped?.path;
    } catch (_) {
      return null;
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
      final targetPath = p.join(coversDir.path, '$id-crop-$ts.jpg');
      final src = File(croppedPath);
      if (!await src.exists()) return null;

      final out = await src.copy(targetPath);

      if (croppedPath != targetPath) {
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

    final cleanedVariant = MediaVariant(
      kind: MediaVariantKind.audio,
      format: format.isEmpty ? 'wav' : format,
      fileName: p.basename(outputPath),
      localPath: outputPath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
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
      durationSeconds: cleanedDurationSeconds ?? latest.durationSeconds,
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
        'Metadata',
        'El titulo no puede estar vacio',
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
        'Artista',
        'El nombre no puede estar vacio',
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
        'Playlist',
        'El nombre no puede estar vacio',
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
        'Tematica',
        'El nombre no puede estar vacio',
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
        'Lista',
        'El nombre no puede estar vacio',
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
}
