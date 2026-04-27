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
  static const _resumePromptPendingKey = 'audio_resume_prompt_pending';

  final Rx<PlaybackState> state = PlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;
  final RxDouble speed = 1.0.obs;
  final RxDouble volume = 1.0.obs;
  final RxInt crossfadeSeconds = 0.obs;

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
  bool _shuffleEnabled = false;
  bool get shuffleEnabled => _shuffleEnabled;
  DateTime _lastSessionPersistAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _nextHandlerStopShouldHardStop = false;
  bool _resumePromptPendingCache = false;

  bool get resumePromptPending => _resumePromptPendingCache;

  bool get eqSupported => Platform.isAndroid && _androidEqualizer != null;
  int? get androidAudioSessionId => _player.androidAudioSessionId;
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  Duration get currentPosition => _player.position;
  Duration? get currentDuration => _player.duration;

  bool get hasSourceLoaded => _player.processingState != ProcessingState.idle;
  List<MediaItem> get queueItems => List<MediaItem>.from(_queueItems);
  int get currentQueueIndex {
    final idx = _player.currentIndex ?? _activeIndex;
    if (idx < 0 || idx >= _queueItems.length) return 0;
    return idx;
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
    _persistSessionSnapshot();
    _notifyHandler();
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _shuffleEnabled = _storage.read<bool>(_shuffleEnabledKey) ?? false;
    _resumePromptPendingCache =
        _storage.read<bool>(_resumePromptPendingKey) ?? false;
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
      _persistSessionSnapshot(throttle: true);
    });

    _player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      if (idx < 0 || idx >= _queueItems.length) return;
      if (idx >= _queueVariants.length) return;

      _activeIndex = idx;
      final item = _queueItems[idx];
      final variant = _queueVariants[idx];
      currentItem.value = item;
      currentVariant.value = variant;
      _persistLastItem(item, variant);
      _keepLastItem = true;
      _notifyHandler();
      _persistSessionSnapshot();
    });

    _player.positionStream.listen((_) {
      _persistSessionSnapshot(throttle: true);
    });

    await _restoreSessionIfAny();
  }

  @override
  void onClose() {
    _persistSessionSnapshot();
    _player.dispose();
    super.onClose();
  }

  void attachHandler(dynamic handler) {
    _handler = handler;
    _notifyHandler();
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
    if (local != null && local.isNotEmpty) return Uri.file(local);
    final remote = item.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) return Uri.tryParse(remote);
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
  }) async {
    final incomingQueue = queue;
    if (!forceReload &&
        hasSourceLoaded &&
        _queueItems.isNotEmpty &&
        incomingQueue != null &&
        incomingQueue.isNotEmpty &&
        _sameQueueById(incomingQueue, _queueItems)) {
      final target = (queueIndex ?? 0).clamp(0, _queueItems.length - 1).toInt();
      await _transitionToIndex(target, autoPlay: autoPlay);
      return;
    }

    // Cambio de variante en la misma cola sin regenerar orden/shuffle.
    if (forceReload &&
        hasSourceLoaded &&
        _queueItems.isNotEmpty &&
        incomingQueue != null &&
        incomingQueue.isNotEmpty &&
        _sameQueueById(incomingQueue, _queueItems)) {
      final target = (queueIndex ?? 0).clamp(0, _queueItems.length - 1).toInt();
      if (_sameItem(_queueItems[target], item)) {
        await _reloadVariantInCurrentQueue(
          targetIndex: target,
          selectedVariant: variant,
          autoPlay: autoPlay,
        );
        return;
      }
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

      final sources = <AudioSource>[];
      for (var i = 0; i < _queueItems.length; i++) {
        sources.add(
          AudioSource.uri(
            _resolvePlayableUri(_queueItems[i], _queueVariants[i]),
          ),
        );
      }
      await _player.setAudioSources(sources, initialIndex: _activeIndex);

      currentItem.value = _queueItems[_activeIndex];
      currentVariant.value = _queueVariants[_activeIndex];
      _persistLastItem(_queueItems[_activeIndex], _queueVariants[_activeIndex]);
      _keepLastItem = true;
      if (autoPlay) {
        await _player.play();
      } else {
        await _player.pause();
      }
      _notifyHandler();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _reloadVariantInCurrentQueue({
    required int targetIndex,
    required MediaVariant selectedVariant,
    required bool autoPlay,
  }) async {
    if (targetIndex < 0 || targetIndex >= _queueItems.length) return;
    if (targetIndex >= _queueVariants.length) return;
    if (!selectedVariant.isValid) {
      throw Exception('Variante inválida para reproducir.');
    }

    final nextQueueVariants = List<MediaVariant>.from(_queueVariants);
    nextQueueVariants[targetIndex] = selectedVariant;
    final targetItem = _queueItems[targetIndex];
    final currentPosition = _player.position;

    isLoading.value = true;
    state.value = PlaybackState.loading;

    try {
      final sources = <AudioSource>[];
      for (var i = 0; i < _queueItems.length; i++) {
        sources.add(
          AudioSource.uri(
            _resolvePlayableUri(_queueItems[i], nextQueueVariants[i]),
          ),
        );
      }

      await _player.setAudioSources(
        sources,
        initialIndex: targetIndex,
        initialPosition: currentPosition,
      );

      _queueVariants = nextQueueVariants;
      _activeIndex = targetIndex;

      for (var i = 0; i < _linearItems.length; i++) {
        if (_sameItem(_linearItems[i], targetItem)) {
          _linearVariants[i] = selectedVariant;
        }
      }

      currentItem.value = _queueItems[targetIndex];
      currentVariant.value = _queueVariants[targetIndex];
      _persistLastItem(_queueItems[targetIndex], _queueVariants[targetIndex]);
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
      await _player.play();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() async {
    if (!hasSourceLoaded) return;
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
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
    _keepLastItem = false;
    _clearSessionSnapshot();
    _notifyHandler();
  }

  Future<void> stopFromNotificationClose() async {
    if (hasSourceLoaded) {
      _persistSessionSnapshot();
    }
    _resumePromptPendingCache = true;
    _storage.write(_resumePromptPendingKey, true);

    await _player.stop();
    isPlaying.value = false;
    isLoading.value = false;
    state.value = PlaybackState.stopped;
    _keepLastItem = currentItem.value != null;
    _notifyHandler();
  }

  Future<void> seek(Duration position) async {
    if (!hasSourceLoaded) return;
    await _player.seek(position);
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

  Future<void> jumpToQueueIndex(int index) async {
    if (_queueItems.isEmpty) return;
    if (index < 0 || index >= _queueItems.length) return;
    await _transitionToIndex(index, autoPlay: true);
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

  Future<void> _transitionToIndex(int target, {required bool autoPlay}) async {
    final wasPlaying = _player.playing;
    final shouldFade = wasPlaying && crossfadeSeconds.value > 0;
    if (shouldFade) {
      await _fadeTo(
        0.0,
        Duration(milliseconds: (crossfadeSeconds.value * 500).clamp(120, 6000)),
      );
    }

    await _player.seek(Duration.zero, index: target);
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
    final pos = _player.position;
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

    final sources = <AudioSource>[];
    for (var i = 0; i < _queueItems.length; i++) {
      sources.add(
        AudioSource.uri(_resolvePlayableUri(_queueItems[i], _queueVariants[i])),
      );
    }

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
    _keepLastItem = false;
    _clearSessionSnapshot();
  }

  void _persistLastItem(MediaItem item, MediaVariant variant) {
    _storage.write(_lastItemKey, item.toJson());
    _storage.write(_lastVariantKey, variant.toJson());
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
    final ok = await _restoreSessionIfAny(autoPlayOverride: autoPlay);
    if (ok) {
      _resumePromptPendingCache = false;
      _storage.write(_resumePromptPendingKey, false);
    }
    return ok;
  }

  Future<void> dismissResumePrompt({required bool discardSession}) async {
    _resumePromptPendingCache = false;
    _storage.write(_resumePromptPendingKey, false);
    if (discardSession) {
      _clearSessionSnapshot();
      clearLastItem();
      await stop();
    }
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
    _storage.write(_sessionPositionMsKey, _player.position.inMilliseconds);
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
      if (_queueItems.isNotEmpty) {
        handler.updateQueue(_queueItems.map(buildBackgroundItem).toList());
      } else {
        handler.updateQueue([buildBackgroundItem(item)]);
      }
    }
    handler.updatePlayback(
      playing: isPlaying.value,
      buffering: isLoading.value,
      hasSourceLoaded: hasSourceLoaded,
      position: _player.position,
      speed: speed.value,
    );

    _updateHomeWidget();
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
