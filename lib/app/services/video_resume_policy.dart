import 'dart:math' as math;
import 'package:get_storage/get_storage.dart';
import '../models/media_item.dart';
import '../data/playback/playback_state_storage.dart';

/// Resume persistence follows the engine, not the lifetime of its route.
class VideoResumePolicy {
  VideoResumePolicy(this.storage, {int Function()? monotonicMs})
    : _clock = monotonicMs ?? (Stopwatch()..start()).elapsedMillisecondsGetter;
  final GetStorage storage;
  final int Function() _clock;
  String _key = '';
  int _lastPosition = 0, _lastTick = -1, _watch = 0, _lastPersist = -1;
  bool _wasPlaying = false;
  void observe(
    MediaItem? item,
    Duration position,
    Duration duration,
    bool playing,
  ) {
    if (item == null) return;
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    final now = _clock();
    if (key != _key) {
      _key = key;
      _lastTick = -1;
      _watch = 0;
      _lastPersist = now;
      _wasPlaying = false;
    }
    final delta = position.inMilliseconds - _lastPosition;
    final wall = now - _lastTick;
    if (playing &&
        _wasPlaying &&
        _lastTick >= 0 &&
        delta > 0 &&
        delta <= 3500 &&
        wall > 0 &&
        wall <= 5000) {
      _watch += math.min(delta, wall);
    }
    _lastPosition = position.inMilliseconds;
    _lastTick = now;
    _wasPlaying = playing;
    if (now - _lastPersist >= 2000) {
      persist(item, position, duration);
      _lastPersist = now;
    }
  }

  void discontinuity() {
    _lastTick = -1;
    _wasPlaying = false;
  }

  void persist(MediaItem item, Duration position, Duration duration) {
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    if (key.trim().isEmpty) return;
    final positions = Map<String, dynamic>.from(
      storage.read<Map>('video_resume_positions') ?? {},
    );
    final watches = Map<String, dynamic>.from(
      storage.read<Map>('video_resume_watch_ms') ?? {},
    );
    final stored = watches[key];
    final watch = math.max(
      stored is num ? stored.toInt() : int.tryParse('$stored') ?? 0,
      _watch,
    );
    final total = duration > Duration.zero
        ? duration
        : Duration(seconds: item.effectiveDurationSeconds ?? 0);
    if (total < const Duration(seconds: 150) ||
        position.inMilliseconds <= total.inMilliseconds * 0.05 ||
        position >= total - const Duration(seconds: 5) ||
        watch < 8000) {
      positions.remove(key);
      watches.remove(key);
    } else {
      positions[key] = position.inMilliseconds;
      watches[key] = watch;
    }
    if (storage is! PlaybackStateStorage && positions.length > 300) {
      for (final key in positions.keys.take(positions.length - 300).toList()) {
        positions.remove(key);
        watches.remove(key);
      }
    }
    storage.write('video_resume_positions', positions);
    storage.write('video_resume_watch_ms', watches);
  }
}

extension on Stopwatch {
  int elapsedMillisecondsGetter() => elapsedMilliseconds;
}
