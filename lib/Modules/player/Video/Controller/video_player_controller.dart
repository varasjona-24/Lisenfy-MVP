import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../app/models/media_item.dart';
import '../../../../app/services/video_service.dart';
import '../../../../app/data/playback/playback_boundary_command.dart';
import '../../../settings/controller/playback_settings_controller.dart';

class VideoPlayerController extends GetxController {
  static const double _resumeProgressThreshold = 0.05;
  static const _resumeEligibleDuration = Duration(seconds: 150);
  static const _trustedResumeWatchThreshold = Duration(seconds: 8);

  final VideoService videoService;
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
    });

    _completedWorker = ever<int>(videoService.completedTick, (_) async {
      await videoService.flushPlaybackHistory();
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

  Future<void> _playCurrent({
    PlaybackTermination reason = PlaybackTermination.manualSelection,
  }) async {
    error.value = null;

    final item = currentItemOrNull;
    final variant = currentVideoVariant;
    if (item == null || variant == null) {
      error.value = tr('player.video_corrupt');
      return;
    }

    await _playItem(item, variant, reason: reason);
  }

  Future<void> _playItem(
    MediaItem item,
    MediaVariant variant, {
    PlaybackTermination reason = PlaybackTermination.manualSelection,
  }) async {
    // Validar variante
    if (!variant.isValid) {
      error.value = tr('player.invalid_video_variant');
      return;
    }

    try {
      final sameTrackLoaded =
          videoService.hasSourceLoaded &&
          videoService.isSameVideo(item, variant);
      if (!sameTrackLoaded) {
        _resetTrustedResumeWatch(item);
      }
      await videoService.play(item, variant, replacementReason: reason);
      if (!sameTrackLoaded) {
        await _resumeIfAny(item);
        await videoService.flushPlaybackHistory();
      }
      error.value = null;
    } catch (e) {
      error.value = 'Error al reproducir: $e';
    }
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
        await videoService.flushPlaybackHistory();
      }
      currentIndex.value++;
      await _playCurrent(
        reason: recordSkip
            ? PlaybackTermination.manualNext
            : PlaybackTermination.naturalEnd,
      );
    }
  }

  Future<void> previous({bool recordSkip = true}) async {
    if (currentIndex.value > 0) {
      if (recordSkip) {
        await videoService.flushPlaybackHistory();
      }
      currentIndex.value--;
      await _playCurrent(
        reason: recordSkip
            ? PlaybackTermination.manualPrevious
            : PlaybackTermination.explicitStop,
      );
    }
  }

  Future<void> playAt(int index, {bool recordSkip = true}) async {
    if (index < 0 || index >= queue.length) return;
    if (index == currentIndex.value) return;
    if (recordSkip) {
      await videoService.flushPlaybackHistory();
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
          title: Text(tr('player.video.continue_title')),
          content: Text(
            tr(
              'player.video.continue_body',
            ).replaceFirst('{}', _fmtDuration(resume)),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(tr('player.video.start_btn')),
            ),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: Text(
                tr(
                  'player.video.continue_btn',
                ).replaceFirst('{}', _fmtDuration(resume)),
              ),
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
    unawaited(videoService.flushPlaybackHistory());
    _persistQueue();
    _persistPosition(position.value);
    _positionWorker?.dispose();
    _completedWorker?.dispose();
    _queueWorker?.dispose();
    _indexWorker?.dispose();
    _progressWorker?.dispose();
    super.onClose();
  }
}
