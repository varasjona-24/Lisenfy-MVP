import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart' as aud;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../config/api_config.dart';
import '../controllers/theme_controller.dart';
import '../models/media_item.dart';

enum PlaybackState { stopped, loading, playing, paused }

class AudioService extends GetxService {
  static const MethodChannel _widgetChannel = MethodChannel(
    'listenfy/player_widget',
  );
  late final AndroidEqualizer? _androidEqualizer = Platform.isAndroid
      ? AndroidEqualizer()
      : null;
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: _androidEqualizer == null
        ? null
        : AudioPipeline(androidAudioEffects: [_androidEqualizer]),
  );
  final GetStorage _storage = GetStorage();

  static const _lastItemKey = 'audio_last_item';
  static const _lastVariantKey = 'audio_last_variant';
  static const _shuffleEnabledKey = 'audio_shuffle_enabled';
  static const _speedKey = 'audio_speed';
  static const _crossfadeSecondsKey = 'audio_crossfade_seconds';
  static const _sessionQueueItemsKey = 'audio_session_queue_items';
  static const _sessionQueueVariantsKey = 'audio_session_queue_variants';
  static const _sessionIndexKey = 'audio_session_index';
  static const _sessionPositionMsKey = 'audio_session_position_ms';
  static const _sessionWasPlayingKey = 'audio_session_was_playing';
  static const _resumePositionsKey = 'audio_resume_positions';
  static const _resumePromptThreshold = Duration(seconds: 5);
  static const _resumeNearEndThreshold = Duration(seconds: 10);

  final Rx<PlaybackState> state = PlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool miniPlayerDismissed = false.obs;
  final RxBool isPrivatePlaybackSession = false.obs;
  final RxDouble speed = 1.0.obs;
  final RxDouble volume = 1.0.obs;
  final RxInt crossfadeSeconds = 0.obs;
  final Rx<Duration> _position = Duration.zero.obs;

  final Rxn<MediaItem> currentItem = Rxn<MediaItem>();
  final Rxn<MediaVariant> currentVariant = Rxn<MediaVariant>();

  bool _keepLastItem = false;
  bool get keepLastItem => _keepLastItem;

  dynamic _handler;
  List<MediaItem> _queueItems = <MediaItem>[];
  List<MediaVariant> _queueVariants = <MediaVariant>[];
  List<MediaItem> _linearItems = <MediaItem>[];
  List<MediaVariant> _linearVariants = <MediaVariant>[];
  int _activeIndex = 0;
  int _queueRevision = 0;
  int _lastHandlerQueueRevision = -1;
  bool _shuffleEnabled = false;
  bool get shuffleEnabled => _shuffleEnabled;
  DateTime _lastSessionPersistAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHomeWidgetUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _positionOverrideUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _positionOverride = Duration.zero;
  bool _nextHandlerStopShouldHardStop = false;
  bool _hiddenSessionSnapshotPreserved = false;
  int _privatePlaybackSessionDepth = 0;
  Timer? _lastItemPersistTimer;
  Timer? _homeWidgetUpdateTimer;
  MediaItem? _pendingLastItem;
  MediaVariant? _pendingLastVariant;
  String _lastHomeWidgetSignature = '';

  void _showMiniPlayerForPlayback() {
    _hiddenSessionSnapshotPreserved = false;
    if (miniPlayerDismissed.value) {
      miniPlayerDismissed.value = false;
    }
  }

  bool get eqSupported => Platform.isAndroid && _androidEqualizer != null;
  int? get androidAudioSessionId => _player.androidAudioSessionId;
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  Stream<Duration> get positionStream => _position.stream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  Duration get currentPosition => _position.value;
  Duration? get currentDuration => _player.duration;

  bool get hasSourceLoaded => _player.processingState != ProcessingState.idle;
  bool get isInPrivatePlaybackSession => isPrivatePlaybackSession.value;
  List<MediaItem> get queueItems => List<MediaItem>.from(_queueItems);
  int get queueLength => _queueItems.length;
  int get queueRevision => _queueRevision;
  int get currentQueueIndex {
    final idx = _player.currentIndex ?? _activeIndex;
    if (idx < 0 || idx >= _queueItems.length) return 0;
    return idx;
  }

  void beginPrivatePlaybackSession() {
    _privatePlaybackSessionDepth += 1;
    if (!isPrivatePlaybackSession.value) {
      isPrivatePlaybackSession.value = true;
    }
  }

  void endPrivatePlaybackSession() {
    if (_privatePlaybackSessionDepth > 0) {
      _privatePlaybackSessionDepth -= 1;
    }
    if (_privatePlaybackSessionDepth == 0 && isPrivatePlaybackSession.value) {
      isPrivatePlaybackSession.value = false;
    }
  }

  void applyUpdatedMediaItem(MediaItem updatedItem) {
    var changed = false;

    List<MediaItem> replaceIn(List<MediaItem> items) {
      return items
          .map((item) {
            if (!_sameItem(item, updatedItem)) return item;
            changed = true;
            return updatedItem;
          })
          .toList(growable: false);
    }

    _queueItems = replaceIn(_queueItems);
    _linearItems = replaceIn(_linearItems);

    final current = currentItem.value;
    if (current != null && _sameItem(current, updatedItem)) {
      currentItem.value = updatedItem;
      final variant = currentVariant.value;
      if (variant != null) {
        _persistLastItem(updatedItem, variant);
      }
      changed = true;
    }

    if (!changed) return;
    _markQueueChanged();
    _persistSessionSnapshot();
    _notifyHandler();
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _shuffleEnabled = _storage.read<bool>(_shuffleEnabledKey) ?? false;
    _storage.remove('audio_resume_prompt_pending');
    final storedSpeed = _storage.read<double>(_speedKey);
    if (storedSpeed != null && storedSpeed > 0) {
      speed.value = storedSpeed;
      await _player.setSpeed(storedSpeed);
    }
    final storedCrossfade = _storage.read<int>(_crossfadeSecondsKey) ?? 0;
    crossfadeSeconds.value = storedCrossfade.clamp(0, 12);
    _restoreLastItem();

    _player.playerStateStream.listen((ps) {
      final loading =
          ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering;
      isLoading.value = loading;
      isPlaying.value = ps.playing;

      if (loading) {
        state.value = PlaybackState.loading;
      } else if (ps.playing) {
        state.value = PlaybackState.playing;
      } else if (ps.processingState == ProcessingState.ready ||
          ps.processingState == ProcessingState.completed) {
        state.value = PlaybackState.paused;
      } else {
        state.value = PlaybackState.stopped;
      }

      _notifyHandler();
      _persistSessionPlaybackState(throttle: true);
    });

    _player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      if (idx < 0 || idx >= _queueItems.length) return;
      if (idx >= _queueVariants.length) return;

      final changedTrack = idx != _activeIndex;
      if (changedTrack) {
        _beginTrackPositionLifecycle(Duration.zero);
      }
      _activeIndex = idx;
      final item = _queueItems[idx];
      final variant = _queueVariants[idx];
      currentItem.value = item;
      currentVariant.value = variant;
      _persistLastItemSoon(item, variant);
      _keepLastItem = true;
      _notifyHandler();
      _persistSessionPlaybackState();
    });

    _player.positionStream.listen((position) {
      _publishPlayerPosition(position);
      _persistSessionPlaybackState(throttle: true);
    });

    await _restoreSessionIfAny();
  }

  @override
  void onClose() {
    _flushPendingLastItem();
    _lastItemPersistTimer?.cancel();
    _homeWidgetUpdateTimer?.cancel();
    if (!_hiddenSessionSnapshotPreserved) {
      _persistSessionSnapshot();
    }
    _player.dispose();
    super.onClose();
  }

  void attachHandler(dynamic handler) {
    _handler = handler;
    _lastHandlerQueueRevision = -1;
    _notifyHandler();
  }

  void _publishPosition(Duration position) {
    if (_position.value == position) return;
    _position.value = position;
  }

  void _beginTrackPositionLifecycle(Duration initialPosition) {
    _positionOverride = initialPosition;
    _positionOverrideUntil = DateTime.now().add(
      const Duration(milliseconds: 1200),
    );
    _publishPosition(initialPosition);
  }

  void _beginSeekPositionLifecycle(Duration position) {
    _positionOverride = position;
    _positionOverrideUntil = DateTime.now().add(
      const Duration(milliseconds: 450),
    );
    _publishPosition(position);
  }

  void _publishPlayerPosition(Duration rawPosition) {
    if (DateTime.now().isBefore(_positionOverrideUntil)) {
      _publishPosition(_positionOverride);
      return;
    }
    _publishPosition(rawPosition);
  }

  aud.MediaItem buildBackgroundItem(
    MediaItem item, {
    int? overrideDurationSeconds,
  }) {
    final sec = overrideDurationSeconds ?? item.effectiveDurationSeconds;
    return aud.MediaItem(
      id: item.id,
      title: item.title,
      artist: item.displaySubtitle.isEmpty ? null : item.displaySubtitle,
      duration: (sec != null && sec > 0) ? Duration(seconds: sec) : null,
      artUri: _resolveArtUri(item),
    );
  }

  Uri? _resolveArtUri(MediaItem item) {
    final local = item.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      return Uri.file(local);
    }

    final remote = item.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) {
      return Uri.tryParse(remote);
    }

    return null;
  }

  bool isSameTrack(MediaItem item, MediaVariant variant) {
    return currentItem.value?.id == item.id &&
        currentVariant.value?.sameIdentityAs(variant) == true;
  }

  Future<void> play(
    MediaItem item,
    MediaVariant variant, {
    bool autoPlay = true,
    List<MediaItem>? queue,
    int? queueIndex,
    bool forceReload = false,
    Duration initialPosition = Duration.zero,
  }) async {
    _showMiniPlayerForPlayback();

    final incomingQueue = queue;
    if (forceReload &&
        hasSourceLoaded &&
        _queueItems.isNotEmpty &&
        incomingQueue != null &&
        incomingQueue.isNotEmpty &&
        _sameQueueById(incomingQueue, _queueItems)) {
      final target = (queueIndex ?? 0).clamp(0, _queueItems.length - 1).toInt();
      if (_sameItem(_queueItems[target], item) &&
          currentVariant.value?.sameIdentityAs(variant) != true) {
        await _reloadVariantInCurrentQueueFromStart(
          targetIndex: target,
          selectedItem: item,
          selectedVariant: variant,
          autoPlay: autoPlay,
        );
        return;
      }
    }

    if (hasSourceLoaded &&
        _queueItems.isNotEmpty &&
        incomingQueue != null &&
        incomingQueue.isNotEmpty &&
        _sameQueueById(incomingQueue, _queueItems)) {
      final target = (queueIndex ?? 0).clamp(0, _queueItems.length - 1).toInt();
      final sameLoadedTrack =
          target == currentQueueIndex &&
          currentVariant.value?.sameIdentityAs(variant) == true;
      if (sameLoadedTrack) {
        if (forceReload || initialPosition > Duration.zero) {
          await seek(initialPosition);
        }
        if (autoPlay) await _player.play();
        return;
      }
      await _transitionToIndex(
        target,
        autoPlay: autoPlay,
        initialPosition: initialPosition,
      );
      return;
    }

    if (!forceReload &&
        isSameTrack(item, variant) &&
        hasSourceLoaded &&
        _queueItems.isNotEmpty) {
      if (autoPlay) await _player.play();
      return;
    }

    isLoading.value = true;
    state.value = PlaybackState.loading;

    try {
      final built = _buildQueue(
        selectedItem: item,
        selectedVariant: variant,
        queue: queue,
        queueIndex: queueIndex,
      );

      _linearItems = List<MediaItem>.from(built.items);
      _linearVariants = List<MediaVariant>.from(built.variants);

      if (_shuffleEnabled && _linearItems.length > 1) {
        final shuffled = _buildShuffledIndices(
          _linearItems.length,
          startAt: built.index,
        );
        _assignActiveQueueFromIndices(shuffled);
        _activeIndex = 0;
      } else {
        _queueItems = List<MediaItem>.from(_linearItems);
        _queueVariants = List<MediaVariant>.from(_linearVariants);
        _activeIndex = built.index;
      }
      _markQueueChanged();

      final sources = <AudioSource>[];
      for (var i = 0; i < _queueItems.length; i++) {
        sources.add(
          AudioSource.uri(
            _resolvePlayableUri(_queueItems[i], _queueVariants[i]),
          ),
        );
      }
      _beginTrackPositionLifecycle(initialPosition);
      await _player.setAudioSources(
        sources,
        initialIndex: _activeIndex,
        initialPosition: initialPosition,
      );

      currentItem.value = _queueItems[_activeIndex];
      currentVariant.value = _queueVariants[_activeIndex];
      _persistLastItem(_queueItems[_activeIndex], _queueVariants[_activeIndex]);
      _keepLastItem = true;
      if (autoPlay) {
        await _player.play();
      } else {
        await _player.pause();
      }
      _persistSessionSnapshot();
      _notifyHandler();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _reloadVariantInCurrentQueueFromStart({
    required int targetIndex,
    required MediaItem selectedItem,
    required MediaVariant selectedVariant,
    required bool autoPlay,
  }) async {
    if (targetIndex < 0 || targetIndex >= _queueItems.length) return;
    if (targetIndex >= _queueVariants.length) return;
    if (!selectedVariant.isValid) {
      throw Exception('Variante inválida para reproducir.');
    }

    isLoading.value = true;
    state.value = PlaybackState.loading;

    try {
      final nextQueueItems = List<MediaItem>.from(_queueItems);
      final nextQueueVariants = List<MediaVariant>.from(_queueVariants);
      nextQueueItems[targetIndex] = selectedItem;
      nextQueueVariants[targetIndex] = selectedVariant;

      final sources = <AudioSource>[];
      for (var i = 0; i < nextQueueItems.length; i++) {
        sources.add(
          AudioSource.uri(
            _resolvePlayableUri(nextQueueItems[i], nextQueueVariants[i]),
          ),
        );
      }

      _beginTrackPositionLifecycle(Duration.zero);
      await _player.setAudioSources(
        sources,
        initialIndex: targetIndex,
        initialPosition: Duration.zero,
      );

      _queueItems = nextQueueItems;
      _queueVariants = nextQueueVariants;
      _activeIndex = targetIndex;
      _markQueueChanged();

      for (var i = 0; i < _linearItems.length; i++) {
        if (_sameItem(_linearItems[i], selectedItem)) {
          _linearItems[i] = selectedItem;
          _linearVariants[i] = selectedVariant;
        }
      }

      currentItem.value = selectedItem;
      currentVariant.value = selectedVariant;
      _persistLastItem(selectedItem, selectedVariant);
      _keepLastItem = true;

      if (autoPlay) {
        await _player.play();
      } else {
        await _player.pause();
      }

      _notifyHandler();
      _persistSessionSnapshot();
    } finally {
      isLoading.value = false;
    }
  }

  Uri _resolvePlayableUri(MediaItem item, MediaVariant variant) {
    final local = variant.localPath?.trim();
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (!f.existsSync()) {
        throw Exception('Archivo no encontrado: $local');
      }
      return Uri.file(local);
    }

    final fileName = variant.fileName.trim();
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return Uri.parse(fileName);
    }

    if (item.playableUrl.trim().isNotEmpty) {
      return Uri.parse(item.playableUrl.trim());
    }

    final kind = variant.kind == MediaVariantKind.video ? 'video' : 'audio';
    final fileId = item.fileId.trim();
    final format = variant.format.trim();
    if (fileId.isEmpty || format.isEmpty) {
      throw Exception('No hay URL remota disponible para reproducir.');
    }
    return Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/media/file/$fileId/$kind/$format',
    );
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (hasSourceLoaded) {
      _showMiniPlayerForPlayback();
      await _player.play();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> pauseAndHideMiniPlayer() async {
    miniPlayerDismissed.value = true;
    if (hasSourceLoaded && _player.playing) {
      await _player.pause();
    }
    isPlaying.value = false;
    if (hasSourceLoaded) {
      state.value = PlaybackState.paused;
    }
    _notifyHandler();
    _persistSessionSnapshot();
  }

  Future<void> resume() async {
    if (!hasSourceLoaded) return;
    _showMiniPlayerForPlayback();
    await _player.play();
  }

  Future<void> stop() async {
    _hiddenSessionSnapshotPreserved = false;
    _clearPendingLastItem();
    await _player.stop();
    _publishPosition(Duration.zero);
    isPlaying.value = false;
    isLoading.value = false;
    state.value = PlaybackState.stopped;
    currentItem.value = null;
    currentVariant.value = null;
    _queueItems = <MediaItem>[];
    _queueVariants = <MediaVariant>[];
    _linearItems = <MediaItem>[];
    _linearVariants = <MediaVariant>[];
    _activeIndex = 0;
    _markQueueChanged();
    _keepLastItem = false;
    _clearSessionSnapshot();
    _notifyHandler();
  }

  Future<void> stopAndHidePreservingSession() async {
    final shouldPersist = hasSourceLoaded && _player.playing;

    miniPlayerDismissed.value = true;
    isPlaying.value = false;
    isLoading.value = false;
    state.value = PlaybackState.stopped;
    _keepLastItem = false;
    _notifyHandler();

    await Future<void>.delayed(Duration.zero);
    if (shouldPersist) {
      _persistSessionSnapshot();
      _hiddenSessionSnapshotPreserved = true;
    } else {
      _clearSessionSnapshot();
      _storage.remove(_lastItemKey);
      _storage.remove(_lastVariantKey);
      _clearPendingLastItem();
      _hiddenSessionSnapshotPreserved = false;
      currentItem.value = null;
      currentVariant.value = null;
      _queueItems = <MediaItem>[];
      _queueVariants = <MediaVariant>[];
      _linearItems = <MediaItem>[];
      _linearVariants = <MediaVariant>[];
      _activeIndex = 0;
      _markQueueChanged();
    }
    await _player.stop();
    _publishPosition(Duration.zero);
  }

  void persistCurrentTrackResumePositionNow() {
    final item = currentItem.value;
    if (item == null || !hasSourceLoaded) return;

    persistTrackResumePosition(
      item: item,
      position: currentPosition,
      duration:
          currentDuration ??
          Duration(seconds: item.effectiveDurationSeconds ?? 0),
    );
  }

  void persistTrackResumePosition({
    required MediaItem item,
    required Duration position,
    required Duration duration,
  }) {
    final publicId = item.publicId.trim();
    final key = publicId.isNotEmpty ? publicId : item.id.trim();
    if (key.isEmpty) return;

    final raw = _storage.read<Map>(_resumePositionsKey);
    final next = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(raw);
    final nearEnd =
        duration > Duration.zero &&
        position >= duration - _resumeNearEndThreshold;

    if (position <= _resumePromptThreshold || nearEnd) {
      next.remove(key);
    } else {
      next[key] = position.inMilliseconds;
    }

    if (next.length > 300) {
      final overflow = next.length - 300;
      final keys = next.keys.take(overflow).toList(growable: false);
      for (final oldKey in keys) {
        next.remove(oldKey);
      }
    }

    _storage.write(_resumePositionsKey, next);
  }

  Future<void> seek(Duration position) async {
    if (!hasSourceLoaded) return;
    _beginSeekPositionLifecycle(position);
    await _player.seek(position);
    _beginSeekPositionLifecycle(position);
    _persistSessionSnapshot();
  }

  Future<void> next({bool withTransition = false}) async {
    if (_queueItems.isEmpty) return;
    final target = currentQueueIndex + 1;
    if (target < 0 || target >= _queueItems.length) return;
    if (withTransition) {
      await _transitionToIndex(target, autoPlay: true);
      return;
    }
    await _seekToIndex(target, autoPlay: true);
  }

  Future<void> previous({bool withTransition = false}) async {
    if (_queueItems.isEmpty) return;
    final target = currentQueueIndex - 1;
    if (target < 0 || target >= _queueItems.length) return;
    if (withTransition) {
      await _transitionToIndex(target, autoPlay: true);
      return;
    }
    await _seekToIndex(target, autoPlay: true);
  }

  Future<void> jumpToQueueIndex(
    int index, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (_queueItems.isEmpty) return;
    if (index < 0 || index >= _queueItems.length) return;
    await _transitionToIndex(
      index,
      autoPlay: true,
      initialPosition: initialPosition,
    );
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (_queueItems.isEmpty || _queueItems.length != _queueVariants.length) {
      return;
    }
    if (oldIndex < 0 || oldIndex >= _queueItems.length) return;
    if (newIndex < 0 || newIndex > _queueItems.length) return;

    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final wasPlaying = _player.playing;
    final pos = currentPosition;
    var activeIndex = currentQueueIndex;

    final movedItem = _queueItems.removeAt(oldIndex);
    final movedVariant = _queueVariants.removeAt(oldIndex);
    _queueItems.insert(newIndex, movedItem);
    _queueVariants.insert(newIndex, movedVariant);
    _markQueueChanged();

    if (activeIndex == oldIndex) {
      activeIndex = newIndex;
    } else if (oldIndex < newIndex &&
        activeIndex > oldIndex &&
        activeIndex <= newIndex) {
      activeIndex -= 1;
    } else if (oldIndex > newIndex &&
        activeIndex >= newIndex &&
        activeIndex < oldIndex) {
      activeIndex += 1;
    }
    _activeIndex = activeIndex.clamp(0, _queueItems.length - 1).toInt();

    if (!_shuffleEnabled) {
      _linearItems = List<MediaItem>.from(_queueItems);
      _linearVariants = List<MediaVariant>.from(_queueVariants);
    }

    final sources = <AudioSource>[];
    for (var i = 0; i < _queueItems.length; i++) {
      sources.add(
        AudioSource.uri(_resolvePlayableUri(_queueItems[i], _queueVariants[i])),
      );
    }

    _beginTrackPositionLifecycle(pos);
    await _player.setAudioSources(
      sources,
      initialIndex: _activeIndex,
      initialPosition: pos,
    );

    currentItem.value = _queueItems[_activeIndex];
    currentVariant.value = _queueVariants[_activeIndex];
    _persistLastItem(_queueItems[_activeIndex], _queueVariants[_activeIndex]);
    _keepLastItem = true;

    if (wasPlaying) {
      await _player.play();
    } else {
      await _player.pause();
    }
    _persistSessionSnapshot();
    _notifyHandler();
  }

  Future<void> setSpeed(double value) async {
    speed.value = value;
    _storage.write(_speedKey, value);
    await _player.setSpeed(value);
    _persistSessionSnapshot();
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    volume.value = clamped;
    await _player.setVolume(clamped);
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    final safe = seconds.clamp(0, 12).toInt();
    crossfadeSeconds.value = safe;
    _storage.write(_crossfadeSecondsKey, safe);
  }

  Future<void> _transitionToIndex(
    int target, {
    required bool autoPlay,
    Duration initialPosition = Duration.zero,
  }) async {
    final wasPlaying = _player.playing;
    final shouldFade = wasPlaying && crossfadeSeconds.value > 0;
    _beginTrackPositionLifecycle(initialPosition);
    if (shouldFade) {
      await _fadeTo(
        0.0,
        Duration(milliseconds: (crossfadeSeconds.value * 500).clamp(120, 6000)),
      );
    }

    await _player.seek(initialPosition, index: target);
    _activeIndex = target;

    if (autoPlay || wasPlaying) {
      await _player.play();
    } else {
      await _player.pause();
    }

    if (shouldFade) {
      await _player.setVolume(0.0);
      await _fadeTo(
        volume.value,
        Duration(milliseconds: (crossfadeSeconds.value * 500).clamp(120, 6000)),
      );
    }
  }

  Future<void> _seekToIndex(int target, {required bool autoPlay}) async {
    final wasPlaying = _player.playing;
    _beginTrackPositionLifecycle(Duration.zero);
    await _player.seek(Duration.zero, index: target);
    _activeIndex = target;
    if (autoPlay || wasPlaying) {
      await _player.play();
    } else {
      await _player.pause();
    }
    await _player.setVolume(volume.value);
  }

  Future<void> _fadeTo(double target, Duration duration) async {
    final start = _player.volume;
    final steps = 12;
    final diff = target - start;
    if (diff.abs() < 0.001) return;
    final stepMs = (duration.inMilliseconds / steps).round().clamp(8, 500);

    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final v = (start + diff * t).clamp(0.0, 1.0);
      await _player.setVolume(v);
      await Future.delayed(Duration(milliseconds: stepMs));
    }
  }

  Future<void> setLoopOff() => _player.setLoopMode(LoopMode.off);
  Future<void> setLoopOne() => _player.setLoopMode(LoopMode.one);
  Future<void> setShuffle(bool enabled) async {
    if (_shuffleEnabled == enabled) return;
    _shuffleEnabled = enabled;
    _storage.write(_shuffleEnabledKey, enabled);

    if (_linearItems.isEmpty || _linearVariants.isEmpty || !hasSourceLoaded) {
      return;
    }

    final playing = _player.playing;
    final pos = currentPosition;
    final current = currentItem.value;
    final currentV = currentVariant.value;

    final linearIndex = _findLinearIndex(current, currentV);
    if (_shuffleEnabled && _linearItems.length > 1) {
      final shuffled = _buildShuffledIndices(
        _linearItems.length,
        startAt: linearIndex,
      );
      _assignActiveQueueFromIndices(shuffled);
      _activeIndex = 0;
    } else {
      _queueItems = List<MediaItem>.from(_linearItems);
      _queueVariants = List<MediaVariant>.from(_linearVariants);
      _activeIndex = linearIndex.clamp(0, _queueItems.length - 1);
    }
    _markQueueChanged();

    final sources = <AudioSource>[];
    for (var i = 0; i < _queueItems.length; i++) {
      sources.add(
        AudioSource.uri(_resolvePlayableUri(_queueItems[i], _queueVariants[i])),
      );
    }

    _beginTrackPositionLifecycle(pos);
    await _player.setAudioSources(
      sources,
      initialIndex: _activeIndex,
      initialPosition: pos,
    );

    if (_queueItems.isNotEmpty) {
      currentItem.value = _queueItems[_activeIndex];
      currentVariant.value = _queueVariants[_activeIndex];
      _persistLastItem(_queueItems[_activeIndex], _queueVariants[_activeIndex]);
      _keepLastItem = true;
    }

    if (playing) {
      await _player.play();
    } else {
      await _player.pause();
    }
    _persistSessionSnapshot();
    _notifyHandler();
  }

  Future<AndroidEqualizerParameters?> getEqParameters() async {
    if (!eqSupported || _androidEqualizer == null) return null;
    if (_player.processingState == ProcessingState.idle) return null;

    try {
      return await _androidEqualizer.parameters.timeout(
        const Duration(seconds: 2),
      );
    } on TimeoutException {
      return null;
    } catch (e) {
      debugPrint('Equalizer getEqParameters error: $e');
      return null;
    }
  }

  Future<void> setEqEnabled(bool enabled) async {
    if (!eqSupported || _androidEqualizer == null) return;
    try {
      await _androidEqualizer.setEnabled(enabled);
    } catch (e) {
      debugPrint('Equalizer setEqEnabled error: $e');
    }
  }

  Future<void> setEqBandGain(int index, double gain) async {
    if (!eqSupported || _androidEqualizer == null) return;
    try {
      final params = await getEqParameters();
      if (params == null) return;
      if (index < 0 || index >= params.bands.length) return;
      await params.bands[index].setGain(gain);
    } catch (e) {
      debugPrint('Equalizer setEqBandGain error: $e');
    }
  }

  Future<void> stopAndDismissNotification() async {
    await stop();
    final handler = _handler;
    if (handler == null) return;
    try {
      _nextHandlerStopShouldHardStop = true;
      await handler.stop();
    } catch (_) {}
  }

  bool consumeNextHandlerStopShouldHardStop() {
    final out = _nextHandlerStopShouldHardStop;
    _nextHandlerStopShouldHardStop = false;
    return out;
  }

  void refreshNotification() => _notifyHandler();

  void clearLastItem() {
    _storage.remove(_lastItemKey);
    _storage.remove(_lastVariantKey);
    _clearPendingLastItem();
    _keepLastItem = false;
    _clearSessionSnapshot();
  }

  void _persistLastItem(MediaItem item, MediaVariant variant) {
    _clearPendingLastItem();
    _storage.write(_lastItemKey, item.toJson());
    _storage.write(_lastVariantKey, variant.toJson());
  }

  void _persistLastItemSoon(MediaItem item, MediaVariant variant) {
    _pendingLastItem = item;
    _pendingLastVariant = variant;
    _lastItemPersistTimer?.cancel();
    _lastItemPersistTimer = Timer(const Duration(milliseconds: 700), () {
      _flushPendingLastItem();
    });
  }

  void _flushPendingLastItem() {
    final item = _pendingLastItem;
    final variant = _pendingLastVariant;
    _clearPendingLastItem();
    if (item == null || variant == null) return;
    _persistLastItem(item, variant);
  }

  void _clearPendingLastItem() {
    _pendingLastItem = null;
    _pendingLastVariant = null;
    _lastItemPersistTimer?.cancel();
    _lastItemPersistTimer = null;
  }

  void _restoreLastItem() {
    final rawItem = _storage.read<Map>(_lastItemKey);
    if (rawItem == null) return;

    try {
      currentItem.value = MediaItem.fromJson(
        Map<String, dynamic>.from(rawItem),
      );
      final rawVariant = _storage.read<Map>(_lastVariantKey);
      if (rawVariant != null) {
        currentVariant.value = MediaVariant.fromJson(
          Map<String, dynamic>.from(rawVariant),
        );
      }
      _keepLastItem = true;
      state.value = PlaybackState.paused;
    } catch (_) {}
  }

  Future<bool> _restoreSessionIfAny({bool? autoPlayOverride}) async {
    final rawItems = _storage.read<List>(_sessionQueueItemsKey);
    final rawVariants = _storage.read<List>(_sessionQueueVariantsKey);
    if (rawItems == null || rawVariants == null) return false;
    if (rawItems.isEmpty || rawVariants.isEmpty) return false;
    if (rawItems.length != rawVariants.length) {
      _clearSessionSnapshot();
      return false;
    }

    try {
      final restoredItems = <MediaItem>[];
      final restoredVariants = <MediaVariant>[];
      for (var i = 0; i < rawItems.length; i++) {
        final itemMap = rawItems[i];
        final variantMap = rawVariants[i];
        if (itemMap is! Map || variantMap is! Map) continue;

        final item = MediaItem.fromJson(Map<String, dynamic>.from(itemMap));
        final variant = MediaVariant.fromJson(
          Map<String, dynamic>.from(variantMap),
        );
        if (!variant.isValid) continue;

        restoredItems.add(item);
        restoredVariants.add(variant);
      }

      if (restoredItems.isEmpty ||
          restoredItems.length != restoredVariants.length) {
        _clearSessionSnapshot();
        return false;
      }

      _queueItems = restoredItems;
      _queueVariants = restoredVariants;
      _linearItems = List<MediaItem>.from(restoredItems);
      _linearVariants = List<MediaVariant>.from(restoredVariants);
      _markQueueChanged();

      final rawIndex = _storage.read<int>(_sessionIndexKey) ?? 0;
      _activeIndex = rawIndex.clamp(0, _queueItems.length - 1).toInt();
      final rawPositionMs = _storage.read<int>(_sessionPositionMsKey) ?? 0;
      final initialPos = Duration(
        milliseconds: rawPositionMs.clamp(0, 86400000),
      );
      final wasPlaying = _storage.read<bool>(_sessionWasPlayingKey) ?? false;

      final sources = <AudioSource>[];
      for (var i = 0; i < _queueItems.length; i++) {
        sources.add(
          AudioSource.uri(
            _resolvePlayableUri(_queueItems[i], _queueVariants[i]),
          ),
        );
      }

      _beginTrackPositionLifecycle(initialPos);
      await _player.setAudioSources(
        sources,
        initialIndex: _activeIndex,
        initialPosition: initialPos,
      );

      currentItem.value = _queueItems[_activeIndex];
      currentVariant.value = _queueVariants[_activeIndex];
      _persistLastItem(_queueItems[_activeIndex], _queueVariants[_activeIndex]);
      _keepLastItem = true;

      final shouldAutoPlay = autoPlayOverride ?? wasPlaying;
      if (shouldAutoPlay) {
        _showMiniPlayerForPlayback();
        await _player.play();
      } else {
        await _player.pause();
      }

      _notifyHandler();
      return true;
    } catch (_) {
      _clearSessionSnapshot();
      return false;
    }
  }

  Future<bool> restorePersistedSession({required bool autoPlay}) async {
    _hiddenSessionSnapshotPreserved = false;
    if (autoPlay) {
      _showMiniPlayerForPlayback();
    }
    return _restoreSessionIfAny(autoPlayOverride: autoPlay);
  }

  void _persistSessionSnapshot({bool throttle = false}) {
    if (_queueItems.isEmpty || _queueVariants.isEmpty) return;
    if (_queueItems.length != _queueVariants.length) return;

    if (throttle) {
      final now = DateTime.now();
      if (now.difference(_lastSessionPersistAt) < const Duration(seconds: 2)) {
        return;
      }
      _lastSessionPersistAt = now;
    }

    _storage.write(
      _sessionQueueItemsKey,
      _queueItems.map((e) => e.toJson()).toList(growable: false),
    );
    _storage.write(
      _sessionQueueVariantsKey,
      _queueVariants.map((e) => e.toJson()).toList(growable: false),
    );
    _storage.write(_sessionIndexKey, currentQueueIndex);
    _storage.write(_sessionPositionMsKey, currentPosition.inMilliseconds);
    _storage.write(_sessionWasPlayingKey, _player.playing);
  }

  void _persistSessionPlaybackState({bool throttle = false}) {
    if (_queueItems.isEmpty || _queueVariants.isEmpty) return;
    if (_queueItems.length != _queueVariants.length) return;

    if (throttle) {
      final now = DateTime.now();
      if (now.difference(_lastSessionPersistAt) < const Duration(seconds: 2)) {
        return;
      }
      _lastSessionPersistAt = now;
    }

    _storage.write(_sessionIndexKey, currentQueueIndex);
    _storage.write(_sessionPositionMsKey, currentPosition.inMilliseconds);
    _storage.write(_sessionWasPlayingKey, _player.playing);
  }

  void _clearSessionSnapshot() {
    _storage.remove(_sessionQueueItemsKey);
    _storage.remove(_sessionQueueVariantsKey);
    _storage.remove(_sessionIndexKey);
    _storage.remove(_sessionPositionMsKey);
    _storage.remove(_sessionWasPlayingKey);
  }

  void _notifyHandler() {
    final handler = _handler;
    if (handler == null) return;
    final item = currentItem.value;
    if (item != null) {
      final runtimeSec = _runtimeDurationSecondsForCurrent(item);
      handler.updateMediaItem(
        buildBackgroundItem(item, overrideDurationSeconds: runtimeSec),
      );
      if (_lastHandlerQueueRevision != _queueRevision) {
        if (_queueItems.isNotEmpty) {
          handler.updateQueue(_queueItems.map(buildBackgroundItem).toList());
        } else {
          handler.updateQueue([buildBackgroundItem(item)]);
        }
        _lastHandlerQueueRevision = _queueRevision;
      }
    }
    handler.updatePlayback(
      playing: isPlaying.value,
      buffering: isLoading.value,
      hasSourceLoaded: hasSourceLoaded,
      position: currentPosition,
      speed: speed.value,
      queueIndex: currentQueueIndex,
    );

    _scheduleHomeWidgetUpdate();
  }

  void _scheduleHomeWidgetUpdate() {
    if (!Platform.isAndroid) return;

    final item = currentItem.value;
    final signature = [
      item?.id ?? '',
      item?.title ?? '',
      item?.displaySubtitle ?? '',
      item?.thumbnailLocalPath ?? '',
      item?.thumbnail ?? '',
      isPlaying.value,
    ].join('|');
    if (signature == _lastHomeWidgetSignature) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastHomeWidgetUpdateAt);
    if (elapsed >= const Duration(milliseconds: 700) &&
        _homeWidgetUpdateTimer == null) {
      _lastHomeWidgetSignature = signature;
      _lastHomeWidgetUpdateAt = now;
      unawaited(_updateHomeWidget());
      return;
    }

    _homeWidgetUpdateTimer?.cancel();
    _homeWidgetUpdateTimer = Timer(const Duration(milliseconds: 450), () {
      _homeWidgetUpdateTimer = null;
      _lastHomeWidgetSignature = signature;
      _lastHomeWidgetUpdateAt = DateTime.now();
      unawaited(_updateHomeWidget());
    });
  }

  Future<void> _updateHomeWidget() async {
    if (!Platform.isAndroid) return;

    final item = currentItem.value;
    final title = item?.title.trim().isNotEmpty == true
        ? item!.title
        : 'Listenfy';
    final artist = item?.displaySubtitle ?? '';

    String artPath = '';
    final localThumb = item?.thumbnailLocalPath?.trim();
    if (localThumb != null && localThumb.isNotEmpty) {
      final file = File(localThumb);
      if (file.existsSync()) {
        artPath = file.path;
      }
    }

    Color barColor = const Color(0xFF1E2633);
    if (Get.isRegistered<ThemeController>()) {
      barColor = Get.find<ThemeController>().palette.value.primary;
    }
    final logoColor = barColor.computeLuminance() > 0.55
        ? Colors.black
        : Colors.white;

    try {
      await _widgetChannel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'artPath': artPath,
        'playing': isPlaying.value,
        'positionMs': currentPosition.inMilliseconds,
        'durationMs': (currentDuration ?? Duration.zero).inMilliseconds,
        'barColor': barColor.toARGB32(),
        'logoColor': logoColor.toARGB32(),
      });
    } catch (_) {}
  }

  int? _runtimeDurationSecondsForCurrent(MediaItem current) {
    if (_queueItems.isEmpty) return null;
    final idx = currentQueueIndex;
    if (idx < 0 || idx >= _queueItems.length) return null;
    final q = _queueItems[idx];
    final same =
        q.id == current.id ||
        (q.publicId.trim().isNotEmpty &&
            q.publicId.trim() == current.publicId.trim());
    if (!same) return null;

    final runtime = _player.duration;
    if (runtime == null || runtime <= Duration.zero) return null;
    return runtime.inSeconds;
  }

  _BuiltQueue _buildQueue({
    required MediaItem selectedItem,
    required MediaVariant selectedVariant,
    required List<MediaItem>? queue,
    required int? queueIndex,
  }) {
    if (!selectedVariant.isValid) {
      throw Exception('Variante inválida para reproducir.');
    }

    final source = (queue == null || queue.isEmpty)
        ? <MediaItem>[selectedItem]
        : queue;

    final outItems = <MediaItem>[];
    final outVariants = <MediaVariant>[];
    var start = 0;

    final useExplicit =
        queueIndex != null && queueIndex >= 0 && queueIndex < source.length;

    for (var i = 0; i < source.length; i++) {
      final qItem = source[i];
      final qVariant = _resolveQueueVariant(
        queueItem: qItem,
        selectedItem: selectedItem,
        selectedVariant: selectedVariant,
      );
      if (qVariant == null) continue;

      outItems.add(qItem);
      outVariants.add(qVariant);

      if (useExplicit && i == queueIndex) {
        start = outItems.length - 1;
      } else if (!useExplicit && _sameItem(qItem, selectedItem)) {
        start = outItems.length - 1;
      }
    }

    if (outItems.isEmpty) {
      outItems.add(selectedItem);
      outVariants.add(selectedVariant);
      start = 0;
    }

    if (start < 0 || start >= outItems.length) start = 0;

    return _BuiltQueue(items: outItems, variants: outVariants, index: start);
  }

  MediaVariant? _resolveQueueVariant({
    required MediaItem queueItem,
    required MediaItem selectedItem,
    required MediaVariant selectedVariant,
  }) {
    if (_sameItem(queueItem, selectedItem)) return selectedVariant;

    for (final v in queueItem.variants) {
      if (v.kind == MediaVariantKind.audio &&
          !v.isInstrumental &&
          !v.isSpatial8d &&
          v.isValid) {
        return v;
      }
    }
    for (final v in queueItem.variants) {
      if (v.kind == MediaVariantKind.audio && v.isValid) return v;
    }
    return null;
  }

  bool _sameItem(MediaItem a, MediaItem b) {
    if (a.id == b.id) return true;
    final ap = a.publicId.trim();
    final bp = b.publicId.trim();
    return ap.isNotEmpty && bp.isNotEmpty && ap == bp;
  }

  bool _sameQueueById(List<MediaItem> a, List<MediaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id == b[i].id) continue;
      final ap = a[i].publicId.trim();
      final bp = b[i].publicId.trim();
      if (ap.isEmpty || bp.isEmpty || ap != bp) return false;
    }
    return true;
  }

  int _findLinearIndex(MediaItem? item, MediaVariant? variant) {
    if (item == null || variant == null || _linearItems.isEmpty) return 0;
    for (var i = 0; i < _linearItems.length; i++) {
      final it = _linearItems[i];
      final v = _linearVariants[i];
      if (it.id == item.id && v.sameIdentityAs(variant)) {
        return i;
      }
      final pid = item.publicId.trim();
      if (pid.isNotEmpty && it.publicId.trim() == pid) {
        return i;
      }
    }
    return 0;
  }

  List<int> _buildShuffledIndices(int length, {required int startAt}) {
    final out = List<int>.generate(length, (i) => i);
    out.remove(startAt);
    out.shuffle(Random());
    out.insert(0, startAt);
    return out;
  }

  void _assignActiveQueueFromIndices(List<int> indices) {
    _queueItems = indices.map((i) => _linearItems[i]).toList();
    _queueVariants = indices.map((i) => _linearVariants[i]).toList();
  }

  void _markQueueChanged() {
    _queueRevision++;
  }
}

class _BuiltQueue {
  final List<MediaItem> items;
  final List<MediaVariant> variants;
  final int index;

  const _BuiltQueue({
    required this.items,
    required this.variants,
    required this.index,
  });
}
