import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/services/audio_service.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';

class LocalConnectPlaybackSync {
  LocalConnectPlaybackSync({required AudioService audioService})
    : _audioService = audioService;

  final AudioService _audioService;

  String queueSignature() {
    final ids = _audioService.queueItems.map((item) => item.id).join('|');
    return '$ids#${_audioService.currentQueueIndex}';
  }

  String trackSignature() {
    final current = _audioService.currentItem.value;
    final variant = _audioService.currentVariant.value;
    if (current == null || variant == null) return 'none';
    return '${current.id}::${variant.kind.name}::${variant.format}::${variant.localPath ?? variant.fileName}';
  }

  String playbackStateSignature() {
    final buffering = _audioService.isLoading.value;
    final playing = _audioService.isPlaying.value;
    final speed = _audioService.speed.value.toStringAsFixed(2);
    final volume = _audioService.volume.value.toStringAsFixed(2);
    return '$playing|$buffering|$speed|$volume';
  }

  Map<String, dynamic> buildSessionPayload() {
    final current = _audioService.currentItem.value;
    final duration =
        _audioService.currentVariant.value?.durationSeconds ??
        current?.effectiveDurationSeconds;
    final positionMs = _audioService.currentPosition.inMilliseconds;

    return <String, dynamic>{
      'track': _trackToJson(current),
      'playback': <String, dynamic>{
        'isPlaying': _audioService.isPlaying.value,
        'isBuffering': _audioService.isLoading.value,
        'positionMs': positionMs,
        'durationMs': (duration ?? 0) * 1000,
        'speed': _audioService.speed.value,
        'volume': _audioService.volume.value,
      },
      'queue': _audioService.queueItems.map(_queueItemToJson).toList(),
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
    };
  }

  Map<String, dynamic>? currentTrackPayload() {
    return _trackToJson(_audioService.currentItem.value);
  }

  List<Map<String, dynamic>> queuePayload() {
    return _audioService.queueItems.map(_queueItemToJson).toList();
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
      'source': item.source.name,
      'origin': item.origin.key,
      'isFavorite': item.isFavorite,
      'playCount': item.playCount,
      'fullListenCount': item.fullListenCount,
      'skipCount': item.skipCount,
      'avgListenProgress': item.avgListenProgress,
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
}
