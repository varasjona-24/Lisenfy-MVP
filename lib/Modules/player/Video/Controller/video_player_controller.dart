import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../app/models/media_item.dart';
import '../../../../app/services/video_service.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../settings/controller/playback_settings_controller.dart';

class VideoPlayerController extends GetxController {
  static const double _completedViewProgressThreshold = 0.90;
  static const double _resumeProgressThreshold = 0.05;
  static const _resumeEligibleDuration = Duration(seconds: 150);
  static const _trustedResumeWatchThreshold = Duration(seconds: 8);

  final VideoService videoService;
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final PlaybackSettingsController _settings =
      Get.find<PlaybackSettingsController>();
  final GetStorage _storage = GetStorage();
  final List<MediaItem> _initialQueue;
  final int initialIndex;

  final RxList<MediaItem> queue = <MediaItem>[].obs;
  final RxInt currentIndex = 0.obs;
  final RxBool isQueueOpen = false.obs;
  final Rxn<String> error = Rxn<String>();
  Worker? _positionWorker;
  Worker? _completedWorker;
  Worker? _queueWorker;
  Worker? _indexWorker;
  Worker? _progressWorker;
  double _sessionMaxProgress = 0;
  String _sessionTrackKey = '';
  String _completionLoggedTrackKey = '';
  int _trustedResumeWatchMs = 0;
  Duration _lastTrustedResumePosition = Duration.zero;
  int _lastTrustedResumeTick = 0;
  String _trustedResumeTrackKey = '';

  static const queueStorageKey = 'video_queue_items';
  static const queueIndexStorageKey = 'video_queue_index';
  static const resumePosStorageKey = 'video_resume_positions';
  static const resumeWatchStorageKey = 'video_resume_watch_ms';

  VideoPlayerController({
    required this.videoService,
    required List<MediaItem> queue,
    required this.initialIndex,
  }) : _initialQueue = List<MediaItem>.from(queue);

