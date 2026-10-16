enum PlaybackMode { audio, video }

enum PlaybackContext {
  library,
  search,
  artist,
  album,
  playlist,
  atlas,
  recommendations,
  mix,
  connect,
  androidAuto,
  widget,
  notification,
  manualQueue,
  automaticQueue,
  unknown,
}

extension PlaybackContextStorage on PlaybackContext {
  String get storageValue => switch (this) {
    PlaybackContext.androidAuto => 'android_auto',
    PlaybackContext.manualQueue => 'manual_queue',
    PlaybackContext.automaticQueue => 'automatic_queue',
    _ => name,
  };
}

class PlaybackVariant {
  const PlaybackVariant({
    required this.id,
    required this.mode,
    required this.role,
    this.format,
  });
  final String id;
  final PlaybackMode mode;
  final String role;
  final String? format;
}

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.id,
    this.title,
    this.artist,
    this.album,
    this.artworkRef,
  });
  final String id;
  final String? title;
  final String? artist;
  final String? album;
  final String? artworkRef;
  // v2 hashes exact UTF8 strings; no undocumented platform normalization.
  List<Object?> get canonicalFields => [
    'snapshot',
    2,
    title,
    artist,
    album,
    artworkRef,
    'observed',
  ];
}

/// Submit only after the engine is actually ready + playing, never on route open.
class OpenPlaybackSession {
  const OpenPlaybackSession({
    required this.commandId,
    required this.sessionId,
    required this.eventId,
    required this.mediaId,
    required this.variant,
    required this.snapshot,
    required this.startedAtUtcMs,
    required this.clockEpoch,
    required this.monotonicMs,
    required this.context,
    this.positionMs = 0,
    this.durationMs,
    this.speed = 1,
    this.utcOffsetMinutes,
    this.timezoneId,
    this.sourceId,
  });
  final String commandId;
  final String sessionId;
  final String eventId;
  final String mediaId;
  final PlaybackVariant variant;
  final PlaybackSnapshot snapshot;
  final int startedAtUtcMs;
  final String clockEpoch;
  final int monotonicMs;
  final PlaybackContext context;
  final int positionMs;
  final int? durationMs;
  final double speed;
  final int? utcOffsetMinutes;
  final String? timezoneId;
  final String? sourceId;

  List<Object?> get canonicalRequest => [
    'open_session',
    1,
    sessionId,
    eventId,
    mediaId,
    variant.id,
    variant.mode.name,
    variant.role,
    variant.format,
    snapshot.id,
    snapshot.canonicalFields,
    startedAtUtcMs,
    clockEpoch,
    monotonicMs,
    context.storageValue,
    positionMs,
    durationMs,
    speed,
    utcOffsetMinutes,
    timezoneId,
    sourceId,
  ];

  void validate() {
    for (final value in [
      commandId,
      sessionId,
      eventId,
      mediaId,
      variant.id,
      variant.role,
      snapshot.id,
      clockEpoch,
    ]) {
      if (value.isEmpty) {
        throw ArgumentError('Empty playback identifier');
      }
    }
    if (positionMs < 0 ||
        monotonicMs < 0 ||
        (durationMs != null && durationMs! <= 0) ||
        !speed.isFinite ||
        speed <= 0) {
      throw ArgumentError('Invalid playback position, duration or speed');
    }
    if (utcOffsetMinutes != null &&
        (utcOffsetMinutes! < -840 || utcOffsetMinutes! > 840)) {
      throw ArgumentError('Invalid UTC offset');
    }
  }
}

class PlaybackSessionResult {
  const PlaybackSessionResult({
    required this.sessionId,
    required this.eventId,
    required this.snapshotId,
    required this.revision,
  });
  final String sessionId;
  final String eventId;
  final String snapshotId;
  final int revision;
}
