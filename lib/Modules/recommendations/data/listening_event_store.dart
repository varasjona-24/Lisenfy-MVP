import 'package:get_storage/get_storage.dart';

class ListeningEvent {
  const ListeningEvent({
    required this.trackKey,
    required this.occurredAt,
    required this.progress,
    required this.completed,
    required this.skipped,
  });

  final String trackKey;
  final int occurredAt;
  final double progress;
  final bool completed;
  final bool skipped;

  factory ListeningEvent.fromJson(Map<String, dynamic> json) {
    return ListeningEvent(
      trackKey: (json['trackKey'] as String?)?.trim() ?? '',
      occurredAt: (json['occurredAt'] as num?)?.toInt() ?? 0,
      progress: ((json['progress'] as num?)?.toDouble() ?? 0)
          .clamp(0, 1)
          .toDouble(),
      completed: json['completed'] == true,
      skipped: json['skipped'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'trackKey': trackKey,
    'occurredAt': occurredAt,
    'progress': progress,
    'completed': completed,
    'skipped': skipped,
  };
}

class ListeningEventStore {
  ListeningEventStore(this._box);
  ListeningEventStore.memory([List<Map<String, dynamic>>? initial])
    : _box = null,
      _memory = initial ?? [];

  static const storageKey = 'listening_events_v1';
  static const _retention = Duration(days: 120);
  static const _maxEvents = 4000;

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

  Future<void> add(ListeningEvent event) async {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _retention.inMilliseconds;
    final events = readAll()
        .where((existing) => existing.occurredAt >= cutoff)
        .toList();
    events.add(event);
    final trimmed = events.length <= _maxEvents
        ? events
        : events.sublist(events.length - _maxEvents);
    _memory = trimmed.map((entry) => entry.toJson()).toList();
    await _box?.write(storageKey, _memory);
  }
}
