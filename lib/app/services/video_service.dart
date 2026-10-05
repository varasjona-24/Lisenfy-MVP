import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:video_player/video_player.dart' as vp;

import '../models/media_item.dart';
import '../config/api_config.dart';
import '../../Modules/settings/controller/playback_settings_controller.dart';
import 'playback_history_recorder.dart';
import 'engine_history_recorder.dart';
import '../data/playback/playback_boundary_command.dart';
import '../data/local/local_library_store.dart';
import '../../Modules/recommendations/data/listening_event_store.dart';
import '../../Modules/recommendations/domain/recommendation_models.dart';

enum VideoPlaybackState { stopped, loading, playing, paused }

class VideoService extends GetxService with WidgetsBindingObserver {
  VideoService({EngineHistoryRecorder? historyRecorder})
    : _providedHistory = historyRecorder;
  final EngineHistoryRecorder? _providedHistory;
  late final EngineHistoryRecorder _history =
      _providedHistory ??
      PlaybackHistoryRecorder(
        events: Get.find<ListeningEventStore>(),
        library: Get.find<LocalLibraryStore>(),
        mode: RecommendationMode.video,
      );
  Future<void> flushPlaybackHistory() => _history.flush();
  final Rxn<Object> historyPersistenceFailure = Rxn<Object>();
  Future<void> _flushEngineHistory() async {
    try {
      await _history.flush();
    } catch (error) {
      historyPersistenceFailure.value = error;
      debugPrint('Video history persistence failed: $error');
    }
  }

  final GetStorage _storage = GetStorage();

  static const _lastItemKey = 'video_last_item';
  static const _lastVariantKey = 'video_last_variant';
  bool _keepLastItem = false;

  bool get keepLastItem => _keepLastItem;
  final Rx<VideoPlaybackState> state = VideoPlaybackState.stopped.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = false.obs;

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxDouble volume = 1.0.obs;
  final RxDouble speed = 1.0.obs;
  final RxInt completedTick = 0.obs;
  bool _completedOnce = false;

  MediaItem? _currentItem;
  MediaVariant? _currentVariant;
  final Rxn<MediaItem> currentItem = Rxn<MediaItem>();
  final Rxn<MediaVariant> currentVariant = Rxn<MediaVariant>();

  vp.VideoPlayerController? _player;
  Timer? _posTimer;

  bool get hasSourceLoaded => _player != null;

  String? resolveVideoSource(MediaItem item, MediaVariant variant) {
    if (!variant.isValid) return null;

    final localPath = variant.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      return localPath;
    }

