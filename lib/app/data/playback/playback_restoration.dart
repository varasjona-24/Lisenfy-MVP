import 'dart:convert';

enum RestorationMode { audio, video }

/// Operational state only. These snapshots never create historical sessions.
class PlaybackRestoration {
  PlaybackRestoration({
    required this.mode,
    required List<Map<String, dynamic>> queue,
    List<Map<String, dynamic>> variants = const [],
    this.index = 0,
    this.positionMs = 0,
    this.wasPlaying = false,
    Map<String, dynamic>? lastItem,
    Map<String, dynamic>? lastVariant,
    this.speed = 1,
    this.shuffle = false,
    this.crossfadeSeconds = 0,
    this.repeatMode,
  }) : _payload = jsonEncode({
         'queue': queue,
         'variants': variants,
         'index': index,
         'positionMs': positionMs,
         'wasPlaying': wasPlaying,
         'lastItem': lastItem,
         'lastVariant': lastVariant,
         'speed': speed,
         'shuffle': shuffle,
         'crossfadeSeconds': crossfadeSeconds,
         'repeatMode': repeatMode,
       }) {
    if (index < 0 ||
        (queue.isNotEmpty && index >= queue.length) ||
        (queue.isEmpty && index != 0) ||
        positionMs < 0 ||
        !speed.isFinite ||
        speed <= 0 ||
        crossfadeSeconds < 0 ||
        crossfadeSeconds > 12 ||
        (repeatMode != null && !{'off', 'once', 'loop'}.contains(repeatMode)) ||
        (mode == RestorationMode.audio && queue.length != variants.length)) {
      throw ArgumentError('Invalid playback restoration');
    }
  }

  final RestorationMode mode;
  final int index;
  final int positionMs;
  final bool wasPlaying;
  final double speed;
  final bool shuffle;
  final int crossfadeSeconds;
  final String? repeatMode;
  final String _payload;
  String get payloadJson => _payload;
  Map<String, dynamic> get payload =>
      jsonDecode(_payload) as Map<String, dynamic>;

  factory PlaybackRestoration.decode(RestorationMode mode, String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return PlaybackRestoration(
      mode: mode,
      queue: (data['queue'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      variants: (data['variants'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      index: data['index'] as int,
      positionMs: data['positionMs'] as int,
      wasPlaying: data['wasPlaying'] as bool,
      lastItem: data['lastItem'] as Map<String, dynamic>?,
      lastVariant: data['lastVariant'] as Map<String, dynamic>?,
      speed: (data['speed'] as num).toDouble(),
      shuffle: data['shuffle'] as bool,
      crossfadeSeconds: data['crossfadeSeconds'] as int,
      repeatMode: data['repeatMode'] as String?,
    );
  }
}

class PlaybackResumePoint {
  const PlaybackResumePoint({
    required this.mode,
    required this.trackKey,
    required this.positionMs,
    this.trustedWatchMs,
  });
  final RestorationMode mode;

  /// Legacy id/publicId retained verbatim until alias reconciliation.
  final String trackKey;
  final int positionMs;
  final int? trustedWatchMs;
  void validate() {
    if (trackKey.trim().isEmpty ||
        positionMs < 0 ||
        (trustedWatchMs != null && trustedWatchMs! < 0)) {
      throw ArgumentError('Invalid resume point');
    }
  }
}
