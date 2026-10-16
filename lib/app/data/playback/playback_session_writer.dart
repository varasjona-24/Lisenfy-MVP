part of 'playback_repository.dart';

extension PlaybackSessionWriter on PlaybackRepository {
  Future<PlaybackBoundaryResult> recordBoundary(
    RecordPlaybackBoundary command,
  ) {
    if (_closing) {
      return Future.error(StateError('Playback repository is closing'));
    }
    final complete = Completer<PlaybackBoundaryResult>();
    _tail = _tail.then((_) async {
      try {
        complete.complete(await _writeBoundary(command));
      } catch (error, stack) {
        complete.completeError(error, stack);
      }
    });
    return complete.future;
  }

  Future<PlaybackBoundaryResult> _writeBoundary(
    RecordPlaybackBoundary c,
  ) async {
    c.validate();
    final hash = sha256
        .convert(utf8.encode(jsonEncode(c.canonical)))
        .toString();
    var changed = false;
    final result = await _database.transaction(() async {
      final retry = await _database
          .customSelect(
            'SELECT * FROM applied_command WHERE command_id=?',
            variables: [Variable(c.commandId)],
          )
          .getSingleOrNull();
      if (retry != null) {
        if (retry.read<String>('request_hash') != hash ||
            retry.read<int>('codec_version') != 1 ||
            retry.read<int>('canonicalization_version') != 1) {
          throw PlaybackIdempotencyConflict(c.commandId);
        }
        final r =
            jsonDecode(retry.read<String>('result_json'))
                as Map<String, dynamic>;
        return PlaybackBoundaryResult(
          revision: r['revision'] as int,
          sequence: r['sequence'] as int,
          skipped: r['skipped'] as bool,
          completed: r['completed'] as bool,
        );
      }
      final session = await _database
          .customSelect(
            'SELECT * FROM playback_session WHERE session_id=?',
            variables: [Variable(c.sessionId)],
          )
          .getSingle();
      if (session.read<String>('status') != 'open') {
        throw StateError('Session already terminal');
      }
      final lastSequence = session.read<int>('last_sequence');
      final previous = await _database
          .customSelect(
            'SELECT * FROM playback_event WHERE session_id=? AND sequence=?',
            variables: [Variable(c.sessionId), Variable(lastSequence)],
          )
          .getSingle();
      if (previous.data['clock_epoch'] != c.clockEpoch ||
          c.monotonicMs < (previous.data['monotonic_ms'] as int)) {
        throw StateError(
          'Clock discontinuity requires dedicated recovery command',
        );
      }
      final previousPayload =
          jsonDecode(previous.read<String>('payload_json'))
              as Map<String, dynamic>;
      final wasPlaying = previousPayload['engineState'] == 'ready_playing';
      if ((c.boundary == PlaybackBoundary.resume ||
              c.boundary == PlaybackBoundary.bufferingEnd) &&
          (wasPlaying || !c.playingAfter)) {
        throw StateError('Resume requires inactive -> playing');
      }
      if ((c.boundary == PlaybackBoundary.pause ||
              c.boundary == PlaybackBoundary.bufferingStart) &&
          !wasPlaying) {
        throw StateError('Pause/buffering requires a playing segment');
      }
      if ((c.boundary == PlaybackBoundary.checkpoint ||
              c.boundary == PlaybackBoundary.speedChange ||
              c.boundary == PlaybackBoundary.seek) &&
          c.playingAfter != wasPlaying) {
        throw StateError(
          'This boundary cannot implicitly change playing state',
        );
      }
      if (wasPlaying && c.intervalStartSequence != lastSequence) {
        throw StateError('Playing segment must close at its next boundary');
      }
      if (!wasPlaying && c.intervalStartSequence != null) {
        throw StateError('Inactive time cannot become listening');
      }
      final duration = session.data['duration_ms'] as int?;
      final ratio = duration == null
          ? null
          : (c.positionMs / duration).clamp(0.0, 1.0);
      final manual = [
        PlaybackTermination.manualNext,
        PlaybackTermination.manualPrevious,
        PlaybackTermination.manualSelection,
      ].contains(c.termination);
      final nearEnd =
          duration != null && c.positionMs * 10000 >= duration * 9200;
      final skipped = manual && duration != null && !nearEnd;
      final completed =
          c.termination == PlaybackTermination.naturalEnd ||
          (manual && nearEnd);
      final sequence = lastSequence + 1;
      final terminal = c.boundary == PlaybackBoundary.stop;
      final type = terminal
          ? (completed
                ? 'complete'
                : skipped
                ? 'skip'
                : c.termination == PlaybackTermination.engineError
                ? 'error'
                : 'stop')
          : switch (c.boundary) {
              PlaybackBoundary.bufferingStart => 'buffering_start',
              PlaybackBoundary.bufferingEnd => 'buffering_end',
              PlaybackBoundary.speedChange => 'speed_change',
              _ => c.boundary.name,
            };
      final stopSequence = terminal && type != 'stop' ? sequence + 1 : sequence;
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
      await _database.customStatement(
        'INSERT INTO applied_command VALUES(?,?,?,?,?,?,?)',
        [
          c.commandId,
          hash,
          'sha256',
          1,
          1,
          DateTime.now().toUtc().millisecondsSinceEpoch,
          jsonEncode({
            'revision': revision,
            'sequence': stopSequence,
            'skipped': skipped,
            'completed': completed,
          }),
        ],
      );
      final endPosition = c.seekTargetMs ?? c.positionMs;
      final payload = {
        'engineState': c.playingAfter ? 'ready_playing' : 'inactive',
        'positionMs': endPosition,
        'from': c.positionMs,
        'to': c.seekTargetMs,
        if (c.seekReason != null) 'seekReason': c.seekReason,
        'reason': c.termination?.stored,
        'progress': ratio,
        'durationMs': duration,
        'evidence': completed
            ? (c.termination == PlaybackTermination.naturalEnd
                  ? 'natural_end'
                  : 'progress_threshold')
            : null,
        'oldSpeed': session.data['final_speed'],
        'newSpeed': c.newSpeed,
      };
      Future<void> event(
        String id,
        int seq,
        String eventType,
        int index,
      ) => _database.customStatement(
        'INSERT INTO playback_event(event_id,session_id,sequence,type,occurred_at_utc_ms,clock_epoch,monotonic_ms,position_ms,event_version,codec_version,payload_version,payload_json,command_id,command_event_index) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          id,
          c.sessionId,
          seq,
          eventType,
          c.utcMs,
          c.clockEpoch,
          c.monotonicMs,
          endPosition,
          1,
          1,
          1,
          jsonEncode(payload),
          c.commandId,
          index,
        ],
      );
      await event(c.eventId, sequence, type, 0);
      if (stopSequence != sequence) {
        await event('${c.eventId}:stop', stopSequence, 'stop', 1);
      }
      if (wasPlaying) {
        final startPosition = previous.read<int>('position_ms');
        final startUtc = previous.read<int>('occurred_at_utc_ms');
        final wall = c.monotonicMs - previous.read<int>('monotonic_ms');
        final media = c.positionMs - startPosition;
        final speed = session.read<double>('final_speed');
        if (media < 0 || c.utcMs < startUtc || media > wall * speed + 1000) {
          throw StateError(
            'Seek or engine discontinuity cannot be an effective interval',
          );
        }
        if (wall > 0) {
          await _database.customStatement(
            'INSERT INTO playback_interval VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
            [
              '${c.eventId}:interval',
              c.sessionId,
              session.data['media_id'],
              session.data['mode'],
              session.data['final_variant_id'],
              lastSequence,
              sequence,
              startUtc,
              c.utcMs,
              c.clockEpoch,
              wall,
              media,
              startPosition,
              c.positionMs,
              speed,
              'observed',
            ],
          );
        }
      }
      final intervals = await _database
          .customSelect(
            'SELECT wall_ms,media_ms,start_position_ms,end_position_ms FROM playback_interval WHERE session_id=?',
            variables: [Variable(c.sessionId)],
          )
          .get();
      final wall = intervals.fold<int>(0, (n, r) => n + r.read<int>('wall_ms'));
      final media = intervals.fold<int>(
        0,
        (n, r) => n + r.read<int>('media_ms'),
      );
      final coverage = playbackCoverage(
        intervals
            .map(
              (r) => (
                r.read<int>('start_position_ms'),
                r.read<int>('end_position_ms'),
              ),
            )
            .toList(),
        durationMs: duration,
      );
      final valid =
          wall >= 20000 ||
          (c.termination == PlaybackTermination.naturalEnd &&
              duration != null &&
              duration < 20000 &&
              wall >= 3000);
      final maxPosition = (session.data['max_position_ms'] as int?) ?? 0;
      await _database.customStatement(
        'UPDATE playback_session SET last_sequence=?,final_position_ms=?,max_position_ms=?,final_speed=?,wall_ms=?,media_ms=?,coverage_ms=?,completion_ratio=?,progress_ratio=?,valid_play=?,completed=?,skipped=?,status=?,ended_at_utc_ms=?,termination_reason=? WHERE session_id=?',
        [
          stopSequence,
          endPosition,
          c.positionMs > maxPosition ? c.positionMs : maxPosition,
          c.newSpeed ?? session.data['final_speed'],
          wall,
          media,
          coverage,
          duration == null ? null : (coverage / duration).clamp(0.0, 1.0),
          ratio,
          valid ? 1 : 0,
          completed ? 1 : 0,
          skipped ? 1 : 0,
          terminal
              ? (c.termination == PlaybackTermination.processLost
                    ? 'interrupted'
                    : 'closed')
              : 'open',
          terminal ? c.utcMs : null,
          terminal ? c.termination!.stored : null,
          c.sessionId,
        ],
      );
      await _refreshAggregate(
        session.read<String>('media_id'),
        session.read<String>('mode'),
      );
      await faultInjector?.call(PlaybackFaultPoint.beforeCommit);
      changed = true;
      return PlaybackBoundaryResult(
        revision: revision,
        sequence: stopSequence,
        skipped: skipped,
        completed: completed,
      );
    });
    if (changed) {
      _revisions.add(result.revision);
      await faultInjector?.call(PlaybackFaultPoint.afterCommit);
    }
    return result;
  }
}
