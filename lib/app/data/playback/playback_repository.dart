import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'playback_database.dart';
import 'playback_session_command.dart';
import 'playback_boundary_command.dart';

part 'playback_session_writer.dart';
part 'playback_aggregate_writer.dart';

enum PlaybackFaultPoint { afterIdentityWrite, beforeCommit, afterCommit }

class PlaybackIdempotencyConflict implements Exception {
  PlaybackIdempotencyConflict(this.commandId);
  final String commandId;

  @override
  String toString() => 'PlaybackIdempotencyConflict($commandId)';
}

class PlaybackAlias {
  const PlaybackAlias({
    required this.namespace,
    required this.scope,
    required this.value,
  });
  final String namespace;
  final String scope;
  final String value;
}

/// Typed first persistence command; strings are not SQL fragments.
class RegisterPlaybackIdentity {
  const RegisterPlaybackIdentity({
    required this.commandId,
    required this.mediaId,
    required this.createdAtUtcMs,
    required this.alias,
    this.libraryId,
  });
  final String commandId;
  final String mediaId;
  final int createdAtUtcMs;
  final PlaybackAlias alias;
  final String? libraryId;

  List<Object?> get canonicalRequest => [
    'register_identity',
    1,
    mediaId,
    libraryId,
    createdAtUtcMs,
    alias.namespace,
    alias.scope,
    alias.value,
  ];
}

class PlaybackCommandResult {
  const PlaybackCommandResult({required this.mediaId, required this.revision});
  final String mediaId;
  final int revision;
}

/// Single in-process owner. Do not construct multiple owners for one generation.
/// Other isolates must route commands to this owner, not instantiate another one.
class PlaybackRepository {
  PlaybackRepository(this._database, {this.faultInjector});
  final PlaybackDatabase _database;
  final FutureOr<void> Function(PlaybackFaultPoint point)? faultInjector;
  final _revisions = StreamController<int>.broadcast();
  Future<void> _tail = Future<void>.value();
  bool _closing = false;

  Stream<int> get revisions => _revisions.stream;

