import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:listenfy/Modules/artists/data/artist_store.dart';
import 'package:listenfy/Modules/artists/domain/artist_profile.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/utils/artist_credit_parser.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/audio_service.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'local_connect_http_policy.dart';

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

  int _artistStoreRevision = -1;
  int _libraryRevision = -1;
  final Map<String, ArtistProfile> _profilesByKey = <String, ArtistProfile>{};
  final Map<String, ArtistProfile> _profilesByName = <String, ArtistProfile>{};
  final Map<String, int> _trackCountByArtistKey = <String, int>{};
  final Map<String, ArtistCredits> _creditsByArtistText =
      <String, ArtistCredits>{};
  final Map<String, Map<String, dynamic>?> _artistProfileJsonCache =
      <String, Map<String, dynamic>?>{};
  final Map<String, ArtistProfile?> _resolvedProfiles = {};
  String? _cachedQueueSignature;
  List<Map<String, dynamic>> _cachedQueue = const [];

  String queueSignature() {
    return '${_audioService.queueRevision}:${_audioService.queueLength}:${_artistStore.revision}:${_localLibraryStore.revision}';
  }

  String trackSignature() {
    final current = _audioService.currentItem.value;
    final variant = _audioService.currentVariant.value;
    if (current == null || variant == null) return 'none';
    return '${current.id}::${current.title}::${current.displaySubtitle}::${current.effectiveThumbnail ?? ''}::$currentVariantId';
  }

  /// Stable stream identity without publishing the device filesystem path.
  String? get currentVariantId {
    final variant = _audioService.currentVariant.value;
    final item = _audioService.currentItem.value;
    if (variant == null || item == null) return null;
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              item.id,
              variant.kind.name,
              variant.format,
              variant.roleKey,
              variant.localPath,
              variant.fileName,
              variant.createdAt,
            ]),
          ),
        )
        .toString();
  }

  String playbackStateSignature() {
    final buffering = _audioService.isLoading.value;
    final playing = _audioService.isPlaying.value;
    final speed = _audioService.speed.value.toStringAsFixed(2);
    final volume = _audioService.volume.value.toStringAsFixed(2);
    final shuffle = _audioService.shuffleEnabled;
    return '$playing|$buffering|$speed|$volume|$shuffle|${_audioService.currentQueueIndex}';
  }

  Map<String, dynamic> buildSessionPayload({bool includeQueue = true}) {
    _ensureMetadataIndex();
    final current = _audioService.currentItem.value;
    final duration =
        _audioService.currentVariant.value?.durationSeconds ??
        current?.effectiveDurationSeconds;
    final positionMs = _audioService.currentPosition.inMilliseconds;
    final currentQueueIndex = _audioService.currentQueueIndex;
    final queueLength = _audioService.queueLength;

    return <String, dynamic>{
      'track': _trackToJson(current),
      'playback': <String, dynamic>{
        'isPlaying': _audioService.isPlaying.value,
        'isBuffering': _audioService.isLoading.value,
        'positionMs': positionMs,
        'durationMs': (duration ?? 0) * 1000,
        'speed': _audioService.speed.value,
        'volume': _audioService.volume.value,
        'shuffleEnabled': _audioService.shuffleEnabled,
      },
      if (includeQueue) 'queue': queuePayload(),
      'currentQueueIndex': currentQueueIndex,
      'hasNext': currentQueueIndex < queueLength - 1,
      'hasPrevious': currentQueueIndex > 0,
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
      'speed': _audioService.speed.value,
      'shuffleEnabled': _audioService.shuffleEnabled,
    };
  }

  Map<String, dynamic>? currentTrackPayload() {
    _ensureMetadataIndex();
    return _trackToJson(_audioService.currentItem.value);
  }

  List<Map<String, dynamic>> queuePayload() {
    _ensureMetadataIndex();
    final signature = queueSignature();
    if (_cachedQueueSignature != signature) {
      _cachedQueue = List.unmodifiable(
        _audioService.queueItems.map(
          (item) => Map<String, dynamic>.unmodifiable(_queueItemToJson(item)),
        ),
      );
      _cachedQueueSignature = signature;
    }
    return _cachedQueue;
  }

  Map<String, dynamic>? _trackToJson(MediaItem? item) {
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
      'variantId': currentVariantId,
      'variantRole': _audioService.currentVariant.value?.roleKey,
      'source': item.source.name,
      'origin': item.origin.key,
      'artistProfile': _artistProfileToJson(item),
      'isFavorite': item.isFavorite,
      'playCount': item.playCount,
      'lastPlayedAt': item.lastPlayedAt,
      'fullListenCount': item.fullListenCount,
      'skipCount': item.skipCount,
      'avgListenProgress': item.avgListenProgress,
      'lastCompletedAt': item.lastCompletedAt,
    };
  }

  Map<String, dynamic> _queueItemToJson(MediaItem item) {
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
      'artistProfile': _artistProfileToJson(item),
      'isFavorite': item.isFavorite,
      'playCount': item.playCount,
      'lastPlayedAt': item.lastPlayedAt,
      'fullListenCount': item.fullListenCount,
      'skipCount': item.skipCount,
      'avgListenProgress': item.avgListenProgress,
      'lastCompletedAt': item.lastCompletedAt,
    };
  }

  String? _coverUrl(MediaItem item) {
    final local = item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      return Uri(
        path: '/cover/item',
        queryParameters: {'itemId': item.id},
      ).toString();
    }
    final remote = item.thumbnail?.trim();
    if (LocalConnectHttpPolicy.isRemoteUrl(remote)) return remote;
    return null;
  }

  Map<String, dynamic>? _artistProfileToJson(MediaItem item) {
    if (_resolvedProfiles.length >= 2048) _resolvedProfiles.clear();
    final profile = _resolvedProfiles.putIfAbsent(
      item.displaySubtitle,
      () => _resolveArtistProfile(item),
    );
    if (profile == null) return null;
    final key = profile.key;
    if (_artistProfileJsonCache.containsKey(key)) {
      return _artistProfileJsonCache[key];
    }
    final trackCount = _trackCountForArtistKey(key);
    final data = <String, dynamic>{
      'key': profile.key,
      'displayName': profile.displayName,
      'kind': profile.kind.key,
      'country': profile.country,
      'countryCode': profile.countryCode,
      'thumbnail': LocalConnectHttpPolicy.isRemoteUrl(profile.thumbnail)
          ? profile.thumbnail
          : null,
      // Artwork is served by id; never expose device filesystem paths.
      'thumbnailLocalPath': null,
      'memberCount': profile.memberKeys.length,
      'trackCount': trackCount,
    };
    return _artistProfileJsonCache[key] = Map<String, dynamic>.unmodifiable(
      data,
    );
  }

  ArtistProfile? _resolveArtistProfile(MediaItem item) {
    final credits = _creditsFor(item.displaySubtitle);
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

    ArtistProfile? byKey;
    for (final candidate in keyCandidates) {
      byKey = _pickRicherProfile(byKey, _profilesByKey[candidate]);
    }

    ArtistProfile? byName;
    final nameTargets = <String>{
      ArtistCreditParser.normalizeKey(primaryName),
      ArtistCreditParser.normalizeKey(strippedPrimary),
    }..removeWhere((key) => key.isEmpty || key == 'unknown');
    for (final target in nameTargets) {
      byName = _pickRicherProfile(byName, _profilesByName[target]);
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
    return _trackCountByArtistKey[target] ?? 0;
  }

  /// Recorre artistas y biblioteca solo tras un cambio persistido. Esto evita
  /// hacerlo una vez por cada pista al serializar una cola para Connect.
  void _ensureMetadataIndex() {
    final artistRevision = _artistStore.revision;
    final libraryRevision = _localLibraryStore.revision;
    if (artistRevision == _artistStoreRevision &&
        libraryRevision == _libraryRevision) {
      return;
    }

    _artistProfileJsonCache.clear();
    _resolvedProfiles.clear();

    if (artistRevision != _artistStoreRevision) {
      _profilesByKey.clear();
      _profilesByName.clear();
      for (final profile in _artistStore.readAllSync()) {
        final profileKey = ArtistCreditParser.normalizeKey(profile.key);
        if (profileKey.isNotEmpty && profileKey != 'unknown') {
          _profilesByKey[profileKey] =
              _pickRicherProfile(_profilesByKey[profileKey], profile) ??
              profile;
        }

        final displayKey = ArtistCreditParser.normalizeKey(profile.displayName);
        if (displayKey.isNotEmpty && displayKey != 'unknown') {
          _profilesByName[displayKey] =
              _pickRicherProfile(_profilesByName[displayKey], profile) ??
              profile;
        }
      }
      _artistStoreRevision = artistRevision;
    }

    if (libraryRevision != _libraryRevision) {
      _trackCountByArtistKey.clear();
      _creditsByArtistText.clear();
      for (final item in _localLibraryStore.readAllSync()) {
        final credits = _creditsFor(item.displaySubtitle);
        for (final artist in credits.allArtists) {
          final key = ArtistCreditParser.normalizeKey(artist);
          if (key.isEmpty || key == 'unknown') continue;
          _trackCountByArtistKey.update(
            key,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      _libraryRevision = libraryRevision;
    }
  }

  ArtistCredits _creditsFor(String artistText) {
    if (_creditsByArtistText.length >= 2048) _creditsByArtistText.clear();
    return _creditsByArtistText.putIfAbsent(
      artistText,
      () => ArtistCreditParser.parse(artistText),
    );
  }
}
