import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'playback_database.dart';

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
