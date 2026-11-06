import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';

import '../../Modules/artists/data/artist_store.dart';
import '../../Modules/artists/domain/artist_profile.dart';
import '../../Modules/artists/domain/artist_relationship_resolver.dart';
import '../utils/artist_credit_parser.dart';
import '../../Modules/playlists/data/playlist_store.dart';
import '../../Modules/playlists/domain/playlist.dart';
import '../data/local/local_library_store.dart';
import '../models/media_item.dart' as local;
import 'audio_service.dart' as app;

class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final app.AudioService _audio;
  static const _maxChildrenPageSize = 120;
  static const _homeRootId = 'listenfy:auto:home';
  static const _artistsRootId = 'listenfy:auto:artists';
  static const _recentRootId = 'listenfy:auto:recent';
  static const _resumeId = 'listenfy:auto:resume';
  static const _artistPrefix = 'listenfy:auto:artist:';
  static const _entryPrefix = 'listenfy:auto:entry:';
  static const _singleStyle =
      'android.media.browse.CONTENT_STYLE_SINGLE_ITEM_HINT';
  static const _groupTitle =
      'android.media.browse.CONTENT_STYLE_GROUP_TITLE_HINT';
  static const _songsRootId = 'listenfy:auto:songs';
  static const _favoritesRootId = 'listenfy:auto:favorites';
  static const _playlistsRootId = 'listenfy:auto:playlists';
  static const _queueRootId = 'listenfy:auto:queue';
  static const _songPrefix = 'listenfy:auto:song:';
  static const _playlistPrefix = 'listenfy:auto:playlist:';
  static const _queuePrefix = 'listenfy:auto:queue:';
  static MediaControl get closeControl => MediaControl(
    androidIcon: 'drawable/ic_close',
    label: tr('common.close'),
    action: MediaAction.stop,
  );

  AppAudioHandler(this._audio);

  Future<void> updatePlayback({
    required bool playing,
    required bool buffering,
    required bool hasSourceLoaded,
    required Duration position,
    required double speed,
    required int queueIndex,
  }) async {
    final processingState = buffering
        ? AudioProcessingState.buffering
        : (hasSourceLoaded
              ? AudioProcessingState.ready
              : AudioProcessingState.idle);

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          closeControl,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setSpeed,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        queueIndex: queueIndex,
        speed: speed,
      ),
    );
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    this.queue.add(queue);
  }

  @override
  Future<void> play() async {
    if (_audio.hasSourceLoaded) {
      await _audio.resume();
      return;
    }
    final restored = await _audio.restorePersistedSession(autoPlay: true);
    if (restored) return;
    final items = _audioItems();
    if (items.isNotEmpty) {
      await _audio.playQueueFromExternalRequest(items: items, index: 0);
    }
  }

  @override
  Future<void> pause() => _audio.pause();

  @override
  Future<void> stop() async {
    if (_audio.consumeNextHandlerStopShouldHardStop()) {
      await _audio.stop();
      await super.stop();
    } else {
      _audio.persistCurrentTrackResumePositionNow();
      await _audio.stopAndHidePreservingSession();
      // No llamamos super.stop() aquí para que el servicio pueda volver
      // a publicar notificación al reanudar desde la app.
    }
  }

  @override
  Future<void> seek(Duration position) => _audio.seek(position);

  @override
  Future<void> skipToNext() => _audio.next();

  @override
  Future<void> skipToPrevious() => _audio.previous();

  @override
  Future<void> setSpeed(double speed) => _audio.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (repeatMode == AudioServiceRepeatMode.one) {
      await _audio.setLoopOne();
    } else {
      await _audio.setLoopOff();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) {
    return _audio.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
  }

  @override
  Future<void> skipToQueueItem(int index) {
    return _audio.playQueueIndexFromExternalRequest(index);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) {
    return playFromMediaId(mediaItem.id, mediaItem.extras);
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    if (mediaId == _resumeId) {
      await play();
      return;
    }
    final entry = _entryFromId(mediaId);
    if (entry != null) {
      final items = _itemsForParent(entry.$1);
      final index = items.indexWhere((item) => _sameItemId(item, entry.$2));
      if (index >= 0) {
        await _audio.playQueueFromExternalRequest(items: items, index: index);
      }
      return;
    }
    final playlistId = _playlistIdFromMediaId(mediaId);
    if (playlistId != null) {
      final playlist = _playlistById(playlistId);
      if (playlist == null) return;
      final items = _itemsForPlaylist(playlist);
      await _audio.playQueueFromExternalRequest(items: items, index: 0);
      return;
    }

    if (mediaId.startsWith(_queuePrefix)) {
      final index = int.tryParse(mediaId.substring(_queuePrefix.length));
      if (index != null) {
        await _audio.playQueueIndexFromExternalRequest(index);
      }
      return;
    }

    final itemId = _songIdFromMediaId(mediaId);
    if (itemId == null) return;
    final items = _audioItems();
    final index = items.indexWhere((item) => _sameItemId(item, itemId));
    if (index < 0) return;
    await _audio.playQueueFromExternalRequest(items: items, index: index);
  }

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final results = await search(query, extras);
    final firstPlayable = results.firstWhereOrNull(
      (item) => item.playable == true,
    );
    if (firstPlayable != null) {
      await playMediaItem(firstPlayable);
    }
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    await _refreshLibraryMetrics();
    List<MediaItem> children;
    switch (parentMediaId) {
      case AudioService.browsableRootId:
        children = [
          _rootFolder(_homeRootId)!,
          _rootFolder(_playlistsRootId)!,
          _rootFolder(_artistsRootId)!,
          _rootFolder(_songsRootId)!,
        ];
        break;
      case AudioService.recentRootId:
        // The system's recent-items endpoint expects playable recommendations.
        children = _songsForParent(_recentRootId).take(10).toList();
        break;
      case _homeRootId:
        children = _homeChildren();
        break;
      case _playlistsRootId:
        children = _playlists().map(_playlistItem).toList(growable: false);
        break;
      case _artistsRootId:
        children = _artists().map(_artistItem).toList(growable: false);
        break;
      case _queueRootId:
        children = _audio.queueItems
            .asMap()
            .entries
            .map(
              (entry) =>
                  _songItem(entry.value, mediaId: '$_queuePrefix${entry.key}'),
            )
            .toList();
        break;
      default:
        children = _songsForParent(parentMediaId);
    }
    return _applyChildrenOptions(children, options);
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final root = _rootFolder(mediaId);
    if (root != null) return root;
    if (mediaId == _resumeId) return _resumeItem();
    final entry = _entryFromId(mediaId);
    if (entry != null) {
      final song = _itemsForParent(
        entry.$1,
      ).firstWhereOrNull((item) => _sameItemId(item, entry.$2));
      return song == null ? null : _songItem(song, mediaId: mediaId);
    }
    if (mediaId.startsWith(_artistPrefix)) {
      final artist = _artists().firstWhereOrNull(
        (a) => a.key == mediaId.substring(_artistPrefix.length),
      );
      return artist == null ? null : _artistItem(artist);
    }
    final playlistId = _playlistIdFromMediaId(mediaId);
    if (playlistId != null) {
      final playlist = _playlistById(playlistId);
      return playlist == null ? null : _playlistItem(playlist);
    }

    if (mediaId.startsWith(_queuePrefix)) {
      final index = int.tryParse(mediaId.substring(_queuePrefix.length));
      final items = _audio.queueItems;
      if (index == null || index < 0 || index >= items.length) return null;
      return _songItem(items[index], mediaId: mediaId);
    }

    final songId = _songIdFromMediaId(mediaId);
    if (songId == null) return null;
    final item = _audioItems().firstWhereOrNull(
      (entry) => _sameItemId(entry, songId),
    );
    return item == null ? null : _songItem(item);
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    await _refreshLibraryMetrics();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _audioItems().take(25).map(_songItem).toList(growable: false);
    }
    return _audioItems()
        .where((item) {
          return item.title.toLowerCase().contains(q) ||
              item.displaySubtitle.toLowerCase().contains(q);
        })
        .take(25)
        .map(_songItem)
        .toList(growable: false);
  }

  List<MediaItem> _applyChildrenOptions(
    List<MediaItem> children,
    Map<String, dynamic>? options,
  ) {
    if (children.isEmpty) return children;
    final page = _optionInt(
      options,
      'android.media.browse.extra.PAGE',
      fallback: -1,
    );
    final rawPageSize = _optionInt(
      options,
      'android.media.browse.extra.PAGE_SIZE',
      fallback: -1,
    );
    if (page >= 0 && rawPageSize > 0) {
      final pageSize = rawPageSize.clamp(1, _maxChildrenPageSize).toInt();
      final start = page * pageSize;
      if (start >= children.length) return const <MediaItem>[];
      final end = (start + pageSize).clamp(0, children.length).toInt();
      return children.sublist(start, end);
    }
    if (children.length <= _maxChildrenPageSize) return children;
    return children.take(_maxChildrenPageSize).toList(growable: false);
  }

  int _optionInt(
    Map<String, dynamic>? options,
    String key, {
    required int fallback,
  }) {
    final value = options?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  MediaItem? _rootFolder(String id) {
    final spec = switch (id) {
      _homeRootId => ('home', 'home_subtitle', 'ic_auto_home', 1),
      _playlistsRootId => (
        'playlists',
        'playlists_subtitle',
        'ic_auto_playlists',
        2,
      ),
      _artistsRootId => ('artists', 'artists_subtitle', 'ic_auto_artists', 2),
      _songsRootId => ('songs', 'songs_subtitle', 'ic_auto_songs', 1),
      _favoritesRootId => (
        'favorites',
        'favorites_subtitle',
        'ic_auto_favorites',
        1,
      ),
      _recentRootId => ('recent', 'recent_subtitle', 'ic_auto_recent', 1),
      _queueRootId => (
        'current_queue',
        'current_queue_subtitle',
        'ic_auto_queue',
        1,
      ),
      _ => null,
    };
    if (spec == null) return null;
    return MediaItem(
      id: id,
      title: tr('android_auto.${spec.$1}'),
      playable: false,
      displaySubtitle: tr('android_auto.${spec.$2}'),
      artUri: _audio.androidAutoIconUri(spec.$3),
      extras: {
        AndroidContentStyle.browsableHintKey: spec.$4,
        AndroidContentStyle.playableHintKey: 1,
        _singleStyle: 1,
      },
    );
  }

  List<MediaItem> _homeChildren() {
    MediaItem group(MediaItem item, String key) => item.copyWith(
      extras: {...?item.extras, _groupTitle: tr('android_auto.$key')},
    );
    final resume = _resumeItem();
    return [
      for (final id in [_recentRootId, _favoritesRootId, _queueRootId])
        group(_rootFolder(id)!, 'shortcuts'),
      if (resume != null) group(resume, 'continue_listening'),
      ..._songsForParent(
        _recentRootId,
      ).take(8).map((item) => group(item, 'recent')),
      ..._songsForParent(
        _favoritesRootId,
      ).take(6).map((item) => group(item, 'favorites')),
    ];
  }

  MediaItem? _resumeItem() {
    final item = _audio.currentItem.value;
    if (item == null || item.localAudioVariant == null) return null;
    return _songItem(item, mediaId: _resumeId);
  }

  MediaItem _playlistItem(Playlist playlist) {
    final items = _itemsForPlaylist(playlist);
    var artwork = _audio.buildArtworkUri(
      localPath: playlist.coverLocalPath,
      remoteUrl: playlist.coverUrl,
    );
    if (artwork == null && !playlist.coverCleared) {
      for (final item in items) {
        artwork = _audio.buildBackgroundItem(item).artUri;
        if (artwork != null) break;
      }
    }
    return MediaItem(
      id: '$_playlistPrefix${playlist.id}',
      title: playlist.name,
      playable: false,
      displayTitle: playlist.name,
      displaySubtitle: _trackCount(items.length),
      artUri: artwork ?? _audio.androidAutoIconUri('ic_auto_playlists'),
      extras: const {_singleStyle: 2, AndroidContentStyle.playableHintKey: 1},
    );
  }

  String _trackCount(int count) => count == 1
      ? tr('android_auto.track_count_one')
      : tr('android_auto.track_count_many', args: ['$count']);

  List<local.MediaItem> _itemsForParent(String parent) {
    if (parent == _songsRootId) return _audioItems();
    if (parent == _favoritesRootId) {
      return _audioItems().where((i) => i.isFavorite).toList();
    }
    if (parent == _recentRootId) {
      final items =
          _audioItems().where((i) => (i.lastPlayedAt ?? 0) > 0).toList()
            ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
      return items;
    }
    if (parent.startsWith(_artistPrefix)) {
      return _artists()
              .firstWhereOrNull(
                (a) => a.key == parent.substring(_artistPrefix.length),
              )
              ?.items ??
          [];
    }
    final playlistId = _playlistIdFromMediaId(parent);
    final playlist = playlistId == null ? null : _playlistById(playlistId);
    return playlist == null ? [] : _itemsForPlaylist(playlist);
  }

  List<MediaItem> _songsForParent(String parent) => _itemsForParent(parent)
      .map(
        (item) => _songItem(
          item,
          mediaId:
              '$_entryPrefix${Uri.encodeComponent(parent)}:${Uri.encodeComponent(item.id)}',
        ),
      )
      .toList();

  (String, String)? _entryFromId(String id) {
    if (!id.startsWith(_entryPrefix)) return null;
    final parts = id.substring(_entryPrefix.length).split(':');
    if (parts.length != 2) return null;
    try {
      return (Uri.decodeComponent(parts[0]), Uri.decodeComponent(parts[1]));
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  List<_AutoArtist> _artists() {
    final profiles = Get.isRegistered<ArtistStore>()
        ? Get.find<ArtistStore>().readAllSync()
        : <ArtistProfile>[];
    final byKey = {for (final profile in profiles) profile.key: profile};
    final grouped = <String, _AutoArtist>{};
    for (final item in _audioItems()) {
      final credits = resolveArtistCredits(item);
      final names = credits.allArtists;
      for (var i = 0; i < names.length; i++) {
        final key =
            credits.artistKeys?[i] ?? ArtistCreditParser.normalizeKey(names[i]);
        if (key.isEmpty || key == 'unknown') continue;
        final artist = grouped.putIfAbsent(
          key,
          () => _AutoArtist(
            key,
            byKey[key]?.displayName.trim().isNotEmpty == true
                ? byKey[key]!.displayName
                : names[i],
            byKey[key],
          ),
        );
        if (!artist.items.any((existing) => existing.id == item.id)) {
          artist.items.add(item);
        }
      }
    }
    return grouped.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  MediaItem _artistItem(_AutoArtist artist) {
    final profile = artist.profile;
    final artwork =
        _audio.buildArtworkUri(
          localPath: profile?.thumbnailLocalPath,
          remoteUrl: profile?.thumbnail,
        ) ??
        _audio.buildBackgroundItem(artist.items.first).artUri ??
        _audio.androidAutoIconUri('ic_auto_artists');
    return MediaItem(
      id: '$_artistPrefix${artist.key}',
      title: artist.name,
      playable: false,
      artUri: artwork,
      displaySubtitle: _trackCount(artist.items.length),
      extras: const {_singleStyle: 2, AndroidContentStyle.playableHintKey: 1},
    );
  }

  MediaItem _songItem(local.MediaItem item, {String? mediaId}) {
    return _audio
        .buildBackgroundItem(item)
        .copyWith(
          id: mediaId ?? '$_songPrefix${item.id}',
          playable: true,
          displayTitle: item.title,
          displaySubtitle: item.displaySubtitle,
          extras: const <String, dynamic>{
            AndroidContentStyle.playableHintKey: 1,
            _singleStyle: 1,
          },
        );
  }

  Future<void> _refreshLibraryMetrics() async {
    if (Get.isRegistered<LocalLibraryStore>()) {
      // The SQL-backed store hydrates lastPlayedAt asynchronously. Do not rely
      // on a phone screen having loaded the library before the car connects.
      await Get.find<LocalLibraryStore>().readAll();
    }
  }

  List<local.MediaItem> _audioItems() {
    final store = Get.isRegistered<LocalLibraryStore>()
        ? Get.find<LocalLibraryStore>()
        : null;
    if (store == null) return const <local.MediaItem>[];
    return store
        .readAllSync()
        .where((item) => item.localAudioVariant != null)
        .toList(growable: false);
  }

  List<Playlist> _playlists() {
    final store = Get.isRegistered<PlaylistStore>()
        ? Get.find<PlaylistStore>()
        : null;
    if (store == null) return const <Playlist>[];
    return store
        .readAllSync()
        .where((playlist) {
          return !playlist.isTemporary &&
              _itemsForPlaylist(playlist).isNotEmpty;
        })
        .toList(growable: false);
  }

  Playlist? _playlistById(String id) {
    return _playlists().firstWhereOrNull((playlist) => playlist.id == id);
  }

  List<local.MediaItem> _itemsForPlaylist(Playlist playlist) {
    final all = _audioItems();
    if (all.isEmpty || playlist.itemIds.isEmpty) {
      return const <local.MediaItem>[];
    }
    final byKey = <String, local.MediaItem>{};
    for (final item in all) {
      byKey[item.id] = item;
      final publicId = item.publicId.trim();
      if (publicId.isNotEmpty) byKey[publicId] = item;
    }
    final items = <local.MediaItem>[];
    final seen = <String>{};
    for (final id in playlist.itemIds) {
      final item = byKey[id.trim()];
      if (item == null || !seen.add(item.id)) continue;
      items.add(item);
    }
    return items;
  }

  String? _songIdFromMediaId(String mediaId) {
    if (mediaId.startsWith(_songPrefix)) {
      return mediaId.substring(_songPrefix.length);
    }
    if (mediaId.isNotEmpty && !mediaId.startsWith('listenfy:auto:')) {
      return mediaId;
    }
    return null;
  }

  String? _playlistIdFromMediaId(String mediaId) {
    if (!mediaId.startsWith(_playlistPrefix)) return null;
    return mediaId.substring(_playlistPrefix.length);
  }

  bool _sameItemId(local.MediaItem item, String id) {
    if (item.id == id) return true;
    final publicId = item.publicId.trim();
    return publicId.isNotEmpty && publicId == id;
  }
}

class _AutoArtist {
  _AutoArtist(this.key, this.name, this.profile);
  final String key;
  final String name;
  final ArtistProfile? profile;
  final items = <local.MediaItem>[];
}