    final fileId = item.fileId.trim();
    final format = variant.format.trim();
    if (fileId.isEmpty || format.isEmpty) return null;
    return '${ApiConfig.baseUrl}/api/v1/media/file/$fileId/video/$format';
  }

  bool isSameVideo(MediaItem item, MediaVariant v) {
    return _currentItem?.id == item.id &&
        _currentVariant?.format == v.format &&
        _currentVariant?.kind == v.kind;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (Get.isRegistered<PlaybackSettingsController>()) {
      final settings = Get.find<PlaybackSettingsController>();
      setVolume(settings.defaultVolume.value / 100);
    }
    _restoreLastItem();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _history.intent(PlaybackTermination.appShutdown);
    _history.select(null);
    unawaited(_flushEngineHistory());
    _posTimer?.cancel();
    _player?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_flushEngineHistory());
  }

  // ===========================================================================
  // PLAYBACK CONTROL
  // ===========================================================================

  Future<void> play(
    MediaItem item,
    MediaVariant variant, {
    PlaybackTermination replacementReason = PlaybackTermination.manualSelection,
  }) async {
    if (!variant.isValid) {
      throw Exception('No existe archivo para reproducir (variant inválido).');
    }

    final sameTrack = isSameVideo(item, variant);
    if (sameTrack && hasSourceLoaded) {
      if (!isPlaying.value) await _player?.play();
      return;
    }

    // Detener reproductor anterior
    _history.intent(replacementReason);
    await _disposePlayer();

    // UI inmediato
    isLoading.value = true;
    isPlaying.value = false;
    state.value = VideoPlaybackState.loading;
    _completedOnce = false;

    // -----------------------------------------------------------------------
    // ✅ LOCAL
    // -----------------------------------------------------------------------
    final localPath = variant.localPath?.trim();
    final hasLocal = localPath != null && localPath.isNotEmpty;

    String? videoUrl;

    if (hasLocal) {
      final f = File(localPath);
      if (!await f.exists()) {
        // debug útil
        print('❌ Local video file not found');
        print('fileName = ${variant.fileName}');
        print('localPath = ${variant.localPath}');
        print('using path = $localPath');

        isLoading.value = false;
        isPlaying.value = false;
        state.value = VideoPlaybackState.stopped;

        throw Exception('Archivo local no encontrado: $localPath');
      }

      try {
        videoUrl = Uri.file(localPath).toString();
        print('🎬 Playing local video: $videoUrl');

        _player = vp.VideoPlayerController.file(
          File(localPath),
          videoPlayerOptions: vp.VideoPlayerOptions(
            allowBackgroundPlayback: true,
          ),
        );

        await _player!.initialize().timeout(const Duration(seconds: 12));
        final v = _player!.value;
        print(
          '🎥 LOCAL init=${v.isInitialized} '
          'size=${v.size} '
          'dur=${v.duration} '
          'buffering=${v.isBuffering} '
          'error=${v.hasError ? v.errorDescription : "none"}',
        );
        _currentItem = item;
        _currentVariant = variant;
        currentItem.value = item;
        currentVariant.value = variant;
        _persistLastItem(item, variant);
        _keepLastItem = true;

        _setupPlayerListener();

        duration.value = _player!.value.duration;
        await _player!.setVolume(volume.value);
        await _player!.setPlaybackSpeed(speed.value);
        await _player!.play();
        isPlaying.value = true;
        state.value = VideoPlaybackState.playing;

        return;
      } catch (e) {
        _history.intent(PlaybackTermination.engineError);
        await _disposePlayer();
        isLoading.value = false;
        isPlaying.value = false;
        state.value = VideoPlaybackState.stopped;

        print('❌ Error playing local video: $e');
        throw Exception('Error al reproducir video local: $e');
      } finally {
        isLoading.value = false;
      }
    }

    // -----------------------------------------------------------------------
    // 🌐 REMOTO (backend)
    // -----------------------------------------------------------------------
    final fileId = item.fileId.trim();
    final format = variant.format.trim();

    if (fileId.isEmpty || format.isEmpty) {
      isLoading.value = false;
      isPlaying.value = false;
      state.value = VideoPlaybackState.stopped;

      throw Exception(
        'Faltan datos para reproducción remota (fileId o format vacíos)',
      );
    }

    videoUrl = '${ApiConfig.baseUrl}/api/v1/media/file/$fileId/video/$format';

    print('🎬 VideoService.play (remote)');
    print('🌐 Video URL: $videoUrl');

    try {
      _player = vp.VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: vp.VideoPlayerOptions(
          allowBackgroundPlayback: true,
        ),
      );

      await _player!.initialize().timeout(const Duration(seconds: 12));

      _currentItem = item;
      _currentVariant = variant;
      currentItem.value = item;
      currentVariant.value = variant;
      _persistLastItem(item, variant);
      _keepLastItem = true;

      _setupPlayerListener();

      duration.value = _player!.value.duration;
      await _player!.setVolume(volume.value);
      await _player!.setPlaybackSpeed(speed.value);
      await _player!.play();
      isPlaying.value = true;
      state.value = VideoPlaybackState.playing;
    } catch (e) {
      _history.intent(PlaybackTermination.engineError);
      _history.select(null);
      await _disposePlayer();
      isLoading.value = false;
      isPlaying.value = false;
      state.value = VideoPlaybackState.stopped;

      print('❌ Error playing remote video: $e');
      throw Exception('Error al reproducir video remoto: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _setupPlayerListener() {
    _posTimer?.cancel();
    _posTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_player == null) return;
      final v = _player!.value;
      if (v.hasError) {
        _history.intent(PlaybackTermination.engineError);
        _history.select(null);
        unawaited(_flushEngineHistory());
        return;
      }
      _history.select(currentItem.value, variant: currentVariant.value);
      _history.update(
        position: v.position,
        duration: v.duration,
        playing: v.isPlaying && !v.isBuffering,
        speed: v.playbackSpeed,
        buffering: v.isBuffering,
        completed: v.isCompleted,
      );
      position.value = v.position;
      isPlaying.value = v.isPlaying;
      duration.value = v.duration;

      if (v.isPlaying) {
        state.value = VideoPlaybackState.playing;
      } else {
        state.value = VideoPlaybackState.paused;
      }

      final d = v.duration;
      final completed =
          d > Duration.zero &&
          v.position >= d - const Duration(milliseconds: 200);
      if (!_completedOnce && completed) {
        _completedOnce = true;
        completedTick.value++;
      }
    });
  }

  Future<void> _disposePlayer() async {
    await _flushEngineHistory();
    _history.select(null);
    _posTimer?.cancel();
    _posTimer = null;

    if (_player != null) {
      try {
        await _player!.pause();
      } catch (_) {}
      try {
        await _player!.dispose();
      } catch (_) {}
      _player = null;
    }

    position.value = Duration.zero;
    duration.value = Duration.zero;
    if (_keepLastItem) {
      state.value = VideoPlaybackState.paused;
      isPlaying.value = false;
    } else {
      _currentItem = null;
      _currentVariant = null;
      currentItem.value = null;
      currentVariant.value = null;
    }
  }

  Future<void> toggle() async {
    if (_player == null) {
      print('❌ No video loaded. Call play(item, variant) first.');
      return;
    }

    if (_player!.value.isPlaying) {
      await _player!.pause();
      state.value = VideoPlaybackState.paused;
    } else {
      await _player!.play();
      state.value = VideoPlaybackState.playing;
    }
  }

  Future<void> pause() async {
    if (_player == null) return;
    await _player!.pause();
    await _flushEngineHistory();
    state.value = VideoPlaybackState.paused;
  }

  Future<void> resume() async {
    if (_player == null) return;
    await _player!.play();
    state.value = VideoPlaybackState.playing;
  }

  Future<void> seek(Duration position) async {
    if (_player == null) return;
    _history.beforeSeek(position);
    try {
      await _player!.seekTo(position);
    } finally {
      final value = _player?.value;
      _history.afterSeek(
        playing: value != null && value.isPlaying && !value.isBuffering,
      );
    }
  }

  Future<void> replay() async {
    if (_player == null) return;
    _history.intent(PlaybackTermination.explicitStop);
    _history.select(null);
    _history.select(currentItem.value, variant: currentVariant.value);
    await _player!.seekTo(Duration.zero);
    await _player!.play();
    state.value = VideoPlaybackState.playing;
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    volume.value = clamped;
    await _player?.setVolume(clamped);
  }

  Future<void> setSpeed(double v) async {
    final clamped = v.clamp(0.5, 2.0);
    speed.value = clamped;
    await _player?.setPlaybackSpeed(clamped);
  }

  Future<void> stop() async {
    _history.intent(PlaybackTermination.explicitStop);
    await _disposePlayer();
    state.value = VideoPlaybackState.stopped;
    _keepLastItem = false;
  }

  void clearLastItem() {
    _storage.remove(_lastItemKey);
    _storage.remove(_lastVariantKey);
    _keepLastItem = false;
  }

  void _persistLastItem(MediaItem item, MediaVariant variant) {
    _storage.write(_lastItemKey, item.toJson());
    _storage.write(_lastVariantKey, variant.toJson());
  }

  void _restoreLastItem() {
    final rawItem = _storage.read<Map>(_lastItemKey);
    if (rawItem == null) return;
    try {
      final item = MediaItem.fromJson(Map<String, dynamic>.from(rawItem));
      final rawVariant = _storage.read<Map>(_lastVariantKey);
      MediaVariant? variant;
      if (rawVariant != null) {
        variant = MediaVariant.fromJson(Map<String, dynamic>.from(rawVariant));
      }

      _currentItem = item;
      _currentVariant = variant;
      currentItem.value = item;
      currentVariant.value = variant;
      state.value = VideoPlaybackState.paused;
      isPlaying.value = false;
      _keepLastItem = true;
    } catch (_) {
      // ignore restore failures
    }
  }

  // Getter para acceso al controlador si es necesario en UI
  vp.VideoPlayerController? get playerController => _player;
}
