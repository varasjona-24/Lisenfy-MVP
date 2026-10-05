part of 'playback_repository.dart';

extension PlaybackRestorationRepository on PlaybackRepository {
  Future<T> _restorationTask<T>(Future<T> Function() task) {
    if (_closing) {
      return Future.error(StateError('Playback repository is closing'));
    }
    final completion = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completion.complete(await task());
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    });
    return completion.future;
  }

  Future<PlaybackRestoration?> readRestoration(
    RestorationMode mode,
  ) => _restorationTask(() async {
    final row = await _database
        .customSelect(
          'SELECT payload_version,payload_json FROM playback_restoration WHERE mode=?',
          variables: [Variable(mode.name)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    if (row.read<int>('payload_version') != 1) {
      throw StateError('Unknown restoration codec');
    }
    return PlaybackRestoration.decode(mode, row.read<String>('payload_json'));
  });

  Future<List<PlaybackResumePoint>> readResumePoints(
    RestorationMode mode,
  ) => _restorationTask(
    () async =>
        (await _database
                .customSelect(
                  'SELECT track_key,position_ms,trusted_watch_ms FROM playback_resume WHERE mode=? ORDER BY track_key',
                  variables: [Variable(mode.name)],
                )
                .get())
            .map(
              (row) => PlaybackResumePoint(
                mode: mode,
                trackKey: row.read<String>('track_key'),
                positionMs: row.read<int>('position_ms'),
                trustedWatchMs: row.readNullable<int>('trusted_watch_ms'),
              ),
            )
            .toList(),
  );

  Future<void> _writeRestoration(
    PlaybackRestoration state,
    int now,
  ) => _database.customStatement(
    'INSERT INTO playback_restoration(mode,payload_version,payload_json,updated_at_utc_ms) VALUES(?,1,?,?) '
    'ON CONFLICT(mode) DO UPDATE SET payload_json=excluded.payload_json,updated_at_utc_ms=excluded.updated_at_utc_ms',
    [state.mode.name, state.payloadJson, now],
  );

  Future<void> _writeResume(PlaybackResumePoint point) {
    point.validate();
    return _database.customStatement(
      'INSERT INTO playback_resume(mode,track_key,position_ms,trusted_watch_ms) VALUES(?,?,?,?) '
      'ON CONFLICT(mode,track_key) DO UPDATE SET position_ms=excluded.position_ms,trusted_watch_ms=excluded.trusted_watch_ms',
      [point.mode.name, point.trackKey, point.positionMs, point.trustedWatchMs],
    );
  }

  Future<int> _restorationRevision() async {
    await _database.customStatement(
      'UPDATE repository_state SET revision=revision+1 WHERE singleton=1',
    );
    return (await _database
            .customSelect(
              'SELECT revision FROM repository_state WHERE singleton=1',
            )
            .getSingle())
        .read<int>('revision');
  }

  /// Mutable operational writes do not append playback events or change metrics.
  Future<void> saveRestoration(
    PlaybackRestoration state, {
    required int nowUtcMs,
  }) => _restorationTask(() async {
    final revision = await _database.transaction(() async {
      await _writeRestoration(state, nowUtcMs);
      return _restorationRevision();
    });
    _revisions.add(revision);
  });

  Future<void> saveResumePoint(PlaybackResumePoint point) =>
      _restorationTask(() async {
        final revision = await _database.transaction(() async {
          await _writeResume(point);
          return _restorationRevision();
        });
        _revisions.add(revision);
      });

  Future<void> clearResumePoint(RestorationMode mode, String trackKey) =>
      _restorationTask(() async {
        final revision = await _database.transaction(() async {
          await _database.customStatement(
            'DELETE FROM playback_resume WHERE mode=? AND track_key=?',
            [mode.name, trackKey],
          );
          return _restorationRevision();
        });
        _revisions.add(revision);
      });

  /// Frozen source, captured before engines start. One receipt for the whole
  /// import; retry cannot overwrite subsequent operational updates.
  Future<bool> importRestoration({
    required String sourceId,
    required String sourceHash,
    required int importedAtUtcMs,
    required List<PlaybackRestoration> states,
    required List<PlaybackResumePoint> resumePoints,
  }) => _restorationTask(() async {
    if (sourceId.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceHash) ||
        states.map((s) => s.mode).toSet().length != states.length ||
        resumePoints
                .map((p) => jsonEncode([p.mode.name, p.trackKey]))
                .toSet()
                .length !=
            resumePoints.length) {
      throw ArgumentError('Invalid restoration import');
    }
    int? revision;
    final imported = await _database.transaction(() async {
      final receipt = await _database
          .customSelect(
            'SELECT source_hash FROM restoration_import WHERE source_id=?',
            variables: [Variable(sourceId)],
          )
          .getSingleOrNull();
      if (receipt != null) {
        if (receipt.read<String>('source_hash') != sourceHash) {
          throw PlaybackIdempotencyConflict(sourceId);
        }
        return false;
      }
      if ((await _database
                  .customSelect('SELECT mode FROM playback_restoration LIMIT 1')
                  .get())
              .isNotEmpty ||
          (await _database
                  .customSelect('SELECT mode FROM playback_resume LIMIT 1')
                  .get())
              .isNotEmpty) {
        throw StateError('Import requires empty restoration target');
      }
      for (final state in states) {
        await _writeRestoration(state, importedAtUtcMs);
      }
      for (final point in resumePoints) {
        await _writeResume(point);
      }
      await faultInjector?.call(PlaybackFaultPoint.beforeCommit);
      await _database.customStatement(
        'INSERT INTO restoration_import(source_id,source_hash,imported_at_utc_ms) VALUES(?,?,?)',
        [sourceId, sourceHash, importedAtUtcMs],
      );
      revision = await _restorationRevision();
      return true;
    });
    if (revision != null) _revisions.add(revision!);
    return imported;
  });
}
