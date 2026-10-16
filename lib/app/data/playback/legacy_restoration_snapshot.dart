import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'playback_restoration.dart';

/// Capture while legacy writers are stopped, before constructing engines.
/// Persist [bytes] unchanged for migration retries. This does not delete keys.
class LegacyRestorationSnapshot {
  LegacyRestorationSnapshot._(this.bytes);
  final String bytes;
  static const keys = [
    'audio_last_item',
    'audio_last_variant',
    'audio_session_queue_items',
    'audio_session_queue_variants',
    'audio_session_index',
    'audio_session_position_ms',
    'audio_session_was_playing',
    'audio_resume_positions',
    'audio_speed',
    'audio_shuffle_enabled',
    'audio_crossfade_seconds',
    'audio_repeat_mode',
    'video_last_item',
    'video_last_variant',
    'video_queue_items',
    'video_queue_index',
    'video_resume_positions',
    'video_resume_watch_ms',
  ];
  factory LegacyRestorationSnapshot.capture(Object? Function(String) read) =>
      LegacyRestorationSnapshot._(
        jsonEncode({for (final key in keys) key: read(key)}),
      );
  factory LegacyRestorationSnapshot.fromBytes(String bytes) {
    final value = jsonDecode(bytes);
    if (value is! Map ||
        keys
            .where((key) => key != 'audio_repeat_mode')
            .any((key) => !value.containsKey(key))) {
      throw FormatException('Incomplete frozen restoration snapshot');
    }
    return LegacyRestorationSnapshot._(bytes);
  }
  String get hash => sha256.convert(utf8.encode(bytes)).toString();
  Map<String, dynamic> get _values => jsonDecode(bytes) as Map<String, dynamic>;

  List<PlaybackRestoration> get states {
    final data = _values;
    List<Map<String, dynamic>> maps(String key) => ((data[key] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    Map<String, dynamic>? map(String key) =>
        data[key] == null ? null : Map<String, dynamic>.from(data[key] as Map);
    final audio = maps('audio_session_queue_items');
    final video = maps('video_queue_items');
    return [
      PlaybackRestoration(
        mode: RestorationMode.audio,
        queue: audio,
        variants: maps('audio_session_queue_variants'),
        index: data['audio_session_index'] as int? ?? 0,
        positionMs: data['audio_session_position_ms'] as int? ?? 0,
        wasPlaying: data['audio_session_was_playing'] as bool? ?? false,
        lastItem: map('audio_last_item'),
        lastVariant: map('audio_last_variant'),
        speed: (data['audio_speed'] as num?)?.toDouble() ?? 1,
        shuffle: data['audio_shuffle_enabled'] as bool? ?? false,
        crossfadeSeconds: data['audio_crossfade_seconds'] as int? ?? 0,
        repeatMode: data['audio_repeat_mode'] as String?,
      ),
      PlaybackRestoration(
        mode: RestorationMode.video,
        queue: video,
        index: data['video_queue_index'] as int? ?? 0,
        lastItem: map('video_last_item'),
        lastVariant: map('video_last_variant'),
      ),
    ];
  }

  List<PlaybackResumePoint> get resumePoints {
    final data = _values;
    final watch = data['video_resume_watch_ms'] as Map? ?? {};
    return [
      for (final mode in RestorationMode.values)
        for (final entry
            in (data['${mode.name}_resume_positions'] as Map? ?? {}).entries)
          PlaybackResumePoint(
            mode: mode,
            trackKey: entry.key as String,
            positionMs: entry.value as int,
            trustedWatchMs: mode == RestorationMode.video
                ? watch[entry.key] as int?
                : null,
          ),
    ];
  }
}
