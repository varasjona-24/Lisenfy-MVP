import 'package:audio_service/audio_service.dart';

import 'audio_service.dart' as app;

class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final app.AudioService _audio;
  static const MediaControl closeControl = MediaControl(
    androidIcon: 'drawable/ic_close',
    label: 'Cerrar',
    action: MediaAction.stop,
  );

  AppAudioHandler(this._audio);

  Future<void> updatePlayback({
    required bool playing,
    required bool buffering,
    required bool hasSourceLoaded,
    required Duration position,
    required double speed,
    required int queueIndex,
  }) async {
    final processingState = buffering
        ? AudioProcessingState.buffering
        : (hasSourceLoaded
              ? AudioProcessingState.ready
              : AudioProcessingState.idle);

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          closeControl,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setSpeed,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        queueIndex: queueIndex,
        speed: speed,
      ),
    );
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    this.queue.add(queue);
  }

  @override
  Future<void> play() => _audio.resume();

  @override
  Future<void> pause() => _audio.pause();

  @override
  Future<void> stop() async {
    if (_audio.consumeNextHandlerStopShouldHardStop()) {
      await _audio.stop();
      await super.stop();
    } else {
      _audio.persistCurrentTrackResumePositionNow();
      await _audio.stopAndHidePreservingSession();
      // No llamamos super.stop() aquí para que el servicio pueda volver
      // a publicar notificación al reanudar desde la app.
    }
  }

  @override
  Future<void> seek(Duration position) => _audio.seek(position);

  @override
  Future<void> skipToNext() => _audio.next();

  @override
  Future<void> skipToPrevious() => _audio.previous();

  @override
  Future<void> setSpeed(double speed) => _audio.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (repeatMode == AudioServiceRepeatMode.one) {
      await _audio.setLoopOne();
    } else {
      await _audio.setLoopOff();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) {
    return _audio.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
  }

  @override
  Future<void> skipToQueueItem(int index) async {}

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {}
}