  Future<PlaybackSessionResult> openSession(OpenPlaybackSession command) {
    if (_closing) {
      return Future.error(StateError('Playback repository is closing'));
    }
    final completion = Completer<PlaybackSessionResult>();
    _tail = _tail.then((_) async {
      try {
        completion.complete(await _openSession(command));
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    });
    return completion.future;
  }

  Future<PlaybackSessionResult> _openSession(OpenPlaybackSession c) async {
    c.validate();
    final hash = sha256
        .convert(utf8.encode(jsonEncode(c.canonicalRequest)))
        .toString();
    var changed = false;
    final result = await _database.transaction(() async {
      final previous = await _database
          .customSelect(
            'SELECT request_hash,codec_version,canonicalization_version,result_json FROM applied_command WHERE command_id=?',
            variables: [Variable(c.commandId)],
          )
          .getSingleOrNull();
      if (previous != null) {
        if (previous.read<String>('request_hash') != hash ||
            previous.read<int>('codec_version') != 1 ||
            previous.read<int>('canonicalization_version') != 1) {
          throw PlaybackIdempotencyConflict(c.commandId);
        }
        final stored =
            jsonDecode(previous.read<String>('result_json'))
                as Map<String, dynamic>;
        return PlaybackSessionResult(
          sessionId: stored['sessionId'] as String,
          eventId: stored['eventId'] as String,
          snapshotId: stored['snapshotId'] as String,
          revision: stored['revision'] as int,
        );
      }
      final variant = await _database
          .customSelect(
            'SELECT media_id,mode,role,format FROM media_variant WHERE variant_id=?',
            variables: [Variable(c.variant.id)],
          )
          .getSingleOrNull();
      if (variant == null) {
        await _database.customStatement(
          'INSERT INTO media_variant(variant_id,media_id,mode,role,format,created_at_utc_ms) VALUES(?,?,?,?,?,?)',
          [
            c.variant.id,
            c.mediaId,
            c.variant.mode.name,
            c.variant.role,
            c.variant.format,
            c.startedAtUtcMs,
          ],
        );
      } else if (variant.read<String>('media_id') != c.mediaId ||
          variant.read<String>('mode') != c.variant.mode.name ||
          variant.read<String>('role') != c.variant.role ||
          variant.data['format'] != c.variant.format) {
        throw StateError('Variant identity conflict');
      }
      final snapshotHash = sha256
          .convert(utf8.encode(jsonEncode(c.snapshot.canonicalFields)))
          .toString();
      final existing = await _database
          .customSelect(
            'SELECT * FROM metadata_snapshot WHERE hash_algorithm=? AND canonicalization_version=? AND content_hash=?',
            variables: [
              Variable('sha256'),
              Variable(2),
              Variable(snapshotHash),
            ],
          )
          .getSingleOrNull();
      String snapshotId;
      if (existing == null) {
        snapshotId = c.snapshot.id;
        await _database.customStatement(
          'INSERT INTO metadata_snapshot(snapshot_id,content_hash,hash_algorithm,canonicalization_version,title,artist,album,artwork_ref,provenance) VALUES(?,?,?,?,?,?,?,?,?)',
          [
            snapshotId,
            snapshotHash,
            'sha256',
            2,
            c.snapshot.title,
            c.snapshot.artist,
            c.snapshot.album,
            c.snapshot.artworkRef,
            'observed',
          ],
        );
      } else {
        if (existing.data['title'] != c.snapshot.title ||
            existing.data['artist'] != c.snapshot.artist ||
            existing.data['album'] != c.snapshot.album ||
            existing.data['artwork_ref'] != c.snapshot.artworkRef ||
            existing.data['provenance'] != 'observed') {
          throw StateError('Snapshot hash collision');
        }
        snapshotId = existing.read<String>('snapshot_id');
      }
      await _database.customStatement(
        'INSERT INTO playback_session(session_id,media_id,mode,initial_variant_id,final_variant_id,snapshot_id,started_at_utc_ms,timezone_id,timezone_quality,initial_position_ms,max_position_ms,duration_ms,initial_speed,final_speed,resumed,context,source_id,status,policy_version,aggregate_scope,provenance,last_sequence) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          c.sessionId,
          c.mediaId,
          c.variant.mode.name,
          c.variant.id,
          c.variant.id,
          snapshotId,
          c.startedAtUtcMs,
          c.timezoneId,
          c.timezoneId == null ? 'unknown' : 'observed',
          c.positionMs,
          c.positionMs,
          c.durationMs,
          c.speed,
          c.speed,
          c.positionMs > 0 ? 1 : 0,
          c.context.storageValue,
          c.sourceId,
          'open',
          1,
          'post_cutover',
          'observed',
          1,
        ],
      );
      await _database.customStatement(
        'UPDATE repository_state SET revision=revision+1 WHERE singleton=1',
      );
      final revision =
          (await _database
                  .customSelect(
                    'SELECT revision FROM repository_state WHERE singleton=1',
                  )
                  .getSingle())
              .read<int>('revision');
      final stored = {
        'sessionId': c.sessionId,
        'eventId': c.eventId,
        'snapshotId': snapshotId,
        'revision': revision,
      };
      await _database.customStatement(
        'INSERT INTO applied_command VALUES(?,?,?,?,?,?,?)',
        [
          c.commandId,
          hash,
          'sha256',
          1,
          1,
          DateTime.now().toUtc().millisecondsSinceEpoch,
          jsonEncode(stored),
        ],
      );
      await _database.customStatement(
        'INSERT INTO playback_event(event_id,session_id,sequence,type,occurred_at_utc_ms,utc_offset_minutes,timezone_id,event_version,codec_version,clock_epoch,monotonic_ms,position_ms,payload_version,payload_json,command_id,command_event_index) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          c.eventId,
          c.sessionId,
          1,
          'play',
          c.startedAtUtcMs,
          c.utcOffsetMinutes,
          c.timezoneId,
          1,
          1,
          c.clockEpoch,
          c.monotonicMs,
          c.positionMs,
          1,
          jsonEncode({
            'engineState': 'ready_playing',
            'positionMs': c.positionMs,
            'variantId': c.variant.id,
          }),
          c.commandId,
          0,
        ],
      );
      await _refreshAggregate(c.mediaId, c.variant.mode.name);
      await faultInjector?.call(PlaybackFaultPoint.beforeCommit);
      changed = true;
      return PlaybackSessionResult(
        sessionId: c.sessionId,
        eventId: c.eventId,
        snapshotId: snapshotId,
        revision: revision,
      );
    });
    if (changed) {
      _revisions.add(result.revision);
      await faultInjector?.call(PlaybackFaultPoint.afterCommit);
    }
    return result;
  }

  Future<PlaybackCommandResult> registerIdentity(
    RegisterPlaybackIdentity command,
  ) {
    if (_closing) {
      return Future.error(StateError('Playback repository is closing'));
    }
    final completion = Completer<PlaybackCommandResult>();
    _tail = _tail.then((_) async {
      try {
        completion.complete(await _registerIdentity(command));
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    });
    return completion.future;
  }

  Future<PlaybackCommandResult> _registerIdentity(
    RegisterPlaybackIdentity command,
  ) async {
    for (final value in [
      command.commandId,
      command.mediaId,
      command.alias.namespace,
      command.alias.scope,
      command.alias.value,
    ]) {
      if (value.isEmpty) {
        throw ArgumentError('Playback identifiers cannot be empty');
      }
    }
    // Fixed-field array, UTF8 JSON, exact strings; no implicit case/trim changes.
    final hash = sha256
        .convert(utf8.encode(jsonEncode(command.canonicalRequest)))
        .toString();
    var changed = false;
    final result = await _database.transaction(() async {
      final previous = await _database
          .customSelect(
            'SELECT request_hash, codec_version, canonicalization_version, result_json FROM applied_command WHERE command_id = ?',
            variables: [Variable(command.commandId)],
          )
          .getSingleOrNull();
      if (previous != null) {
        if (previous.read<String>('request_hash') != hash ||
            previous.read<int>('codec_version') != 1 ||
            previous.read<int>('canonicalization_version') != 1) {
          throw PlaybackIdempotencyConflict(command.commandId);
        }
        final stored =
            jsonDecode(previous.read<String>('result_json'))
                as Map<String, dynamic>;
        return PlaybackCommandResult(
          mediaId: stored['mediaId'] as String,
          revision: stored['revision'] as int,
        );
      }
      await _database.customStatement(
        'INSERT INTO media_identity(media_id, library_id, created_at_utc_ms) VALUES (?, ?, ?)',
        [command.mediaId, command.libraryId, command.createdAtUtcMs],
      );
      await faultInjector?.call(PlaybackFaultPoint.afterIdentityWrite);
      await _database.customStatement(
        'INSERT INTO media_alias(namespace, scope, value, media_id, provenance) VALUES (?, ?, ?, ?, ?)',
        [
          command.alias.namespace,
          command.alias.scope,
          command.alias.value,
          command.mediaId,
          'observed',
        ],
      );
      await _database.customStatement(
        'UPDATE repository_state SET revision = revision + 1 WHERE singleton = 1',
      );
      final revision =
          (await _database
                  .customSelect(
                    'SELECT revision FROM repository_state WHERE singleton = 1',
                  )
                  .getSingle())
              .read<int>('revision');
      await _database.customStatement(
        'INSERT INTO applied_command(command_id, request_hash, hash_algorithm, canonicalization_version, codec_version, applied_at_utc_ms, result_json) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          command.commandId,
          hash,
          'sha256',
          1,
          1,
          DateTime.now().toUtc().millisecondsSinceEpoch,
          jsonEncode({'mediaId': command.mediaId, 'revision': revision}),
        ],
      );
      await faultInjector?.call(PlaybackFaultPoint.beforeCommit);
      changed = true;
      return PlaybackCommandResult(
        mediaId: command.mediaId,
        revision: revision,
      );
    });
    if (changed) {
      _revisions.add(result.revision);
      await faultInjector?.call(PlaybackFaultPoint.afterCommit);
    }
    return result;
  }

  Future<int> readRevision() async {
    await _tail;
    return (await _database
            .customSelect(
              'SELECT revision FROM repository_state WHERE singleton = 1',
            )
            .getSingle())
        .read<int>('revision');
  }

  Future<String?> resolveAlias(PlaybackAlias alias) async {
    await _tail;
    return (await _database
            .customSelect(
              'SELECT media_id FROM media_alias WHERE namespace = ? AND scope = ? AND value = ?',
              variables: [
                Variable(alias.namespace),
                Variable(alias.scope),
                Variable(alias.value),
              ],
            )
            .getSingleOrNull())
        ?.read<String>('media_id');
  }

  Future<void> close() async {
    if (_closing) {
      await _tail;
      return;
    }
    _closing = true;
    await _tail;
    await _revisions.close();
    await _database.close();
  }
}