  static List<MediaItem> restorePersistedQueue({GetStorage? storage}) {
    final box = storage ?? GetStorage();
    final rawQueue = box.read<List>(queueStorageKey);
    if (rawQueue == null || rawQueue.isEmpty) return <MediaItem>[];

    try {
      return rawQueue
          .whereType<Map>()
          .map((m) => MediaItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      clearPersistedQueueSnapshot(storage: box);
      return <MediaItem>[];
    }
  }

  static int restorePersistedIndex({
    required int queueLength,
    GetStorage? storage,
  }) {
    if (queueLength <= 0) return 0;
    final box = storage ?? GetStorage();
    final rawIndex = box.read<int>(queueIndexStorageKey) ?? 0;
    return rawIndex.clamp(0, queueLength - 1).toInt();
  }

  static void clearPersistedQueueSnapshot({GetStorage? storage}) {
    final box = storage ?? GetStorage();
    box.remove(queueStorageKey);
    box.remove(queueIndexStorageKey);
  }

  // Delegación de streams al VideoService
  Rx<Duration> get position => videoService.position;
  Rx<Duration> get duration => videoService.duration;
  RxBool get isPlaying => videoService.isPlaying;
  Rx<VideoPlaybackState> get state => videoService.state;

  vp.VideoPlayerController? get playerController =>
      videoService.playerController;

  @override
  void onInit() {
    super.onInit();

    queue.assignAll(_initialQueue);
    if (queue.isEmpty) {
      currentIndex.value = 0;
      clearPersistedQueueSnapshot(storage: _storage);
    } else {
      final safeIndex = initialIndex.clamp(0, queue.length - 1).toInt();
      currentIndex.value = safeIndex;
      _persistQueue();
    }

    _positionWorker = debounce<Duration>(
      position,
      (p) => _persistPosition(p),
      time: const Duration(seconds: 2),
    );
    _progressWorker = ever<Duration>(position, (_) {
      _captureTrustedResumeWatch();
      _captureSessionProgress();
      unawaited(_recordCompletionIfThresholdReached());
    });

    _completedWorker = ever<int>(videoService.completedTick, (_) async {
      await _recordSessionForCurrent(
        markCompleted: true,
        forceProgress: 1.0,
        resetSessionAfterRecord: true,
      );
      if (!_settings.autoPlayNext.value) return;
      await next(recordSkip: false);
    });
    _queueWorker = ever<List<MediaItem>>(queue, (_) => _persistQueue());
    _indexWorker = ever<int>(currentIndex, (_) => _persistQueue());
  }

  @override
  void onReady() {
    super.onReady();
    // Evita actualizaciones de Rx durante el build inicial.
    Future.microtask(_playCurrent);
  }

  // ===========================================================================
  // STATE / GETTERS
  // ===========================================================================

  MediaItem? get currentItemOrNull {
    if (queue.isEmpty) return null;
    final i = currentIndex.value;
    if (i < 0 || i >= queue.length) return null;
    return queue[i];
  }

  MediaItem get currentItem {
    final item = currentItemOrNull;
    if (item == null) throw StateError('currentItem is null');
    return item;
  }

  /// Lógica para seleccionar la variante de video preferida
  /// Prioridad:
  /// 1) video local con localPath válido
  /// 2) mp4 remoto
  /// 3) cualquier video válido
  MediaVariant? get currentVideoVariant {
    final item = currentItemOrNull;
    if (item == null) return null;
    return resolveVideoVariantFor(item);
  }

  MediaVariant? resolveVideoVariantFor(MediaItem item) {
    // 1️⃣ Buscar video local con localPath válido
    final localVideo = item.variants.firstWhereOrNull(
      (v) =>
          v.kind == MediaVariantKind.video &&
          v.localPath != null &&
          v.localPath!.trim().isNotEmpty &&
          v.isValid,
    );
    if (localVideo != null) return localVideo;

    // 2️⃣ Preferir mp4 formato si disponible (remoto)
    final mp4 = item.variants.firstWhereOrNull(
      (v) =>
          v.kind == MediaVariantKind.video &&
          v.format.toLowerCase() == 'mp4' &&
          v.isValid,
    );
    if (mp4 != null) return mp4;

    // 3️⃣ Buscar cualquier video válido
    final anyVideo = item.variants.firstWhereOrNull(
      (v) => v.kind == MediaVariantKind.video && v.isValid,
    );
    return anyVideo;
  }

  String? previewSourceFor(MediaItem item) {
    final variant = resolveVideoVariantFor(item);
    if (variant == null) return null;
    return videoService.resolveVideoSource(item, variant);
  }

  // ===========================================================================
  // PLAYBACK CONTROL
  // ===========================================================================

  Future<void> _playCurrent() async {
    error.value = null;

    final item = currentItemOrNull;
    final variant = currentVideoVariant;
    if (item == null || variant == null) {
      error.value = 'Este archivo está corrupto o no existe, selecciona otro.';
      return;
    }

    await _playItem(item, variant);
  }

  Future<void> _playItem(MediaItem item, MediaVariant variant) async {
    // Validar variante
    if (!variant.isValid) {
      error.value = 'Variante de video no válida.';
      return;
    }

    try {
      final sameTrackLoaded =
          videoService.hasSourceLoaded &&
          videoService.isSameVideo(item, variant);
      if (!sameTrackLoaded) {
        _resetTrustedResumeWatch(item);
      }
      await videoService.play(item, variant);
      if (!sameTrackLoaded) {
        await _resumeIfAny(item);
        await _trackPlay(item);
      }
      error.value = null;
    } catch (e) {
      error.value = 'Error al reproducir: $e';
    }
  }

  Future<void> _trackPlay(MediaItem item) async {
    await _applyPlaybackMetrics(item, incrementPlay: true);
  }

  Future<void> togglePlay() async {
    await videoService.toggle();
  }

  Future<void> seek(Duration value) async {
    await videoService.seek(value);
  }

  Future<void> next({bool recordSkip = true}) async {
    if (currentIndex.value < queue.length - 1) {
      if (recordSkip) {
        await _recordTransitionSkipIfNeeded();
      }
      currentIndex.value++;
      await _playCurrent();
    }
  }

  Future<void> previous({bool recordSkip = true}) async {
    if (currentIndex.value > 0) {
      if (recordSkip) {
        await _recordTransitionSkipIfNeeded();
      }
      currentIndex.value--;
      await _playCurrent();
    }
  }

  Future<void> playAt(int index, {bool recordSkip = true}) async {
    if (index < 0 || index >= queue.length) return;
    if (index == currentIndex.value) return;
    if (recordSkip) {
      await _recordTransitionSkipIfNeeded();
    }
    currentIndex.value = index;
    await _playCurrent();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex > queue.length) return;

    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);

