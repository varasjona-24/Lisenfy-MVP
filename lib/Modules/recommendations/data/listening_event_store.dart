import 'dart:async';
import 'package:get_storage/get_storage.dart';
import '../../../app/models/media_item.dart';

import '../domain/recommendation_models.dart';

class ListeningEvent {
  const ListeningEvent({
    required this.trackKey,
    required this.occurredAt,
    required this.progress,
    required this.completed,
    required this.skipped,
    this.mode,
    this.sessionId,
    this.playedSeconds,
    this.mediaSnapshot,
  });

  final String trackKey;
  final int occurredAt;
  final double progress;
  final bool completed;
  final bool skipped;

  /// Null denotes events written before playback mode was tracked.
  final RecommendationMode? mode;
  final String? sessionId;
  final double? playedSeconds;
  final MediaItem? mediaSnapshot;

  factory ListeningEvent.fromJson(Map<String, dynamic> json) {
    return ListeningEvent(
      trackKey: (json['trackKey'] as String?)?.trim() ?? '',
      occurredAt: (json['occurredAt'] as num?)?.toInt() ?? 0,
      progress: ((json['progress'] as num?)?.toDouble() ?? 0)
          .clamp(0, 1)
          .toDouble(),
      completed: json['completed'] == true,
      skipped: json['skipped'] == true,
      sessionId: json['sessionId'] as String?,
      playedSeconds: (json['playedSeconds'] as num?)?.toDouble(),
      mediaSnapshot: json['mediaSnapshot'] is Map
          ? MediaItem.fromJson(
              Map<String, dynamic>.from(json['mediaSnapshot'] as Map),
            )
          : null,
      mode: json['mode'] == null
          ? null
          : RecommendationModeX.fromKey(json['mode'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'trackKey': trackKey,
    'occurredAt': occurredAt,
    'progress': progress,
    'completed': completed,
    'skipped': skipped,
    if (mode != null) 'mode': mode!.key,
    if (sessionId != null) 'sessionId': sessionId,
    if (playedSeconds != null) 'playedSeconds': playedSeconds,
    if (mediaSnapshot != null) 'mediaSnapshot': mediaSnapshot!.toJson(),
  };
}

class ListeningEventStore {
  ListeningEventStore(this._box);
  ListeningEventStore.memory([List<Map<String, dynamic>>? initial])
    : _box = null,
      _memory = initial ?? [];

  static const storageKey = 'listening_events_v1';
  static const _retention = Duration(days: 120);
  Future<void> _pendingWrite = Future<void>.value();

  final GetStorage? _box;
  List<Map<String, dynamic>> _memory = [];

  List<ListeningEvent> readAll() {
    final raw = _box?.read<List>(storageKey) ?? _memory;
    return raw
        .whereType<Map>()
        .map(
          (entry) => ListeningEvent.fromJson(Map<String, dynamic>.from(entry)),
        )
        .where((event) => event.trackKey.isNotEmpty && event.occurredAt > 0)
        .toList(growable: false);
  }

  Future<void> add(ListeningEvent event) {
    final operation = _pendingWrite.then((_) => _save(event));
    _pendingWrite = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> flush() => _pendingWrite;

  Future<void> _save(ListeningEvent event) async {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _retention.inMilliseconds;
    final events = readAll()
        .where((existing) => existing.occurredAt >= cutoff)
        .toList();
    final index = event.sessionId == null
        ? -1
        : events.indexWhere(
            (existing) => existing.sessionId == event.sessionId,
          );
    if (index < 0) {
      events.add(event);
    } else {
      events[index] = event;
    }
    _memory = events.map((entry) => entry.toJson()).toList();
    await _box?.write(storageKey, _memory);
  }

  List<Map<String, dynamic>> exportBackupPayload() =>
      readAll().map((e) => e.toJson()).toList();

  Future<void> restoreBackupPayload(List raw) async {
    for (final entry in raw.whereType<Map>()) {
      final event = ListeningEvent.fromJson(Map<String, dynamic>.from(entry));
      if (event.trackKey.isEmpty || event.occurredAt <= 0) continue;
      if (event.sessionId == null &&
          readAll().any(
            (existing) =>
                existing.trackKey == event.trackKey &&
                existing.occurredAt == event.occurredAt &&
                existing.mode == event.mode &&
                existing.progress == event.progress,
          )) {
        continue;
      }
      await add(event);
    }
  }
}
