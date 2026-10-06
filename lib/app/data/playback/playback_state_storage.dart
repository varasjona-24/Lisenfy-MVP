import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'legacy_restoration_snapshot.dart';
import 'playback_repository.dart';
import 'playback_restoration.dart';

GetStorage playbackStateStorage() => Get.isRegistered<PlaybackStateStorage>()
    ? Get.find<PlaybackStateStorage>()
    : GetStorage();

/// Compatibility boundary for synchronous engine state reads. Only restoration
/// keys are routed to SQL; never fallback to GetStorage for those keys.
/// Pending memory is the live engine projection; flush confirms durability.
class PlaybackStateStorage implements GetStorage {
  PlaybackStateStorage._(this.repository, this.preferences, this._values);
  final PlaybackRepository repository;
  final GetStorage preferences;
  Map<String, dynamic> _values;
  Future<void> reload() async {
    await flush();
    final refreshed = await load(repository, preferences);
    _values = refreshed._values;
  }

  Future<void> _tail = Future.value();
  Completer<void>? _batch;
  Object? failure;
  static Future<PlaybackStateStorage> load(
    PlaybackRepository repository,
    GetStorage preferences,
  ) async {
    final values = <String, dynamic>{};
    for (final mode in RestorationMode.values) {
      final state = await repository.readRestoration(mode);
      final data = state?.payload ?? {};
      final prefix = mode.name;
      values['${prefix}_last_item'] = data['lastItem'];
      values['${prefix}_last_variant'] = data['lastVariant'];
      if (mode == RestorationMode.audio) {
        values['audio_repeat_mode'] = data['repeatMode'];
      }
      if (mode == RestorationMode.audio) {
        values.addAll({
          'audio_session_queue_items': data['queue'] ?? [],
          'audio_session_queue_variants': data['variants'] ?? [],
          'audio_session_index': data['index'] ?? 0,
          'audio_session_position_ms': data['positionMs'] ?? 0,
          'audio_session_was_playing': data['wasPlaying'] ?? false,
          'audio_speed': data['speed'] ?? 1.0,
          'audio_shuffle_enabled': data['shuffle'] ?? false,
          'audio_crossfade_seconds': data['crossfadeSeconds'] ?? 0,
        });
      } else {
        values.addAll({
          'video_queue_items': data['queue'] ?? [],
          'video_queue_index': data['index'] ?? 0,
        });
      }
      final points = await repository.readResumePoints(mode);
      values['${prefix}_resume_positions'] = {
        for (final p in points) p.trackKey: p.positionMs,
      };
      if (mode == RestorationMode.video) {
        values['video_resume_watch_ms'] = {
          for (final p in points)
            if (p.trustedWatchMs != null) p.trackKey: p.trustedWatchMs,
        };
      }
    }
    return PlaybackStateStorage._(repository, preferences, values);
  }

  bool _owns(String key) => LegacyRestorationSnapshot.keys.contains(key);
  @override
  T? read<T>(String key) {
    if (!_owns(key)) return preferences.read<T>(key);
    final value = _values[key];
    return value == null ? null : jsonDecode(jsonEncode(value)) as T;
  }

  @override
  Future<void> write(String key, dynamic value) {
    if (!_owns(key)) return preferences.write(key, value);
    if (failure != null) {
      return Future.error(StateError('SQLite restoration failed: $failure'));
    }
    _values[key] = jsonDecode(jsonEncode(value));
    return _schedule();
  }

  @override
  Future<void> remove(String key) {
    if (!_owns(key)) return preferences.remove(key);
    _values.remove(key);
    return _schedule();
  }

  Future<void> _schedule() {
    if (_batch != null) return _batch!.future;
    final batch = _batch = Completer<void>();
    // Existing callers sometimes intentionally discard write futures. Register
    // an error handler while preserving the error for callers and flush.
    unawaited(batch.future.catchError((Object _) {}));
    scheduleMicrotask(() {
      _batch = null;
      final frozen = LegacyRestorationSnapshot.capture((key) => _values[key]);
      _tail = _tail
          .then((_) async {
            if (failure != null) {
              throw StateError('SQLite restoration failed: $failure');
            }
            await repository.saveOperationalBundle(
              frozen.states,
              frozen.resumePoints,
              DateTime.now().millisecondsSinceEpoch,
            );
          })
          .then(
            (_) => batch.complete(),
            onError: (Object error, StackTrace stack) {
              failure = error;
              batch.completeError(error, stack);
            },
          );
    });
    return batch.future;
  }

  Future<void> flush() async {
    final pending = _batch;
    if (pending != null) await pending.future;
    await _tail;
    if (failure != null) {
      throw StateError('SQLite restoration failed: $failure');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unsupported playback storage operation ${invocation.memberName}',
  );
}
