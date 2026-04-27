import 'package:listenfy/Modules/artists/data/artist_store.dart';
import 'package:listenfy/Modules/artists/domain/artist_profile.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/utils/artist_credit_parser.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/audio_service.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';

class LocalConnectPlaybackSync {
  LocalConnectPlaybackSync({
    required AudioService audioService,
    required ArtistStore artistStore,
    required LocalLibraryStore localLibraryStore,
  }) : _audioService = audioService,
       _artistStore = artistStore,
       _localLibraryStore = localLibraryStore;

  final AudioService _audioService;
  final ArtistStore _artistStore;
  final LocalLibraryStore _localLibraryStore;
  static final RegExp _parenChunkPattern = RegExp(r'\([^)]*\)|\[[^\]]*\]');

  String queueSignature() {
    final ids = _audioService.queueItems
        .map(
          (item) =>
              '${item.id}:${item.title}:${item.displaySubtitle}:${item.effectiveThumbnail ?? ''}',
        )
        .join('|');
    return '$ids#${_audioService.currentQueueIndex}';
  }

  String trackSignature() {
    final current = _audioService.currentItem.value;
    final variant = _audioService.currentVariant.value;
    if (current == null || variant == null) return 'none';
    return '${current.id}::${current.title}::${current.displaySubtitle}::${current.effectiveThumbnail ?? ''}::${variant.kind.name}::${variant.format}::${variant.localPath ?? variant.fileName}';
  }

  String playbackStateSignature() {
    final buffering = _audioService.isLoading.value;
    final playing = _audioService.isPlaying.value;
    final speed = _audioService.speed.value.toStringAsFixed(2);
    final volume = _audioService.volume.value.toStringAsFixed(2);
    final shuffle = _audioService.shuffleEnabled;
    return '$playing|$buffering|$speed|$volume|$shuffle';
  }

  Map<String, dynamic> buildSessionPayload({bool includeQueue = true}) {
    final current = _audioService.currentItem.value;
    final duration =
        _audioService.currentVariant.value?.durationSeconds ??
        current?.effectiveDurationSeconds;
    final positionMs = _audioService.currentPosition.inMilliseconds;
    final artistProfileCache = <String, Map<String, dynamic>?>{};

    return <String, dynamic>{
      'track': _trackToJson(current, artistProfileCache: artistProfileCache),
      'playback': <String, dynamic>{
        'isPlaying': _audioService.isPlaying.value,
        'isBuffering': _audioService.isLoading.value,
        'positionMs': positionMs,
        'durationMs': (duration ?? 0) * 1000,
        'speed': _audioService.speed.value,
        'volume': _audioService.volume.value,
        'shuffleEnabled': _audioService.shuffleEnabled,
      },
      if (includeQueue)
        'queue': _audioService.queueItems
            .map(
              (item) => _queueItemToJson(
                item,
                artistProfileCache: artistProfileCache,
              ),
            )
            .toList(),
      'currentQueueIndex': _audioService.currentQueueIndex,
      'hasNext':
          _audioService.currentQueueIndex < _audioService.queueItems.length - 1,
      'hasPrevious': _audioService.currentQueueIndex > 0,
    };
  }

  Map<String, dynamic> buildProgressPayload() {
    final current = _audioService.currentItem.value;
    final duration =
        _audioService.currentVariant.value?.durationSeconds ??
        current?.effectiveDurationSeconds;
    return <String, dynamic>{
      'positionMs': _audioService.currentPosition.inMilliseconds,
      'durationMs': (duration ?? 0) * 1000,
      'isPlaying': _audioService.isPlaying.value,
      'isBuffering': _audioService.isLoading.value,
      'shuffleEnabled': _audioService.shuffleEnabled,
    };
  }

  Map<String, dynamic>? currentTrackPayload() {
    final artistProfileCache = <String, Map<String, dynamic>?>{};
    return _trackToJson(
      _audioService.currentItem.value,
      artistProfileCache: artistProfileCache,
    );
  }

  List<Map<String, dynamic>> queuePayload() {
    final artistProfileCache = <String, Map<String, dynamic>?>{};
    return _audioService.queueItems
        .map(
          (item) =>
              _queueItemToJson(item, artistProfileCache: artistProfileCache),
        )
        .toList();
  }

  Map<String, dynamic>? _trackToJson(
    MediaItem? item, {
    required Map<String, Map<String, dynamic>?> artistProfileCache,
  }) {
    if (item == null) return null;
    final duration =
        _audioService.currentVariant.value?.durationSeconds ??
        item.effectiveDurationSeconds;
    return <String, dynamic>{
      'id': item.id,
      'title': item.title,
      'artist': item.displaySubtitle,
      'country': item.country,
      'coverUrl': _coverUrl(item),
      'durationMs': (duration ?? 0) * 1000,
      'kind': _audioService.currentVariant.value?.kind.name,
      'format': _audioService.currentVariant.value?.format,
      'source': item.source.name,
      'origin': item.origin.key,
      'artistProfile': _artistProfileToJson(
        item,
        artistProfileCache: artistProfileCache,
      ),
      'isFavorite': item.isFavorite,
      'playCount': item.playCount,
      'fullListenCount': item.fullListenCount,
      'skipCount': item.skipCount,
      'avgListenProgress': item.avgListenProgress,
    };
  }