    if (currentIndex.value == oldIndex) {
      currentIndex.value = newIndex;
    } else if (oldIndex < newIndex &&
        currentIndex.value > oldIndex &&
        currentIndex.value <= newIndex) {
      currentIndex.value -= 1;
    } else if (oldIndex > newIndex &&
        currentIndex.value >= newIndex &&
        currentIndex.value < oldIndex) {
      currentIndex.value += 1;
    }

    _persistQueue();
  }

  /// Reintentar cargar el mismo vídeo
  Future<void> retry() async {
    await _playCurrent();
  }

  void _persistQueue() {
    if (queue.isEmpty) {
      clearPersistedQueueSnapshot(storage: _storage);
      return;
    }
    _storage.write(
      queueStorageKey,
      queue.map((e) => e.toJson()).toList(growable: false),
    );
    _storage.write(queueIndexStorageKey, currentIndex.value);
  }

  void _persistPosition(Duration p) {
    final item = currentItemOrNull;
    if (item == null) return;
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    if (key.trim().isEmpty) return;

    final map = _storage.read<Map>(resumePosStorageKey);
    final watchMap = _storage.read<Map>(resumeWatchStorageKey);
    final next = <String, dynamic>{};
    if (map != null) {
      for (final entry in map.entries) {
        next[entry.key.toString()] = entry.value;
      }
    }
    final nextWatch = <String, dynamic>{};
    if (watchMap != null) {
      for (final entry in watchMap.entries) {
        nextWatch[entry.key.toString()] = entry.value;
      }
    }

    final total = duration.value > Duration.zero
        ? duration.value
        : Duration(seconds: item.effectiveDurationSeconds ?? 0);
    final nearEnd =
        total > Duration.zero && p >= total - const Duration(seconds: 5);
    final isEligible = total >= _resumeEligibleDuration;
    final progress = total > Duration.zero
        ? p.inMilliseconds / total.inMilliseconds
        : 0.0;
    final storedWatch = nextWatch[key];
    final storedWatchMs = storedWatch is num
        ? storedWatch.toInt()
        : int.tryParse('$storedWatch') ?? 0;
    final trustedWatchMs = math.max(storedWatchMs, _trustedResumeWatchMs);
    final hasTrustedWatch =
        trustedWatchMs >= _trustedResumeWatchThreshold.inMilliseconds;

    if (!isEligible ||
        progress <= _resumeProgressThreshold ||
        nearEnd ||
        !hasTrustedWatch) {
      next.remove(key);
      nextWatch.remove(key);
    } else {
      next[key] = p.inMilliseconds;
      nextWatch[key] = trustedWatchMs;
    }

    if (next.length > 300) {
      final overflow = next.length - 300;
      final keys = next.keys.take(overflow).toList(growable: false);
      for (final oldKey in keys) {
        next.remove(oldKey);
        nextWatch.remove(oldKey);
      }
    }

    _storage.write(resumePosStorageKey, next);
    _storage.write(resumeWatchStorageKey, nextWatch);
  }

  Future<void> _resumeIfAny(MediaItem item) async {
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    final map = _storage.read<Map>(resumePosStorageKey);
    if (map == null) return;
    final raw = map[key];
    if (raw is! int) return;
    final resume = Duration(milliseconds: raw);

    try {
      Duration d = videoService.duration.value;
      for (var i = 0; i < 10 && d == Duration.zero; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        d = videoService.duration.value;
      }
      if (d == Duration.zero) return;
      if (d < _resumeEligibleDuration) {
        _clearStoredResumePosition(item);
        return;
      }
      if (resume >= d - const Duration(seconds: 5)) {
        _clearStoredResumePosition(item);
        return;
      }
      final progress = resume.inMilliseconds / d.inMilliseconds;
      if (progress <= _resumeProgressThreshold) {
        _clearStoredResumePosition(item);
        return;
      }

      final shouldResume = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Continuar video'),
          content: Text(
            'Este video quedó en ${_fmtDuration(resume)}. ¿Quieres retomarlo desde ahí o reproducirlo desde el principio?',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Desde el principio'),
            ),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: Text('Retomar ${_fmtDuration(resume)}'),
            ),
          ],
        ),
        barrierDismissible: true,
      );

      if (shouldResume == true) {
        await videoService.seek(resume);
        return;
      }

      _clearStoredResumePosition(item);
      await videoService.seek(Duration.zero);
    } catch (_) {
      // ignore resume failures
    }
  }

  void _clearStoredResumePosition(MediaItem item) {
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    final raw = _storage.read<Map>(resumePosStorageKey);
    if (raw == null) return;
    final next = Map<String, dynamic>.from(raw);
    next.remove(key);
    _storage.write(resumePosStorageKey, next);
    final watchRaw = _storage.read<Map>(resumeWatchStorageKey);
    if (watchRaw == null) return;
    final nextWatch = Map<String, dynamic>.from(watchRaw);
    nextWatch.remove(key);
    _storage.write(resumeWatchStorageKey, nextWatch);
  }

  void _resetTrustedResumeWatch(MediaItem item) {
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    _trustedResumeTrackKey = key;
    _trustedResumeWatchMs = 0;
    _lastTrustedResumePosition = Duration.zero;
    _lastTrustedResumeTick = 0;
  }

  void _captureTrustedResumeWatch() {
    final item = currentItemOrNull;
    if (item == null) return;

    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    if (_trustedResumeTrackKey != key) {
      _resetTrustedResumeWatch(item);
    }

    final currentPosition = position.value;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!isPlaying.value) {
      _lastTrustedResumePosition = currentPosition;
      _lastTrustedResumeTick = now;
      return;
    }

    if (_lastTrustedResumeTick <= 0) {
      _lastTrustedResumePosition = currentPosition;
      _lastTrustedResumeTick = now;
      return;
    }

    final positionDelta =
        currentPosition.inMilliseconds -
        _lastTrustedResumePosition.inMilliseconds;
    final wallDelta = now - _lastTrustedResumeTick;
    final looksLikeNaturalPlayback =
        positionDelta > 0 &&
        positionDelta <= 3500 &&
        wallDelta > 0 &&
        wallDelta <= 5000;

    if (looksLikeNaturalPlayback) {
      _trustedResumeWatchMs += math.min(positionDelta, wallDelta);
    }

    _lastTrustedResumePosition = currentPosition;
    _lastTrustedResumeTick = now;
  }

  String _fmtDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    unawaited(_recordSessionForCurrent(resetSessionAfterRecord: true));
    _persistQueue();
    _persistPosition(position.value);
    _positionWorker?.dispose();
    _completedWorker?.dispose();
    _queueWorker?.dispose();
    _indexWorker?.dispose();
    _progressWorker?.dispose();
    super.onClose();
  }

  String _stableTrackKey(MediaItem item) {
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) return publicId;
    return item.id.trim();
  }

  double _currentProgressRatio() {
    final totalMs = duration.value.inMilliseconds;
    if (totalMs <= 0) {
      final sec = currentItemOrNull?.effectiveDurationSeconds ?? 0;
      if (sec <= 0) return 0;
      final fallbackTotalMs = sec * 1000;
      return (position.value.inMilliseconds / fallbackTotalMs).clamp(0.0, 1.0);
    }
    return (position.value.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  void _captureSessionProgress() {
    final item = currentItemOrNull;
    if (item == null) {
      _sessionTrackKey = '';
      _sessionMaxProgress = 0;
      return;
    }

    final key = _stableTrackKey(item);
    if (_sessionTrackKey != key) {
      _sessionTrackKey = key;
      _sessionMaxProgress = 0;
      _completionLoggedTrackKey = '';
    }

    final progress = _currentProgressRatio();
    if (progress > _sessionMaxProgress) {
      _sessionMaxProgress = progress;
    }
  }

  Future<void> _recordCompletionIfThresholdReached() async {
    final item = currentItemOrNull;
    if (item == null) return;

    final key = _stableTrackKey(item);
    if (_completionLoggedTrackKey == key) return;
    if (_sessionMaxProgress < _completedViewProgressThreshold) return;

    await _recordSessionForCurrent(
      markCompleted: true,
      forceProgress: 1.0,
      resetSessionAfterRecord: true,
    );
  }

  int _playbackSamples(MediaItem item) {
    final byEvents = item.fullListenCount + item.skipCount;
    final byPlays = item.playCount;
    var samples = byEvents > byPlays ? byEvents : byPlays;
    if (samples <= 0 && item.avgListenProgress > 0) {
      samples = 1;
    }
    return samples;
  }

  Future<void> _applyPlaybackMetrics(
    MediaItem seed, {
    bool incrementPlay = false,
    double? sessionProgress,
    bool markSkip = false,
    bool markCompleted = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final all = await _store.readAll();
    final publicId = seed.publicId.trim();
    final related = all
        .where((existing) {
          if (existing.id == seed.id) return true;
          return publicId.isNotEmpty && existing.publicId.trim() == publicId;
        })
        .toList(growable: false);
    final targets = related.isEmpty ? <MediaItem>[seed] : related;

    for (final existing in targets) {
      final prevAvg = existing.avgListenProgress.clamp(0, 1).toDouble();
      final prevSamples = _playbackSamples(existing);
      final hasSessionSample = sessionProgress != null;
      final sample = (sessionProgress ?? prevAvg).clamp(0.0, 1.0).toDouble();
      final nextSamples = hasSessionSample ? (prevSamples + 1) : prevSamples;
      final nextAvg = hasSessionSample && nextSamples > 0
          ? (((prevAvg * prevSamples) + sample) / nextSamples)
                .clamp(0.0, 1.0)
                .toDouble()
          : prevAvg;

      final updated = existing.copyWith(
        playCount: existing.playCount + (incrementPlay ? 1 : 0),
        lastPlayedAt: incrementPlay ? now : existing.lastPlayedAt,
        skipCount: existing.skipCount + ((markSkip && !markCompleted) ? 1 : 0),
        fullListenCount: existing.fullListenCount + (markCompleted ? 1 : 0),
        avgListenProgress: nextAvg,
        lastCompletedAt: markCompleted ? now : existing.lastCompletedAt,
      );
      await _store.upsert(updated);
    }
  }

  Future<void> _recordSessionForCurrent({
    bool markCompleted = false,
    bool forceSkip = false,
    double? forceProgress,
    bool resetSessionAfterRecord = false,
  }) async {
    final item = currentItemOrNull;
    if (item == null) return;

    final key = _stableTrackKey(item);
    if (markCompleted && _completionLoggedTrackKey == key) return;

    _captureSessionProgress();
    final progress = (forceProgress ?? _sessionMaxProgress).clamp(0.0, 1.0);
    final hasDuration =
        duration.value > Duration.zero ||
        ((currentItemOrNull?.effectiveDurationSeconds ?? 0) > 0);
    final shouldPersist =
        markCompleted ||
        forceSkip ||
        progress >= 0.03 ||
        (hasDuration && position.value >= const Duration(seconds: 3));
    if (!shouldPersist) return;

    await _applyPlaybackMetrics(
      item,
      sessionProgress: markCompleted ? 1.0 : progress,
      markSkip: forceSkip,
      markCompleted: markCompleted,
    );

    if (markCompleted) {
      _completionLoggedTrackKey = key;
    }

    if (resetSessionAfterRecord || markCompleted || forceSkip) {
      _sessionMaxProgress = 0;
    }
  }

  Future<void> _recordTransitionSkipIfNeeded() async {
    final item = currentItemOrNull;
    if (item == null) return;

    _captureSessionProgress();
    final progress = _sessionMaxProgress.clamp(0.0, 1.0).toDouble();
    final hasDuration =
        duration.value > Duration.zero ||
        ((currentItemOrNull?.effectiveDurationSeconds ?? 0) > 0);
    final hasProgress =
        progress >= 0.03 ||
        (hasDuration && position.value >= const Duration(seconds: 3));
    if (!hasProgress) return;

    final shouldMarkCompleted = progress >= _completedViewProgressThreshold;
    final shouldSkip = !shouldMarkCompleted;

    await _recordSessionForCurrent(
      markCompleted: shouldMarkCompleted,
      forceSkip: shouldSkip,
      forceProgress: shouldMarkCompleted ? 1.0 : progress,
      resetSessionAfterRecord: true,
    );
  }
}
