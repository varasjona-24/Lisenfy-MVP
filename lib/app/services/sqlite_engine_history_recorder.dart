import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../data/playback/playback_repository.dart';
import '../data/playback/playback_session_command.dart';
import '../data/playback/playback_boundary_command.dart';
import 'engine_history_recorder.dart';

/// Composition owns durable identity/variant mapping; never infer canonical IDs
/// from a title or pathname. Factory must return IDs for this actual source.
typedef EngineSessionFactory =
    Future<OpenPlaybackSession> Function(
      MediaItem item,
      MediaVariant variant,
      int utcMs,
      int monotonicMs,
      Duration position,
      Duration duration,
      double speed,
    );

class SqliteEngineHistoryRecorder implements EngineHistoryRecorder {
  SqliteEngineHistoryRecorder({
    required this.repository,
    required this.sessionFactory,
    required this.commandIdFactory,
    DateTime Function()? clock,
    Stopwatch? stopwatch,
    int Function()? monotonicClock,
  }) : _clock = clock ?? DateTime.now,
       _watch = stopwatch ?? (Stopwatch()..start()),
       _monotonicClock = monotonicClock;
  final PlaybackRepository repository;
  final EngineSessionFactory sessionFactory;
  final String Function() commandIdFactory;
  final DateTime Function() _clock;
  final Stopwatch _watch;
  final int Function()? _monotonicClock;
  Future<void> _tail = Future.value();
  Object? _failure;
  MediaItem? _selected;
  MediaVariant? _variant;
  OpenPlaybackSession? _active;
  int _sequence = 1;
  bool _playing = false, _buffering = false, _seeking = false;
  Duration _position = Duration.zero;
  double _speed = 1;
  int _utc = 0, _mono = 0, _lastCheckpoint = 0;
  PlaybackTermination? _intent;

  void _enqueue(Future<void> Function() work) {
    _tail = _tail.then((_) async {
      if (_failure != null) {
        return;
      }
      try {
        await work();
      } catch (error) {
        _failure = error;
        debugPrint('SQLite engine history stopped: $error');
      }
    });
  }

  @override
  void intent(PlaybackTermination reason) {
    _enqueue(() async {
      if (reason == PlaybackTermination.engineError ||
          reason == PlaybackTermination.sourceLost) {
        _intent = reason;
      } else {
        _intent ??= reason;
      }
    });
  }

  @override
  void select(
    MediaItem? item, {
    MediaVariant? variant,
    bool occurrenceChanged = false,
  }) {
    _enqueue(() async {
      final changed =
          occurrenceChanged ||
          _selected?.id != item?.id ||
          (_variant != null &&
              variant != null &&
              !_variant!.sameIdentityAs(variant));
      if (changed && _active != null) {
        await _boundary(
          PlaybackBoundary.stop,
          reason:
              _intent ??
              (item == null
                  ? PlaybackTermination.explicitStop
                  : PlaybackTermination.naturalEnd),
        );
      }
      _selected = item;
      _variant = variant;
      if (changed) {
        _intent = null;
      }
    });
  }

