import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../../../settings/controller/playback_settings_controller.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/services/spatial_audio_service.dart';

enum CoverStyle { square, vinyl, wave, miniSpectrum }

enum RepeatMode { off, once, loop }

class AudioPlayerController extends GetxController {
  final AudioService audioService;
  final SpatialAudioService _spatial = Get.find<SpatialAudioService>();
  final PlaybackSettingsController _settings =
      Get.find<PlaybackSettingsController>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final GetStorage _storage = GetStorage();
  static const _repeatModeKey = 'audio_repeat_mode';
  static const _countThreshold = Duration(seconds: 15);

  AudioPlayerController({required this.audioService});

  final RxList<MediaItem> queue = <MediaItem>[].obs;
  final RxInt currentIndex = 0.obs;

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;

  final RxBool isShuffling = false.obs;
  final Rx<RepeatMode> repeatMode = RepeatMode.off.obs;
  final Rx<CoverStyle> coverStyle = CoverStyle.square.obs;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<ProcessingState>? _procSub;
  Worker? _itemWorker;
  bool _countedCurrentSession = false;
  String _currentSessionTrackKey = '';
  bool _handlingCompleted = false;
  bool _endActionHandledForTrack = false;
  String _endActionTrackKey = '';

  Rx<SpatialAudioMode> get spatialMode => _spatial.mode;

  @override
  void onInit() {
    super.onInit();

    isShuffling.value = audioService.shuffleEnabled;
    _restoreRepeatMode();

    _posSub = audioService.positionStream.listen((v) {
      position.value = v;
      _maybeCountPlayback();
      _maybeApplyAutoPlayNextPolicy();
    });
    _durSub = audioService.durationStream.listen((v) {
      if (v != null && v > Duration.zero) {
        duration.value = v;
        return;
      }
      _applyDurationFallbackFromCurrentItem();
    });
    _procSub = audioService.processingStateStream.listen((state) async {
      if (state != ProcessingState.completed) return;
      if (_handlingCompleted) return;
      _handlingCompleted = true;
      try {
        if (_settings.autoPlayNext.value) {
          await next();
        } else {
          await audioService.pause();
        }
      } finally {
        await Future.delayed(const Duration(milliseconds: 200));
        _handlingCompleted = false;
      }
    });

    _itemWorker = ever<MediaItem?>(audioService.currentItem, (_) {
      _resetCountSession();
      _resetAutoPauseSession();
      _syncFromService();
      _applyDurationFallbackFromCurrentItem();
    });

    _syncFromService();
    _resetCountSession();
  }

