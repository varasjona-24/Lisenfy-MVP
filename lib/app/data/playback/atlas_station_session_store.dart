import 'dart:convert';

import '../../models/media_item.dart';
import 'playback_repository.dart';

class AtlasTrackReference {
  const AtlasTrackReference(this.id, this.publicId);
  factory AtlasTrackReference.fromItem(MediaItem item) =>
      AtlasTrackReference(item.id, item.publicId);
  final String id;
  final String publicId;

  bool matches(MediaItem item) =>
      id == item.id ||
      (publicId.trim().isNotEmpty && publicId.trim() == item.publicId.trim());
  Map<String, dynamic> toJson() => {'id': id, 'publicId': publicId};
}

class AtlasStationSession {
  const AtlasStationSession({
    required this.stationId,
    required this.queue,
    required this.index,
    required this.positionMs,
  });
  final String stationId;
  final List<AtlasTrackReference> queue;
  final int index;
  final int positionMs;

  Map<String, dynamic> toJson() => {
    'stationId': stationId,
    'queue': queue.map((item) => item.toJson()).toList(),
    'index': index,
    'positionMs': positionMs,
  };

  static AtlasStationSession? fromJson(dynamic raw) {
    if (raw is! Map || raw['queue'] is! List) return null;
    final id = raw['stationId'];
    final index = raw['index'];
    final position = raw['positionMs'];
    if (id is! String ||
        id.isEmpty ||
        index is! int ||
        position is! int ||
        position < 0) {
      return null;
    }
    final queue = <AtlasTrackReference>[];
    for (final entry in raw['queue'] as List) {
      if (entry is! Map ||
          entry['id'] is! String ||
          entry['publicId'] is! String) {
        return null;
      }
      queue.add(AtlasTrackReference(entry['id'], entry['publicId']));
    }
    if (index < 0 || index >= queue.length) return null;
    return AtlasStationSession(
      stationId: id,
      queue: queue,
      index: index,
      positionMs: position,
    );
  }

  /// Uses current catalog records, never paths copied from an old backup.
  AtlasStationResume? resolve(List<MediaItem> playableLibrary) {
    final resolved = <MediaItem>[];
    final originalIndices = <int>[];
    for (var i = 0; i < queue.length; i++) {
      final matches = playableLibrary.where(queue[i].matches);
      if (matches.isEmpty) continue;
      resolved.add(matches.first);
      originalIndices.add(i);
    }
    if (resolved.isEmpty) return null;
    var target = originalIndices.indexOf(index);
    final sameTrack = target >= 0;
    if (!sameTrack) {
      target = originalIndices.indexWhere((entry) => entry > index);
      if (target < 0) target = 0;
    }
    var position = sameTrack ? positionMs : 0;
    final seconds = resolved[target].effectiveDurationSeconds;
    if (seconds != null && seconds > 0 && position >= seconds * 1000) {
      position = 0;
    }
    return AtlasStationResume(
      resolved,
      target,
      Duration(milliseconds: position),
    );
  }
}

class AtlasStationResume {
  const AtlasStationResume(this.queue, this.index, this.position);
  final List<MediaItem> queue;
  final int index;
  final Duration position;
}

/// A durable SQLite domain, included in the existing full backup protocol.
/// Commands are serialized; failed writes are surfaced by flush/read.
class AtlasStationSessionStore {
  AtlasStationSessionStore(this.repository);
  static const namespace = 'world_mode_station_sessions_v1';
  final PlaybackRepository repository;
  Future<void> _tail = Future<void>.value();
  Object? _failure;

  Future<Map<String, dynamic>> _read() async {
    final domains = await repository.readDomains(namespace: namespace);
    final raw = domains[namespace];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  Future<void> flush() async {
    await _tail;
    if (_failure != null) {
      throw StateError('Atlas session write failed: $_failure');
    }
  }

  Future<AtlasStationSession?> read(String stationId) async {
    await flush();
    final raw = await _read();
    final sessions = raw['sessions'];
    final session = AtlasStationSession.fromJson(
      sessions is Map ? sessions[stationId] : null,
    );
    return session?.stationId == stationId ? session : null;
  }

  Future<String?> readActiveStationId() async {
    await flush();
    final raw = (await _read())['activeStationId'];
    return raw is String ? raw : null;
  }

  Future<void> save(AtlasStationSession? session, {required String? activeId}) {
    // Freeze mutable inputs before scheduling an asynchronous write.
    final snapshot = session == null
        ? null
        : jsonDecode(jsonEncode(session.toJson()));
    final operation = _tail.then((_) async {
      final data = await _read();
      final sessions = Map<String, dynamic>.from(
        data['sessions'] as Map? ?? {},
      );
      if (session != null) sessions[session.stationId] = snapshot;
      final updated = {'sessions': sessions, 'activeStationId': activeId};
      if (jsonEncode(data) != jsonEncode(updated)) {
        await repository.replaceDomain(namespace, updated);
      }
      _failure = null;
    });
    _tail = operation.catchError((Object error) {
      _failure = error;
    });
    return operation;
  }
}
