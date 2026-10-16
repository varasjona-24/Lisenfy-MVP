import '../models/media_item.dart';
import '../data/playback/playback_boundary_command.dart';

/// Exactly one recorder is selected per motor; injection never adds a second writer.
abstract interface class EngineHistoryRecorder {
  void select(
    MediaItem? item, {
    MediaVariant? variant,
    bool occurrenceChanged = false,
  });
  void update({
    required Duration position,
    required Duration duration,
    required bool playing,
    double speed = 1,
    bool buffering = false,
    bool completed = false,
    bool looped = false,
  });
  void intent(PlaybackTermination reason);
  void beforeSeek([Duration? target]);
  void afterSeek({bool playing = false});

  /// Exclude an uncertain engine-observation gap without inventing media time.
  void reconcileEnginePosition(Duration position, {required bool playing});
  Future<void> flush();
}
