import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../../app/models/media_item.dart';
import '../../../../app/services/video_service.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../settings/controller/playback_settings_controller.dart';

class VideoPlayerController extends GetxController {
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

  static const queueStorageKey = 'video_queue_items';
  static const queueIndexStorageKey = 'video_queue_index';
  static const resumePosStorageKey = 'video_resume_positions';

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

    _completedWorker = ever<int>(videoService.completedTick, (_) async {
      if (!_settings.autoPlayNext.value) return;
      await next();
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final all = await _store.readAll();

    MediaItem updated = item.copyWith(
      playCount: item.playCount + 1,
      lastPlayedAt: now,
    );

    for (final existing in all) {
      if (existing.id == item.id ||
          (item.publicId.isNotEmpty && existing.publicId == item.publicId)) {
        updated = existing.copyWith(
          playCount: existing.playCount + 1,
          lastPlayedAt: now,
        );
        break;
      }
    }

    await _store.upsert(updated);
  }

  Future<void> togglePlay() async {
    await videoService.toggle();
  }

  Future<void> seek(Duration value) async {
    await videoService.seek(value);
  }

  Future<void> next() async {
    if (currentIndex.value < queue.length - 1) {
      currentIndex.value++;
      await _playCurrent();
    }
  }

  Future<void> previous() async {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      await _playCurrent();
    }
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;
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
    if (key.trim().isNotEmpty) {
      final map = _storage.read<Map>(resumePosStorageKey);
      final next = <String, dynamic>{};
      if (map != null) {
        for (final entry in map.entries) {
          next[entry.key.toString()] = entry.value;
        }
      }
      final ms = p.inMilliseconds;
      if (ms <= 1000) {
        next.remove(key);
      } else {
        next[key] = ms;
      }
      _storage.write(resumePosStorageKey, next);
    }
  }

  Future<void> _resumeIfAny(MediaItem item) async {
    final key = item.publicId.isNotEmpty ? item.publicId : item.id;
    final map = _storage.read<Map>(resumePosStorageKey);
    if (map == null) return;
    final raw = map[key];
    if (raw is! int) return;
    if (raw < 1500) return;

    try {
      Duration d = videoService.duration.value;
      for (var i = 0; i < 10 && d == Duration.zero; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        d = videoService.duration.value;
      }
      if (d == Duration.zero) return;

      final resume = Duration(milliseconds: raw);
      if (resume < d - const Duration(seconds: 2)) {
        await videoService.seek(resume);
      }
    } catch (_) {
      // ignore resume failures
    }
  }

  @override
  void onClose() {
    _persistQueue();
    _persistPosition(position.value);
    _positionWorker?.dispose();
    _completedWorker?.dispose();
    _queueWorker?.dispose();
    _indexWorker?.dispose();
    super.onClose();
  }
}