  @override
  void update({
    required Duration position,
    required Duration duration,
    required bool playing,
    double speed = 1,
    bool buffering = false,
    bool completed = false,
    bool looped = false,
  }) {
    final observedPosition = position;
    final utc = _clock().toUtc().millisecondsSinceEpoch,
        mono = _monotonicClock?.call() ?? _watch.elapsedMilliseconds;
    _enqueue(() async {
      if (_seeking || _selected == null || _variant == null) {
        return;
      }
      if (looped && _active != null) {
        await _boundary(
          PlaybackBoundary.stop,
          reason: PlaybackTermination.naturalEnd,
        );
      }
      if (_active == null) {
        if (!playing || completed || buffering) {
          return;
        }
        final command = await sessionFactory(
          _selected!,
          _variant!,
          utc,
          mono,
          position,
          duration,
          speed,
        );
        if (command.positionMs != position.inMilliseconds ||
            command.monotonicMs != mono ||
            command.startedAtUtcMs != utc ||
            command.speed != speed) {
          throw StateError(
            'Session factory must preserve observed engine timing',
          );
        }
        final actualMode = _variant!.kind == MediaVariantKind.audio
            ? PlaybackMode.audio
            : PlaybackMode.video;
        if (command.variant.mode != actualMode) {
          throw StateError('Session factory changed the actual engine mode');
        }
        await repository.openSession(command);
        _active = command;
        _sequence = 1;
        _playing = true;
        _buffering = false;
        _position = position;
        _speed = speed;
        _utc = utc;
        _mono = mono;
        _lastCheckpoint = mono;
        return;
      }
      // Player-state and position streams can report slightly different engine
      // estimates (including a small correction backwards). Keep a monotonic
      // anchor for that bounded jitter; real seeks still require explicit hooks.
      var trustedPosition = observedPosition;
      final backwardsMs = (_position - observedPosition).inMilliseconds;
      if (backwardsMs > 0 && backwardsMs <= 250) {
        trustedPosition = _position;
      }
      // Reject implicit position jumps. The explicit seek hook supplies destination.
      if (_playing &&
          (trustedPosition < _position ||
              (trustedPosition - _position).inMilliseconds >
                  (mono - _mono) * _speed + 1000)) {
        throw StateError(
          'Unreported seek/loop/discontinuity from engine: '
          'previous=${_position.inMilliseconds}ms observed=${observedPosition.inMilliseconds}ms '
          'elapsed=${mono - _mono}ms speed=$_speed',
        );
      }
      _position = trustedPosition;
      _utc = utc;
      _mono = mono;
      if (completed) {
        await _boundary(
          PlaybackBoundary.stop,
          reason: PlaybackTermination.naturalEnd,
        );
        return;
      }
      if (speed != _speed) {
        await _boundary(PlaybackBoundary.speedChange, newSpeed: speed);
        _speed = speed;
      }
      if (_playing && !playing) {
        await _boundary(
          buffering ? PlaybackBoundary.bufferingStart : PlaybackBoundary.pause,
        );
        _playing = false;
        _buffering = buffering;
      } else if (!_playing && playing) {
        await _boundary(
          _buffering ? PlaybackBoundary.bufferingEnd : PlaybackBoundary.resume,
        );
        _playing = true;
        _buffering = false;
      } else if (mono - _lastCheckpoint >= 5000) {
        await _boundary(PlaybackBoundary.checkpoint);
      }
    });
  }

  Future<void> _boundary(
    PlaybackBoundary type, {
    PlaybackTermination? reason,
    int? target,
    double? newSpeed,
  }) async {
    final active = _active;
    if (active == null) {
      return;
    }
    final id = commandIdFactory();
    final playingAfter = switch (type) {
      PlaybackBoundary.stop ||
      PlaybackBoundary.pause ||
      PlaybackBoundary.bufferingStart => false,
      PlaybackBoundary.resume || PlaybackBoundary.bufferingEnd => true,
      _ => _playing,
    };
    final result = await repository.recordBoundary(
      RecordPlaybackBoundary(
        commandId: id,
        sessionId: active.sessionId,
        eventId: id,
        boundary: type,
        utcMs: _utc,
        monotonicMs: _mono,
        clockEpoch: active.clockEpoch,
        positionMs: _position.inMilliseconds,
        playingAfter: playingAfter,
        intervalStartSequence: _playing ? _sequence : null,
        seekTargetMs: target,
        newSpeed: newSpeed,
        termination: reason,
      ),
    );
    _sequence = result.sequence;
    _lastCheckpoint = _mono;
    if (type == PlaybackBoundary.stop) {
      _active = null;
      _playing = false;
    }
    if (target != null) {
      _position = Duration(milliseconds: target);
    }
  }

  @override
  void beforeSeek([Duration? target]) {
    _enqueue(() async {
      if (target == null) {
        throw ArgumentError('SQLite seek requires destination');
      }
      if (_playing) {
        await _boundary(PlaybackBoundary.pause);
        _playing = false;
      }
      await _boundary(PlaybackBoundary.seek, target: target.inMilliseconds);
      _seeking = true;
    });
  }

  @override
  void afterSeek({bool playing = false}) {
    final utc = _clock().toUtc().millisecondsSinceEpoch;
    final mono = _monotonicClock?.call() ?? _watch.elapsedMilliseconds;
    _enqueue(() async {
      _seeking = false;
      _utc = utc;
      _mono = mono;
      if (playing && _active != null) {
        await _boundary(PlaybackBoundary.resume);
        _playing = true;
      }
    });
  }

  @override
  Future<void> flush() async {
    _enqueue(() async {
      await _boundary(PlaybackBoundary.checkpoint);
    });
    await _tail;
    if (_failure != null) {
      throw StateError('Engine history persistence stopped: $_failure');
    }
  }
}
