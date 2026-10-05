part of 'playback_repository.dart';

extension PlaybackAggregateWriter on PlaybackRepository {
  Future<void> _refreshAggregate(String mediaId, String mode) async {
    await _database.customStatement(
      'DELETE FROM playback_aggregate WHERE media_id=? AND mode=?',
      [mediaId, mode],
    );
    await _database.customStatement(
      '''
      INSERT INTO playback_aggregate
      (media_id,mode,session_count,play_count,completed_count,skip_count,wall_ms,media_ms,
       completion_sum,completion_samples,first_played_at_utc_ms,last_played_at_utc_ms,
       last_completed_at_utc_ms,projection_version)
      SELECT media_id,mode,count(*),sum(valid_play),sum(completed),sum(skipped),
        sum(wall_ms),sum(media_ms),coalesce(sum(completion_ratio),0),count(completion_ratio),
        min(CASE WHEN valid_play=1 THEN started_at_utc_ms END),
        max(CASE WHEN valid_play=1 THEN started_at_utc_ms END),
        max(CASE WHEN completed=1 THEN ended_at_utc_ms END),1
      FROM playback_session WHERE media_id=? AND mode=?
        AND aggregate_scope IN ('post_cutover','independent') GROUP BY media_id,mode
    ''',
      [mediaId, mode],
    );
  }

  /// Serialized repair. Uses session/interval materializations, never old aggregates.
  Future<int> rebuildAggregates() {
    if (_closing) {
      return Future.error(StateError('Playback repository is closing'));
    }
    final done = Completer<int>();
    _tail = _tail.then((_) async {
      try {
        final revision = await _database.transaction(() async {
          await _database.customStatement('DELETE FROM playback_aggregate');
          final keys = await _database
              .customSelect(
                'SELECT DISTINCT media_id,mode FROM playback_session',
              )
              .get();
          for (final key in keys) {
            await _refreshAggregate(
              key.read<String>('media_id'),
              key.read<String>('mode'),
            );
          }
          await _database.customStatement(
            'UPDATE repository_state SET revision=revision+1 WHERE singleton=1',
          );
          return (await _database
                  .customSelect(
                    'SELECT revision FROM repository_state WHERE singleton=1',
                  )
                  .getSingle())
              .read<int>('revision');
        });
        _revisions.add(revision);
        done.complete(revision);
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  /// Startup only, before attaching an engine. Never invent the unsaved tail.
  Future<int> recoverInterruptedSessions() async {
    await _tail;
    final sessions = await _database
        .customSelect(
          "SELECT session_id,last_sequence FROM playback_session WHERE status='open'",
        )
        .get();
    var recovered = 0;
    for (final session in sessions) {
      final id = session.read<String>('session_id');
      final sequence = session.read<int>('last_sequence');
      final last = await _database
          .customSelect(
            'SELECT * FROM playback_event WHERE session_id=? AND sequence=?',
            variables: [Variable(id), Variable(sequence)],
          )
          .getSingle();
      final payload =
          jsonDecode(last.read<String>('payload_json')) as Map<String, dynamic>;
      await recordBoundary(
        RecordPlaybackBoundary(
          commandId: 'recovery:$id:$sequence',
          sessionId: id,
          eventId: 'recovery:$id:$sequence',
          boundary: PlaybackBoundary.stop,
          utcMs: last.read<int>('occurred_at_utc_ms'),
          monotonicMs: last.read<int>('monotonic_ms'),
          clockEpoch: last.read<String>('clock_epoch'),
          positionMs: last.read<int>('position_ms'),
          playingAfter: false,
          intervalStartSequence: payload['engineState'] == 'ready_playing'
              ? sequence
              : null,
          termination: PlaybackTermination.processLost,
        ),
      );
      recovered++;
    }
    return recovered;
  }
}
