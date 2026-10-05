import 'dart:async';
import 'engine_history_recorder.dart';
import '../data/playback/playback_boundary_command.dart';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../data/local/local_library_store.dart';
import '../../Modules/recommendations/data/listening_event_store.dart';
import '../../Modules/recommendations/domain/recommendation_models.dart';

/// Owned by the playback engine, independently of any presentation controller.
/// Position discontinuities (seeks) never contribute listening time.
class PlaybackHistoryRecorder implements EngineHistoryRecorder {
  PlaybackHistoryRecorder({
    required this.events,
    required this.mode,
    this.library,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final ListeningEventStore events;
  final RecommendationMode mode;
  final LocalLibraryStore? library;
  final DateTime Function() _clock;
  MediaItem? _item;
  String? _sessionId;
  DateTime? _started;
  Duration? _lastPosition;
  DateTime? _lastTick;
  Duration _duration = Duration.zero;
  double _seconds = 0;
  double _savedSeconds = 0;
  bool _wasPlaying = false;
  bool _counted = false;
  bool _completed = false;
  bool _completionCounted = false;
  bool _skipCounted = false;
  double _persistedProgress = 0;
  Future<void> _writes = Future<void>.value();
  static int _sequence = 0;
  static Future<void> _operations = Future<void>.value();

  @override
  void select(
    MediaItem? item, {
    MediaVariant? variant,
    bool occurrenceChanged = false,
  }) {
    final currentKey = _key(_item);
    if (currentKey == _key(item)) {
      if (item != null) _item = item;
      return;
    }
    checkpoint(finalize: true);
    _item = item;
    _reset();
  }

  String? _key(MediaItem? item) => item == null
      ? null
      : item.publicId.trim().isNotEmpty
      ? 'p:${item.publicId.trim()}'
      : 'i:${item.id.trim()}';

  void _reset() {
    _sessionId = null;
    _started = null;
    _lastPosition = null;
    _lastTick = null;
    _seconds = 0;
    _savedSeconds = 0;
    _counted = false;
    _completed = false;
    _completionCounted = false;
    _skipCounted = false;
    _persistedProgress = 0;
    _wasPlaying = false;
  }

  @override
  void update({
    required Duration position,
    required Duration duration,
    required bool playing,
    double speed = 1,
    bool buffering = false,
    bool completed = false,
    bool looped = false,
  }) {
    if (_item == null) return;
    final now = _clock();
    final previous = _lastPosition;
    final lastTick = _lastTick;
    final delta = previous == null
        ? 0.0
        : (position - previous).inMilliseconds / 1000;
    final elapsed = lastTick == null
        ? 0.0
        : now.difference(lastTick).inMilliseconds / 1000;
    // Loop/replay: close the previous occurrence, then begin a new one.
    if (previous != null &&
        delta < 0 &&
        _completed &&
        position < const Duration(seconds: 2)) {
      checkpoint(finalize: true);
      _reset();
    }
    if (playing && _sessionId == null) {
      _started = now;
      _sessionId = '${mode.key}:${now.microsecondsSinceEpoch}:${_sequence++}';
    }
    if (_sessionId != null &&
        _wasPlaying &&
        delta > 0 &&
        delta <= elapsed * speed + 1.0) {
      _seconds += delta;
    }
    _duration = duration;
    _lastPosition = position;
    _lastTick = now;
    final paused = _wasPlaying && !playing;
    _wasPlaying = playing;
    if (duration > Duration.zero &&
        _seconds >= duration.inMilliseconds / 1000 * .9) {
      _completed = true;
    }
    if (_seconds - _savedSeconds >= 5 || paused) checkpoint();
  }

  void checkpoint({bool finalize = false}) {
    final item = _item;
    final id = _sessionId;
    if (item == null || id == null || _seconds < 3) return;
    final first = !_counted;
    final completion = _completed && !_completionCounted;
    final skip = finalize && !_completed && !_skipCounted;
    final previousProgress = _persistedProgress;
    _completionCounted = _completionCounted || completion;
    _skipCounted = _skipCounted || skip;
    _counted = true;
    _savedSeconds = _seconds;
    final event = ListeningEvent(
      trackKey: _key(item)!,
      occurredAt: _started!.millisecondsSinceEpoch,
      progress: _duration > Duration.zero
          ? (_seconds / (_duration.inMilliseconds / 1000)).clamp(0, 1)
          : 0,
      completed: _completed,
      skipped: finalize && !_completed,
      mode: mode,
      sessionId: id,
      playedSeconds: _seconds,
      mediaSnapshot: item,
    );
    _persistedProgress = event.progress;
    final write = _operations.then((_) async {
      await events.add(event);
      if (library != null) {
        final all = await library!.readAll();
        final related = all.where((candidate) => _key(candidate) == _key(item));
        for (final existing in related) {
          await library!.upsert(
            existing.copyWith(
              playCount: existing.playCount + (first ? 1 : 0),
              lastPlayedAt: event.occurredAt,
              fullListenCount: existing.fullListenCount + (completion ? 1 : 0),
              lastCompletedAt: completion
                  ? event.occurredAt
                  : existing.lastCompletedAt,
              skipCount: existing.skipCount + (skip ? 1 : 0),
              avgListenProgress:
                  ((existing.avgListenProgress * existing.playCount +
                              event.progress -
                              (first ? 0 : previousProgress)) /
                          (existing.playCount + (first ? 1 : 0)).clamp(
                            1,
                            1 << 30,
                          ))
                      .clamp(0, 1),
            ),
          );
        }
      }
    });
    _writes = write.catchError((Object error, StackTrace stack) {
      debugPrint('Playback history save failed: $error');
    });
    _operations = _writes;
  }

  @override
  void beforeSeek([Duration? target]) {
    checkpoint();
    if (target == Duration.zero && _completed) _reset();
    _lastPosition = null;
    _lastTick = null;
  }

  @override
  Future<void> flush() async {
    checkpoint();
    await _writes;
    await events.flush();
  }

  @override
  void intent(PlaybackTermination reason) {}
  @override
  void afterSeek({bool playing = false}) {}
}