  @override
  void onClose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _procSub?.cancel();
    _itemWorker?.dispose();
    super.onClose();
  }

  void applyRouteArgs(dynamic args) {
    if (audioService.resumePromptPending) {
      unawaited(_handleResumePrompt(args));
      return;
    }

    if (args is! Map) return;
    final rawQueue = args['queue'];
    final rawIndex = args['index'];

    final items = _extractItems(rawQueue);
    if (items.isEmpty) return;

    queue.assignAll(items);
    currentIndex.value = (rawIndex is int ? rawIndex : 0)
        .clamp(0, items.length - 1)
        .toInt();

    _playCurrent(forceReload: true);
  }

  Future<bool> _handleResumePrompt(dynamic args) async {
    final resume = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Continuar reproducción'),
        content: const Text(
          'Cerraste la notificación. ¿Deseas continuar desde donde se quedó?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Sí'),
          ),
        ],
      ),
      barrierDismissible: true,
    );

    if (resume == true) {
      final ok = await audioService.restorePersistedSession(autoPlay: true);
      if (ok) {
        _syncFromService();
        _resetCountSession();
        _resetAutoPauseSession();
        return true;
      }
    }

    await audioService.dismissResumePrompt(discardSession: true);

    if (args is! Map) return true;
    final rawQueue = args['queue'];
    final rawIndex = args['index'];
    final items = _extractItems(rawQueue);
    if (items.isEmpty) return true;
    queue.assignAll(items);
    currentIndex.value = (rawIndex is int ? rawIndex : 0)
        .clamp(0, items.length - 1)
        .toInt();
    return true;
  }

  List<MediaItem> _extractItems(dynamic rawQueue) {
    if (rawQueue is List<MediaItem>) return rawQueue;
    if (rawQueue is List) return rawQueue.whereType<MediaItem>().toList();
    return <MediaItem>[];
  }

  MediaItem? get currentItemOrNull {
    if (queue.isEmpty) return null;
    final idx = currentIndex.value;
    if (idx < 0 || idx >= queue.length) return null;
    return queue[idx];
  }

  MediaVariant? _resolveAudioVariant(MediaItem item) {
    for (final v in item.variants) {
      if (v.kind == MediaVariantKind.audio && v.isValid) return v;
    }
    return null;
  }

  Future<void> _playCurrent({bool forceReload = false}) async {
    final item = currentItemOrNull;
    if (item == null) return;
    final variant = _resolveAudioVariant(item);
    if (variant == null) return;

    await audioService.play(
      item,
      variant,
      autoPlay: true,
      queue: queue.toList(),
      queueIndex: currentIndex.value,
      forceReload: forceReload,
    );

    _syncFromService();
  }

  Future<void> togglePlay() async {
    final item = currentItemOrNull;
    final variant = item == null ? null : _resolveAudioVariant(item);
    if (item == null || variant == null) return;

    if (audioService.hasSourceLoaded &&
        audioService.isSameTrack(item, variant)) {
      await audioService.toggle();
      return;
    }

    if (audioService.resumePromptPending) {
      final handled = await _handleResumePrompt(Get.arguments);
      _syncFromService();
      if (handled) return;
    }

    if (!audioService.hasSourceLoaded ||
        !audioService.isSameTrack(item, variant)) {
      await _playCurrent(forceReload: true);
      return;
    }

    await audioService.toggle();
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;
    currentIndex.value = index;
    if (audioService.hasSourceLoaded &&
        _sameQueue(queue, audioService.queueItems)) {
      await audioService.jumpToQueueIndex(index);
      _syncFromService();
      return;
    }
    await _playCurrent(forceReload: true);
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    final before = currentIndex.value;
    final fallback = currentIndex.value + 1;
    await audioService.next();
    _syncFromService();
    if (currentIndex.value != before) return;
    if (audioService.currentQueueIndex == currentIndex.value &&
        fallback >= 0 &&
        fallback < queue.length) {
      await playAt(fallback);
    }
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    final before = currentIndex.value;
    final fallback = currentIndex.value - 1;
    await audioService.previous();
    _syncFromService();
    if (currentIndex.value != before) return;
    if (audioService.currentQueueIndex == currentIndex.value &&
        fallback >= 0 &&
        fallback < queue.length) {
      await playAt(fallback);
    }
  }

  Future<void> seek(Duration value) => audioService.seek(value);

  Future<void> skipForward10() async {
    final target = position.value + const Duration(seconds: 10);
    final max = duration.value;
    await seek(target > max ? max : target);
  }

  Future<void> skipBackward10() async {
    final target = position.value - const Duration(seconds: 10);
    await seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex > queue.length) return;

    if (newIndex > oldIndex) newIndex -= 1;

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

    final wasPlaying = audioService.isPlaying.value;
    final pos = position.value;
    await _playCurrent(forceReload: true);
    if (pos > Duration.zero) {
      await audioService.seek(pos);
    }
    if (!wasPlaying) {
      await audioService.pause();
    }
  }

  void addToQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    queue.addAll(items);
  }

  void insertNext(List<MediaItem> items) {
    if (items.isEmpty) return;
    final insertAt = (currentIndex.value + 1).clamp(0, queue.length);
    queue.insertAll(insertAt, items);
  }

  void _syncFromService() {
    final serviceQueue = audioService.queueItems;
    if (serviceQueue.isNotEmpty) {
      queue.assignAll(serviceQueue);
      final idx = audioService.currentQueueIndex;
      if (idx >= 0 && idx < queue.length) {
        currentIndex.value = idx;
      }
      return;
    }

    final current = audioService.currentItem.value;
    if (current == null || queue.isEmpty) return;

    final idx = queue.indexWhere((e) {
      if (e.id == current.id) return true;
      final ap = e.publicId.trim();
      final bp = current.publicId.trim();
      return ap.isNotEmpty && bp.isNotEmpty && ap == bp;
    });
    if (idx >= 0) currentIndex.value = idx;
  }

  void _applyDurationFallbackFromCurrentItem() {
    final sec = audioService.currentItem.value?.effectiveDurationSeconds ?? 0;
    if (sec > 0) {
      duration.value = Duration(seconds: sec);
    } else {
      duration.value = Duration.zero;
    }
  }

  bool _sameQueue(List<MediaItem> a, List<MediaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id == b[i].id) continue;
      final ap = a[i].publicId.trim();
      final bp = b[i].publicId.trim();
      if (ap.isEmpty || bp.isEmpty || ap != bp) return false;
    }
    return true;
  }

  Future<void> setSpatialMode(SpatialAudioMode mode) async {
    await _spatial.setMode(mode);
  }

  void toggleCoverStyle() {
    final all = CoverStyle.values;
    final idx = all.indexOf(coverStyle.value);
    final next = (idx + 1) % all.length;
    coverStyle.value = all[next];
  }

  void setCoverStyle(CoverStyle style) {
    coverStyle.value = style;
  }

  Future<void> toggleShuffle() async {
    isShuffling.value = !isShuffling.value;
    await audioService.setShuffle(isShuffling.value);
    _syncFromService();
  }

  Future<void> toggleRepeatOnce() async {
    repeatMode.value = repeatMode.value == RepeatMode.once
        ? RepeatMode.off
        : RepeatMode.once;
    _storage.write(_repeatModeKey, repeatMode.value.name);
    if (repeatMode.value == RepeatMode.once) {
      await audioService.setLoopOne();
    } else {
      await audioService.setLoopOff();
    }
  }

  Future<void> toggleRepeatLoop() async {
    repeatMode.value = repeatMode.value == RepeatMode.loop
        ? RepeatMode.off
        : RepeatMode.loop;
    _storage.write(_repeatModeKey, repeatMode.value.name);
    if (repeatMode.value == RepeatMode.loop) {
      await audioService.setLoopOne();
    } else {
      await audioService.setLoopOff();
    }
  }

  Future<void> cyclePlaybackSpeed() async {
    const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final current = audioService.speed.value;
    final idx = presets.indexWhere((e) => e == current);
    final next = presets[(idx + 1) % presets.length];
    await audioService.setSpeed(next);
  }

  Future<void> _trackPlay(MediaItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final all = await _store.readAll();

    MediaItem updated = item.copyWith(
      playCount: item.playCount + 1,
      lastPlayedAt: now,
    );

    for (final existing in all) {
      if (existing.id == item.id ||
          (item.publicId.trim().isNotEmpty &&
              existing.publicId.trim() == item.publicId.trim())) {
        updated = existing.copyWith(
          playCount: existing.playCount + 1,
          lastPlayedAt: now,
        );
        break;
      }
    }

    await _store.upsert(updated);
  }

  void _resetCountSession() {
    final item = audioService.currentItem.value;
    if (item == null) {
      _currentSessionTrackKey = '';
      _countedCurrentSession = false;
      return;
    }

    final key = item.publicId.trim().isNotEmpty
        ? item.publicId.trim()
        : item.id.trim();

    if (_currentSessionTrackKey != key) {
      _currentSessionTrackKey = key;
      _countedCurrentSession = false;
    }
  }

  void _maybeCountPlayback() {
    if (_countedCurrentSession) return;
    if (!audioService.isPlaying.value) return;
    if (position.value < _countThreshold) return;

    final item = audioService.currentItem.value;
    if (item == null) return;
    _countedCurrentSession = true;
    unawaited(_trackPlay(item));
  }

  void _resetAutoPauseSession() {
    final item = audioService.currentItem.value;
    if (item == null) {
      _endActionTrackKey = '';
      _endActionHandledForTrack = false;
      return;
    }

    final key = item.publicId.trim().isNotEmpty
        ? item.publicId.trim()
        : item.id.trim();

    if (_endActionTrackKey != key) {
      _endActionTrackKey = key;
      _endActionHandledForTrack = false;
    }
  }

  void _maybeApplyAutoPlayNextPolicy() {
    if (!audioService.isPlaying.value) return;

    final item = audioService.currentItem.value;
    if (item == null) return;

    final key = item.publicId.trim().isNotEmpty
        ? item.publicId.trim()
        : item.id.trim();
    if (_endActionTrackKey != key) {
      _endActionTrackKey = key;
      _endActionHandledForTrack = false;
    }

    if (_endActionHandledForTrack) return;
    if (duration.value <= Duration.zero) return;

    if (_settings.autoPlayNext.value) {
      final secs = audioService.crossfadeSeconds.value;
      if (secs <= 0) return;
      final transitionMargin = Duration(seconds: secs.clamp(1, 12));
      if (position.value >= duration.value - transitionMargin) {
        _endActionHandledForTrack = true;
        unawaited(audioService.next(withTransition: true));
      }
      return;
    }

    const pauseMargin = Duration(milliseconds: 350);
    if (position.value >= duration.value - pauseMargin) {
      _endActionHandledForTrack = true;
      unawaited(audioService.pause());
    }
  }

  void _restoreRepeatMode() {
    final raw = _storage.read<String>(_repeatModeKey);
    if (raw == RepeatMode.once.name) {
      repeatMode.value = RepeatMode.once;
      audioService.setLoopOne();
      return;
    }
    if (raw == RepeatMode.loop.name) {
      repeatMode.value = RepeatMode.loop;
      audioService.setLoopOne();
      return;
    }
    repeatMode.value = RepeatMode.off;
    audioService.setLoopOff();
  }
}