  Map<String, dynamic> _queueItemToJson(
    MediaItem item, {
    required Map<String, Map<String, dynamic>?> artistProfileCache,
  }) {
    final audioVariant = item.localAudioVariant;
    final duration =
        audioVariant?.durationSeconds ?? item.effectiveDurationSeconds;
    return <String, dynamic>{
      'id': item.id,
      'title': item.title,
      'artist': item.displaySubtitle,
      'country': item.country,
      'coverUrl': _coverUrl(item),
      'durationMs': (duration ?? 0) * 1000,
      'source': item.source.name,
      'origin': item.origin.key,
      'artistProfile': _artistProfileToJson(
        item,
        artistProfileCache: artistProfileCache,
      ),
      'isFavorite': item.isFavorite,
      'playCount': item.playCount,
      'fullListenCount': item.fullListenCount,
      'skipCount': item.skipCount,
      'avgListenProgress': item.avgListenProgress,
    };
  }

  String? _coverUrl(MediaItem item) {
    final local = item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) return local;
    final remote = item.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    return null;
  }

  Map<String, dynamic>? _artistProfileToJson(
    MediaItem item, {
    required Map<String, Map<String, dynamic>?> artistProfileCache,
  }) {
    final profile = _resolveArtistProfile(item);
    if (profile == null) return null;
    final key = profile.key;
    if (artistProfileCache.containsKey(key)) {
      return artistProfileCache[key];
    }
    final trackCount = _trackCountForArtistKey(key);
    final data = <String, dynamic>{
      'key': profile.key,
      'displayName': profile.displayName,
      'kind': profile.kind.key,
      'country': profile.country,
      'countryCode': profile.countryCode,
      'thumbnail': profile.thumbnail,
      'thumbnailLocalPath': profile.thumbnailLocalPath,
      'memberCount': profile.memberKeys.length,
      'trackCount': trackCount,
    };
    artistProfileCache[key] = data;
    return data;
  }

  ArtistProfile? _resolveArtistProfile(MediaItem item) {
    final credits = ArtistCreditParser.parse(item.displaySubtitle);
    final primaryName = ArtistCreditParser.cleanName(credits.primaryArtist);
    if (primaryName.isEmpty) return null;

    final strippedPrimary = ArtistCreditParser.cleanName(
      primaryName.replaceAll(_parenChunkPattern, ' '),
    );
    final rawSubtitle = ArtistCreditParser.cleanName(item.displaySubtitle);

    final keyCandidates = <String>{
      ArtistCreditParser.normalizeKey(primaryName),
      ArtistCreditParser.normalizeKey(strippedPrimary),
      ArtistCreditParser.normalizeKey(rawSubtitle),
    }..removeWhere((key) => key.isEmpty || key == 'unknown');

    final profiles = _artistStore.readAllSync();
    if (profiles.isEmpty) return null;

    final byNormalizedKey = <String, ArtistProfile>{};
    for (final profile in profiles) {
      final profileKey = ArtistCreditParser.normalizeKey(profile.key);
      if (profileKey.isEmpty || profileKey == 'unknown') continue;
      final existing = byNormalizedKey[profileKey];
      byNormalizedKey[profileKey] =
          _pickRicherProfile(existing, profile) ?? profile;
    }

    ArtistProfile? byKey;
    for (final candidate in keyCandidates) {
      byKey = _pickRicherProfile(byKey, byNormalizedKey[candidate]);
    }

    ArtistProfile? byName;
    final nameTargets = <String>{
      ArtistCreditParser.normalizeKey(primaryName),
      ArtistCreditParser.normalizeKey(strippedPrimary),
    }..removeWhere((key) => key.isEmpty || key == 'unknown');
    if (nameTargets.isNotEmpty) {
      for (final profile in profiles) {
        final displayKey = ArtistCreditParser.normalizeKey(profile.displayName);
        if (!nameTargets.contains(displayKey)) continue;
        byName = _pickRicherProfile(byName, profile);
      }
    }

    return _pickRicherProfile(byKey, byName);
  }

  ArtistProfile? _pickRicherProfile(ArtistProfile? a, ArtistProfile? b) {
    if (a == null) return b;
    if (b == null) return a;
    final scoreA = _profileRichnessScore(a);
    final scoreB = _profileRichnessScore(b);
    if (scoreB > scoreA) return b;
    if (scoreA > scoreB) return a;
    return b;
  }

  int _profileRichnessScore(ArtistProfile profile) {
    final hasLocalThumb =
        (profile.thumbnailLocalPath?.trim().isNotEmpty ?? false);
    final hasRemoteThumb = (profile.thumbnail?.trim().isNotEmpty ?? false);
    final hasCountry =
        (profile.country?.trim().isNotEmpty ?? false) ||
        (profile.countryCode?.trim().isNotEmpty ?? false);
    var score = 0;
    if (hasLocalThumb) score += 8;
    if (hasRemoteThumb) score += 5;
    if (profile.kind == ArtistProfileKind.band) score += 4;
    if (hasCountry) score += 2;
    score += profile.memberKeys.length;
    return score;
  }

  int _trackCountForArtistKey(String artistKey) {
    final target = ArtistCreditParser.normalizeKey(artistKey);
    if (target.isEmpty || target == 'unknown') return 0;
    final library = _localLibraryStore.readAllSync();
    var count = 0;
    for (final item in library) {
      final credits = ArtistCreditParser.parse(item.displaySubtitle);
      if (credits.containsArtistKey(target)) {
        count += 1;
      }
    }
    return count;
  }
}
