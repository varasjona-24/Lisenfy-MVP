enum PlaybackBoundary {
  checkpoint,
  pause,
  resume,
  seek,
  bufferingStart,
  bufferingEnd,
  speedChange,
  stop,
}

enum PlaybackTermination {
  naturalEnd,
  manualNext,
  manualPrevious,
  manualSelection,
  explicitStop,
  appShutdown,
  processLost,
  sourceLost,
  engineError,
  externalInterruption,
}

extension PlaybackTerminationCodec on PlaybackTermination {
  String get stored => switch (this) {
    PlaybackTermination.naturalEnd => 'natural_end',
    PlaybackTermination.manualNext => 'manual_next',
    PlaybackTermination.manualPrevious => 'manual_previous',
    PlaybackTermination.manualSelection => 'manual_selection',
    PlaybackTermination.explicitStop => 'explicit_stop',
    PlaybackTermination.appShutdown => 'app_shutdown',
    PlaybackTermination.processLost => 'process_lost',
    PlaybackTermination.sourceLost => 'source_lost',
    PlaybackTermination.engineError => 'engine_error',
    PlaybackTermination.externalInterruption => 'external_interruption',
  };
}

/// An engine boundary. Position is observed BEFORE any seek; target is separate.
/// Closing an interval requires the sequence of its actual playing start.
class RecordPlaybackBoundary {
  const RecordPlaybackBoundary({
    required this.commandId,
    required this.sessionId,
    required this.eventId,
    required this.boundary,
    required this.utcMs,
    required this.monotonicMs,
    required this.clockEpoch,
    required this.positionMs,
    required this.playingAfter,
    this.intervalStartSequence,
    this.seekTargetMs,
    this.newSpeed,
    this.termination,
  });
  final String commandId, sessionId, eventId, clockEpoch;
  final PlaybackBoundary boundary;
  final int utcMs, monotonicMs, positionMs;
  final bool playingAfter;
  final int? intervalStartSequence, seekTargetMs;
  final double? newSpeed;
  final PlaybackTermination? termination;
  List<Object?> get canonical => [
    'boundary',
    1,
    sessionId,
    eventId,
    boundary.name,
    utcMs,
    monotonicMs,
    clockEpoch,
    positionMs,
    playingAfter,
    intervalStartSequence,
    seekTargetMs,
    newSpeed,
    termination?.stored,
  ];
  void validate() {
    if ([commandId, sessionId, eventId, clockEpoch].any((s) => s.isEmpty) ||
        positionMs < 0 ||
        monotonicMs < 0) {
      throw ArgumentError('Invalid boundary');
    }
    if ((boundary == PlaybackBoundary.stop) != (termination != null) ||
        (boundary == PlaybackBoundary.seek) != (seekTargetMs != null) ||
        (boundary == PlaybackBoundary.speedChange) != (newSpeed != null) ||
        (seekTargetMs != null && seekTargetMs! < 0) ||
        (newSpeed != null && (!newSpeed!.isFinite || newSpeed! <= 0))) {
      throw ArgumentError('Inconsistent boundary fields');
    }
    if ((boundary == PlaybackBoundary.pause ||
            boundary == PlaybackBoundary.bufferingStart ||
            boundary == PlaybackBoundary.stop) &&
        playingAfter) {
      throw ArgumentError('Inactive boundary cannot remain playing');
    }
  }
}

class PlaybackBoundaryResult {
  const PlaybackBoundaryResult({
    required this.revision,
    required this.sequence,
    required this.skipped,
    required this.completed,
  });
  final int revision, sequence;
  final bool skipped, completed;
}

/// Total length of the union of content ranges, not total media advancement.
int playbackCoverage(List<(int, int)> ranges, {int? durationMs}) {
  final sorted =
      ranges
          .map(
            (r) => (
              r.$1.clamp(0, durationMs ?? r.$2),
              r.$2.clamp(0, durationMs ?? r.$2),
            ),
          )
          .where((r) => r.$2 > r.$1)
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
  int total = 0, start = 0, end = 0;
  for (final range in sorted) {
    if (range.$1 > end) {
      total += end - start;
      start = range.$1;
      end = range.$2;
    } else {
      if (range.$2 > end) {
        end = range.$2;
      }
    }
  }
  return total + end - start;
}
